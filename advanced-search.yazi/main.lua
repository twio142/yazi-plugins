---@diagnostic disable: undefined-global
--- @since 25.3.7
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
			ya.emit("escape", { find = true })
			break
		end

		ya.emit("find_do", { value, smart = true })

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
			ya.emit("escape", { filter = true })
			break
		end

		ya.emit("filter_do", { value, smart = true })

		local h = hovered()
		if event == 1 then
			if h.url then
				ya.emit("reveal", { h.url })
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
			ya.emit("escape", { filter = true })
			break
		end

		ya.emit("filter_do", { value, smart = true })

		local h = hovered()
		if h.unique and h.is_dir then
			ya.emit("escape", { filter = true })
			ya.emit("enter", {})
			input = prompt("Smart filter:")
		elseif event == 1 then
			ya.emit("reveal", { h.url })
			return
		end
	end
end

local get_cwd = ya.sync(function()
	return cx.active.current.cwd
end)

function M.git_changes()
	local cwd = get_cwd()
	local child = Command("git")
		:arg({ "--no-optional-locks", "-c", "core.quotePath=", "status", "--short", "-uall", "--no-renames" })
		:cwd(tostring(cwd))
		:stdout(Command.PIPED)
		:spawn()
	local files = {}
	while true do
		local line, event = child:read_line()
		if event ~= 0 then
			break
		end
		line = line:gsub("\n", "")
		local status = line:sub(1, 2)
		if not status:find("D") then
			local url = cwd:join(line:sub(4))
			local cha = fs.cha(url)
			table.insert(files, File({ url = url, cha = cha }))
		end
	end
	if #files > 0 then
		local id = ya.id("ft")
		cwd = cwd:into_search("Git changes")
		ya.emit("cd", { Url(cwd) })
		ya.emit("update_files", { op = fs.op("part", { id = id, url = Url(cwd), files = {} }) })
		ya.emit("update_files", { op = fs.op("part", { id = id, url = Url(cwd), files = files }) })
		ya.emit("update_files", { op = fs.op("done", { id = id, url = cwd, cha = Cha({ kind = 16 }) }) })
	else
		ya.notify({ title = "Git changes", content = "No changed files", timeout = 4 })
	end
end

return {
	entry = function(_, job)
		M[job.args[1]]()
	end,
}
