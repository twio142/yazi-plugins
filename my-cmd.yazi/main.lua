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
		first = url.name
		break
	end
	for _, url in pairs(cx.yanked) do
		first = first or url.name
		ya.emit("toggle", { url, state = "on" })
	end
	ya.emit("unyank", {})
	for i = 1, #cx.tabs do
		for _, url in pairs(cx.tabs[i].selected) do
			first = first or url.name
			ya.emit("toggle", { url, state = "on" })
		end
	end
	if not first then
		return
	end
	local function locate()
		ya.emit("reveal", { (is_dir and h.url or h.url.parent):join(first) })
		ya.emit("unyank", {})
		ya.emit("escape", {})
	end
	if mode == "copy" or mode == "copy-force" then
		if is_dir then
			ya.emit("enter", {})
		end
		ya.emit("yank", {})
		ya.emit("paste", { force = mode:match("force") and true or false })
		locate()
	elseif mode == "move" or mode == "move-force" then
		ps.sub("move", function(body)
			ya.emit("reveal", { body.items[1].to })
			ps.unsub("move")
		end)
		if is_dir then
			ya.emit("enter", {})
		end
		ya.emit("yank", { cut = true })
		ya.emit("paste", { force = mode:match("force") and true or false })
		ya.emit("unyank", {})
		ya.emit("escape", {})
	elseif mode:match("new%-dir") then
		local dir = (is_dir and h.url or h.url.parent):join("Folder with selected items")
		dir = tostring(dir)
		local cmd = string.format(
			[[mkdir -p '%s'; %s "$@" '%s'; ya emit reveal '%s'; ya emit unyank; ya emit escape]],
			dir,
			mode:match("move") and "mv" or "cp -a",
			dir,
			dir
		)
		ya.emit("shell", { cmd })
	elseif mode:match("link") then
		if is_dir then
			ya.emit("enter", {})
		end
		ya.emit("yank", {})
		ya.emit(
			mode:match("symlink") and "link" or "hardlink",
			{
				force = mode:match("force") and true or false,
				relative = mode:match("relative") and true or false,
				follow = true,
			}
		)
		locate()
	elseif mode == "delete" then
		ya.emit("remove", {})
	elseif mode == "edit" then
		if os.getenv("NVIM") and not os.getenv("TMUX_POPUP") then
			ya.emit("shell", { 'nvr -cc quit "$@"' })
		elseif os.getenv("TMUX_POPUP") then
			local cmd = 'tmux-edit "$@"; tmux popup -C'
			ya.emit("shell", { cmd })
		else
			ya.emit("open", {})
		end
	elseif mode == "rename" then
		ya.emit("rename", {})
		ya.emit("escape", {})
	elseif mode == "diff" then
		ya.emit("shell", {
			[=[
				[ "$#" -eq 2 ] || exit 0
				bg=$(~/.local/bin/background)
				w=$(stty size < /dev/tty | awk '{print $2}')
				delta --$bg --navigate --tabs=2 -n -s --paging=always -w=$w "$@" | less -R
			]=],
			block = true,
		})
	elseif mode == "exec" then
		ya.emit("shell", {
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
			ya.emit("shell", { 'tmux-edit "$@"; tmux popup -C' })
		elseif os.getenv("NVIM") then
			ya.emit("shell", { 'nvr -cc quit "$@"' })
		else
			ya.emit("shell", { 'nvim "$@"', block = true })
		end
	elseif mode == "sync" then
		ya.emit("shell", { 'ya pub-to 0 select --list "$@"' })
	end
end

M.smart = function(arg)
	if arg == "enter" then
		local h = cx.active.current.hovered
		local function is_code()
			local files = cx.active.current.files
			local mime
			for i = 1, #files do
				if files[i].is_hovered then
					mime = files[i]:mime()
					break
				end
			end
			return mime:match("^text/") or mime:match("^application/json")
		end
		if os.getenv("NVIM") and not os.getenv("TMUX_POPUP") and not h.cha.is_dir then
			if is_code() then
				ya.emit("shell", { 'nvr -cc quit "$1"' })
			else
				ya.emit("open", { hovered = true })
			end
		elseif os.getenv("TMUX_POPUP") then
			local cmd = 'tmux-run %s "$1"; tmux popup -C'
			if h.cha.is_dir then
				cmd = cmd:format("cd")
			elseif is_code() then
				cmd = cmd:format("nvim")
			else
				ya.emit("open", { hovered = true })
				return
			end
			ya.emit("shell", { cmd })
		elseif h.cha.is_dir then
			ya.emit("shell", { 'cd "$1"; $SHELL -l', block = true })
		else
			ya.emit("open", { hovered = true })
		end
	elseif arg == "open-neww" then
		if not os.getenv("TMUX") then
			return
		end
		local h = cx.active.current.hovered
		local cmd = string.format('NEWW=1 tmux-run %s "$1"; tmux popup -C', h.cha.is_dir and "cd" or "nvim")
		ya.emit("shell", { cmd })
	elseif arg == "esc" then
		if #cx.yanked > 0 then
			ya.emit("unyank", {})
		else
			ya.emit("escape", {})
		end
	elseif arg == "parent-up" then
		local parent = cx.active.parent
		if not parent then
			return
		end
		local target = parent.files[parent.cursor]
		if target and target.cha.is_dir then
			ya.emit("cd", { target.url })
		end
	elseif arg == "parent-down" then
		local parent = cx.active.parent
		if not parent then
			return
		end
		local target = parent.files[parent.cursor + 2]
		if target and target.cha.is_dir then
			ya.emit("cd", { target.url })
		end
	elseif arg == "next-tab" then
		if #cx.tabs == 1 then
			local h = cx.active.current.hovered
			ya.emit("tab_create", h and h.cha.is_dir and { h.url } or { current = true })
		else
			ya.emit("tab_switch", { 1, relative = true })
		end
	elseif arg == "split" then
		local h = cx.active.current.hovered
		if h.cha.is_dir and os.getenv("TMUX") then
			ya.emit("shell", { 'tmux splitw -v -c "$1"; tmux popup -C' })
		elseif os.getenv("NVIM") and not os.getenv("TMUX_POPUP") then
			ya.emit("shell", { 'nvr -cc quit -cc split "$1"' })
		elseif os.getenv("TMUX") then
			ya.emit("shell", { 'tmux splitw -v "nvim "$1""; tmux popup -C' })
		end
	elseif arg == "vsplit" then
		local h = cx.active.current.hovered
		if h.cha.is_dir and os.getenv("TMUX") then
			ya.emit("shell", { 'tmux splitw -h -c "$1"; tmux popup -C' })
		elseif os.getenv("NVIM") and not os.getenv("TMUX_POPUP") then
			ya.emit("shell", { 'nvr -cc quit -cc vsplit "$1"' })
		elseif os.getenv("TMUX") then
			ya.emit("shell", { 'tmux splitw -h "nvim "$1""; tmux popup -C' })
		end
	end
end

return {
	setup = function()
		ps.sub_remote("select", function(body)
			for _, item in ipairs(body) do
				ya.emit("toggle", { item, state = "on" })
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
