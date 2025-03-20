--- @since 25.2.26
--- @sync entry
--- @diagnostic disable: undefined-global
_G.ya = _G.ya or {}
_G.cx = _G.cx or {}

local M = {}

M.on_selection = function(mode)
	local h = cx.active.current.hovered
	local is_dir = h and h.cha.is_dir
	local first
	for _, url in pairs(cx.active.selected) do
		first = url:name()
		break
	end
	for _, url in pairs(cx.yanked) do
		first = first or url:name()
		ya.mgr_emit("toggle", { url, state = "on" })
	end
	ya.mgr_emit("unyank", {})
	for i = 1, #cx.tabs do
		for _, url in pairs(cx.tabs[i].selected) do
			first = first or url:name()
			ya.mgr_emit("toggle", { url, state = "on" })
		end
	end
	if not first then
		return
	end
	local function locate()
		ya.mgr_emit("reveal", { (is_dir and h.url or h.url:parent()):join(first) })
		ya.mgr_emit("unyank", {})
		ya.mgr_emit("escape", {})
	end
	if mode == "copy" or mode == "copy-force" then
		if is_dir then
			ya.mgr_emit("enter", {})
		end
		ya.mgr_emit("yank", {})
		ya.mgr_emit("paste", { force = mode == "copy-force" })
		locate()
	elseif mode == "move" or mode == "move-force" then
		ps.sub("move", function(body)
			ya.mgr_emit("reveal", { body.items[1].to })
			ps.unsub("move")
		end)
		if is_dir then
			ya.mgr_emit("enter", {})
		end
		ya.mgr_emit("yank", { cut = true })
		ya.mgr_emit("paste", { force = mode == "move-force" })
		ya.mgr_emit("unyank", {})
		ya.mgr_emit("escape", {})
	elseif mode == "move-new-dir" or mode == "copy-new-dir" then
		local dir = (is_dir and h.url or h.url:parent()):join("Folder with selected items")
		dir = tostring(dir)
		local cmd = string.format(
			[[mkdir -p '%s'; %s "$@" '%s'; ya emit reveal '%s'; ya emit unyank; ya emit escape]],
			dir,
			mode == "move-dir" and "mv" or "cp -a",
			dir,
			dir
		)
		ya.mgr_emit("shell", { cmd })
	elseif mode == "symlink" or mode == "symlink-force" then
		if is_dir then
			ya.mgr_emit("enter", {})
		end
		ya.mgr_emit("yank", {})
		ya.mgr_emit("link", { force = mode == "symlink-force" })
		locate()
	elseif mode == "hardlink" or mode == "hardlink-force" then
		if is_dir then
			ya.mgr_emit("enter", {})
		end
		ya.mgr_emit("yank", {})
		ya.mgr_emit("hardlink", { follow = true, force = mode == "hardlink-force" })
		if is_dir then
			ya.mgr_emit("leave", {})
		end
		locate()
	elseif mode == "delete" then
		ya.mgr_emit("remove", {})
	elseif mode == "edit" then
		if os.getenv("NVIM") and not os.getenv("TMUX_POPUP") then
			ya.mgr_emit("shell", { 'nvr -cc quit "$@"' })
		elseif os.getenv("TMUX_POPUP") then
			local cmd = os.getenv("XDG_CONFIG_HOME") .. "/tmux/scripts/open_in_vim.sh '' \"$@\"; tmux popup -C"
			ya.mgr_emit("shell", { cmd })
		else
			ya.mgr_emit("open", {})
		end
	elseif mode == "rename" then
		ya.mgr_emit("rename", {})
		ya.mgr_emit("escape", {})
	elseif mode == "exec" then
		ya.mgr_emit("shell", {
			[=[
			cache=/tmp/yazi_map_selection;
			cmd="\n"
			printf '' > $cache;
			[ "$#" -eq 0 ] && set -- "$0"
			for x in "$@"; do
				(( i++ ))
				echo "# $i -> $x" >> $cache
				cmd="$cmd \$$i"
			done;
			echo $cmd >> $cache
			nvim $cache +$ && eval "$(cat $cache)" || true
		]=],
			block = true,
		})
	elseif mode == "enter" then
    if os.getenv("TMUX_POPUP") then
      ya.mgr_emit("shell", { 'tmux_edit "$@"; tmux popup -C' })
    elseif os.getenv("NVIM") then
			ya.mgr_emit("shell", { 'nvr -cc quit "$@"' })
		else
			ya.mgr_emit("shell", { 'nvim "$@"', block = true })
		end
	elseif mode == "sync" then
		ya.mgr_emit("shell", { 'ya pub-to 0 select --list "$@"' })
	end
end

