_G.ya = _G.ya or {}
_G.cx = _G.cx or {}
_G.Command = _G.Command or {}

local S = {}
local A = {}

A.alfred = function(state, mode)
  local cmd = "alfred"
  local args = {state.hovered}
  if mode ~= nil then
    cmd = "altr"
    local wf = mode == "buffer" and "com.nyako520.syspre" or "com.nyako520.alfred"
    args = {"-w", wf, "-t", mode, "-a", "-"}
    if #state.selected == 0 then
      table.insert(args, state.hovered)
    else
      for _, url in pairs(state.selected) do
        table.insert(args, url)
      end
    end
  end
  Command(cmd)
    :env("PATH", os.getenv("HOME") .. "/.local/bin:" .. os.getenv("PATH"))
    :args(args)
    :output()
  if #state.selected > 0 then
    ya.manager_emit("escape", {})
  end
end

S.on_selection = function(mode)
  if #cx.active.selected == 0 then
    return
  end
  if mode == "copy" then
    ya.manager_emit("yank", {})
    ya.manager_emit("paste", {})
  elseif mode == "move" then
    ya.manager_emit("yank", {cut = true})
    ya.manager_emit("paste", {})
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

S.smart = function(arg)
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

local state = ya.sync(function()
  local cwd = tostring(cx.active.current.cwd)
  local hovered = tostring(cx.active.current.hovered.url)
  local selected = {}
  local yanked = {}
  for idx, url in pairs(cx.active.selected) do
    selected[idx] = tostring(url)
  end
  for idx, url in pairs(cx.yanked) do
    yanked[idx] = tostring(url)
  end
  return {
    cwd = cwd,
    hovered = hovered,
    selected = selected,
    yanked = yanked
  }
end)

return {
  entry = function(_, args)
    local func = S[args[1]]
    if func ~= nil then
      table.remove(args, 1)
      return func(table.unpack(args))
    end
    func = A[args[1]]
    if not func then
      return
    end
    table.remove(args, 1)
    func(state(), table.unpack(args))
  end
}
