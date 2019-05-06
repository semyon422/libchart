local NoteBlock = {}

local NoteBlock_metatable = {}
NoteBlock_metatable.__index = NoteBlock

NoteBlock.new = function(self)
	local noteBlock = {}
	
	noteBlock.columnIndex = 0
	noteBlock.size = 0
	noteBlock.notes = {}
	
	setmetatable(noteBlock, NoteBlock_metatable)
	
	return noteBlock
end

NoteBlock.addNote = function(self, note)
	self.notes[#self.notes + 1] = note
	self.baseColumnIndex = self.baseColumnIndex or note.columnIndex
	self.columnIndex = self.baseColumnIndex
	self.startTime = math.min(self.startTime or note.startTime, note.startTime)
	self.endTime = math.max(self.endTime or note.endTime, note.endTime)
	self.size = self.size + 1
	
	return self
end

NoteBlock.getNotes = function(self)
	local notes = {}
	
	for _, note in ipairs(self.notes) do
		notes[#notes + 1] = note
		note.columnIndex = self.columnIndex
	end
	
	return notes
end

NoteBlock.getLastNote = function(self)
	return self.notes[#self.notes]
end

NoteBlock.lock = function(self)
	self.locked = true
	
	self.notes[1].blockStart = true
	for _, note in ipairs(self.notes) do
		note.block = self
		note.locked = true
	end
	
	return self
end

local isNextLineFree = function(lastNote)
	local nextLine = lastNote.line.next
	
	if not nextLine then return end
	
	for _, note in ipairs(nextLine) do
		if note.columnIndex == lastNote.columnIndex then
			return
		end
	end
	
	return true
end

NoteBlock.extend = function(self)
	local lastNote = self.notes[#self.notes]
	local nextNote = lastNote.top
	local preLastNote = self.notes[#self.notes - 1]
	local nextLine = lastNote.line.next
	
	if lastNote.startTime ~= lastNote.endTime then
		return self
	end
	
	if not isNextLineFree(lastNote) then
		return
	end
	
	if preLastNote then
		local deltaTime = lastNote.startTime - preLastNote.startTime
		local nextTime = lastNote.startTime + deltaTime
		
		if nextTime > nextLine.startTime and math.abs(nextTime - nextLine.startTime) > 1 then
			if not nextNote or nextTime < nextNote.startTime and math.abs(nextTime - nextNote.startTime) > 1 then
				self.endTime = nextTime
				return self
			end
		end
	end
	
	self.endTime = nextLine.startTime
	
	return self
end

NoteBlock.print = function(self)
	print("block")
	print("lanePos, linePos")
	for _, note in ipairs(self.notes) do
		print(note.lanePos, note.linePos)
	end
	
	return notes
end

NoteBlock.printNote = function(self, note)
	print("note")
	print("lanePos, linePos")
	print(note.lanePos, note.linePos)
end

return NoteBlock
