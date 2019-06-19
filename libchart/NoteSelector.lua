local NoteSelector = {}

local selectNotes = function(notes, check)
	local startTime = {}
	local endTime = {}
	
	for _, note in ipairs(notes) do
		if check(note) then
			table.insert(startTime, note.startTime)
			endTime[#startTime] = note.endTime
		end
	end
	
	return startTime, endTime
end

NoteSelector.create = function(notes)
	return function(check)
		local st, et = selectNotes(notes, check)
		local c = 0
		
		return function()
			c = c + 1
			return st[c], et[c], st, et, c, #st
		end
	end
end

return NoteSelector
