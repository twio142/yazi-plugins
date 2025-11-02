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

local get_ctx = ya.sync(function()
	local current = cx.active.current
	local files = {}
	for _, f in ipairs(current.files) do
		table.insert(files, f.url)
	end
	return {
		cwd = current.cwd,
		cursor = current.cursor,
		files = files,
	}
end)

local function get_changed_files(dir, map)
	local child = Command("git")
		:arg({ "--no-optional-locks", "-c", "status.branch=false", "status", "--short", "-uall", "--no-renames" })
		:cwd(tostring(dir))
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
			local url = line:sub(4)
			url = url:gsub('^"(.+)"$', "%1")
			if map then
				url = dir:join(url:match("^([^/]+)"))
				files[tostring(url)] = true
			else
				url = dir:join(url)
				table.insert(files, File({ url = url, cha = fs.cha(url) }))
			end
		end
	end
	return files
end

function M.git_changes()
	local cwd = get_ctx().cwd
	local changed_files = get_changed_files(cwd)
	if #changed_files > 0 then
		local id = ya.id("ft")
		cwd = cwd:into_search("Git changes")
		ya.emit("cd", { Url(cwd) })
		ya.emit("update_files", { op = fs.op("part", { id = id, url = Url(cwd), files = {} }) })
		ya.emit("update_files", { op = fs.op("part", { id = id, url = Url(cwd), files = changed_files }) })
		ya.emit("update_files", { op = fs.op("done", { id = id, url = cwd, cha = Cha({ kind = 16 }) }) })
	else
		ya.notify({ title = "Git changes", content = "No changed files", timeout = 4 })
	end
end

function M.prev_change()
	local ctx = get_ctx()
	local cursor = ctx.cursor
	local files = ctx.files
	local changed_files = get_changed_files(ctx.cwd, true)
	for i = cursor, 1, -1 do
		local f = files[i]
		if changed_files[tostring(f)] then
			ya.emit("reveal", { f })
			return
		end
	end
end

function M.next_change()
	local ctx = get_ctx()
	local cursor = ctx.cursor
	local files = ctx.files
	local changed_files = get_changed_files(ctx.cwd, true)
	for i = cursor + 2, #files, 1 do
		local f = files[i]
		if changed_files[tostring(f)] then
			ya.emit("reveal", { f })
			return
		end
	end
end

local function find_tag(prev)
	local ctx = get_ctx()
	local files = ctx.files
	local cursor = ctx.cursor
	local child = Command("tag")
		:arg({ "-f", "*", "." })
		:cwd(tostring(ctx.cwd))
		:stdout(Command.PIPED)
		:spawn()
	local map = {}
	while true do
		local line, event = child:read_line()
		if event ~= 0 then
			break
		end
		line = line:gsub("\n", "")
		map[line] = true
	end
	if next(map) == nil then
		return
	end
	if prev then
		for i = cursor, 1, -1 do
			local f = files[i]
			if map[tostring(f)] then
				ya.emit("reveal", { f })
				return
			end
		end
	else
		for i = cursor + 2, #files, 1 do
			local f = files[i]
			if map[tostring(f)] then
				ya.emit("reveal", { f })
				return
			end
		end
	end
end

function M.prev_tag()
	find_tag(true)
end

function M.next_tag()
	find_tag(false)
end

return {
	entry = function(_, job)
		M[job.args[1]]()
	end,
}
