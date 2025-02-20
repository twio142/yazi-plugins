--- @diagnostic disable: undefined-global
_G.ya = _G.ya or {}
_G.cx = _G.cx or {}
_G.Command = _G.Command or {}

local M = {}

M.z = function(s)
	local cwd = s.cwd
	ya.hide()
	local _z = ":reload:zoxide query {q} -l --exclude $PWD || true"
	local child = Command("fzf")
		:args({ "--bind", "start" .. _z })
		:args({ "--bind", "change" .. _z })
		:args({ "--bind", "ctrl-t:print(tab)+accept" })
		:args({ "--header", "\x1b[1;36m⌃T\x1b[0m Open in a new tab" })
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
		ya.manager_emit("cd", { lines[1] })
	elseif lines[1] == "tab" then
		ya.manager_emit("tab_create", { lines[2] })
	end
end

M.fd = function(s)
	local cwd = s.cwd
	ya.hide()
	local _hd = function(t)
		local types = {
			f = "file",
			d = "dir",
			l = "symlink",
			s = "socket",
			x = "executable",
		}
		local header = {}
		local BOLD = "\x1b[1;36m"
		local OFF = "\x1b[0m"
		for k, v in pairs(types) do
			local h = t == k and BOLD or ""
			h = h .. string.format("⌥%s %s", string.upper(k), v)
			h = h .. (t == k and OFF or "")
			table.insert(header, h)
		end
		return table.concat(header, " / ")
	end
	local _fd = function(k, t)
		local base = string.format("fd -t%s -H%s --strip-cwd-prefix=always", t, t == 'l' and '' or 'L')
		return string.format("%s:reload([ $FZF_PROMPT = '> ' ] && %s || %s --no-ignore-vcs)+change-header( %s )", k, base, base, _hd(t))
	end
	local child = Command("fzf")
		:args({ "--preview", "fzf-preview {}", "--preview-window=up,60%", "-m" })
		:args({ "--bind", _fd("start", "f") })
		:args({ "--bind", _fd("alt-d", "d") })
		:args({ "--bind", _fd("alt-l", "l") })
		:args({ "--bind", _fd("alt-s", "s") })
		:args({ "--bind", _fd("alt-f", "f") })
		:args({ "--bind", _fd("alt-x", "x") })
		:args({ "--bind", "alt-i:clear-query+transform-prompt( [ $FZF_PROMPT = '> ' ] && echo ' > ' || echo '> ' )+" .. _fd("", "f"):sub(2, -1) })
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
		local cha, err = fs.cha(Url(cwd):join(Url(files[1])), true)
		if err then
			return
		end
		ya.manager_emit(cha.is_dir and "cd" or "reveal", { files[1] })
	elseif #files > 1 then
		local last_file
		for _, file in ipairs(files) do
			file = tostring(Url(cwd):join(Url(file)))
			ya.manager_emit("toggle", { file, state = "on" })
			last_file = file
		end
		ya.manager_emit("reveal", { last_file })
	end
end

M.fif = function(s)
	local cwd = s.cwd
	ya.hide()
	local child = Command("fif"):args({ "-o" }):cwd(cwd):stdout(Command.PIPED):spawn()
	local files = {}
	local ln
	while true do
		local line, event = child:read_line()
		if event ~= 0 then
			break
		end
		local file = line:match("^[^:\n]+")
		ln = line:match("^[^:]+:(%d+)")
		table.insert(files, file)
	end
	if #files == 0 then
		return
	end
	if os.getenv("TMUX_POPUP") then
		if #files == 1 then
			ya.manager_emit("reveal", { files[1] })
		else
			local last_file
			for _, file in ipairs(files) do
				file = tostring(Url(cwd):join(Url(file)))
				ya.manager_emit("toggle", { file, state = "on" })
				last_file = file
			end
			ya.manager_emit("reveal", { last_file })
		end
	else
		local args = ""
		if #files == 1 then
			args = args .. ya.quote(files[1])
			if ln then
				args = args .. " +" .. ln
			end
		else
			for _, file in ipairs(files) do
				args = args .. ya.quote(file) .. " "
			end
		end
		ya.manager_emit("shell", { "nvim " .. args, block = true })
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
		ya.manager_emit("cd", { selected })
	end
end

M.obsearch = function()
	ya.hide()
	local child = Command("obsearch"):args({ "-o" }):stdout(Command.PIPED):spawn()
	local files = {}
	local ln
	while true do
		local line, event = child:read_line()
		if event ~= 0 then
			break
		end
		local file = line:match("^[^:\n]+")
		ln = line:match("^[^:]+:(%d+)")
		table.insert(files, file)
	end
	if #files == 0 then
		return
	end
	if os.getenv("TMUX_POPUP") then
		if #files == 1 then
			ya.manager_emit("reveal", { files[1] })
		else
			local last_file
			for _, file in ipairs(files) do
				ya.manager_emit("toggle", { file, state = "on" })
				last_file = file
			end
			ya.manager_emit("reveal", { last_file })
		end
	else
		local args = ""
		if #files == 1 then
			args = args .. ya.quote(files[1])
			if ln then
				args = args .. " +" .. ln
			end
		else
			for _, file in ipairs(files) do
				args = args .. ya.quote(file) .. " "
			end
		end
		ya.manager_emit("shell", { "nvim " .. args, block = true })
	end
end

M.selected = function(s)
	local selected = s.selected
	if #selected == 0 then
		return
	end
	ya.hide()
	local tmpfile = Command("mktemp"):args({ "/tmp/yazi.XXXXXX" }):stdout(Command.PIPED):output().stdout:gsub("\n", "")
	ya.manager_emit("shell", { [[printf '%s\n' "$@" > ]] .. tmpfile })
	local output = Command("fzf")
		:args({ "--preview", "fzf-preview {}", "--preview-window", "up,60%" })
		:args({ "--bind", "start:reload:cat " .. tmpfile })
		:args({
			"--bind",
			[[ctrl-x:reload:ya emit toggle {} --state=off && ya emit shell 'printf "%s\n" "$@" > ]]
				.. tmpfile
				.. "' && sleep 0.1 && cat "
				.. tmpfile,
		})
		:args({ "--header", "\x1b[1;36m⌃X\x1b[0m Deselect" })
		:stdout(Command.PIPED)
		:output()
	local file = output.stdout:gsub("\n", "")
	if file ~= "" then
		ya.manager_emit("reveal", { file })
	end
	ya.manager_emit("shell", { "rm " .. tmpfile })
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
