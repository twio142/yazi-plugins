--- @sync entry
--- @diagnostic disable: undefined-global
_G.ya = _G.ya or {}
_G.cx = _G.cx or {}

local M = {}

M.on_selection = function(mode)
	local selected = #cx.active.selected
	for i = 1, #cx.tabs do
		for _, url in pairs(cx.tabs[i].selected) do
			ya.manager_emit("toggle", { tostring(url), state = "on" })
			selected = selected + 1
		end
	end
	if selected == 0 then
		return
	end
	local h = cx.active.current.hovered
	local is_dir = h and h.cha.is_dir
	local cache_file = "/tmp/yazi_on_selection"
	ya.manager_emit("shell", { string.format('ls "%s" > %s', is_dir and "$0" or "$PWD", cache_file) })
	if mode == "copy" or mode == "copy-force" then
		if is_dir then
			ya.manager_emit("enter", {})
		end
		ya.manager_emit("yank", {})
		ya.manager_emit("paste", { force = mode == "copy-force" })
		ya.manager_emit("unyank", {})
	elseif mode == "move" or mode == "move-force" then
		if is_dir then
			ya.manager_emit("enter", {})
		end
		ya.manager_emit("yank", { cut = true })
		ya.manager_emit("paste", { force = mode == "move-force" })
		ya.manager_emit("unyank", {})
	elseif mode == "move-new-dir" or mode == "copy-new-dir" then
		local dir = (is_dir and h.url or h.url:parent()):join(Url("Folder with selected items"))
		dir = tostring(dir)
		local cmd = string.format(
			[[mkdir -p '%s'; %s "$@" '%s'; ya emit reveal '%s'; ya emit unyank]],
			dir,
			mode == "move-dir" and "mv" or "cp -a",
			dir,
			dir
		)
		ya.manager_emit("shell", { cmd })
		return
	elseif mode == "symlink" or mode == "symlink-force" then
		if is_dir then
			ya.manager_emit("enter", {})
		end
		ya.manager_emit("yank", {})
		ya.manager_emit("link", { force = mode == "symlink-force" })
		ya.manager_emit("unyank", {})
	elseif mode == "hardlink" or mode == "hardlink-force" then
		if is_dir then
			ya.manager_emit("enter", {})
		end
		ya.manager_emit("yank", {})
		ya.manager_emit("hardlink", { follow = true, force = mode == "hardlink-force" })
		ya.manager_emit("unyank", {})
		if is_dir then
			ya.manager_emit("leave", {})
		end
	elseif mode == "delete" then
		ya.manager_emit("remove", {})
		return
	elseif mode == "edit" then
		if os.getenv("NVIM") and not os.getenv("TMUX_POPUP") then
			ya.manager_emit("shell", { 'nvr -cc quit "$@"' })
		elseif os.getenv("TMUX_POPUP") then
			local cmd = os.getenv("XDG_CONFIG_HOME") .. "/tmux/scripts/open_in_vim.sh '' \"$@\"; tmux popup -C"
			ya.manager_emit("shell", { cmd })
		else
			ya.manager_emit("open", {})
		end
		return
	elseif mode == "rename" then
		ya.manager_emit("rename", {})
	end
	ya.manager_emit("escape", {})
	ya.manager_emit("shell", { string.format('ls "$PWD" | grep -F -v -x -f %s | head -n1 | xargs -I _ ya emit reveal "_"', cache_file) })
end

M.smart = function(arg)
	if arg == "enter" then
		local h = cx.active.current.hovered
		if not h then
			return
		end
		local function hovered_mime()
			local files = cx.active.current.files
			for i = 1, #files do
				if files[i]:is_hovered() then
					return files[i]:mime()
				end
			end
		end
		if os.getenv("NVIM") and not os.getenv("TMUX_POPUP") then
			if not h.cha.is_dir then
				if hovered_mime():find("^text/") then
					ya.manager_emit("shell", { 'nvr -cc quit "$1"' })
				else
					ya.manager_emit("open", { hovered = true })
				end
				return
			end
		end
		if os.getenv("TMUX_POPUP") then
			local cmd = 'tmux_run %s "$1"; tmux popup -C'
			if h.cha.is_dir then
				cmd = cmd:format("cd")
			else
				if hovered_mime():find("^text/") then
					cmd = cmd:format("nvim")
				else
					ya.manager_emit("open", { hovered = true })
					return
				end
			end
			ya.manager_emit("shell", { cmd })
		elseif h.cha.is_dir then
			ya.manager_emit("shell", { 'cd "$1"; $SHELL -l', block = true })
		else
			ya.manager_emit("open", { hovered = true })
		end
	elseif arg == "open-neww" then
		if not os.getenv("TMUX") then
			return
		end
		local h = cx.active.current.hovered
		if not h then
			return
		end
		local cmd = string.format('NEWW=1 tmux_run %s "$1"; tmux popup -C', h.cha.is_dir and "cd" or "nvim")
		ya.manager_emit("shell", { cmd })
	elseif arg == "esc" then
		if #cx.yanked > 0 then
			ya.manager_emit("unyank", {})
		else
			ya.manager_emit("escape", {})
		end
	elseif arg == "up" then
		local cursor = cx.active.current.cursor
		if cursor == 0 then
			ya.manager_emit("arrow", { "bot" })
		else
			ya.manager_emit("arrow", { -1 })
		end
	elseif arg == "down" then
		local cursor = cx.active.current.cursor
		local length = #cx.active.current.files
		if cursor == length - 1 then
			ya.manager_emit("arrow", { "top" })
		else
			ya.manager_emit("arrow", { 1 })
		end
	elseif arg == "parent-up" then
		local parent = cx.active.parent
		if not parent then
			return
		end
		local target = parent.files[parent.cursor]
		if target and target.cha.is_dir then
			ya.manager_emit("cd", { target.url })
		end
	elseif arg == "parent-down" then
		local parent = cx.active.parent
		if not parent then
			return
		end
		local target = parent.files[parent.cursor + 2]
		if target and target.cha.is_dir then
			ya.manager_emit("cd", { target.url })
		end
	elseif arg == "n" then
		local files = cx.active.current.files
		for i = 1, #files do
			if files[i]:found() then
				ya.manager_emit("find_arrow", { previous = true })
				return
			end
		end
		ya.manager_emit("create", {})
	elseif arg == "create-tab" then
		local h = cx.active.current.hovered
		ya.manager_emit("tab_create", h and h.cha.is_dir and { h.url } or { current = true })
	elseif arg == "next-tab" then
		if #cx.tabs == 1 then
			local h = cx.active.current.hovered
			ya.manager_emit("tab_create", h and h.cha.is_dir and { h.url } or { current = true })
		else
			ya.manager_emit("tab_switch", { 1, relative = true })
		end
	end
end

return {
	entry = function(_, job)
		local args = job.args
		local func = M[args[1]]
		if func ~= nil then
			table.remove(args, 1)
			return func(table.unpack(args))
		end
	end,
}
