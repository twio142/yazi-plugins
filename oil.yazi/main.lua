--- @diagnostic disable: undefined-global
_G.ya = _G.ya or {}
_G.cx = _G.cx or {}

local M = {}

local cache_file = "/tmp/yazi_oil"
local is_linux = ya.target_os() == "linux"
local stat_cmd = is_linux and "stat -c '%i'" or "stat -f '%i'"
local trash_cmd = is_linux and "gio trash" or "trash"
local trash_dir = is_linux and "~/.local/share/Trash/files" or "~/.Trash"

M.delete = function(state)
	ya.emit("shell", {
		([=[
      cache="%s"
      rm -f "$cache"

      for file in "$@"; do
        inode=$(%s "$file")
        [ -n "$inode" ] && echo "$inode	$(basename "$file")" >> "$cache"
      done
    ]=]):format(cache_file, stat_cmd),
	})
	local count = math.max(1, #state.selected)
	local title = string.format("Trash %d selected item%s?", count, count > 1 and "s" or "")
	local body = #state.selected == 0 and state.hovered or state.selected
	local confirmed = ya.confirm({
		pos = { "center", w = 60, h = 20 },
		title = title,
		content = ui.Text(body):align(ui.Align.LEFT),
	})
	if confirmed then
		ya.emit("shell", { trash_cmd .. ' "$@"' })
	end
end

M.put = function()
	ya.emit("shell", {
		([=[
      cache="%s"
      [ -f "$cache" ] || { ya emit paste; ya emit unyank; exit 0; }

      trash_dir=%s
      [ -d "$trash_dir" ] || { ya emit paste; ya emit unyank; exit 0; }

      target="$0"
      [ -d "$target" ] || target="$(dirname "$target")"

      while read -r line; do
        IFS=$'\t' read -r inode name <<< "$line"
        file=$(find "$trash_dir" -inum "$inode" 2>/dev/null | head -n 1)
        if [ -n "$file" ]; then
          root_name="${name%%.*}"
          [ "$root_name" = "$name" ] && ext= || ext=".${name##*.}"
          i=0
          while [ -e "$target/$name" ]; do
            (( i++ ))
            name="${root_name}_$i$ext"
          done
          mv "$file" "$target/$name"
				else
				  ya emit plugin oil "notify '$name not found in trash.'"
        fi
      done < "$cache"
    ]=]):format(cache_file, trash_dir),
	})
end

M.yank = function()
	ya.emit("shell", { "rm -f " .. cache_file })
	ya.emit("yank", {})
end

M.add = function(state)
	local value, event = ya.input({
		title = "Create:",
		position = { "hovered", w = 50, x = 13, y = 1 },
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

M.notify = function(_, message, level)
	ya.notify({
		title = "Error",
		content = message,
		level = level or "error",
		timeout = 2,
	})
end

local state = ya.sync(function()
	local selected = {}
	for _, url in pairs(cx.active.selected) do
		table.insert(selected, tostring(url))
	end
	return {
		cwd = tostring(cx.active.current.cwd),
		hovered = tostring(cx.active.current.hovered.url),
		selected = selected,
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
