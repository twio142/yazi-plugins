---@diagnostic disable: undefined-global
local M = {}

local function detect_separator(file)
	local scpt = [=[
file="%s"
ss=(, ";" "|", "	")
vs=("${ss[@]}")
read -r fl < "$file"
while IFS= read -r l; do
	nvs=()
	for s in "${vs[@]}"; do
		fc=$(echo "$fl" | grep -o "$s" | wc -l)
		cc=$(echo "$l" | grep -o "$s" | wc -l)
		[[ "$fc" -eq "$cc" && "$cc" -gt 0 ]] && nvs+=("$s")
	done
	vs=("${nvs[@]}")
	[[ ${#vs[@]} -eq 1 ]] && break
done < "$file"
printf "${vs[0]}"
	]=]
	scpt = string.format(scpt, tostring(file.url))
	local output, _ = Command("bash"):args({ "-c", scpt }):stdout(Command.PIPED):stderr(Command.PIPED):output()
	local sep = output.stdout
	return sep == "" and "," or sep
end

M.opts = {
	["--icsv"] = true,
	["--opprint"] = true,
	["-C"] = true,
	["--ifs"] = detect_separator,
	["--key-color"] = "208",
	["--value-color"] = "grey70",
}

function M:peek(job)
	local args = {}
	for k, v in pairs(M.opts) do
		table.insert(args, k)
		if type(v) == "string" then
			table.insert(args, v)
		elseif type(v) == "function" and v then
			table.insert(args, v(job.file))
		end
	end
	table.insert(args, "cat")
	table.insert(args, tostring(job.file.url))
	local child = Command("mlr"):args(args):stdout(Command.PIPED):spawn()

	local limit = job.area.h
	local i, lines = 0, ""
	repeat
		local line, event = child:read_line()
		if event == 1 then
			ya.dbg(tostring(event))
		elseif event ~= 0 then
			break
		end

		i = i + 1
		if i > job.skip then
			lines = lines .. line
		end
	until i >= job.skip + limit

	child:start_kill()
	if job.skip > 0 and i < job.skip + limit then
		ya.mgr_emit("peek", { math.max(0, i - limit), only_if = job.file.url, upper_bound = true })
	else
		lines = lines:gsub("\t", string.rep(" ", rt.preview.tab_size))
		ya.preview_widgets(job, { ui.Text(lines):area(job.area) })
	end
end

function M:seek(job)
	require("code").seek(job)
end

function M.setup(_, opts)
	for k, v in pairs(opts) do
		if k:find("-") == 1 and (type(v) == "boolean" or type(v) == "string" or type(v) == "function") then
			if v == false then
				M.opts[k] = nil
			else
				M.opts[k] = v
			end
		end
	end
end

return M
