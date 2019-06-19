local NoteSelector = {}

local selectNotes = function(notes, check)
	local newNotes = {}
	local startTime = {}
	local endTime = {}
	
	for _, note in ipairs(notes) do
		if check(note) then
			table.insert(startTime, note.startTime)
			endTime[#startTime] = note.endTime
			newNotes[#startTime] = note
		end
	end
	
	return startTime, endTime, newNotes
end

NoteSelector.create = function(notes)
	return function(check)
		local st, et, newNotes = selectNotes(notes, check)
		local c = 0
		
		return function()
			c = c + 1
			return st[c], et[c], newNotes[c], st, et, newNotes, c
		end
	end
end

return NoteSelector
