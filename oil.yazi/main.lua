--- @diagnostic disable: undefined-global
_G.ya = _G.ya or {}
_G.cx = _G.cx or {}

local M = {}

local cache_file = "/tmp/yazi_oil"
local is_linux = ya.target_os() == "linux"
local stat_cmd = is_linux and "stat -c '%i'" or "stat -f '%i'"
local trash_dir = is_linux and "~/.local/share/Trash/files" or "~/.Trash"

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
	if confirmed then
		ya.emit("shell", {
			([=[
				cache="%s"
				rm -f "$cache"

				for file in "$@"; do
					inode=$(%s "$file")
					[ -n "$inode" ] && echo "$inode	$(basename "$file")" >> "$cache"
				done
				ya emit remove --force
				ya emit unyank
				ya emit escape
			]=]):format(cache_file, stat_cmd),
		})
	end
end

M.put = function(state)
	if #state.yanked > 0 then
		ya.emit("paste", {})
		ya.emit("unyank", {})
		return
	end

	local scpt = ([=[
      cache="%s"
      [ -f "$cache" ] || { ya emit paste; ya emit unyank; exit 0; }

      trash_dir=%s
      [ -d "$trash_dir" ] || { ya emit paste; ya emit unyank; exit 0; }

      while read -r line; do
        IFS=$'\t' read -r inode name <<< "$line"
        file=$(find "$trash_dir" -inum "$inode" 2>/dev/null | head -n 1)
				[ -n "$file" ] && echo "$name	$file" || echo "$name	"
      done < "$cache"
    ]=]):format(cache_file, trash_dir)
	local child = Command("/bin/zsh"):arg({ "-lc", scpt }):stdout(Command.PIPED):spawn()
	local files = {}
	local not_found = {}
	while true do
		local line, event = child:read_line()
		if event ~= 0 then
			break
		end
		line = line:gsub("\n", "")
		local name, path = line:match("([^\t]*)\t(.*)")
		if path ~= "" then
			table.insert(files, { file = Url(path), name = name })
		else
			table.insert(not_found, name)
		end
	end
	if #not_found > 0 then
		ya.notify({
			title = "Files not found in trash:",
			content = table.concat(not_found, "\n"),
			level = "warn",
			timeout = 2,
		})
	end
	if #files > 0 then
		local target_dir
		if state.hovered then
			target_dir = state.hovered_is_dir and Url(state.hovered) or Url(state.hovered).parent
		else
			target_dir = Url(state.cwd)
		end

		local first
		for _, f in pairs(files) do
			local is_dir = fs.cha(f.file).is_dir
			local target = fs.unique(is_dir and "dir" or "file", target_dir:join(f.name))
			if is_dir then
				Command(is_linux and "mv" or "gmv"):arg({ "-T", tostring(f.file), tostring(target) }):spawn():wait()
			else
				fs.copy(f.file, target)
			end
			if not first then
				first = target
			end
		end
		ya.emit("reveal", { first })
	end
end

M.yank = function()
	ya.emit("shell", { "rm -f " .. cache_file })
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
	if cwd:match("^sftp://") then
		ya.notify({
			title = "Shell",
			content = "Only supported in local directory",
			timeout = 2,
			level = "warn",
		})
		return
	end
	local title = "Shell"
	local value, event = ya.input({
		realtime = false,
		title = title .. ":",
		pos = { "hovered", w = 50, x = 13, y = 1 },
	})
	if event == 1 then
		if #state.selected == 0 then
			state.selected = { state.hovered }
		end
		local child = Command("/bin/zsh")
			:arg({ "-lic", value, state.hovered })
			:arg(state.selected)
			:cwd(cwd)
			:stdout(Command.PIPED)
			:stderr(Command.PIPED)
		local output = child:output()
		ya.dbg(output)
		if output then
			local stdout = output.stdout:gsub("\n$", "")
			local stderr = output.stderr:gsub("\n$", "")
			local status = output.status
			if status ~= 0 and stderr ~= "" then
				ya.notify({ title = title .. " Error", content = stderr, timeout = 2, level = "error" })
			elseif stdout ~= "" then
				ya.notify({ title = title, content = stdout, timeout = 2 })
			end
		end
	end
end

local state = ya.sync(function()
	local selected = {}
	for _, url in pairs(cx.active.selected) do
		table.insert(selected, tostring(url))
	end
	local yanked = {}
	for _, url in pairs(cx.yanked) do
		table.insert(yanked, tostring(url))
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
