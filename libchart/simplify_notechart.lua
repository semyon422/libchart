---@param chart ncdk2.Chart
---@return table
local function simplify_notechart(chart)
	local notes = {}

	local inputMap = chart.inputMode:getInputMap()

	for _, _note in chart.notes:iter() do
		local column = _note.column
		local t = _note.noteType
		local col = inputMap[column]
		if col and (t == "ShortNote" or t == "LongNoteStart" or t == "LaserNoteStart") then
			local note = {
				time = _note:getTime(),
				column = col,
				input = column,
			}
			if _note.endNote then
				note.end_time = _note.endNote:getTime()
			end
			table.insert(notes, note)
		end
	end
	table.sort(notes, function(a, b)
		if a.time == b.time then
			return a.column < b.column
		end
		return a.time < b.time
	end)

	return notes
end

return simplify_notechart
