_G.ya = _G.ya or {}
_G.cx = _G.cx or {}
_G.Command = _G.Command or {}

-- local function fail(s, ...) ya.notify { title = "fzf", content = s:format(...), timeout = 5, level = "error" } end

local M = {}

M.z = function(cwd)
  ya.hide()
  local _z = ":reload:zoxide query {q} -l --exclude '${PWD}' | awk '{ if (!seen[tolower()]++) print }' || true"
  local output = Command("fzf")
    :args({"--bind", "start".._z})
    :args({"--bind", "change".._z})
    :args({"--disabled", "--preview", "fzf-preview {}"})
    :cwd(cwd)
    :stdout(Command.PIPED)
    :output()
  local selected = output.stdout:gsub("\n", "")
  if selected ~= "" then
    ya.manager_emit("cd", { selected })
  end
end

M.fd = function(cwd)
  ya.hide()
  local _hd = function(t)
    local types = {
      f = "file",
      d = "dir",
      l = "symlink",
      s = "socket",
      x = "executable",
    }
    local header = {}
    local BOLD="\x1b[1;36m"
    local OFF="\x1b[0m"
    for k, v in pairs(types) do
      local h = t == k and BOLD or ""
      h = h .. string.format("⌥%s %s", string.upper(k), v)
      h = h .. (t == k and OFF or "")
      table.insert(header, h)
    end
    return table.concat(header, " / ")
  end
  local _fd = function(k, t)
    return string.format("%s:reload(fd --type %s -H -L --exclude .DS_Store --exclude .git --strip-cwd-prefix=always .)+change-header( %s )", k, t, _hd(t))
  end
  local output = Command("fzf")
    :args({"--preview", "fzf-preview {}"})
    :args({"--bind", _fd("start", "f")})
    :args({"--bind", _fd("alt-d", "d")})
    :args({"--bind", _fd("alt-l", "l")})
    :args({"--bind", _fd("alt-s", "s")})
    :args({"--bind", _fd("alt-f", "f")})
    :args({"--bind", _fd("alt-x", "x")})
    :cwd(cwd)
    :stdout(Command.PIPED)
    :output()
  local selected = output.stdout:gsub("\n", "")
  if selected ~= "" then
    ya.manager_emit(selected:find("/$") and "cd" or "reveal", { selected })
  end
end

M.fif = function(cwd)
  ya.hide()
  local child = Command("fif")
    :args({"-o"})
    :cwd(cwd)
    :stdout(Command.PIPED)
    :spawn()
  local files = {}
  local ln
  while true do
    local line, event = child:read_line()
    if event ~= 0 then break end
    local file, l = line:match("^([^:]+):(%d+):")
    ln = l
    table.insert(files, file)
  end
  if #files == 0 then return end
  local cmd = "nvim "
  if #files == 1 then
    cmd = cmd .. '"' .. files[1] .. '" +' .. ln
  else
    for _, file in ipairs(files) do
      cmd = cmd .. '"' .. file .. '" '
    end
  end
  ya.manager_emit("shell", { cmd, confirm = true, block = true })
end

M.git = function(cwd)
  ya.hide()
  local child = Command("awk")
    :arg("/recentrepos:/ {found=1; next} found && /^[^[:space:]]/ {exit} found {print}")
    :arg(os.getenv("XDG_STATE_HOME") .. "/lazygit/state.yml")
    :stdout(Command.PIPED)
    :spawn()
  local repos = {}
  while true do
    local repo, event = child:read_line()
    if event ~= 0 then break end
    repo = repo:gsub("^ +- ", ""):gsub("\n", "")
    if repo ~= "" and repo ~= cwd then
      table.insert(repos, repo)
    end
  end
  child = Command("fzf")
    :args({"--preview", [[echo -e "\033[1m$(basename {})\033[0m\n"; git -c color.status=always -C {} status -bs]], "--preview-window=wrap"})
    :stdin(Command.PIPED)
    :stdout(Command.PIPED)
    :spawn()
  child:write_all(table.concat(repos, "\n"))
  child:flush()
  local selected = child:wait_with_output().stdout:gsub("\n", "")
  if selected ~= "" then
    ya.manager_emit("cd", { selected })
  end
end

M.obsearch = function(cwd)
  ya.hide()
  local child = Command("obsearch")
    :args({"-o"})
    :cwd(cwd)
    :stdout(Command.PIPED)
    :spawn()
  local files = {}
  local ln
  while true do
    local line, event = child:read_line()
    if event ~= 0 then break end
    local file, l = line:match("^([^:]+):(%d+):")
    ln = l
    table.insert(files, file)
  end
  if #files == 0 then return end
  local cmd = "nvim "
  if #files == 1 then
    cmd = cmd .. '"' .. files[1] .. '" +' .. ln
  else
    for _, file in ipairs(files) do
      cmd = cmd .. '"' .. file .. '" '
    end
  end
  ya.manager_emit("shell", { cmd, confirm = true, block = true })
end

local state = ya.sync(function() return tostring(cx.active.current.cwd) end)

return {
  entry = function(_, args)
    local cwd = state()
    M[args[1]](cwd)
  end
}

