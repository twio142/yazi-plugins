--- @since 25.12.29
--- @diagnostic disable: undefined-global

local M = {}

local get_state = ya.sync(function()
	local h = cx.active.current.hovered
	local selected = {}
	for _, url in pairs(cx.active.selected) do
		table.insert(selected, tostring(url))
	end
	for _, url in pairs(cx.yanked) do
		if not cx.active.selected[tostring(url)] then
			table.insert(selected, tostring(url))
		end
	end
	for i = 1, #cx.tabs do
		for _, url in pairs(cx.tabs[i].selected) do
			local s = tostring(url)
			local found = false
			for _, existing in ipairs(selected) do
				if existing == s then
					found = true
					break
				end
			end
			if not found then
				table.insert(selected, s)
			end
		end
	end
	return {
		cwd = tostring(cx.active.current.cwd),
		hovered = h and tostring(h.url) or nil,
		hovered_name = h and h.url.name or nil,
		hovered_parent = h and tostring(h.url.parent) or nil,
		selected = selected,
	}
end)

local function get_password()
	local value, event = ya.input({
		title = "Password:",
		pos = { "top-center", w = 40 },
		obscure = true,
	})
	if event ~= 1 then
		return nil
	end
	return value
end

local function sudo_run(password, args)
	local child, err =
		Command("sudo"):arg({ "-S" }):arg(args):stdin(Command.PIPED):stdout(Command.PIPED):stderr(Command.PIPED):spawn()
	if not child then
		ya.notify({ title = "Sudo", content = tostring(err), timeout = 2, level = "error" })
		return nil
	end
	child:write_all(password .. "\n")
	child:flush()
	local output = child:wait_with_output()
	if not output or not output.status.success then
		local msg = output and output.stderr ~= "" and output.stderr:gsub("\n$", "") or "Command failed"
		ya.notify({ title = "Sudo", content = msg, timeout = 5, level = "error" })
		return nil
	end
	return output.stdout
end

function M.copy(force)
	local state = get_state()
	if #state.selected == 0 then
		ya.notify({ title = "Sudo", content = "No files selected", timeout = 2 })
		return
	end
	local password = get_password()
	if not password then
		return
	end
	local args = { "cp", "-r", force and "-f" or "-n" }
	for _, f in ipairs(state.selected) do
		table.insert(args, f)
	end
	table.insert(args, state.cwd)
	if sudo_run(password, args) then
		ya.emit("reload", {})
	end
end

function M.move(force)
	local state = get_state()
	if #state.selected == 0 then
		ya.notify({ title = "Sudo", content = "No files selected", timeout = 2 })
		return
	end
	local password = get_password()
	if not password then
		return
	end
	local args = { "mv", force and "-f" or "-n" }
	for _, f in ipairs(state.selected) do
		table.insert(args, f)
	end
	table.insert(args, state.cwd)
	if sudo_run(password, args) then
		ya.emit("reload", {})
	end
end

function M.remove()
	local state = get_state()
	if #state.selected == 0 then
		ya.notify({ title = "Sudo", content = "No files selected", timeout = 2 })
		return
	end
	local password = get_password()
	if not password then
		return
	end
	local args = { "rm", "-rf" }
	for _, f in ipairs(state.selected) do
		table.insert(args, f)
	end
	if sudo_run(password, args) then
		ya.emit("reload", {})
	end
end

function M.symlink()
	local state = get_state()
	if #state.selected == 0 then
		ya.notify({ title = "Sudo", content = "No files selected", timeout = 2 })
		return
	end
	local password = get_password()
	if not password then
		return
	end
	local args = { "ln", "-s" }
	for _, f in ipairs(state.selected) do
		table.insert(args, f)
	end
	table.insert(args, state.cwd)
	if sudo_run(password, args) then
		ya.emit("reload", {})
	end
end

function M.hardlink()
	local state = get_state()
	if #state.selected == 0 then
		ya.notify({ title = "Sudo", content = "No files selected", timeout = 2 })
		return
	end
	local password = get_password()
	if not password then
		return
	end
	local args = { "ln" }
	for _, f in ipairs(state.selected) do
		table.insert(args, f)
	end
	table.insert(args, state.cwd)
	if sudo_run(password, args) then
		ya.emit("reload", {})
	end
end

function M.rename()
	local state = get_state()
	if not state.hovered then
		return
	end
	local new_name, event = ya.input({
		title = "Rename:",
		value = state.hovered_name,
		pos = { "hovered", w = 50, x = 13, y = 1 },
	})
	if event ~= 1 or new_name == "" or new_name == state.hovered_name then
		return
	end
	local password = get_password()
	if not password then
		return
	end
	local dest = state.hovered_parent .. "/" .. new_name
	if sudo_run(password, { "mv", state.hovered, dest }) then
		ya.emit("reload", {})
	end
end

function M.shell()
	local state = get_state()
	local value, event = ya.input({
		realtime = false,
		title = "Sudo Shell:",
		pos = { "top-center", w = 50, x = 0, y = 2 },
	})
	if event ~= 1 then
		return
	end
	local password = get_password()
	if not password then
		return
	end
	if #state.selected == 0 and state.hovered then
		state.selected = { state.hovered }
	end
	local shell_path = os.getenv("SHELL") or "/bin/zsh"
	local args = { shell_path, "-c", value }
	if state.hovered then
		table.insert(args, state.hovered)
	end
	for _, f in ipairs(state.selected) do
		table.insert(args, f)
	end
	local stdout = sudo_run(password, args)
	if stdout ~= nil then
		local out = stdout:gsub("\n$", "")
		if out ~= "" then
			ya.notify({ title = "Sudo Shell", content = out, timeout = 2 })
		end
		ya.emit("reload", {})
	end
end

return {
	entry = function(_, job)
		local mode = job.args[1]
		if mode == "copy-force" then
			M.copy(true)
		elseif mode == "copy" then
			M.copy(false)
		elseif mode == "move-force" then
			M.move(true)
		elseif mode == "move" then
			M.move(false)
		else
			local func = M[mode]
			if func then
				func()
			end
		end
	end,
}
