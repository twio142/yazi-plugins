--- @sync entry
_G.ya = _G.ya or {}
_G.cx = _G.cx or {}
_G.Command = _G.Command or {}

local M = {}

M.on_selection = function(mode)
  if #cx.active.selected == 0 then
    return
  end
  if mode == "copy" then
    ya.manager_emit("yank", {})
    ya.manager_emit("paste", {})
    ya.manager_emit("unyank", {})
  elseif mode == "move" then
    ya.manager_emit("yank", {cut = true})
    ya.manager_emit("paste", {})
    ya.manager_emit("unyank", {})
  elseif mode == "symlink" then
    ya.manager_emit("link", {})
  elseif mode == "hardlink" then
    ya.manager_emit("hardlink", {follow = true})
  elseif mode == "delete" then
    ya.manager_emit("remove", {})
  elseif mode == "edit" then
    ya.manager_emit("open", {})
  elseif mode == "rename" then
    ya.manager_emit("rename", {})
  end
  ya.manager_emit("escape", {})
end

M.smart = function(arg)
  if arg == "enter" then
    local h = cx.active.current.hovered
    if h and h.cha.is_dir then
      ya.manager_emit("shell", { "cd '"..tostring(h.url).."'; $SHELL -l", confirm = true, block = true })
    else
      ya.manager_emit("open", { hovered = true })
    end
  elseif arg == "esc" then
    if #cx.yanked > 0 then
      ya.manager_emit("unyank", {})
    else
      ya.manager_emit("escape", {})
    end
  elseif arg == "up" then
    local cursor = cx.active.current.cursor
    if cursor == 0 then
      ya.manager_emit("arrow", { 99999999 })
    else
      ya.manager_emit("arrow", { -1 })
    end
  elseif arg == "down" then
    local cursor = cx.active.current.cursor
    local length = #cx.active.current.files
    if cursor == length - 1 then
      ya.manager_emit("arrow", { -99999999 })
    else
      ya.manager_emit("arrow", { 1 })
    end
  elseif arg == "new" then
    local files = cx.active.current.files
    for i = 1, #files do
      if files[i]:found() then
        ya.manager_emit("find_arrow", { previous = true })
        return
      end
    end
    ya.manager_emit("create", {})
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
  end
}
