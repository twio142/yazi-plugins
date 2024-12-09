local M = {}

M.alfred = function(state, mode)
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
  entry = function(_, job)
    local args = job.args
    local func = M[args[1]]
    if not func then
      return
    end
    table.remove(args, 1)
    func(state(), table.unpack(args))
  end
}
