---@diagnostic disable: undefined-global

local save = ya.sync(function(this, cwd, output)
	if cx.active.current.cwd == Url(cwd) then
		this.output = output
		ui.render()
	end
end)

local function theme()
	local t = th.githead or {}
	return {
		branch = t.branch or ui.Style():fg("blue"),
		commit = t.commit or ui.Style():fg("bright magenta"),
		behind = t.behind or ui.Style():fg("bright magenta"),
		ahead = t.ahead or ui.Style():fg("bright magenta"),
		stashes = t.stashes or ui.Style():fg("bright magenta"),
		state = t.state or ui.Style():fg("red"),
		staged = t.staged or ui.Style():fg("bright yellow"),
		unstaged = t.unstaged or ui.Style():fg("bright yellow"),
		untracked = t.untracked or ui.Style():fg("bright blue"),
	}, {
		branch_prefix = t.branch_prefix or "on",
		branch_symbol = t.branch_symbol or "",
		branch_borders = t.branch_borders or "()",
		commit_symbol = t.commit_symbol or "@",
		behind_symbol = t.behind_symbol or "⇣",
		ahead_symbol = t.ahead_symbol or "⇡",
		stashes_symbol = t.stashes_symbol or "$",
		state_symbol = t.state_symbol or "~",
		staged_symbol = t.staged_symbol or "+",
		unstaged_symbol = t.unstaged_symbol or "!",
		untracked_symbol = t.untracked_symbol or "?",
	}
end

