local LinePreReductor = require("libchart.LinePreReductor")
local NoteCountReductor = require("libchart.NoteCountReductor")
local LineBalancer = require("libchart.LineBalancer")
local NoteApplyer = require("libchart.NoteApplyer")
local LongNoteReductor = require("libchart.LongNoteReductor")

local Reductor = {}

local Reductor_metatable = {}
Reductor_metatable.__index = Reductor

Reductor.new = function(self)
	local reductor = {}

	reductor.noteCountReductor = NoteCountReductor:new()
	reductor.linePreReductor = LinePreReductor:new()
	reductor.lineBalancer = LineBalancer:new()
	reductor.noteApplyer = NoteApplyer:new()
	reductor.longNoteReductor = LongNoteReductor:new()

	setmetatable(reductor, Reductor_metatable)

	return reductor
end

Reductor.exportLines = function(self, lines)
	local notes = {}
	for _, line in ipairs(lines) do
		for j = 1, line.reducedNoteCount or line.maxReducedNoteCount do
			notes[#notes + 1] = {
				startTime = line.time,
				endTime = line.time,
				columnIndex = j
			}
		end
	end
	return notes
end

Reductor.exportLineCombination = function(self, lines)
	local notes = {}
	for _, line in ipairs(lines) do
		for i = 1, line.reducedNoteCount do
			notes[#notes + 1] = {
				startTime = line.time,
				endTime = line.time,
				columnIndex = line.bestLineCombination[i]
			}
		end
	end
	return notes
end

Reductor.exportNotes = function(self, lines)
	local notes = {}
	for _, note in ipairs(self.notes) do
		if note.reducedColumnIndex then
			notes[#notes + 1] = note
		end
	end
	return notes
end

Reductor.process = function(self, notes, columnCount, targetMode)
	self.notes = notes
	self.columnCount = columnCount
	self.targetMode = targetMode

	-- line.maxReducedNoteCount
	local lines = self.linePreReductor:getLines(notes, columnCount, targetMode)

	-- line.reducedNoteCount
	self.noteCountReductor:process(lines, columnCount, targetMode)

	-- line.bestLineCombination
	self.lineBalancer:process(lines, columnCount, targetMode)

	self.noteApplyer:process(notes, lines, columnCount, targetMode)

	self.longNoteReductor:process(notes, lines, columnCount, targetMode)

	return self:exportNotes(lines)
end

return Reductor
