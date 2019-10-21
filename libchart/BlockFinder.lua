local NoteBlock = require("libchart.NoteBlock")

local BlockFinder = {}

local BlockFinder_metatable = {}
BlockFinder_metatable.__index = BlockFinder

BlockFinder.new = function(self)
	local blockFinder = {}
	self.noteBlocks = {}
	
	setmetatable(blockFinder, BlockFinder_metatable)
	
	return blockFinder
end

BlockFinder.process = function(self)
	local line = self.noteData[1].line.first
	while line do
		for _, note in ipairs(line) do
			if not note.locked and not note.type then
				self:getBlock(note):lock()
			end
		end
		line = line.next
	end
end

BlockFinder.getBlock = function(self, note)
	local block = self:findBlock(note)
	block:extend()
	return block
end

local abs = math.abs
local matchDelta = function(a, b, c, d, strict)
	if not strict then
		return abs(abs(a - b) - abs(c)) <= abs(d)
	else
		return abs(abs(a - b) - abs(c)) == abs(d)
	end
end

local sameType = function(a, b)
	return
		(a.startTime == a.endTime and b.startTime == b.endTime) or
		matchDelta(abs(a.endTime - a.startTime), abs(b.endTime - b.startTime), 0, 1)
end

-- local sameSpace = function(a, b, c)
	-- return matchDelta(b.startTime - a.endTime, c.startTime - b.endTime, 0, 1)
-- end

local checkType = function(forceSameType, baseNote, nextNote)
	if forceSameType then
		return sameType(baseNote, nextNote)
	end
	return true
end

local checkNextNote = function(note, nextNote, step, deltaTime, forceSameType)
	if not nextNote then return end
	-- if sameType(note, nextNote) and note.startTime ~= note.endTime then
		-- return true
	-- end
	if (matchDelta(nextNote.lanePos, note.lanePos, 0, step, false) or matchDelta(nextNote.startTime, note.startTime, deltaTime, 1))
		and checkType(forceSameType, note, nextNote)
	then
		return true
	end
end

BlockFinder.findBlock = function(self, note)
	local block = NoteBlock:new()
	block:addNote(note)
	
	local nextNote = note.top
	if not nextNote then
		return block
	end
	
	local baseNote = note
	local deltaTime = nextNote.startTime - note.startTime
	local nextNote2 = nextNote.top
	local step = 0
	local forceSameType = false
	
	if matchDelta(nextNote.lanePos, note.lanePos, 0, 1, true) then
		step = 1
	elseif matchDelta(nextNote.lanePos, note.lanePos, 0, 2, true) then
		step = 2
		forceSameType = true
	elseif sameType(note, nextNote) and note.startTime ~= note.endTime then
		forceSameType = true
	elseif nextNote2 and matchDelta(nextNote2.startTime, nextNote.startTime, deltaTime, 1) and sameType(note, nextNote) and sameType(note, nextNote2)	then
		forceSameType = true
	else
		return block
	end
	
	while checkNextNote(note, nextNote, step, deltaTime, forceSameType) do
		block:addNote(nextNote)
		note = nextNote
		nextNote = nextNote.top
	end
	
	return block
end

local sortBlocks = function(a, b)
	return a.startTime < b.startTime or a.startTime == b.startTime and a.columnIndex < b.columnIndex
end

BlockFinder.getNoteBlocks = function(self)
	local blocks = {}
	
	for _, note in ipairs(self.noteData) do
		if note.blockStart then
			blocks[#blocks + 1] = note.block
		end
	end
	table.sort(blocks, sortBlocks)
	
	return blocks
end

BlockFinder.getClearNoteBlocks = function(self)
	local blocks = {}
	
	for _, note in ipairs(self.noteData) do
		local block = NoteBlock:new()
		block:addNote(note)
		block:extend()
		block:lock()
		note.block = block
		blocks[#blocks + 1] = block
	end
	
	return blocks
end

return BlockFinder
