local NoteBlock = require("libchart.NoteBlock")
local SolutionSeeker = require("libchart.SolutionSeeker")

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

Reductor.getPrevNoteIndex = function(self, i, lane)
	for k = i - 1, 1, -1 do
		local cnote = self.notes[k]
		if cnote.seeker.lane == lane then
			return k
		end
	end
end

Reductor.getPrevNote = function(self, i, lane)
	return self.notes[self:getPrevNoteIndex(i, lane)]
end

Reductor.getDelta = function(self, i, lane)
	local startTime = self.notes[i].startTime
	local prevNoteIndex = self:getPrevNoteIndex(i, lane)
	if prevNoteIndex then
		return math.max(0, startTime - self.notes[prevNoteIndex].endTime)
	end
	return startTime
end

Reductor.checkHorizontalSpacing = function(self, i, lane)
	local note = self.notes[i]

	local rates = {}
	for columnIndex = 1, self.targetMode do
		rates[columnIndex] = 1
	end

	for columnIndex = 1, self.targetMode do
		local prevNoteIndex = self:getPrevNoteIndex(i, lane)

		if prevNoteIndex then
			local prevNote = self.notes[prevNoteIndex]

			local deltaTime = note.startTime - prevNote.endTime
			if deltaTime <= 0 then
				rates[columnIndex] = 0

				local distance = note.distance[prevNote]
				for columnIndex2 = 1, self.targetMode do
					if not distance then break end
					if
						rates[columnIndex2] > 0 and
						math.abs(columnIndex2 - prevNote.columnIndex) >= math.abs(distance) and
						(columnIndex2 - prevNote.columnIndex) * distance > 0
					then
						rates[columnIndex2] = rates[columnIndex2]
					else
						rates[columnIndex2] = 0
					end
				end
			end
		end
	end

	return rates[lane]
end

Reductor.checkVerticalSpacing = function(self, i, lane)
	local note = self.notes[i]
	local prevNote = self:getPrevNote(i, lane)

	if not prevNote then
		return 1
	end

	local basePrevNote = note.bottom
	if basePrevNote then
		local baseDelta = note.startTime - basePrevNote.endTime
		local delta = note.startTime - prevNote.endTime

		if delta < baseDelta then
			return 0
		end
	end

	local nextNote = note
	note = prevNote

	local baseNextNote = note.top
	if baseNextNote then
		local baseDelta = baseNextNote.startTime - note.endTime
		local delta = nextNote.startTime - note.endTime

		if delta < baseDelta then
			print(123123123)
			return 0
		end
	end

	return 1
end

local recursionLimit = 1
Reductor.check = function(self, noteIndex, lane)
	local rate = 1

	local note = self.notes[noteIndex]

	if not note then
		return rate
	end

	rate = rate * intersectSegment(lane, self.targetMode, note.columnIndex, self.columnCount)
	if rate == 0 then return rate end

	rate = rate * self:getDelta(noteIndex, lane) / 1000
	if rate == 0 then return rate end

	rate = rate * self:checkHorizontalSpacing(noteIndex, lane)
	if rate == 0 then return rate end

	rate = rate * self:checkVerticalSpacing(noteIndex, lane)
	if rate == 0 then return rate end

	if recursionLimit ~= 0 then
		recursionLimit = recursionLimit - 1
		local maxNextRate = 0
		for i = 1, self.targetMode do
			maxNextRate = math.max(maxNextRate, self:check(noteIndex + 1, i))
		end
		rate = rate * maxNextRate
		recursionLimit = recursionLimit + 1
	end

	return rate
end

-- Reductor.reduceNotes = function(self, line)
-- 	local savedNotes = {}
-- 	local columns = {}
-- 	for i = 1, self.targetMode do
-- 		local notes = {}
-- 		for _, note in ipairs(line) do
-- 			-- print("check", i, note.columnIndex)
-- 			local rate = 1 -- change later
-- 			local rateSegment = intersectSegment(i, self.targetMode, note.columnIndex, self.columnCount)
-- 			-- print(rateSegment, i, self.targetMode, note.columnIndex, self.columnCount)
-- 			if rate * rateSegment > 0 and not savedNotes[note] then
-- 				-- print("good", i, note.columnIndex)
-- 				-- note.r_rate = 1
-- 				note.r_rate = rate * rateSegment
-- 				notes[#notes + 1] = note
-- 			end
-- 		end
-- 		table.sort(notes, function(a, b) return a.r_rate > b.r_rate end)
-- 		local note = notes[1]
-- 		if note and not savedNotes[note] then
-- 			note.suggestedColumn = i
-- 			columns[i] = note
-- 			savedNotes[note] = true
-- 		end
-- 	end

-- 	for _, note in ipairs(line) do
-- 		if not savedNotes[note] then
-- 			note.deleted = true
-- 		end
-- 	end
-- end

Reductor.reduceNotes = function(self, line)
	local overlap = {}

	for i = 1, self.targetMode do
		for _, note in ipairs(line) do
			local rate = intersectSegment(i, self.targetMode, note.columnIndex, self.columnCount)
			overlap[i] = (overlap[i] or 0) + rate
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
	table.sort(columns, function(a, b) return a[2] > b[2] end)

	local maxNoteCount = math.min(countOverlap, #line)
	for i = 1, maxNoteCount do
		local column = columns[i][1]
		line[i].suggestedColumn = column
		line[i].saved = true
	end
	line.overlap = overlap
	line.maxNoteCount = maxNoteCount

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

	print("pair" .. i, unpack(combinations[1]))
end

Reductor.preprocessPairs = function(self)
	self.pairs = {}
	local pairs = self.pairs
	local lines = self.notes[1].line.lines
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
	print("apply pair" .. pair.index, i, unpack(combination))
	pair.appliedCombination = i

	local n1 = 0
	for _, note in ipairs(pair.line1) do
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

Reductor.processPairs = function(self)
	local pairs = self.pairs
	local pair = pairs[1]
	self:applyPair(pair, 1)
	for i = 1, #pairs - 1 do
		local pair = pairs[i]
		local nextPair = pairs[i + 1]
		for j = 1, #nextPair.combinations do
			if pair.combinations[pair.appliedCombination][2] == nextPair.combinations[j][1] then
				self:applyPair(nextPair, j)
				break
			end
		end
		if not nextPair.applied then
			error("unapplied")
			self:applyPair(nextPair, 1)
		end
	end
end

Reductor.process = function(self)
	local line = self.notes[1].line.first
	while line do
		self:reduceNotes(line)
		line = line.next
	end

	self:preprocessPairs()
	self:processPairs()

	for _, note in ipairs(self.notes) do
		note.columnIndex = note.suggestedColumn or 0
	end
end

return Reductor
