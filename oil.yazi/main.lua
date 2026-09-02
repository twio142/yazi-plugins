--- @diagnostic disable: undefined-global
--- @since 26.08.15
_G.ya = _G.ya or {}
_G.cx = _G.cx or {}

local M = {}

-- Items trashed by the last `delete`, kept as plain strings so they survive the
-- async/sync boundary. `put` moves them back out.
local stash = ya.sync(function(st, items)
	if items ~= nil then
		st.trashed = items
	end
	return st.trashed or {}
end)

-- Trash entries are keyed by their backing path, which is unique per item --
-- the trash renames colliding names ("a.txt", "a 2.txt"). Diffing the backing
-- set before/after a removal therefore identifies exactly the batch we just
-- trashed, even when several items share one original path.
local function backing_set()
	local entries, err = fs.trash.list()
	if not entries then
		return nil, err
	end
	local set = {}
	for _, e in ipairs(entries) do
		set[tostring(e.backing)] = true
	end
	return set
end

local function trashed_since(before)
	local entries, err = fs.trash.list()
	if not entries then
		return nil, err
	end
	local added = {}
	for _, e in ipairs(entries) do
		local backing = tostring(e.backing)
		if not before[backing] then
			added[#added + 1] = { backing = backing, name = tostring(e.name), is_dir = e.cha.is_dir }
		end
	end
	return added
end

M.delete = function(state)
	if state.cwd:match("^sftp://") then
		ya.emit("remove", {})
		return
	end
	local count = math.max(1, #state.selected)
	local title = string.format("Trash %d selected item%s?", count, count > 1 and "s" or "")
	local body = #state.selected > 0 and state.selected or (state.hovered or "")
	local confirmed = ya.confirm({
		pos = { "center", w = 60, h = 20 },
		title = title,
		body = ui.Text(body):align(ui.Align.LEFT),
	})
	if not confirmed then
		return
	end

	local before, err = backing_set()
	if not before then
		ya.notify({ title = "Trash", content = "Cannot read trash: " .. tostring(err), level = "error", timeout = 5 })
		return
	end

	ya.emit("remove", { force = true })
	ya.emit("unyank", {})
	ya.emit("escape", {})

	-- `remove` is queued as a background task, so poll until the new entries land.
	local added, deadline = {}, ya.time() + 5
	repeat
		ya.sleep(0.05)
		added = trashed_since(before) or added
	until #added >= count or ya.time() > deadline

	stash(added)
	if #added < count then
		ya.notify({
			title = "Trash",
			content = ("Only %d of %d item%s reached the trash"):format(#added, count, count > 1 and "s" or ""),
			level = "warn",
			timeout = 4,
		})
	end
end

M.put = function(state)
	if #state.yanked > 0 then
		ya.emit("paste", {})
		ya.emit("unyank", {})
		return
	end

	local items = stash()
	if #items == 0 then
		ya.emit("paste", {})
		ya.emit("unyank", {})
		return
	end

	local target_dir
	if state.hovered then
		target_dir = state.hovered_is_dir and Url(state.hovered) or Url(state.hovered).parent
	else
		target_dir = Url(state.cwd)
	end

	local first, failed = nil, {}
	for _, it in ipairs(items) do
		local from = Url(it.backing)
		if not fs.cha(from) then
			failed[#failed + 1] = it.name
		else
			local target = fs.unique(it.is_dir and "dir" or "file", target_dir:join(it.name))
			local ok = fs.rename(from, target)
			if not ok then
				-- `rename` can't cross filesystems; fall back to a real move.
				local status = Command("mv"):arg({ tostring(from), tostring(target) }):spawn():wait()
				ok = status and status.code == 0
			end
			if ok then
				first = first or target
			else
				failed[#failed + 1] = it.name
			end
		end
	end

	stash({})

	if #failed > 0 then
		ya.notify({
			title = "Files not recovered from trash:",
			content = table.concat(failed, "\n"),
			level = "warn",
			timeout = 3,
		})
	end
	if first then
		ya.emit("reveal", { first })
	end
end

M.yank = function()
	stash({})
	ya.emit("yank", {})
end

local function notify(content, level)
	ya.notify({ title = "Create", content = content, level = level or "error", timeout = 5 })
end

-- Bash-style brace expansion: `{a,b}` lists, `{1..9}` / `{a..e}` / `{0..20..5}`
-- sequences, nesting, and `\{` escapes. Purely textual -- nothing here touches
-- the filesystem, so the generated names need not exist yet.
local BRACE_LIMIT = 512

local function brace_open(s, from)
	local i = from
	while i <= #s do
		local c = s:sub(i, i)
		if c == "\\" then
			i = i + 1
		elseif c == "{" then
			return i
		end
		i = i + 1
	end
end

local function brace_close(s, open)
	local depth, i = 0, open
	while i <= #s do
		local c = s:sub(i, i)
		if c == "\\" then
			i = i + 1
		elseif c == "{" then
			depth = depth + 1
		elseif c == "}" then
			depth = depth - 1
			if depth == 0 then
				return i
			end
		end
		i = i + 1
	end
end

-- Splits on top-level commas only, so `{a,{b,c}}` keeps the inner list intact.
local function brace_list(body)
	local parts, depth, start, i = {}, 0, 1, 1
	while i <= #body do
		local c = body:sub(i, i)
		if c == "\\" then
			i = i + 1
		elseif c == "{" then
			depth = depth + 1
		elseif c == "}" then
			depth = depth - 1
		elseif c == "," and depth == 0 then
			parts[#parts + 1] = body:sub(start, i - 1)
			start = i + 1
		end
		i = i + 1
	end
	if #parts == 0 then
		return nil
	end
	parts[#parts + 1] = body:sub(start)
	return parts
end

local function brace_range(from, to, step, fmt)
	local items = {}
	step = math.abs(step)
	if step == 0 then
		step = 1
	end
	if from > to then
		step = -step
	end
	for n = from, to, step do
		if #items > BRACE_LIMIT then
			break
		end
		items[#items + 1] = fmt(n)
	end
	return items
end

local function brace_seq(body)
	local a, b, step = body:match("^(%-?%d+)%.%.(%-?%d+)%.%.(%-?%d+)$")
	if not a then
		a, b = body:match("^(%-?%d+)%.%.(%-?%d+)$")
	end
	if a then
		-- bash pads the whole range when either endpoint carries a leading zero
		local width = 0
		if a:match("^%-?0%d") or b:match("^%-?0%d") then
			width = math.max(#a, #b)
		end
		return brace_range(tonumber(a), tonumber(b), tonumber(step) or 1, function(n)
			return width > 0 and ("%0" .. width .. "d"):format(n) or tostring(n)
		end)
	end

	local ca, cb
	ca, cb, step = body:match("^(%a)%.%.(%a)%.%.(%-?%d+)$")
	if not ca then
		ca, cb = body:match("^(%a)%.%.(%a)$")
	end
	if ca then
		return brace_range(ca:byte(), cb:byte(), tonumber(step) or 1, string.char)
	end
end

local function brace_expand(s, out)
	out = out or {}
	local from = 1
	while true do
		if #out > BRACE_LIMIT then
			return out
		end
		local open = brace_open(s, from)
		if not open then
			out[#out + 1] = s
			return out
		end
		local close = brace_close(s, open)
		local body = close and s:sub(open + 1, close - 1)
		local items = body and (brace_list(body) or brace_seq(body))
		if items then
			local pre, post = s:sub(1, open - 1), s:sub(close + 1)
			for _, item in ipairs(items) do
				brace_expand(pre .. item .. post, out)
			end
			return out
		end
		-- `{}`, `{a}` or an unbalanced brace: literal, keep looking after it
		from = open + 1
	end
end

M.add = function(state)
	if state.cwd:match("^sftp://") then
		ya.emit("create", {})
		return
	end
	local value, event = ya.input({
		title = "Create:",
		pos = { "hovered", w = 50, x = 13, y = 1 },
	})
	if event ~= 1 or value == "" then
		return
	end

	local expanded = brace_expand(value)
	if #expanded > BRACE_LIMIT then
		notify(("Brace expansion yields more than %d items"):format(BRACE_LIMIT), "warn")
		return
	end

	local items = {}
	for _, item in ipairs(expanded) do
		item = item:gsub("\\([{},\\])", "%1")
		if item ~= "" and item ~= "/" then
			items[#items + 1] = item
		end
	end
	if #items == 0 then
		return
	end

	-- The braces produced several names: show the whole list before creating anything.
	if #items > 1 then
		local confirmed = ya.confirm({
			pos = { "center", w = 60, h = math.min(#items + 4, 20) },
			title = ("Create %d items?"):format(#items),
			body = ui.Text(items):align(ui.Align.LEFT),
		})
		if not confirmed then
			return
		end
	end

	local cwd, first, failed = state.cwd, nil, {}
	for _, item in ipairs(items) do
		-- a `/` in the name creates parent directories as needed
		-- a `/` at the end makes the item itself a directory
		local dir = item:match("(.+/)")
		local last_part = item:match("([^/]+)$")
		local ok = true
		if dir then
			local status = Command("mkdir"):arg({ "-p", dir }):cwd(cwd):spawn():wait()
			ok = status and status.code == 0
		end
		if ok and last_part then
			local status = Command("touch"):arg(item):cwd(cwd):spawn():wait()
			ok = status and status.code == 0
		end
		if ok then
			first = first or item
		else
			failed[#failed + 1] = item
		end
	end

	if #failed > 0 then
		notify("Could not create:\n" .. table.concat(failed, "\n"))
	end
	if first then
		ya.emit("reveal", { cwd .. "/" .. first })
	end
end

M.shell = function(state)
	local cwd = state.cwd
	local title = "Shell"
	local domain
	if cwd:match("^sftp://") then
		domain = Url(cwd).spec.domain
		title = title .. " (" .. domain .. ")"
		cwd = tostring(Url(cwd).path)
	end
	local value, event = ya.input({
		realtime = false,
		title = title .. ":",
		pos = { "top-center", w = 50, x = 0, y = 2 },
		history = "yazi-oil",
	})
	if event == 1 then
		if #state.selected == 0 and state.hovered then
			state.selected = { state.hovered }
		end
		local child
		if domain then
			child = Command("/usr/bin/ssh")
				:arg({ domain, "cd", cwd, ";" })
				:arg({ value, state.hovered and tostring(Url(state.hovered).path) or "" })
			for _, file in pairs(state.selected) do
				child:arg({ tostring(Url(file).path) })
			end
		else
			child = Command(os.getenv("SHELL") or "/bin/zsh")
				:arg({ "-lic", value, state.hovered })
				:arg(state.selected)
				:cwd(cwd)
		end
		child:stdout(Command.PIPED):stderr(Command.PIPED)
		local output = child:output()
		ya.dbg(output)
		if output then
			local stdout = output.stdout:gsub("\n$", "")
			local stderr = output.stderr:gsub("\n$", "")
			local status = output.status.code
			if status ~= 0 and stderr ~= "" then
				ya.notify({ title = title .. " Error", content = stderr, timeout = 2, level = "error" })
			elseif stdout ~= "" then
				ya.notify({ title = title, content = stdout, timeout = 2 })
			end
		end
	end
end

M.shell_block = function()
	local value, event = ya.input({
		realtime = false,
		title = "Shell: 󰞌",
		pos = { "top-center", w = 50, x = 0, y = 2 },
		history = "yazi-oil",
	})
	if event == 1 then
		local script = "/tmp/yazi_shell.sh"
		local f = io.open(script, "w")
		if not f then
			return
		end
		f:write(value)
		f:close()
		ya.emit("shell", { ("$SHELL -li %s %%s"):format(script), block = true })
	end
end

local state = ya.sync(function()
	local selected = {}
	for _, file in pairs(cx.active.selected) do
		table.insert(selected, tostring(file.url))
	end
	local yanked = {}
	for _, file in pairs(cx.yanked) do
		table.insert(yanked, tostring(file.url))
	end
	return {
		cwd = tostring(cx.active.current.cwd),
		hovered = cx.active.current.hovered and tostring(cx.active.current.hovered.url) or nil,
		hovered_is_dir = cx.active.current.hovered and cx.active.current.hovered.cha.is_dir or nil,
		selected = selected,
		yanked = yanked,
	}
end)

return {
	entry = function(_, job)
		ya.emit("escape", { visual = true })
		local args = job.args
		local func = M[args[1]]
		if func ~= nil then
			local s = state()
			return func(s, table.unpack(args, 2))
		end
	end,
}
