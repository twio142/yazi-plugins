--- @sync entry
_G.ya = _G.ya or {}
_G.cx = _G.cx or {}
_G.Command = _G.Command or {}

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
  if mode == "copy" then
    if is_dir then
      ya.manager_emit("enter", {})
    end
    ya.manager_emit("yank", {})
    ya.manager_emit("paste", {})
    ya.manager_emit("unyank", {})
    if is_dir then
      ya.manager_emit("leave", {})
    end
  elseif mode == "move" then
    if is_dir then
      ya.manager_emit("enter", {})
    end
    ya.manager_emit("yank", {cut = true})
    ya.manager_emit("paste", {})
    ya.manager_emit("unyank", {})
    if is_dir then
      ya.manager_emit("leave", {})
    end
  elseif mode == "symlink" then
    if is_dir then
      ya.manager_emit("enter", {})
    end
    ya.manager_emit("yank", {})
    ya.manager_emit("link", {})
    ya.manager_emit("unyank", {})
    if is_dir then
      ya.manager_emit("leave", {})
    end
  elseif mode == "hardlink" then
    if is_dir then
      ya.manager_emit("enter", {})
    end
    ya.manager_emit("yank", {})
    ya.manager_emit("hardlink", {follow = true})
    ya.manager_emit("unyank", {})
    if is_dir then
      ya.manager_emit("leave", {})
    end
  elseif mode == "delete" then
    ya.manager_emit("remove", {})
  elseif mode == "edit" then
    if os.getenv("TMUX_POPUP") then
      local cmd = os.getenv("XDG_CONFIG_HOME") .. "/tmux/scripts/open_in_vim.sh '' \"$@\"; tmux popup -C"
      ya.manager_emit("shell", { cmd })
    else
      ya.manager_emit("open", {})
    end
  elseif mode == "rename" then
    ya.manager_emit("rename", {})
  end
  ya.manager_emit("escape", {})
end

M.smart = function(arg)
  if arg == "enter" then
    local h = cx.active.current.hovered
    if not h then return end
    if os.getenv("TMUX_POPUP") then
      local cmd = ""
      if h.cha.is_dir then
        local script = "find_empty_shell"
        cmd = string.format("%s/tmux/scripts/%s.sh '' cd ", os.getenv("XDG_CONFIG_HOME"), script)
      else
        local files = cx.active.current.files
        for i = 1, #files do
          if files[i]:is_hovered() then
            local mime = files[i]:mime()
            if mime:find("^text/") then
              local script = "open_in_vim"
              cmd = string.format("%s/tmux/scripts/%s.sh '' ", os.getenv("XDG_CONFIG_HOME"), script)
              break
            else
              ya.manager_emit("open", { hovered = true })
              return
            end
          end
        end
      end
      cmd = cmd .. ya.quote(tostring(h.url)) .. "; tmux popup -C"
      ya.manager_emit("shell", { cmd })
    else
      if h.cha.is_dir then
        ya.manager_emit("shell", { "cd '"..tostring(h.url).."'; $SHELL -l", block = true })
      else
        ya.manager_emit("open", { hovered = true })
      end
    end
  elseif arg == "alt-enter" then
    if not os.getenv("TMUX") then return end
    local h = cx.active.current.hovered
    if not h then return end
    local script = h.cha.is_dir and "find_empty_shell" or "open_in_vim"
    local cmd = string.format("%s/tmux/scripts/%s.sh '' -n ", os.getenv("XDG_CONFIG_HOME"), script)
    if h.cha.is_dir then
      cmd = cmd .. "cd "
    end
    cmd = cmd .. ya.quote(tostring(h.url)) .. "; tmux popup -C"
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
  elseif arg == "parent-up" then
    local parent = cx.active.parent
    if not parent then return end
    local target = parent.files[parent.cursor]
    if target and target.cha.is_dir then
      ya.manager_emit("cd", { target.url })
    end
  elseif arg == "parent-down" then
    local parent = cx.active.parent
    if not parent then return end
    local target = parent.files[parent.cursor + 2]
    if target and target.cha.is_dir then
      ya.manager_emit("cd", { target.url })
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
  elseif arg == "tab" then
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
  end
}
