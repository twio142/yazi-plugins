--- @since 26.08.11
--- @diagnostic disable: undefined-global

local M = {}

local WINDOWS = ya.target_family() == "windows"
local SEP = WINDOWS and "\\" or "/"
local MAX_TABS = 9
local DEFAULT = "default"

local OPTS = {
	delete_default_after_restore = true,
}

local opts = ya.sync(function(state)
	return state.opts or OPTS
end)

--- Mirrors Yazi's own config directory resolution.
local function config_dir()
	local dir = os.getenv("YAZI_CONFIG_HOME")
	if dir and dir ~= "" and (WINDOWS or dir:sub(1, 1) == "/") then
		return dir
	elseif WINDOWS then
		return (os.getenv("APPDATA") or "") .. "\\yazi\\config"
	end
	dir = os.getenv("XDG_CONFIG_HOME")
	if dir and dir:sub(1, 1) == "/" then
		return dir .. "/yazi"
	end
	return (os.getenv("HOME") or "") .. "/.config/yazi"
end

local SESSIONS = table.concat({ config_dir(), "plugins", "sessions.yazi", "sessions" }, SEP)

--- The per-tab preferences worth keeping, in a fixed order so a session file
--- doesn't churn, each with the type it's written as.
local PREFS = {
	{ "linemode", "string" },
	{ "show_hidden", "boolean" },
	{ "sort_by", "string" },
	{ "sort_sensitive", "boolean" },
	{ "sort_reverse", "boolean" },
	{ "sort_dir_first", "boolean" },
	{ "sort_translit", "boolean" },
	{ "sort_fallback", "string" },
}

local function notify(content, level)
	ya.notify({ title = "Session", content = content, timeout = 1, level = level or "info" })
end

