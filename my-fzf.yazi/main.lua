--- @since 25.2.26
--- @diagnostic disable: undefined-global

local M = {}
local BOLD = "\x1b[1;36m"
local OFF = "\x1b[0m"

M.z = function(s)
	local cwd = s.cwd
	if not s.query then
		ya.hide()
	end
	local _z = ":reload:zoxide query {q} -l --exclude $PWD || true"
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
		:args({ "--query", s.query or "" })
		:args({ "--bind", "start" .. _z })
		:args({ "--bind", "change" .. _z })
		:args({ "--bind", "ctrl-f:become(echo 'file\n{}\n{q}')" })
		:args({ "--bind", "ctrl-g:become(echo 'grep\n{}\n{q}')" })
		:args({ "--bind", "ctrl-t:print(tab)+accept" })
		:args({ "--header", header })
		:args({ "--disabled", "--preview-window=up,60%" })
		:args({ "--preview", "fzf-preview {}" })
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
		ya.mgr_emit("cd", { lines[1] })
	elseif lines[1] == "file" then
		M.fd({ cwd = lines[2], query = lines[3] })
	elseif lines[1] == "grep" then
		M.fif({ cwd = lines[2], query = lines[3] })
	elseif lines[1] == "tab" then
		ya.mgr_emit("tab_create", { lines[2] })
	end
end

M.fd = function(s)
	local cwd = s.cwd
	if not s.query then
		ya.hide()
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
		:args({ "--preview", "fzf-preview {}", "--preview-window=up,60%", "-m" })
		:args({ "--bind", _fd("start", "f") })
		:args({ "--bind", _fd("alt-d", "d") })
		:args({ "--bind", _fd("alt-l", "l") })
		:args({ "--bind", _fd("alt-s", "s") })
		:args({ "--bind", _fd("alt-f", "f") })
		:args({ "--bind", _fd("alt-x", "x") })
		:args({
			"--bind",
			"alt-i:clear-query+transform-prompt( [ $FZF_PROMPT = '> ' ] && echo ' > ' || echo '> ' )+"
				.. _fd("", "f"):sub(2, -1),
		})
		:args({ "--bind", "ctrl-b:print(back)+accept" })
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
		ya.mgr_emit(cha.is_dir and "cd" or "reveal", { file })
	elseif #files > 1 then
		if files[1] == "back" then
			M.z({ cwd = os.getenv("PWD"), query = s.query })
			return
		end
		local last_file
		for _, file in ipairs(files) do
			file = Url(cwd):join(file)
			ya.mgr_emit("toggle", { file, state = "on" })
			last_file = file
		end
		ya.mgr_emit("reveal", { last_file })
	end
end

M.fif = function(s)
	local cwd = s.cwd
	if not s.query then
		ya.hide()
	end
	local fd_prefix = "fd -H -L -tf -p "
	local fd_suffix = ". -X ls -t | sed 's/^\\.\\//\x1b[35m/' | sed 's/\\$/\x1b[0m/'"
	local rg = "rg --ignore-vcs -. -L -S -n --column --no-heading --color=always"
	local child = Command("fzf")
		:args({ "--ansi", "--disabled", "-m" })
		:args({ "--color", "hl:-1:underline,hl+:-1:underline:reverse" })
		:args({ "--bind", "start:reload:" .. fd_prefix .. " . " .. fd_suffix })
		:args({
			"--bind",
			"change:reload:sleep 0.1; " .. fd_prefix .. " {q} " .. fd_suffix .. " || true; " .. rg .. " {q} || true",
		})
		:args({ "--bind", "ctrl-b:print(back)+accept" })
		:args({ "--delimiter", ":" })
		:args({ "--preview", "[ -z {2} ] && fzf-preview {} || bat --color=always {1} --highlight-line {2}" })
		:args({ "--preview-window", "up,60%,border-bottom,+{2}+3/3,~3" })
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
		ya.mgr_emit("reveal", { file })
	elseif #files > 1 then
		if files[1] == "back" then
			M.z({ cwd = os.getenv("PWD"), query = s.query })
			return
		end
		local last_file
		for _, file in ipairs(files) do
			file = Url(cwd):join(file)
			ya.mgr_emit("toggle", { file, state = "on" })
			last_file = file
		end
		ya.mgr_emit("reveal", { last_file })
	end
end

M.git = function(s)
	local cwd = s.cwd
	ya.hide()
	local child = Command("awk")
		:arg("/recentrepos:/ {found=1; next} found && /^[^[:space:]]/ {exit} found {print}")
		:arg(os.getenv("XDG_STATE_HOME") .. "/lazygit/state.yml")
		:stdout(Command.PIPED)
		:spawn()
	local repos = {}
	while true do
		local repo, event = child:read_line()
		if event ~= 0 then
			break
		end
		repo = repo:gsub("^ +- ", ""):gsub("\n", "")
		if repo ~= "" and repo ~= cwd then
			table.insert(repos, repo)
		end
	end
	child = Command("fzf")
		:args({
			"--preview",
			[[echo -e "\033[1m$(basename {})\033[0m\n"; git -c color.status=always -C {} status -bs]],
			"--preview-window=wrap,up,60%",
		})
		:stdin(Command.PIPED)
		:stdout(Command.PIPED)
		:spawn()
	child:write_all(table.concat(repos, "\n"))
	child:flush()
	local selected = child:wait_with_output().stdout:gsub("\n", "")
	if selected ~= "" then
		ya.mgr_emit("cd", { selected })
	end
end

M.obsearch = function()
	ya.hide()
	local child = Command("obsearch"):args({ "-o" }):stdout(Command.PIPED):spawn()
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
		ya.mgr_emit("reveal", { files[1] })
	elseif #files > 1 then
		local last_file
		for _, file in ipairs(files) do
			ya.mgr_emit("toggle", { file, state = "on" })
			last_file = file
		end
		ya.mgr_emit("reveal", { last_file })
	end
end

M.selected = function(s)
	if #s.selected == 0 then
		return
	end
	if not s.map then
		ya.hide()
		s.map = {}
		for _, path in pairs(s.selected) do
			s.map[path] = true
		end
	end
	local child = Command("fzf")
		:args({ "-m", "--preview", "fzf-preview {}", "--preview-window", "up,60%" })
		:args({ "--bind", "ctrl-x:print(deselect)+accept" })
		:args({ "--header", ("%s⌃X%s Deselect"):format(BOLD, OFF) })
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
			ya.mgr_emit("toggle", { lines[i], state = "off" })
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
		ya.mgr_emit("reveal", { lines[1] })
	end
end

local state = ya.sync(function()
	local selected = {}
	for _, url in pairs(cx.active.selected) do
		table.insert(selected, tostring(url))
	end
	return {
		cwd = tostring(cx.active.current.cwd),
		selected = selected,
	}
end)

return {
	entry = function(_, job)
		local s = state()
		M[job.args[1]](s)
	end,
}
