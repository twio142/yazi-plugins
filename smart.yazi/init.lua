_G.ya = _G.ya or {}
_G.cx = _G.cx or {}

local function entry(_, args)
	if args[1] == "enter" then
		local h = cx.active.current.hovered
		if h and h.cha.is_dir then
			ya.manager_emit("shell", { "cd '"..tostring(h.url).."'; $SHELL -l", confirm = true, block = true })
		else
			ya.manager_emit("open", { hovered = true })
		end
	elseif args[1] == "esc" then
		if #cx.yanked > 0 then
			ya.manager_emit("unyank", {})
		else
			ya.manager_emit("escape", {})
		end
	end
end

return { entry = entry }
