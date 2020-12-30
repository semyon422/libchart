local SolutionSeeker = require("libchart.SolutionSeeker")
local enps = require("libchart.enps")
local bit = require("bit")

local Reductor = {}

local Reductor_metatable = {}
Reductor_metatable.__index = Reductor

Reductor.new = function(self)
	local reductor = {}

	setmetatable(reductor, Reductor_metatable)

	return reductor
end

local intersectSegment = function(tc, tm, bc, bm)
	return (
		math.max((tc - 1) / tm, math.min(tc / tm, bc / bm)) -
		math.min(tc / tm, math.max((tc - 1) / tm, (bc - 1) / bm))
	) * tm
end

Reductor.createIntersectTable = function(self)
	local intersectTable = {}
	for i = 1, self.targetMode do
		intersectTable[i] = {}
		for j = 1, self.columnCount do
			intersectTable[i][j] = intersectSegment(i, self.targetMode, j, self.columnCount)
		end
	end
	self.intersectTable = intersectTable
end


-- if #line1 differs from #line2, save difference, don't make identical lines
local recursionLimit = 0
Reductor.check = function(self, pairIndex, combinationId)
	local _pairs = self.pairs
	local rate = 1

	local pair = _pairs[pairIndex]

	if not pair then
		return rate
	end

	local combination = pair.combinations[combinationId]
	if not combination then
		return 0
	end

	rate = rate * combination.sum * combination.ratio
	if rate == 0 then return rate end

	local prevPair = _pairs[pairIndex - 1]
	if not prevPair then
		return rate
	end

	local lane = prevPair.appliedCombination or prevPair.seeker.lane
	if prevPair.combinations[lane][2] ~= combination[1] then
		return 0
	end

	if recursionLimit ~= 0 then
		recursionLimit = recursionLimit - 1
		pair.appliedCombination = combinationId
		local maxNextRate = 0
		for i = 1, self.targetMode ^ 2 do
			maxNextRate = math.max(maxNextRate, self:check(pairIndex + 1, i))
		end
		rate = rate * maxNextRate
		recursionLimit = recursionLimit + 1
		pair.appliedCombination = nil
	end

	return rate
end

