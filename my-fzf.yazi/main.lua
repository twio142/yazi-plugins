--- @since 25.2.26
--- @diagnostic disable: undefined-global

local M = {}
local BOLD = "\x1b[1;36m"
local OFF = "\x1b[0m"

M.zoxide = function(s)
	local cwd = s.cwd
	if not s.query then
		ui.hide()
	end
	local keys = {
		F = "Search files",
		G = "Grep",
		T = "Open in a new tab",
	}
	local header = ""
	for k, v in pairs(keys) do
		local h = string.format("%s⌃%s%s %s", BOLD, k, OFF, v)
		header = header .. h .. " / "
	end
	header = header:sub(1, -4)
	local child = Command("fzf")
		:arg({ "--query", s.query or "" })
		:arg({ "--bind", "start:reload:zoxide query {q} -l --exclude '${PWD}' || true" })
		:arg({ "--bind", "change:reload:eval zoxide query {q} -l --exclude ${PWD:q:q} || true" })
		:arg({ "--bind", "ctrl-f:become(echo 'file\n{}\n{q}')" })
		:arg({ "--bind", "ctrl-g:become(echo 'grep\n{}\n{q}')" })
		:arg({ "--bind", "ctrl-t:print(tab)+accept" })
		:arg({ "--header", header })
		:arg({ "--disabled" })
		:arg({ "--preview", "fzf-preview {}" })
		:arg({ "--preview-window", "up,60%" })
		:arg({ "--preview-label= Jump to path " })
		:arg({ "--preview-label-pos=bottom" })
		:cwd(cwd)
		:stdout(Command.PIPED)
		:spawn()
	local lines = {}
	while true do
		local line, event = child:read_line()
		if event ~= 0 then
			break
		end
		line = line:gsub("\n", "")
		table.insert(lines, line)
	end
	if #lines == 0 then
		return
	end
	if #lines == 1 then
		ya.emit("cd", { lines[1] })
	elseif lines[1] == "file" then
		M.fd({ cwd = lines[2], query = lines[3] })
	elseif lines[1] == "grep" then
		M.grep({ cwd = lines[2], query = lines[3] })
	elseif lines[1] == "tab" then
		ya.emit("tab_create", { lines[2] })
	end
end

M.fd = function(s)
	local cwd = s.cwd
	if cwd:match("^sftp://") then
		ya.notify({
			title = "FZF",
			content = "Only supported in local directory",
			timeout = 2,
			level = "warn",
		})
		return
	end
	if not s.query then
		ui.hide()
	end
	local _hd = function(t)
		local types = {
			f = "file",
			d = "dir",
			l = "symlink",
			s = "socket",
			x = "executable",
		}
		local header = {}
		for k, v in pairs(types) do
			local h = t == k and BOLD or ""
			h = h .. string.format("⌥%s %s", string.upper(k), v)
			h = h .. (t == k and OFF or "")
			table.insert(header, h)
		end
		return table.concat(header, " / ")
	end
	local _fd = function(k, t)
		local base = string.format("fd -t%s -H%s --strip-cwd-prefix=always", t, t == "l" and "" or "L")
		return string.format(
			"%s:reload([ $FZF_PROMPT = '> ' ] && %s || %s --no-ignore-vcs)+change-header( %s )",
			k,
			base,
			base,
			_hd(t)
		)
	end
	local child = Command("fzf")
		:arg({ "--preview", "fzf-preview {}", "-m" })
		:arg({ "--preview-window", "up,60%" })
		:arg({ "--preview-label-pos=bottom" })
		:arg({ "--preview-label= Files " })
		:arg({ "--bind", _fd("start", "f") })
		:arg({ "--bind", _fd("alt-d", "d") })
		:arg({ "--bind", _fd("alt-l", "l") })
		:arg({ "--bind", _fd("alt-s", "s") })
		:arg({ "--bind", _fd("alt-f", "f") })
		:arg({ "--bind", _fd("alt-x", "x") })
		:arg({
			"--bind",
			"alt-i:clear-query+transform-prompt( [ $FZF_PROMPT = '> ' ] && echo ' > ' || echo '> ' )+"
				.. _fd("", "f"):sub(2, -1),
		})
		:arg({ "--bind", "ctrl-b:print(back)+accept" })
		:cwd(cwd)
		:stdout(Command.PIPED)
		:spawn()
	local files = {}
	while true do
		local file, event = child:read_line()
		if event ~= 0 then
			break
		end
		file = file:gsub("\n", "")
		table.insert(files, file)
	end
	if #files == 1 then
		local file = Url(cwd):join(files[1])
		local cha, err = fs.cha(file, true)
		if err then
			return
		end
		ya.emit(cha.is_dir and "cd" or "reveal", { file })
	elseif #files > 1 then
		if files[1] == "back" then
			M.zoxide({ cwd = os.getenv("PWD"), query = s.query })
			return
		end
		local last_file
		for _, file in ipairs(files) do
			file = Url(cwd):join(file)
			ya.emit("toggle", { file, state = "on" })
			last_file = file
		end
		ya.emit("reveal", { last_file })
	end
