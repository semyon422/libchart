---@param noteChart ncdk.NoteChart
---@return table
local function simplify_notechart(noteChart)
	local notes = {}

	for noteDatas, inputType, inputIndex, layerDataIndex in noteChart:getInputIterator() do
		for _, noteData in ipairs(noteDatas) do
			local t = noteData.noteType
			if
				t == "ShortNote" or
				t == "LongNoteStart" or
				t == "LaserNoteStart"
			then
				local note = {
					time = noteData.timePoint.absoluteTime,
					input = inputType .. inputIndex,
				}
				if noteData.endNoteData then
					note.end_time = noteData.endNoteData.timePoint.absoluteTime
				end
				table.insert(notes, note)
			end
		end
	end
	table.sort(notes, function(a, b) return a.time < b.time end)

	return notes
end

return simplify_notechart