Reductor.getColumns = function(self, lineCombinationId)
	local notes = {}
	for i = 1, self.targetMode do
		notes[i] = bit.band(bit.rshift(lineCombinationId, i - 1), 1)
	end

	local columns = {}
	for i = 1, self.targetMode do
		if notes[i] == 1 then
			columns[#columns + 1] = i
		end
	end

	return columns, notes
end

Reductor.createColumnsTable = function(self)
	local columnsTable = {}
	for i = 1, 2 ^ self.targetMode do
		columnsTable[i] = {self:getColumns(i)}
	end
	self.columnsTable = columnsTable
end

Reductor.overDiff = function(self, columnNotes, columns)
	local intersectTable = self.intersectTable
	local overlap = {}

	for i = 1, self.targetMode do
		overlap[i] = 0
		local intersectSubTable = intersectTable[i]
		for j = 1, #columns do
			local rate = intersectSubTable[columns[j]]
			overlap[i] = overlap[i] + rate
		end
	end

	assert(#overlap == #columnNotes)
	local sum = 0
	for i = 1, #overlap do
		sum = sum + math.abs(
			overlap[i] - columnNotes[i]
		)
	end

	return sum
end

Reductor.lineExpDensities = function(self, time)
	local densityStacks = self.densityStacks

	local densities = {}
	for i = 1, self.targetMode do
		local stack = densityStacks[i]
		local stackObject = stack[#stack]
		densities[i] = enps.expDensity((time - stackObject[1]) / 1000, stackObject[2])
	end

	return densities
end

local recursionLimitLines = 0
Reductor.checkLine = function(self, lineIndex, lineCombinationId)
	local lines = self.lines
	local columnsTable = self.columnsTable
	local line = lines[lineIndex]

	if not line then
		return 1
	end

	local columns, columnNotes = columnsTable[lineCombinationId][1], columnsTable[lineCombinationId][2]

	if #columns ~= line.noteCount then
		return 0
	end

	local targetMode = self.targetMode

	local prevLine = lines[lineIndex - 1]
	if prevLine then
		local lane = prevLine.appliedLineCombinationId or prevLine.seeker.lane
		local columnsPrev, columnNotesPrev = columnsTable[lane][1], columnsTable[lane][2]

		local jackCount = line.jackCount or 0
		if jackCount == 0 then
			for i = 1, targetMode do
				if columnNotes[i] == columnNotesPrev[i] and columnNotes[i] == 1 then
					return 0
				end
			end
		else
			local hasJack = false
			local actualJackCount = 0
			for i = 1, targetMode do
				if columnNotes[i] == columnNotesPrev[i] and columnNotes[i] == 1 then
					hasJack = true
					actualJackCount = actualJackCount + 1
				end
			end
			if not hasJack then
				return 0
			end

			if actualJackCount > jackCount then
				return 0
			end
		end
	end

	local densitySum = 0

	local time = line.time
	local lineExpDensities = self:lineExpDensities(time)
	local densityStacks = self.densityStacks
	for i = 1, targetMode do
		if columnNotes[i] == 1 then
			local stack = densityStacks[i]
			stack[#stack + 1] = {
				time,
				lineExpDensities[i]
			}
			densitySum = densitySum + lineExpDensities[i]
		end
	end
	-- densitySum = 0

	local overDiff = self:overDiff(columnNotes, line.baseColumns)

	local rate = 1
	if overDiff > 0 then
		rate = rate * (1 / overDiff)
	end
	if densitySum > 0 then
		rate = rate * (1 / densitySum)
	end

	if recursionLimitLines ~= 0 then
		recursionLimitLines = recursionLimitLines - 1
		line.appliedLineCombinationId = lineCombinationId

		local maxNextRate = 0
		for i = 1, 2 ^ targetMode do
			maxNextRate = math.max(maxNextRate, self:checkLine(lineIndex + 1, i))
		end
		rate = rate * maxNextRate

		recursionLimitLines = recursionLimitLines + 1
		line.appliedLineCombinationId = nil
	end

	for i = 1, targetMode do
		if columnNotes[i] == 1 then
			local stack = densityStacks[i]
			stack[#stack] = nil
		end
	end

	return rate
end

Reductor.processLine = function(self, line) -- accepted
	local intersectTable = self.intersectTable
	local targetMode = self.targetMode
	local overlap = {}

	for i = 1, targetMode do
		overlap[i] = 0
		local intersectSubTable = intersectTable[i]
		for _, column in ipairs(line.baseColumns) do
			local rate = intersectSubTable[column]
			overlap[i] = overlap[i] + rate
		end
	end

	local countOverlap = 0
	for i = 1, targetMode do
		if overlap[i] > 0 then
			countOverlap = countOverlap + 1
		end
	end

	local maxNoteCount = math.min(countOverlap, #line.baseColumns)

	line.overlap = overlap
	line.maxNoteCount = maxNoteCount
	line.noteCount = maxNoteCount
end

Reductor.getJackCount = function(self, i)
	local pairs1 = self.pairs
	local pair = pairs1[i]

	local notes = {}
	for _, column in ipairs(pair.line1.baseColumns) do
		notes[column] = (notes[column] or 0) + 1
	end
	for _, column in ipairs(pair.line2.baseColumns) do
		notes[column] = (notes[column] or 0) + 1
	end

	local jackCount = 0
	for _, count in pairs(notes) do
		if count == 2 then
			jackCount = jackCount + 1
		end
	end

	local overlapsCount = 0
	for j = 1, self.targetMode do
		if pair.line1.overlap[j] > 0 and pair.line2.overlap[j] > 0 then
			overlapsCount = overlapsCount + 1
		end
	end

	return math.min(overlapsCount, jackCount)
end

Reductor.preprocessPair = function(self, i)
	local pairs = self.pairs
	local pair = pairs[i]

	local jackCount = self:getJackCount(i)
	pair.jackCount = jackCount
	pair.line2.jackCount = jackCount

	--[[
		combinationId is in [1;targetMode^2]
		combination is a pair {noteCount1;noteCount2}
		combinationId = (noteCount1 - 1) * targetMode + noteCount2
	]]
	local combinations = {}
	for j = 1, pair.line1.maxNoteCount do
		for k = 1, pair.line2.maxNoteCount do
			if j + k <= self.targetMode + jackCount then
				local combination = {j, k}
				combinations[#combinations + 1] = combination

				local ratio = (j / k) / (#pair.line1.baseNotes / #pair.line2.baseNotes)
				if ratio > 1 then
					ratio = 1 / ratio
				end
				-- ratio is from [0; 1], greater is better

				combination.ratio = ratio
				combination.sum = j + k
				combination.id = (j - 1) * self.targetMode + k
			end
		end
	end
	pair.combinations = combinations

	table.sort(combinations, function(a, b) -- rework
		if a.ratio ~= b.ratio then
			return a.ratio > b.ratio
		end

		if a[1] == a[2] and b[1] ~= b[2] then
			return true
		end
		if a[1] == a[2] and b[1] == b[2] then
			return a[1] > b[1]
		end
	end)
end

Reductor.preprocessPairs = function(self) -- accepted
	self.pairs = {}
	local pairs = self.pairs
	local lines = self.lines
	for i = 1, #lines - 1 do
		local pair = {}
		pair.index = i
		pair.line1 = lines[i]
		pair.line2 = lines[i + 1]
		pairs[i] = pair
		self:preprocessPair(i)
	end
end

Reductor.applyPair = function(self, pair, i)
	local combination = pair.combinations[i]
	pair.appliedCombination = i

	pair.line1.noteCount = combination[1]
end

Reductor.applyLastPair = function(self, pair, i)
	local combination = pair.combinations[pair.appliedCombination]
	pair.appliedCombination = i

	pair.line2.noteCount = combination[2]
end

Reductor.processPairs = function(self)
	local check = function(pairIndex, combinationId)
		return self:check(pairIndex, combinationId)
	end

	-- #lanes can be reduced here
	local status, err = SolutionSeeker:solve(self.pairs, self.targetMode ^ 2, check)
	assert(status, err)

	for _, pair in ipairs(self.pairs) do
		self:applyPair(pair, pair.seeker.lane)
	end
	self:applyLastPair(self.pairs[#self.pairs])
end

Reductor.applyLine = function(self, line, lineCombinationId)
	local columnsTable = self.columnsTable

	local columns, _ = columnsTable[lineCombinationId][1], columnsTable[lineCombinationId][2]

	line.suggestedColumns = columns
end

Reductor.balanceLines = function(self)
	local densityStacks = {}
	self.densityStacks = densityStacks

	local columnsTable = self.columnsTable

	for i = 1, self.targetMode do
		densityStacks[i] = {{-math.huge, 0}}
	end

	local checkLine = function(lineIndex, lineCombinationId)
		return self:checkLine(lineIndex, lineCombinationId)
	end

	SolutionSeeker.onForward = function(_, seeker)
		local time = assert(seeker.note.time)
		local lineCombinationId = seeker.lane
		local columns, columnNotes = columnsTable[lineCombinationId][1], columnsTable[lineCombinationId][2]

		local lineExpDensities = self:lineExpDensities(time)
		for i = 1, self.targetMode do
			if columnNotes[i] == 1 then
				local stack = densityStacks[i]
				stack[#stack + 1] = {
					time,
					lineExpDensities[i]
				}
			end
		end
	end

	local lines = self.lines
	-- reduce #lanes based on pair combinations
	--[[
		#lanes = targetMode! / (nextNoteCount! * (targetMode - nextNoteCount)!)
		(4 2) = 1*2*3*4 / (1*2 * 1*2) = 3*4 / (1*2) = 6 (not 16)
		(10 5) = 252 (not 1024)
		How to enumerate?
	]]
	local status, err = SolutionSeeker:solve(lines, 2 ^ self.targetMode, checkLine)
	assert(status, err)

	for _, line in ipairs(lines) do
		self:applyLine(line, line.seeker.lane)
	end
end

Reductor.getNextLines = function(self, i, note)
	local lines = self.lines
	for j = i + 1, #lines - 2 do
		local nextLine = lines[j]
		for _, column in ipairs(nextLine.suggestedColumns) do
			if column and note.columnIndex == column then
				return nextLine, lines[j - 1]
			end
		end
	end
	return lines[i + 1], lines[i]
end

Reductor.reduceLongNotes = function(self)
	local lines = self.lines
	local allLines = self.allLines
	local allLinesMap = self.allLinesMap
	for i = 1, #lines - 1 do
		local line = lines[i]
		for _, note in ipairs(line.notes) do
			if note.baseEndTime ~= note.startTime then
				local nextLine, preNextLine = self:getNextLines(i, note)

				local window = nextLine.time - line.time - 10

				local gap
				if note.baseEndTime >= line.time + window then
					gap = nextLine.time - preNextLine.time
				end

				local baseGap
				local nearLineTime = allLines[allLinesMap[note.baseEndTime] + 1]
				if nearLineTime then
					baseGap = nearLineTime - note.baseEndTime
				end

				local reverseGap
				local nextAppliedSuggestedNote = nextLine.appliedSuggested[note.columnIndex]
				if nextAppliedSuggestedNote and nextAppliedSuggestedNote.bottom then
					reverseGap = nextAppliedSuggestedNote.startTime - nextAppliedSuggestedNote.bottom.baseEndTime
				end

				local minBaseGap
				if baseGap and reverseGap then
					minBaseGap = math.min(baseGap, reverseGap)
				elseif baseGap then
					minBaseGap = baseGap
				elseif reverseGap then
					minBaseGap = reverseGap
				end

				-- if note.startTime == 79145 then
				-- 	print(gap, baseGap, reverseGap, minBaseGap, window)
				-- end

				-- if note.baseEndTime < line.time + window then
				-- 	note.endTime = note.baseEndTime
				-- elseif minBaseGap and minBaseGap < window then
				if minBaseGap and minBaseGap < window then
					-- note.endTime = nextLine.time - minBaseGap
					note.endTime = math.min(nextLine.time - minBaseGap, note.baseEndTime)
				elseif gap then
					note.endTime = math.min(nextLine.time - gap, note.baseEndTime)
				else
					note.endTime = math.min(note.startTime, note.baseEndTime)
				end
			end
		end
	end
end

Reductor.preprocessLine = function(self, line) -- accepted
	local baseNotes = {}
	line.baseNotes = baseNotes

	local baseColumns = {}
	line.baseColumns = baseColumns

	local appliedSuggested = {}
	line.appliedSuggested = appliedSuggested

	local shortNoteCount = 0
	local longNoteCount = 0
	for _, note in ipairs(line.baseLine) do
		baseNotes[#baseNotes + 1] = note
		baseColumns[#baseColumns + 1] = note.columnIndex

		if note.startTime == note.baseEndTime then
			shortNoteCount = shortNoteCount + 1
		end
		if note.startTime ~= note.baseEndTime then
			longNoteCount = longNoteCount + 1
		end
	end
	line.shortNoteCount = shortNoteCount
	line.longNoteCount = longNoteCount

	line.noteCount = #baseNotes
	line.time = baseNotes[1].startTime
end

Reductor.applyNotesEqual = function(self, line)
	-- add swap here if need
	local notes = {}
	for i = 1, line.noteCount do
		line.baseNotes[i].suggestedColumn = line.suggestedColumns[i]
		line.appliedSuggested[line.baseNotes[i].suggestedColumn] = line.baseNotes[i]
		notes[#notes + 1] = line.baseNotes[i]
	end
	line.notes = notes
end

Reductor.applyNotesLessShort = function(self, line)
	local notes = {}
	for i = 1, line.noteCount do
		line.baseNotes[i].suggestedColumn = line.suggestedColumns[i]
		line.appliedSuggested[line.baseNotes[i].suggestedColumn] = line.baseNotes[i]
		notes[#notes + 1] = line.baseNotes[i]
	end
	line.notes = notes
end

Reductor.applyNotesLessLong = function(self, line)
	-- add swap here if need
	local notes = {}
	for _, note in ipairs(line.baseNotes) do
		notes[#notes + 1] = note
	end
	while #notes > line.noteCount do
		local longest = 1
		for i, note in ipairs(notes) do
			if note.baseEndTime > notes[longest].baseEndTime then
				longest = i
			end
		end
		table.remove(notes, longest)
	end

	for i = 1, line.noteCount do
		notes[i].suggestedColumn = line.suggestedColumns[i]
		line.appliedSuggested[notes[i].suggestedColumn] = notes[i]
	end
	line.notes = notes
end

Reductor.applyNotesLessCombined = function(self, line)
	-- add swap here if need
	local notes = {}
	for _, note in ipairs(line.baseNotes) do
		notes[#notes + 1] = note
	end
	while #notes > line.noteCount do
		local shortNote
		for i, note in ipairs(notes) do
			if note.startTime == note.baseEndTime then
				shortNote = i
				break
			end
		end
		if shortNote then
			table.remove(notes, shortNote)
		else
			local longest = 1
			for i, note in ipairs(notes) do
				if note.baseEndTime > notes[longest].baseEndTime then
					longest = i
				end
			end
			table.remove(notes, longest)
		end
	end

	for i = 1, line.noteCount do
		notes[i].suggestedColumn = line.suggestedColumns[i]
		line.appliedSuggested[notes[i].suggestedColumn] = notes[i]
	end
	line.notes = notes
end

Reductor.applyNotesLess = function(self, line)
	if line.shortNoteCount > 0 and line.longNoteCount == 0 then
		self:applyNotesLessShort(line)
	elseif line.shortNoteCount == 0 and line.longNoteCount > 0 then
		self:applyNotesLessLong(line)
	elseif line.shortNoteCount > 0 and line.longNoteCount > 0 then
		self:applyNotesLessCombined(line)
	end
end

Reductor.applyNotes = function(self)
	for _, line in ipairs(self.lines) do
		if line.noteCount == #line.baseNotes then
			self:applyNotesEqual(line)
		else
			self:applyNotesLess(line)
		end
	end
	-- ! save probortions (ln:sn)
end

Reductor.process = function(self)
	-- local Profiler = require("aqua.util.Profiler")
	-- local profiler = Profiler:new()
	-- profiler:start()

	self:createIntersectTable()
	self:createColumnsTable()


	-- allLines and allLinesMap are for reduceLongNotes
	local allLinesMap = {}
	self.allLinesMap = allLinesMap

	for _, note in ipairs(self.notes) do
		allLinesMap[note.startTime] = true
		allLinesMap[note.baseEndTime] = true
	end

	local allLines = {}
	self.allLines = allLines

	for time in pairs(allLinesMap) do
		allLines[#allLines + 1] = time
	end

	table.sort(allLines)

	for i, time in ipairs(allLines) do
		allLinesMap[time] = i
	end
	--------------------------------------------------------------------------------

	local lines = {}
	self.lines = lines

	for _, line in ipairs(self.notes[1].line.lines) do
		local newLine = {}
		newLine.baseLine = line
		self:preprocessLine(newLine) -- accepted
		lines[#lines + 1] = newLine
	end

	for _, line in ipairs(lines) do
		self:processLine(line) -- accepted
	end

	self:preprocessPairs() -- accepted
	self:processPairs() -- accepted

	self:balanceLines()
	-- try to optimize trills as jacks too

	self:applyNotes()

	for _, note in ipairs(self.notes) do
		if note.suggestedColumn then
			note.columnIndex = note.suggestedColumn
		else
			note.deleted = true
		end
		-- note.endTime = note.startTime
		note.endTime = note.baseEndTime
	end

	-- check end note endings as lines

	self:reduceLongNotes()
	-- profiler:stop()
end

return Reductor
