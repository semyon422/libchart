local class = require("class")
local LinePreReductor = require("libchart.LinePreReductor")
local NoteCountReductor = require("libchart.NoteCountReductor")
local LineBalancer = require("libchart.LineBalancer")
local NoteApplyer = require("libchart.NoteApplyer")
local LongNoteReductor = require("libchart.LongNoteReductor")

local Reductor = class()

function Reductor:new()
	self.noteCountReductor = NoteCountReductor()
	self.linePreReductor = LinePreReductor()
	self.lineBalancer = LineBalancer()
	self.noteApplyer = NoteApplyer()
	self.longNoteReductor = LongNoteReductor()
end

function Reductor:exportLines(lines)
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

function Reductor:exportLineCombination(lines)
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

function Reductor:exportNotes(lines)
	local notes = {}
	for _, note in ipairs(self.notes) do
		if note.reducedColumnIndex then
			notes[#notes + 1] = note
		end
	end
	return notes
end

function Reductor:process(notes, columnCount, targetMode)
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
