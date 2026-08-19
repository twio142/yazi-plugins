--- @since 26.08.11
--- @sync entry
--- @diagnostic disable: undefined-global
_G.ya = _G.ya or {}
_G.cx = _G.cx or {}

local M = {}

M.on_selection = function(action)
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
	if action == "copy" or action == "copy-force" then
		if is_dir then
			ya.emit("enter", {})
		end
		ya.emit("yank", {})
		ya.emit("paste", { force = action:match("force") and true or false })
		ya.emit("unyank", {})
		ya.emit("escape", {})
	elseif action == "move" or action == "move-force" then
		if is_dir then
			ya.emit("enter", {})
		end
		ya.emit("yank", { cut = true })
		ya.emit("paste", { force = action:match("force") and true or false })
		ya.emit("unyank", {})
		ya.emit("escape", {})
	elseif action:match("new%-dir") then
		local dir = (is_dir and h.url or h.url.parent):join("Folder with selected items")
		dir = tostring(dir)
		local cmd = string.format(
			[[mkdir -p '%s'; %s %%s '%s'; ya emit reveal '%s'; ya emit unyank; ya emit escape]],
			dir,
			action:match("move") and "mv" or "cp -a",
			dir,
			dir
		)
		ya.emit("shell", { cmd })
	elseif action:match("link") then
		if is_dir then
			ya.emit("enter", {})
		end
		ya.emit("yank", {})
		ya.emit(action:match("symlink") and "link" or "hardlink", {
			force = action:match("force") and true or false,
			relative = action:match("relative") and true or false,
			follow = true,
		})
	elseif action == "delete" then
		ya.emit("remove", {})
	elseif action == "edit" then
		if os.getenv("NVIM") then
			ya.emit("shell", { "nvr -cc quit %s" })
		elseif os.getenv("TMUX_POPUP") then
			ya.emit("shell", { "tmux-edit %s; ya emit quit" })
		else
			ya.emit("open", {})
		end
	elseif action == "rename" then
		ya.emit("rename", {})
		ya.emit("escape", {})
	elseif action == "diff" then
		local bg = "$(~/.local/bin/background)"
		local light = rt.term.light()
		if light ~= nil then
			bg = light and "light" or "dark"
		end
		ya.emit("shell", {
			([=[
				set -- %%s;
				[ "$#" -eq 2 ] || exit 0
				bg=%s
				w=$(stty size < /dev/tty | awk '{print $2}')
				delta --$bg --navigate --tabs=2 -n -s --paging=always -w=$w "$@" | less -R
			]=]):format(bg),
			block = true,
		})
	elseif action == "exec" then
		ya.emit("shell", {
			[=[
			cache=/tmp/yazi_map_selection;
			cmd="\n"
			printf '' > $cache;
			set -- %s;
			[ "$#" -eq 0 ] && set -- %h
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
	elseif action == "enter" then
		if os.getenv("TMUX_POPUP") then
			ya.emit("shell", { "tmux-edit %s; ya emit quit" })
		elseif os.getenv("NVIM") then
			ya.emit("shell", { "nvr -cc quit %n" })
		else
			ya.emit("shell", { "nvim %s", block = true })
		end
	end
end

M.smart = function(action)
	local h = cx.active.current.hovered
	local function is_remote(file)
		return tostring(file):match("^sftp://")
	end
	local function is_editable(file)
		local mime = file:mime()
		return mime and (mime:match("^text/") or mime:match("^application/json"))
	end
	if action == "enter" then
		-- enter dir or edit file
		local cmd
		local block = false
		if h.cha.is_dir then
			if is_remote(h) then
				cmd = string.format(
					[[ssh %s -t "cd %s && \$SHELL -l"]],
					h.url.spec.domain,
					ya.quote(tostring(h.url.path))
				)
				if os.getenv("TMUX") then
					cmd = "tmux-run " .. cmd
				end
			else
				cmd = "cd %h"
				if os.getenv("TMUX") then
					cmd = "tmux-run " .. cmd
				else
					cmd = cmd .. " && $SHELL -l"
				end
			end
			block = not os.getenv("TMUX")
		elseif is_editable(h) then
			if os.getenv("NVIM") then
				cmd = "nvr -cc quit %h"
			elseif os.getenv("TMUX") then
				cmd = "tmux-edit %h"
			end
		end
		if cmd then
			if os.getenv("TMUX_POPUP") then
				cmd = cmd .. "; ya emit quit"
			end
			ya.emit("shell", { cmd, block = block })
		else
			ya.emit("open", { hovered = true })
		end
	elseif action == "open-neww" then
		-- enter dir or edit file in new window
		if not os.getenv("TMUX") then
			return
		end
		local cmd
		if h.cha.is_dir then
			if is_remote(h) then
				cmd = string.format(
					[[NEWW=1 tmux-run ssh %s -t "cd %s && \$SHELL -l"]],
					h.url.spec.domain,
					ya.quote(tostring(h.url.path))
				)
			else
				cmd = "NEWW=1 tmux-run cd %h"
			end
		elseif is_editable(h) then
			cmd = "NEWW=1 tmux-edit %h"
		end
		if cmd then
			if os.getenv("TMUX_POPUP") then
				cmd = cmd .. "; ya emit quit"
			end
			ya.emit("shell", { cmd })
		end
	elseif action == "split" then
		-- enter dir or edit file in horizontal split
		if not os.getenv("TMUX") then
			return
		end
		local cmd
		if h.cha.is_dir then
			if is_remote(h) then
				cmd = string.format(
					[[SPLIT=down tmux-run ssh %s -t "cd %s && \$SHELL -l"]],
					h.url.spec.domain,
					ya.quote(tostring(h.url.path))
				)
			else
				cmd = "SPLIT=down tmux-run cd %h"
			end
		elseif is_editable(h) then
			if os.getenv("NVIM") then
				cmd = "nvr -cc quit -cc split %h"
			else
				cmd = "SPLIT=down tmux-edit %h"
			end
		end
		if cmd then
			if os.getenv("TMUX_POPUP") then
				cmd = cmd .. "; ya emit quit"
			end
			ya.emit("shell", { cmd })
		end
	elseif action == "vsplit" then
		-- enter dir or edit file in vertical split
		if not os.getenv("TMUX") then
			return
		end
		local cmd
		if h.cha.is_dir then
			if is_remote(h) then
				cmd = string.format(
					[[SPLIT=right tmux-run ssh %s -t "cd %s && \$SHELL -l"]],
					h.url.spec.domain,
					ya.quote(tostring(h.url.path))
				)
			else
				cmd = "SPLIT=right tmux-run cd %h"
			end
		elseif is_editable(h) then
			if os.getenv("NVIM") then
				cmd = "nvr -cc quit -cc vsplit %h"
			else
				cmd = "SPLIT=right tmux-edit %h"
			end
		end
		if cmd then
			if os.getenv("TMUX_POPUP") then
				cmd = cmd .. "; ya emit quit"
			end
			ya.emit("shell", { cmd })
		end
	elseif action == "cd" then
		-- cd to current working directory
		local cwd = cx.active.current.cwd
		local cmd
		if is_remote(cwd) then
			cmd = ([[ssh %s -t "cd %s && \$SHELL -l"]]):format(cwd.spec.domain, ya.quote(tostring(cwd.path)))
			if os.getenv("TMUX") then
				cmd = "tmux-run " .. cmd
			end
		else
			cmd = 'cd "$(pwd)"'
			if os.getenv("TMUX") then
				cmd = "tmux-run " .. cmd
			else
				cmd = "$SHELL -l"
			end
		end
		if cmd then
			if os.getenv("TMUX_POPUP") then
				cmd = cmd .. "; ya emit quit"
			end
			ya.emit("shell", { cmd, block = not os.getenv("TMUX") })
		end
	elseif action == "esc" then
		-- unyank if yanked, otherwise escape
		if #cx.yanked > 0 then
			ya.emit("unyank", {})
		else
			ya.emit("escape", {})
		end
	elseif action == "parent-up" then
		-- go to parent directory's previous sibling directory
		local parent = cx.active.parent
		if not parent then
			return
		end
		local target = parent.files[parent.cursor]
		if target and target.cha.is_dir then
			ya.emit("cd", { target.url })
		end
	elseif action == "parent-down" then
		-- go to parent directory's next sibling directory
		local parent = cx.active.parent
		if not parent then
			return
		end
		local target = parent.files[parent.cursor + 2]
		if target and target.cha.is_dir then
			ya.emit("cd", { target.url })
		end
	elseif action == "next-tab" then
		-- switch to next tab, create new tab if only one tab exists
		if #cx.tabs == 1 then
			ya.emit("tab_create", h and h.cha.is_dir and { h.url } or { current = true })
		else
			ya.emit("tab_switch", { 1, relative = true })
		end
	elseif action == "copy-path" then
		-- copy path of hovered file
		local path = tostring(cx.active.current.hovered.url.path)
		os.execute("printf " .. ya.quote(path) .. " | " .. (os.getenv("TMUX") and "tmux loadb -" or "pbcopy"))
	elseif action == "copy-cwd" then
		-- copy path of current working directory
		local path = tostring(cx.active.current.cwd.path)
		os.execute("printf " .. ya.quote(path) .. " | " .. (os.getenv("TMUX") and "tmux loadb -" or "pbcopy"))
	end
end

M.git = function(action)
	if #cx.active.selected == 0 and not cx.active.current.hovered then
		return
	end
	local map = {
		add = "git add %s",
		unstage = "git reset -- %s",
		revert = "git checkout HEAD -- %s",
	}
	if not map[action] then
		return
	end
	ya.emit("shell", { map[action], block = true })
	ui.render()
	ya.emit("toggle_all", { state = "off" })
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
