--- @since 25.2.26
local M = {}

local function prompt(title)
	return ya.input({
		title = title .. ":",
		position = { "hovered", w = 50, x = 13, y = 1 },
		realtime = true,
		debounce = 0.1,
	})
end

function M.find()
	local input = prompt("Find next")

	while true do
		local value, event = input:recv()
		if event ~= 1 and event ~= 3 then
			ya.mgr_emit("escape", { find = true })
			break
		end

		ya.mgr_emit("find_do", { value, smart = true })

		if event == 1 then
			return
		end
	end
end

local hovered = ya.sync(function()
	local h = cx.active.current.hovered
	if not h then
		return {}
	end

	return {
		url = h.url,
		is_dir = h.cha.is_dir,
		unique = #cx.active.current.files == 1,
	}
end)

function M.filter()
	local input = prompt("Filter")

	while true do
		local value, event = input:recv()
		if event ~= 1 and event ~= 3 then
			ya.mgr_emit("escape", { filter = true })
			break
		end

		ya.mgr_emit("filter_do", { value, smart = true })

		local h = hovered()
		if event == 1 then
			if h.url then
				ya.mgr_emit("reveal", { h.url })
			end
			return
		end
	end
end

function M.smart_filter()
	local input = prompt("Smart filter")

	while true do
		local value, event = input:recv()
		if event ~= 1 and event ~= 3 then
			ya.mgr_emit("escape", { filter = true })
			break
		end

		ya.mgr_emit("filter_do", { value, smart = true })

		local h = hovered()
		if h.unique and h.is_dir then
			ya.mgr_emit("escape", { filter = true })
			ya.mgr_emit("enter", {})
			input = prompt("Smart filter:")
		elseif event == 1 then
			ya.mgr_emit("reveal", { h.url })
			return
		end
	end
end

local get_cwd = ya.sync(function()
	return tostring(cx.active.current.cwd)
end)

function M.git_changes()
	local cwd = get_cwd()
	local child = Command("git"):args({ "status", "--short" }):cwd(cwd):stdout(Command.PIPED):spawn()
	local files = {}
	while true do
		local line, event = child:read_line()
		if event ~= 0 then
			break
		end
		line = line:gsub("\n", "")
		local status = line:sub(1, 2)
		line = line:sub(4)
		if status == "R " then
			line = line:match(" -> (.+)$") or line
		end
		if not status:find("D") then
			if line:find([[^"(.+)"$]]) then
				line = line:match([[^"(.+)"$]]):gsub('\\"', '"')
			end
			if line:find("/$") then
				line = line .. "*"
			end
			table.insert(files, line)
		end
	end
	if #files > 0 then
		local args = "-l -a ."
		for _, file in ipairs(files) do
			args = args .. string.format(' -g "%s"', file)
		end
		ya.mgr_emit("search_do", { via = "rg", args = args })
	else
		ya.notify({ title = "Git changes", content = "No changed files", timeout = 4 })
	end
end

return {
	entry = function(_, job)
		M[job.args[1]]()
	end,
}
