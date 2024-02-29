---@param noteChart ncdk.NoteChart
---@return table
local function simplify_notechart(noteChart)
	local notes = {}

	local input_map = noteChart.inputMode:getInputMap()

	for noteDatas, inputType, inputIndex, layerDataIndex in noteChart:getInputIterator() do
		for _, noteData in ipairs(noteDatas) do
			local input = inputType .. inputIndex
			local t = noteData.noteType
			if input_map[input] and (t == "ShortNote" or t == "LongNoteStart" or t == "LaserNoteStart") then
				local note = {
					time = noteData.timePoint.absoluteTime,
					input = input,
					column = input_map[input],
				}
				if noteData.endNoteData then
					note.end_time = noteData.endNoteData.timePoint.absoluteTime
				end
				table.insert(notes, note)
			end
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