end

M.grep = function(s)
	local cwd = s.cwd
	if cwd:match("^sftp://") then
		ya.notify({
			title = "FZF",
			content = "Only supported in local directory",
			timeout = 2,
			level = "warn",
		})
		return
	end
	if not s.query then
		ui.hide()
	end
	local fd_prefix = "fd -H -L -tf -p "
	local fd_suffix = ". -X ls -t | sed 's/^\\.\\//\x1b[35m/' | sed 's/\\$/\x1b[0m/'"
	local rg = "rg --ignore-vcs -. -L -S -n --column --no-heading --color=always"
	local child = Command("fzf")
		:arg({ "--ansi", "--disabled", "-m" })
		:arg({ "--color", "hl:-1:underline,hl+:-1:underline:reverse" })
		:arg({ "--bind", "start:reload:" .. fd_prefix .. " . " .. fd_suffix })
		:arg({
			"--bind",
			"change:reload:sleep 0.1; " .. fd_prefix .. " {q} " .. fd_suffix .. " || true; " .. rg .. " {q} || true",
		})
		:arg({ "--bind", "ctrl-b:print(back)+accept" })
		:arg({ "--delimiter", ":" })
		:arg({ "--preview", "[ -z {2} ] && fzf-preview {} || bat --color=always {1} --highlight-line {2}" })
		:arg({ "--preview-label= Grep ", "--preview-label-pos=bottom" })
		:arg({ "--preview-window", "up,60%,+{2}+3/3,~3" })
		:cwd(cwd)
		:stdout(Command.PIPED)
		:spawn()
	local files = {}
	while true do
		local line, event = child:read_line()
		if event ~= 0 then
			break
		end
		local file = line:match("^[^:\n]+")
		table.insert(files, file)
	end
	if #files == 1 then
		local file = Url(cwd):join(files[1])
		ya.emit("reveal", { file })
	elseif #files > 1 then
		if files[1] == "back" then
			M.zoxide({ cwd = os.getenv("PWD"), query = s.query })
			return
		end
		local last_file
		for _, file in ipairs(files) do
			file = Url(cwd):join(file)
			ya.emit("toggle", { file, state = "on" })
			last_file = file
		end
		ya.emit("reveal", { last_file })
	end
end

M.selected = function(s)
	if #s.selected == 0 then
		return
	end
	if not s.map then
		ui.hide()
		s.map = {}
		for _, path in pairs(s.selected) do
			s.map[path] = true
		end
	end
	local child = Command("fzf")
		:arg({ "-m" })
		:arg({ "--preview", "fzf-preview {}" })
		:arg({ "--preview-window", "up,60%" })
		:arg({ "--preview-label-pos=bottom" })
		:arg({ "--preview-label= Selected Files " })
		:arg({ "--bind", "ctrl-x:print(deselect)+accept" })
		:arg({ "--header", ("%s⌃X%s Deselect"):format(BOLD, OFF) })
		:stdin(Command.PIPED)
		:stdout(Command.PIPED)
		:spawn()
	child:write_all(table.concat(s.selected, "\n"))
	child:flush()
	child:wait()
	local lines = {}
	while true do
		local line, event = child:read_line()
		if event ~= 0 then
			break
		end
		line = line:gsub("\n", "")
		table.insert(lines, line)
	end
	if #lines == 0 then
		return
	end
	if lines[1] == "deselect" then
		for i = 2, #lines do
			ya.emit("toggle", { lines[i], state = "off" })
			s.map[lines[i]] = false
		end
		s.selected = {}
		for path, ok in pairs(s.map) do
			if ok then
				table.insert(s.selected, path)
			end
		end
		M.selected(s)
	else
		ya.emit("reveal", { lines[1] })
	end
end

M.shell = function(s)
	local cwd = s.cwd
	local title = "Shell"
	local value, event = ya.input({
		realtime = false,
		title = title .. ":",
		pos = { "hovered", w = 50, x = 13, y = 1 },
	})
	if event == 1 then
		if #s.selected == 0 then
			s.selected = { s.hovered }
		end
		local child = Command("/bin/zsh")
			:arg({ "-lic", value, s.hovered })
			:arg(s.selected)
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
	return {
		cwd = tostring(cx.active.current.cwd),
		hovered = cx.active.current.hovered and tostring(cx.active.current.hovered.url) or nil,
		selected = selected,
	}
end)

return {
	entry = function(_, job)
		local s = state()
		M[job.args[1]](s)
	end,
}