return {
	setup = function(this, options)
		options = options or {}

		local config = {
			show_branch = options.show_branch ~= false,
			-- `behind_ahead` is the legacy name of this option
			show_behind_ahead = options.show_behind_ahead ~= false and options.behind_ahead ~= false,
			show_stashes = options.show_stashes ~= false,
			show_state = options.show_state ~= false,
			show_state_prefix = options.show_state_prefix ~= false,
			show_staged = options.show_staged ~= false,
			show_unstaged = options.show_unstaged ~= false,
			show_untracked = options.show_untracked ~= false,
		}

		local styles, signs = theme()
		ps.sub("theme", function()
			styles, signs = theme()
			ui.render()
		end)

		function Header:get_branch(status)
			local branch = status:match("On branch (%S+)")

			if branch == nil then
				local commit = status:match("onto (%S+)") or status:match("detached at (%S+)")

				if commit == nil then
					return ""
				else
					local branch_prefix = signs.branch_prefix == "" and " " or " " .. signs.branch_prefix .. " "
					local commit_prefix = signs.commit_symbol == "" and "" or signs.commit_symbol

					return ui.Line({
						ui.Span(branch_prefix .. commit_prefix),
						ui.Span(commit):style(styles.commit),
					})
				end
			else
				local left_border = signs.branch_borders:sub(1, 1)
				local right_border = signs.branch_borders:sub(2, 2)

				local branch_string = ""

				if signs.branch_symbol == "" then
					branch_string = left_border .. branch .. right_border
				else
					branch_string = left_border .. signs.branch_symbol .. " " .. branch .. right_border
				end

				local branch_prefix = signs.branch_prefix == "" and " " or " " .. signs.branch_prefix .. " "

				return ui.Line({
					ui.Span(branch_prefix),
					ui.Span(branch_string):style(styles.branch),
				})
			end
		end

		function Header:get_behind_ahead(status)
			local diverged_ahead, diverged_behind = status:match("have (%d+) and (%d+) different")

			if diverged_ahead and diverged_behind then
				return ui.Line({
					ui.Span(" " .. signs.behind_symbol .. diverged_behind):style(styles.behind),
					ui.Span(signs.ahead_symbol .. diverged_ahead):style(styles.ahead),
				})
			else
				local behind = status:match("behind %S+ by (%d+) commit")
				local ahead = status:match("ahead of %S+ by (%d+) commit")

				if ahead then
					return ui.Span(" " .. signs.ahead_symbol .. ahead):style(styles.ahead)
				elseif behind then
					return ui.Span(" " .. signs.behind_symbol .. behind):style(styles.behind)
				else
					return ""
				end
			end
		end

		function Header:get_stashes(status)
			local stashes = tonumber(status:match("Your stash currently has (%S+)"))

			return stashes ~= nil and ui.Span(" " .. signs.stashes_symbol .. stashes):style(styles.stashes) or ""
		end

		function Header:get_state(status)
			local result = status:match("Unmerged paths:%s*(.-)%s*\n\n")
			if result then
				local filtered_result = result:gsub("^[%s]*%b()[%s]*", ""):gsub("^[%s]*%b()[%s]*", "")

				local unmerged = 0
				for line in filtered_result:gmatch("[^\r\n]+") do
					if line:match("%S") then
						unmerged = unmerged + 1
					end
				end

				local state_name = ""

				if config.show_state_prefix then
					if status:find("git merge") then
						state_name = "merge "
					elseif status:find("git cherry%-pick") then
						state_name = "cherry "
					elseif status:find("git rebase") then
						state_name = "rebase "

						if status:find("done") then
							local done = status:match("%((%d+) com.- done%)") or ""
							state_name = state_name .. done .. "/" .. unmerged .. " "
						end
					else
						state_name = ""
					end
				end

				return ui.Span(" " .. state_name .. signs.state_symbol .. unmerged):style(styles.state)
			else
				return ""
			end
		end

		function Header:get_staged(status)
			local result = status:match("Changes to be committed:%s*(.-)%s*\n\n")
			if result then
				local filtered_result = result:gsub("^[%s]*%b()[%s]*", "")

				local staged = 0
				for line in filtered_result:gmatch("[^\r\n]+") do
					if line:match("%S") then
						staged = staged + 1
					end
				end

				return ui.Span(" " .. signs.staged_symbol .. staged):style(styles.staged)
			else
				return ""
			end
		end

		function Header:get_unstaged(status)
			local result = status:match("Changes not staged for commit:%s*(.-)%s*\n\n")
			if result then
				local filtered_result = result:gsub("^[%s]*%b()[\r\n]*", ""):gsub("^[%s]*%b()[\r\n]*", "")

				local unstaged = 0
				for line in filtered_result:gmatch("[^\r\n]+") do
					if line:match("%S") then
						unstaged = unstaged + 1
					end
				end

				return ui.Span(" " .. signs.unstaged_symbol .. unstaged):style(styles.unstaged)
			else
				return ""
			end
		end

		function Header:get_untracked(status)
			local result = status:match("Untracked files:%s*(.-)%s*\n\n")
			if result then
				local filtered_result = result:gsub("^[%s]*%b()[\r\n]*", "")

				local untracked = 0
				for line in filtered_result:gmatch("[^\r\n]+") do
					if line:match("%S") then
						untracked = untracked + 1
					end
				end

				return ui.Span(" " .. signs.untracked_symbol .. untracked):style(styles.untracked)
			else
				return ""
			end
		end

		function Header:githead()
			local status = this.output
			if not status then
				return ""
			end

			local branch = config.show_branch and self:get_branch(status) or ""
			local behind_ahead = config.show_behind_ahead and self:get_behind_ahead(status) or ""
			local stashes = config.show_stashes and self:get_stashes(status) or ""
			local state = config.show_state and self:get_state(status) or ""
			local staged = config.show_staged and self:get_staged(status) or ""
			local unstaged = config.show_unstaged and self:get_unstaged(status) or ""
			local untracked = config.show_untracked and self:get_untracked(status) or ""

			return ui.Line({
				branch,
				behind_ahead,
				stashes,
				state,
				staged,
				unstaged,
				untracked,
			})
		end

		Header:children_add(Header.githead, 2000, Header.LEFT)

		local callback = function()
			local cwd = cx.active.current.cwd

			if this.cwd ~= cwd then
				this.cwd = cwd
				ya.emit("plugin", {
					this._id,
					ya.quote(tostring(cwd), true),
				})
			end
		end

		ps.sub("cd", callback)
		ps.sub("tab", callback)
	end,

	entry = function(_, job)
		local args = job.args or job
		local command = Command("git")
			:arg({ "status", "--ignore-submodules=dirty", "--branch", "--show-stash", "--ahead-behind" })
			:cwd(args[1])
			:env("LANGUAGE", "en_US.UTF-8")
			:stdout(Command.PIPED)
		local output = command:output()

		if output then
			save(args[1], output.stdout)
		end
	end,
}
