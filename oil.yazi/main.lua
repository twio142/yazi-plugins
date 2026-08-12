--- @diagnostic disable: undefined-global
--- @since 26.08.11
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

M.add = function(state)
	if state.cwd:match("^sftp://") then
		ya.emit("create", {})
		return
	end
	local value, event = ya.input({
		title = "Create:",
		pos = { "hovered", w = 50, x = 13, y = 1 },
	})
	local cwd = state.cwd
	if event == 1 and value ~= "" then
		-- if value contains a `/`, create parent directories as needed
		-- if value ends with a `/`, create a directory
		local dir = value:match("(.+/)")
		local last_part = value:match("([^/]+)$")
		if dir then
			local status, err = Command("mkdir"):arg({ "-p", dir }):cwd(cwd):spawn():wait()
			if status.code ~= 0 then
				M.notify(_, tostring(err))
				return
			end
		end
		if last_part then
			local status, err = Command("touch"):arg(value):cwd(cwd):spawn():wait()
			if status.code ~= 0 then
				M.notify(_, tostring(err))
			end
			return ya.emit("reveal", { cwd .. "/" .. value })
		end
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
				:env("YAZI_OIL", "1")
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
	})
	if event == 1 then
		local script = "/tmp/yazi_shell.sh"
		local f = io.open(script, "w")
		if not f then
			return
		end
		f:write(value)
		f:close()
		ya.emit("shell", { ('YAZI_OIL=1 $SHELL -li %s %%s'):format(script), block = true })
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
