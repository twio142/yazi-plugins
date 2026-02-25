-- A yazi plugin that provides a spotter for pdf files
---@diagnostic disable: undefined-doc-name, undefined-global

local M = {}

--- @class Job
--- @field file File userdata (url, name, cha metadata)
--- @field mime string MIME type for the file
--- @field area Rect preview area (w/h)
--- @field skip integer scroll offset (rarely used in spotters)
--- @field args table extra args from the plugin config
--- @field id integer unique request identifier

--- Render the metadata table shown in the "spot" overlay
--- @param job Job
function M:spot(job)
	local child, _ = Command("pdfinfo")
		:arg(tostring(job.file.url.path))
		:stdout(Command.PIPED)
		:spawn()

	local metadata = { title = "", author = "", pages = "" }
	while true do
		local line, event = child:read_line()
		if event ~= 0 then
			break
		end
		line = line:gsub("\n", "")
		local key, value = line:match("([^:]+):%s*(.*)")
		if key == "Title" then
			metadata.title = value
		elseif key == "Author" then
			metadata.author = value
		elseif key == "Pages" then
			metadata.pages = value
		elseif key == "Encrypted" then
			metadata.encrypted = value == "yes"
		end
	end

	local rows = {
		ui.Row({ "PDF" }):style(ui.Style():fg("green")),
		ui.Row { "  Title:", metadata.title },
    ui.Row { "  Author:", metadata.author },
    ui.Row { "  Pages:", metadata.pages },
	}
	if metadata.encrypted then
		table.insert(rows, ui.Row { "  Encrypted:", "Yes" })
	end
	table.insert(rows, ui.Row {})

	local width = math.min(100, math.max(
		60,
		#metadata.title + 15,
		#metadata.author + 15
	))

  -- Spotters call ya.spot_table with a ui.Table to render metadata
	ya.spot_table(
		job,
		ui.Table(ya.list_merge(rows, require("file"):spot_base(job)))
			:area(ui.Pos { "center", w = width, h = 20 })
			:row(1)
			:col(1)
			:col_style(th.spot.tbl_col)
			:cell_style(th.spot.tbl_cell)
			:widths { ui.Constraint.Length(14), ui.Constraint.Fill(1) }
	)
end

return M