M.smart = function(arg)
	if arg == "enter" then
		local h = cx.active.current.hovered
		local function is_code()
			local files = cx.active.current.files
			local mime
			for i = 1, #files do
				if files[i]:is_hovered() then
					mime = files[i]:mime()
					break
				end
			end
			return mime:match("^text/") or mime:match("^application/json")
		end
		if os.getenv("NVIM") and not os.getenv("TMUX_POPUP") and not h.cha.is_dir then
			if is_code() then
				ya.mgr_emit("shell", { 'nvr -cc quit "$1"' })
			else
				ya.mgr_emit("open", { hovered = true })
			end
		elseif os.getenv("TMUX_POPUP") then
			local cmd = 'tmux_run %s "$1"; tmux popup -C'
			if h.cha.is_dir then
				cmd = cmd:format("cd")
			elseif is_code() then
				cmd = cmd:format("nvim")
			else
				ya.mgr_emit("open", { hovered = true })
				return
			end
			ya.mgr_emit("shell", { cmd })
		elseif h.cha.is_dir then
			ya.mgr_emit("shell", { 'cd "$1"; $SHELL -l', block = true })
		else
			ya.mgr_emit("open", { hovered = true })
		end
	elseif arg == "open-neww" then
		if not os.getenv("TMUX") then
			return
		end
		local h = cx.active.current.hovered
		local cmd = string.format('NEWW=1 tmux_run %s "$1"; tmux popup -C', h.cha.is_dir and "cd" or "nvim")
		ya.mgr_emit("shell", { cmd })
	elseif arg == "esc" then
		if #cx.yanked > 0 then
			ya.mgr_emit("unyank", {})
		else
			ya.mgr_emit("escape", {})
		end
	elseif arg == "up" then
		local cursor = cx.active.current.cursor
		if cursor == 0 then
			ya.mgr_emit("arrow", { "bot" })
		else
			ya.mgr_emit("arrow", { -1 })
		end
	elseif arg == "down" then
		local cursor = cx.active.current.cursor
		local length = #cx.active.current.files
		if cursor == length - 1 then
			ya.mgr_emit("arrow", { "top" })
		else
			ya.mgr_emit("arrow", { 1 })
		end
	elseif arg == "parent-up" then
		local parent = cx.active.parent
		if not parent then
			return
		end
		local target = parent.files[parent.cursor]
		if target and target.cha.is_dir then
			ya.mgr_emit("cd", { target.url })
		end
	elseif arg == "parent-down" then
		local parent = cx.active.parent
		if not parent then
			return
		end
		local target = parent.files[parent.cursor + 2]
		if target and target.cha.is_dir then
			ya.mgr_emit("cd", { target.url })
		end
	elseif arg == "N" then
		local files = cx.active.current.files
		for i = 1, #files do
			if files[i]:found() then
				ya.mgr_emit("find_arrow", { previous = true })
				return
			end
		end
		ya.mgr_emit("create", {})
	elseif arg == "create-tab" then
		local h = cx.active.current.hovered
		ya.mgr_emit("tab_create", h and h.cha.is_dir and { h.url } or { current = true })
	elseif arg == "next-tab" then
		if #cx.tabs == 1 then
			local h = cx.active.current.hovered
			ya.mgr_emit("tab_create", h and h.cha.is_dir and { h.url } or { current = true })
		else
			ya.mgr_emit("tab_switch", { 1, relative = true })
		end
	elseif arg == "split" then
		local h = cx.active.current.hovered
		if h.cha.is_dir and os.getenv("TMUX") then
			ya.mgr_emit("shell", { 'tmux splitw -v -c "$1"; tmux popup -C' })
		elseif os.getenv("NVIM") and not os.getenv("TMUX_POPUP") then
			ya.mgr_emit("shell", { 'nvr -cc quit -cc split "$1"' })
		elseif os.getenv("TMUX") then
			ya.mgr_emit("shell", { 'tmux splitw -v "nvim "$1""; tmux popup -C' })
		end
	elseif arg == "vsplit" then
		local h = cx.active.current.hovered
		if h.cha.is_dir and os.getenv("TMUX") then
			ya.mgr_emit("shell", { 'tmux splitw -h -c "$1"; tmux popup -C' })
		elseif os.getenv("NVIM") and not os.getenv("TMUX_POPUP") then
			ya.mgr_emit("shell", { 'nvr -cc quit -cc vsplit "$1"' })
		elseif os.getenv("TMUX") then
			ya.mgr_emit("shell", { 'tmux splitw -h "nvim "$1""; tmux popup -C' })
		end
	end
end

return {
	setup = function()
		ps.sub_remote("select", function(body)
			for _, item in ipairs(body) do
				ya.mgr_emit("toggle", { item, state = "on" })
			end
		end)
	end,
	entry = function(_, job)
		local args = job.args
		local func = M[args[1]]
		if func ~= nil then
			table.remove(args, 1)
			return func(table.unpack(args))
		end
	end,
}
