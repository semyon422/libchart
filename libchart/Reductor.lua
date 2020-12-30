local NoteBlock = require("libchart.NoteBlock")
local SolutionSeeker = require("libchart.SolutionSeeker")
local enps = require("libchart.enps")

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

local recursionLimit = 6
Reductor.check = function(self, pairIndex, combinationId)
	local rate = 1

	local pair = self.pairs[pairIndex]

	if not pair then
		return rate
	end

	local combination = pair.combinations[combinationId]
	if not combination then
		return 0
	end

	local prevPair = self.pairs[pairIndex - 1]
	if not prevPair then
		return combination.sum * combination.ratio
	end

	local lane = prevPair.appliedCombination or prevPair.seeker.lane
	if prevPair.combinations[lane][2] ~= combination[1] then
		return 0
	end

	rate = rate * combination.sum * combination.ratio
	if rate == 0 then return rate end

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

Reductor.overDiff = function(self, columnNotes, line)
	local overlap = {}

	for i = 1, self.targetMode do
		overlap[i] = 0
		for _, note in ipairs(line) do
			local rate = intersectSegment(i, self.targetMode, note.columnIndex, self.columnCount)
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

-- Reductor.extOverDiff = function(self, columnNotes, line)
-- 	local overlap = {}

-- 	--[[
-- 		0001111111 -> 0001
-- 		0011111110 -> 0010
-- 		0111111100 -> 0100
-- 		1111111000 -> 1000
		
-- 		0001111 -> 0001
-- 		0011110 -> 0010
-- 		0111100 -> 0100
-- 		1111000 -> 1000
-- 	]]

-- 	for i = 1, self.targetMode do
-- 		overlap[i] = 0
-- 		for _, note in ipairs(line) do
-- 			local rate = intersectSegment(i, self.targetMode, note.columnIndex, self.columnCount)
-- 			overlap[i] = overlap[i] + rate
-- 		end
-- 	end