--- Paths are stored one per line, so anything that would break a line is escaped.
local function esc(s)
	return (s:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\r", "\\r"))
end

local function unesc(s)
	return (
		s:gsub("\\(.)", function(c)
			if c == "n" then
				return "\n"
			elseif c == "r" then
				return "\r"
			end
			return c
		end)
	)
end

local snapshot = ya.sync(function()
	--- A search folder is a virtual URL that can't be `cd`'d back into, so only
	--- the plain path it searched is worth keeping.
	local function plain(url)
		return url.spec.is_search and tostring(url.path) or tostring(url)
	end

	local tabs = {}
	for i = 1, #cx.tabs do
		local tab = cx.tabs[i]
		local selected = {}
		for _, f in pairs(tab.selected) do
			selected[#selected + 1] = plain(f.url)
		end

		-- Only the preferences this tab has moved away from the config are kept,
		-- so the rest keep following `yazi.toml` as it changes.
		local prefs
		for _, p in ipairs(PREFS) do
			if tab.pref[p[1]] ~= rt.mgr[p[1]] then
				prefs = prefs or {}
				prefs[p[1]] = tab.pref[p[1]]
			end
		end

		-- `tab.name` falls back to the cwd's basename, so only `pref.name` tells
		-- whether the tab was actually renamed.
		local h, name = tab.current.hovered, tab.pref.name
		tabs[i] = {
			cwd = plain(tab.current.cwd),
			name = name ~= "" and name or nil,
			hovered = h and plain(h.url) or nil,
			prefs = prefs,
			selected = selected,
		}
	end

	local yanked = {}
	for _, f in pairs(cx.yanked) do
		yanked[#yanked + 1] = plain(f.url)
	end

	return { idx = cx.tabs.idx, cut = cx.yanked.is_cut, yanked = yanked, tabs = tabs }
end)

local tab_count = ya.sync(function()
	return #cx.tabs
end)

local function serialize(s)
	local out = { ("idx\t%d"):format(s.idx), ("cut\t%d"):format(s.cut and 1 or 0) }
	for _, url in ipairs(s.yanked) do
		out[#out + 1] = "yank\t" .. esc(url)
	end
	for _, tab in ipairs(s.tabs) do
		out[#out + 1] = "tab\t" .. esc(tab.cwd)
		if tab.name then
			out[#out + 1] = "name\t" .. esc(tab.name)
		end
		if tab.hovered then
			out[#out + 1] = "hov\t" .. esc(tab.hovered)
		end
		for _, p in ipairs(PREFS) do
			local v = tab.prefs and tab.prefs[p[1]]
			if v ~= nil then
				out[#out + 1] = ("pref\t%s\t%s"):format(p[1], p[2] == "boolean" and (v and 1 or 0) or esc(v))
			end
		end
		for _, url in ipairs(tab.selected) do
			out[#out + 1] = "sel\t" .. esc(url)
		end
	end
	return table.concat(out, "\n") .. "\n"
end

local PREF_TYPES = {}
for _, p in ipairs(PREFS) do
	PREF_TYPES[p[1]] = p[2]
end

local function deserialize(file)
	local s = { idx = 1, cut = false, yanked = {}, tabs = {} }
	for line in file:lines() do
		local key, value = line:match("^(%a+)\t(.*)$")
		local tab = s.tabs[#s.tabs]
		if key == "idx" then
			s.idx = tonumber(value) or 1
		elseif key == "cut" then
			s.cut = value == "1"
		elseif key == "yank" then
			s.yanked[#s.yanked + 1] = unesc(value)
		elseif key == "tab" then
			s.tabs[#s.tabs + 1] = { cwd = unesc(value), prefs = {}, selected = {} }
		elseif key == "name" and tab then
			tab.name = unesc(value)
		elseif key == "hov" and tab then
			tab.hovered = unesc(value)
		elseif key == "sel" and tab then
			tab.selected[#tab.selected + 1] = unesc(value)
		elseif key == "pref" and tab then
			local k, v = value:match("^([%a_]+)\t(.*)$")
			if PREF_TYPES[k] == "boolean" then
				tab.prefs[k] = v == "1"
			elseif PREF_TYPES[k] == "string" then
				tab.prefs[k] = unesc(v)
			end
		end
	end
	return s
end

--- `toggle_all` takes `File`s, not URLs, and selects the whole folder when given
--- none, so paths that no longer exist have to be dropped beforehand.
local function resolve(paths)
	local files = {}
	for _, path in ipairs(paths) do
		local file = fs.file(Url(path))
		if file then
			files[#files + 1] = file
		end
	end
	return files
end

local function path_of(name)
	if name:find("[/\\]") then
		return nil, ("Invalid session name: %s"):format(name)
	end
	return SESSIONS .. SEP .. name
end

function M.save(name, quit)
	name = name or DEFAULT
	local path, err = path_of(name)
	if not path then
		return notify(err, "error")
	end

	local ok, e = fs.create("dir_all", Url(SESSIONS))
	if not ok then
		return notify(("Cannot create %s: %s"):format(SESSIONS, e), "error")
	end

	local s = snapshot()
	local file, msg = io.open(path, "w")
	if not file then
		return notify(("Cannot write %s: %s"):format(path, msg), "error")
	end
	file:write(serialize(s))
	file:close()

	if quit then
		ya.emit("quit", {})
	else
		notify(("Saved %d tab(s) to `%s`"):format(#s.tabs, name))
	end
end

function M.save_as(_, quit)
	local value, event = ya.input({
		title = "Session name:",
		pos = { "top-center", w = 40, x = 0, y = 2 },
	})
	if event ~= 1 then
		return
	end

	local name = value:match("^%s*(.-)%s*$")
	M.save(name ~= "" and name or DEFAULT, quit)
end

function M.setup(self, o)
	self.opts = {}
	for k, v in pairs(OPTS) do
		local given = o and o[k]
		self.opts[k] = given == nil and v or given
	end

	local entries = rt.args.entries
	if not entries[1] or tostring(entries[1]) ~= "-r" then
		return
	end

	ya.async(M.restore, entries[2] and tostring(entries[2]) or DEFAULT)
end

function M.restore(name)
	name = name or DEFAULT
	local path, err = path_of(name)
	if not path then
		return notify(err, "error")
	end

	local file = io.open(path, "r")
	if not file then
		if name ~= DEFAULT then
			notify(("No session named `%s`"):format(name), "error")
		end
		return
	end
	local s = deserialize(file)
	file:close()

	if #s.tabs == 0 then
		return notify(("Session `%s` has no tabs"):format(name), "error")
	end
	while #s.tabs > MAX_TABS do
		table.remove(s.tabs)
	end

	-- Every path is resolved before a single command goes out, so that the awaits
	-- in between can't interleave with the sequence emitted below.
	local yanked = resolve(s.yanked)
	for _, tab in ipairs(s.tabs) do
		tab.files = resolve(tab.selected)
		-- `reveal` conjures a dummy entry for a target that's gone, so a stale
		-- hover is dropped rather than left to haunt the folder.
		if tab.hovered and not fs.file(Url(tab.hovered)) then
			tab.hovered = nil
		end
	end

	-- Everything is rebuilt on the first tab, so the others go away first, and
	-- the selection it carries has to go with them: `yank` below takes whatever
	-- is selected at that point.
	local open = tab_count()
	ya.emit("tab_switch", { 0 })
	for _ = 2, open do
		ya.emit("tab_close", { 1 })
	end
	ya.emit("escape", { all = true })
	ya.emit("unyank", {})

	-- The yanked files are restored first: `yank` consumes the selection and
	-- clears it afterwards, which would wipe the one restored below.
	if #yanked > 0 then
		yanked.state = "on"
		ya.emit("toggle_all", yanked)
		ya.emit("yank", { cut = s.cut })
	end

	for i, tab in ipairs(s.tabs) do
		ya.emit(i == 1 and "cd" or "tab_create", { tab.cwd })
		-- Sent unconditionally: the reused first tab may still carry a name of
		-- its own, and an empty one is how `tab_rename` clears it.
		ya.emit("tab_rename", { tab.name or "" })

		-- A preference is only written down when it left the config behind, so
		-- anything absent falls back to the config: that also undoes whatever the
		-- reused first tab was carrying.
		local p = {}
		for _, k in ipairs(PREFS) do
			local v = tab.prefs[k[1]]
			if v == nil then
				v = rt.mgr[k[1]]
			end
			p[k[1]] = v
		end
		ya.emit("linemode", { p.linemode })
		ya.emit("hidden", { p.show_hidden and "show" or "hide" })
		ya.emit("sort", {
			p.sort_by,
			sensitive = p.sort_sensitive,
			reverse = p.sort_reverse,
			dir_first = p.sort_dir_first,
			translit = p.sort_translit,
			fallback = p.sort_fallback,
		})

		if tab.hovered then
			ya.emit("reveal", { tab.hovered })
		end
		if #tab.files > 0 then
			tab.files.state = "on"
			ya.emit("toggle_all", tab.files)
		end
	end

	ya.emit("tab_switch", { math.max(math.min(s.idx, #s.tabs), 1) - 1 })

	if name == DEFAULT and opts().delete_default_after_restore then
		fs.remove("file", Url(path))
	end

	notify(("Restored %d tab(s) from `%s`"):format(#s.tabs, name))
end

return {
	setup = M.setup,
	entry = function(_, job)
		local action = M[job.args[1]]
		if not action then
			return notify(("Unknown action: %s"):format(tostring(job.args[1])), "error")
		end

		local name, quit
		for i = 2, #job.args do
			if job.args[i] == "-q" then
				quit = true
			else
				name = job.args[i]
			end
		end
		action(name, quit)
	end,
}