-- 	-- assert(#overlap == #columnNotes)
-- 	-- local sum = 0
-- 	-- for i = 1, #overlap do
-- 	-- 	sum = sum + math.abs(
-- 	-- 		overlap[i] - columnNotes[i]
-- 	-- 	)
-- 	-- end

-- 	return sum
end

Reductor.lineExpDensity = function(self, columnNotes, line)
	local overlap = {}

	-- enps

	-- for i = 1, self.targetMode do
	-- 	overlap[i] = 0
	-- 	for _, note in ipairs(line) do
	-- 		local rate = intersectSegment(i, self.targetMode, note.columnIndex, self.columnCount)
	-- 		overlap[i] = overlap[i] + rate
	-- 	end
	-- end

	-- assert(#overlap == #columnNotes)
	-- local sum = 0
	-- for i = 1, #overlap do
	-- 	sum = sum + math.abs(
	-- 		overlap[i] - columnNotes[i]
	-- 	)
	-- end

	return sum
end

local recursionLimitLines = 2
Reductor.checkLine = function(self, lineIndex, lineCombinationId)
	local rate = 1

	local lines = self.lines
	local line = lines[lineIndex]

	if not line then
		return rate
	end

	local columns, columnNotes = self:getColumns(lineCombinationId)

	local j = 0
	for _, note in ipairs(line) do
		if not note.deleted then
			j = j + 1
		end
	end

	if #columns ~= j then
		-- print("#columns ~= j", lineIndex, lineCombinationId)
		return 0
	end

	local prevLine = lines[lineIndex - 1]
	if not prevLine then
		-- print("not prevLine", lineIndex, lineCombinationId)
		return 1 / self:overDiff(columnNotes, line)
	end

	local lane = prevLine.appliedLineCombinationId or prevLine.seeker.lane
	local columnsPrev, columnNotesPrev = self:getColumns(lane)

	local jackCount = line.jackCount or 0
	if jackCount == 0 then
		for i = 1, self.targetMode do
			-- print("lane", prevLine.appliedLineCombinationId, prevLine.seeker.lane)
			-- print("columnNotes[i]", unpack(columnNotes))
			-- print("columnNotesPrev[i]", unpack(columnNotesPrev))
			if columnNotes[i] == columnNotesPrev[i] and columnNotes[i] == 1 then
				-- print(i, lane, prevLine.appliedLineCombinationId, prevLine.seeker.lane)
				-- print("jackCount == 0 but here is jack", lineIndex, lineCombinationId)
				return 0
			end
		end
		-- print("select jackCount == 0", lineIndex, lineCombinationId)
		-- return 1 / self:overDiff(columnNotes, line) + 1 / self:extOverDiff(columnNotes, line)
		-- return 1 / self:overDiff(columnNotes, line) -- * sum(expDensity) ??? + extOverDiff
		return 1 / self:overDiff(columnNotes, line) + 1 / self:lineExpDensity(columnNotes, line)
	end
	-- if line.startTime == 277461 then
	-- 	print("277461")
	-- end

	local hasJack = false
	local actualJackCount = 0
	for i = 1, self.targetMode do
		if columnNotes[i] == columnNotesPrev[i] and columnNotes[i] == 1 then
		-- if columnNotes[i] == columnNotesPrev[i] then
			hasJack = true
			actualJackCount = actualJackCount + 1
		end
	end
	if not hasJack then
		-- print("jackCount ~= 0 but here is no jack", lineIndex, lineCombinationId)
		return 0
	end
	-- if line.startTime == 277461 then
	-- 	print(hasJack, lineCombinationId, actualJackCount, jackCount)
	-- end

	if actualJackCount > jackCount then
		-- print("actualJackCount > jackCount", lineIndex, lineCombinationId)
		return 0
	end

	-- print("select full", lineIndex, lineCombinationId)

	rate = rate * 1 / self:overDiff(columnNotes, line)

	if recursionLimitLines ~= 0 then
		recursionLimitLines = recursionLimitLines - 1
		line.appliedLineCombinationId = lineCombinationId
		local maxNextRate = 0
		for i = 1, 2 ^ self.targetMode do
			maxNextRate = math.max(maxNextRate, self:checkLine(lineIndex + 1, i))
		end
		rate = rate * maxNextRate
		recursionLimitLines = recursionLimitLines + 1
		line.appliedLineCombinationId = nil
	end

	return rate
end

Reductor.reduceNotes = function(self, line)
	local overlap = {}

	for i = 1, self.targetMode do
		overlap[i] = 0
		for _, note in ipairs(line) do
			local rate = intersectSegment(i, self.targetMode, note.columnIndex, self.columnCount)
			overlap[i] = overlap[i] + rate
		end
	end

	local countOverlap = 0
	for i = 1, self.targetMode do
		if overlap[i] > 0 then
			countOverlap = countOverlap + 1
		end
	end

	local columns = {}
	for i = 1, self.targetMode do
		columns[#columns + 1] = {i, overlap[i]}
	end
	table.sort(columns, function(a, b)
		if a[2] ~= b[2] then
			return a[2] > b[2]
		end
		return a[1] < b[1]
	end)

	local minLnLength = math.huge
	local sortedNotes = {}
	for _, note in ipairs(line) do
		sortedNotes[#sortedNotes + 1] = note
		local length = note.baseEndTime - note.startTime
		if length > 0 then
			minLnLength = math.min(minLnLength, length)
		end
	end
	if minLnLength ~= math.huge then
		table.sort(sortedNotes, function(a, b)
			local length1 = a.baseEndTime - a.startTime
			local length2 = b.baseEndTime - b.startTime
			if (length1 ~= 0 and length1 <= minLnLength + 10) and (length2 == 0 or length2 > minLnLength + 10) then
				return true
			end
			if length1 == length2 then
				return a.columnIndex < b.columnIndex
			end
			if length1 ~= 0 and length1 ~= 0 then
				return length1 < length2
			end
		end)
	end

	local maxNoteCount = math.min(countOverlap, #line)
	for i = 1, maxNoteCount do
		local column = columns[i][1]
		sortedNotes[i].suggestedColumn = column
		sortedNotes[i].saved = true
	end
	line.overlap = overlap
	line.maxNoteCount = maxNoteCount
	line.sortedNotes = sortedNotes

	for _, note in ipairs(line) do
		if not note.saved then
			note.deleted = true
		end
	end
end

Reductor.getJackCount = function(self, i)
	local pairs1 = self.pairs
	local pair = pairs1[i]

	local notes = {}
	for _, note in ipairs(pair.line1) do
		notes[note.columnIndex] = (notes[note.columnIndex] or 0) + 1
	end
	for _, note in ipairs(pair.line2) do
		notes[note.columnIndex] = (notes[note.columnIndex] or 0) + 1
	end

	local jackCount = 0
	for columnIndex, count in pairs(notes) do
		if count == 2 then
			jackCount = jackCount + 1
		elseif count == 1 then
		else
			error("getJackCount " .. count .. " " .. columnIndex)
		end
	end

	local overlapsCount = 0
	for i = 1, self.targetMode do
		if pair.line1.overlap[i] > 0 and pair.line2.overlap[i] > 0 then
			overlapsCount = overlapsCount + 1
		end
	end

	return math.min(overlapsCount, jackCount)
end

Reductor.preprocessPair = function(self, i)
	local pairs = self.pairs
	local pair = pairs[i]

	local jackCount = self:getJackCount(i)
	-- print("jackCount pair" .. i, jackCount)
	pair.jackCount = jackCount
	pair.line2.jackCount = jackCount

	local combinations = {}
	for j = 1, pair.line1.maxNoteCount do
		for k = 1, pair.line2.maxNoteCount do
			if j + k <= self.targetMode + jackCount then
				local combination = {j, k}
				combinations[#combinations + 1] = combination

				local ratio = (j / k) / (#pair.line1 / #pair.line2)
				if ratio > 1 then
					ratio = 1 / ratio
				end

				combination.ratio = ratio
				combination.sum = j + k
				combination.id = (j - 1) * self.targetMode + i
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

	-- print("pair" .. i, unpack(combinations[1]))
end

Reductor.preprocessPairs = function(self)
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
	-- print("apply pair" .. pair.index, i, unpack(combination))
	pair.appliedCombination = i

	local n1 = 0
	for _, note in ipairs(pair.line1.sortedNotes) do
		if not note.deleted then
			if n1 < combination[1] then
				n1 = n1 + 1
			else
				note.deleted = true
			end
		end
	end

	pair.applied = true
end

Reductor.applyLastPair = function(self, pair, i)
	local combination = pair.combinations[pair.appliedCombination]
	-- print("apply last pair" .. pair.index, i, unpack(combination))

	local n1 = 0
	for _, note in ipairs(pair.line2) do
		if not note.deleted then
			if n1 < combination[2] then
				n1 = n1 + 1
			else
				note.deleted = true
			end
		end
	end

	pair.applied = true
end

Reductor.processPairs = function(self)
	local check = function(pairIndex, combinationId)
		return self:check(pairIndex, combinationId)
	end

	local status, err = SolutionSeeker:solve(self.pairs, self.targetMode ^ 2, check)
	assert(status, err)

	for _, pair in ipairs(self.pairs) do
		self:applyPair(pair, pair.seeker.lane)
	end
	self:applyLastPair(self.pairs[#self.pairs])
end

local bit = require("bit")
Reductor.applyLine = function(self, line, lineCombinationId)
	local columns = self:getColumns(lineCombinationId)

	local i = 0
	for _, note in ipairs(line) do
		if not note.deleted then
			i = i + 1
			note.suggestedColumn = columns[i]
			assert(columns[i])
		end
	end

	assert(#columns == i)
end

Reductor.balanceLines = function(self)
	local densityStacks = {}
	self.densityStacks = densityStacks

	for i = 1, self.targetMode do
		densityStacks[i] = {0}
	end

	local checkLine = function(lineIndex, lineCombinationId)
		return self:checkLine(lineIndex, lineCombinationId)
	end

	local lines = self.lines
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
		for _, nextNote in ipairs(nextLine) do
			if not nextNote.deleted and note.columnIndex == nextNote.columnIndex then
				-- if note.startTime == 62331 and note.columnIndex == 1 then
				-- 	print("getNextLines", note.columnIndex, note.startTime, nextNote.startTime)
				-- 	print("notes:")
				-- 	for _, note in ipairs(nextLine) do
				-- 		if not note.deleted then
				-- 			print("note", note.columnIndex)
				-- 		end
				-- 	end
				-- end
				return nextLine, lines[j - 1]
			end
		end
	end
	return lines[i + 1], lines[i]
end

Reductor.reduceLongNotes = function(self)
	local lines = self.lines
	for i = 1, #lines - 1 do
		local line = lines[i]
		for _, note in ipairs(line) do
			if not note.deleted and note.baseEndTime ~= note.startTime then
				local nextLine, preNextLine = self:getNextLines(i, note)
				-- if note.startTime == 62331 then
				-- 	print("reduceLongNotes", nextLine[1].startTime, preNextLine[1].startTime)
				-- end
				if note.baseEndTime >= nextLine[1].startTime - 10 then
					note.endTime = preNextLine[1].startTime
					-- if note.startTime == 62331 then
					-- 	print("reduce")
					-- 	print("note", note.startTime, note.endTime, note.columnIndex)
					-- end
				end
			end
		end
	end
end

Reductor.process = function(self)
	local lines = {}
	self.lines = lines

	for _, line in ipairs(self.notes[1].line.lines) do
		local newLine = {}
		for _, note in ipairs(line) do
			newLine[#newLine + 1] = note
		end
		lines[#lines + 1] = newLine
	end

	for _, line in ipairs(lines) do
		self:reduceNotes(line)
	end

	self:preprocessPairs()
	self:processPairs()

	self:balanceLines() -- combine with another overlap function

	for _, note in ipairs(self.notes) do
		note.columnIndex = note.suggestedColumn or 0
		note.endTime = note.baseEndTime
	end

	self:reduceLongNotes()
end

return Reductor
