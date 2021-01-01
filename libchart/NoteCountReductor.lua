local SolutionSeeker = require("libchart.SolutionSeeker")

local NoteCountReductor = {}

NoteCountReductor.new = function(self)
	local noteCountReductor = {}

	setmetatable(noteCountReductor, self)
	self.__index = self

	return noteCountReductor
end

local recursionLimit = 8
NoteCountReductor.check = function(self, linePairIndex, line2NoteCount)
	-- print("check", linePairIndex, line2NoteCount)
	local linePairs = self.linePairs
	local rate = 1

	local linePair = linePairs[linePairIndex]

	if not linePair then
		return rate
	end

	local prevLinePair = linePairs[linePairIndex - 1]
	if not prevLinePair then
		return rate
	end

	-- print("prevPair", prevLinePair.bestLine2NoteCount, prevLinePair.line1.time)
	-- print("pair", linePair.bestLine2NoteCount, linePair.line1.time)
	-- local combinationId = (prevPair.bestLine2NoteCount - 1) * self.targetMode + line2NoteCount
	-- print(prevLinePair.bestLine2NoteCount, line2NoteCount)
	local combination = linePair.combinations[prevLinePair.bestLine2NoteCount][line2NoteCount]

	if not combination then
		-- print("not combination", prevLinePair.bestLine2NoteCount, line2NoteCount)
		return 0
	end

	-- print("combination.ratio", combination.ratio)
	rate = rate * combination.sum * combination.ratio
	if rate == 0 then return rate end

	if recursionLimit ~= 0 then
		recursionLimit = recursionLimit - 1
		linePair.bestLine2NoteCount = line2NoteCount
		local maxNextRate = 0
		for nextLine2NoteCount = 1, self.targetMode do
			maxNextRate = math.max(maxNextRate, self:check(linePairIndex + 1, nextLine2NoteCount))
		end
		rate = rate * maxNextRate
		recursionLimit = recursionLimit + 1
		linePair.bestLine2NoteCount = nil
	end

	return rate
end

NoteCountReductor.getJackCount = function(self, linePairIndex)
	local linePair = self.linePairs[linePairIndex]

	local notes = {}
	for _, laneIndex in ipairs(linePair.line1.combination) do
		notes[laneIndex] = (notes[laneIndex] or 0) + 1
	end
	for _, laneIndex in ipairs(linePair.line2.combination) do
		notes[laneIndex] = (notes[laneIndex] or 0) + 1
	end

	local jackCount = 0
	for _, count in pairs(notes) do
		if count == 2 then
			jackCount = jackCount + 1
		end
	end

	local overlapsCount = 0
	for j = 1, self.targetMode do
		if linePair.line1.overlap[j] > 0 and linePair.line2.overlap[j] > 0 then
			overlapsCount = overlapsCount + 1
		end
	end

	return math.min(overlapsCount, jackCount)
end

NoteCountReductor.preprocessLinePair = function(self, linePairIndex)
	-- if linePairIndex == 0 then
	-- 	return {
	-- 		jackCount = 0,
	-- 		combinations = {}
	-- 	}
	-- end

	local linePairs = self.linePairs
	local pair = linePairs[linePairIndex]

	local jackCount = self:getJackCount(linePairIndex)
	pair.jackCount = jackCount

	--[[
		combinationId is in [1;targetMode^2]
		combination is a pair {noteCount1;noteCount2}
		combinationId = (noteCount1 - 1) * targetMode + noteCount2
	]]
	local combinations = {}
	for j = 1, pair.line1.maxReducedNoteCount do
		local subCombinations = {}
		combinations[j] = subCombinations
		for k = 1, pair.line2.maxReducedNoteCount do
			if j + k <= self.targetMode + jackCount then
				local combination = {j, k}
				subCombinations[k] = combination

				local ratio = (j / k) / (pair.line1.noteCount / pair.line2.noteCount)
				if ratio > 1 then
					ratio = 1 / ratio
				end
				-- ratio is from [0; 1], greater is better

				combination.ratio = ratio
				combination.sum = j + k
				-- combination.id = (j - 1) * self.targetMode + k
			end
		end
	end
	pair.combinations = combinations

	if #combinations == 0 then
		local subCombinations = {}
		combinations[0] = subCombinations
		for k = 1, pair.line2.maxReducedNoteCount do
			combinations[k] = {
				[1] = 0,
				[2] = k,
				ratio = 1,
				sum = k
			}
		end
	end

	-- Return this back!!!
	-- for j = 1, pair.line1.maxReducedNoteCount do
	-- 	table.sort(combinations[j], function(a, b) -- rework
	-- 		if a.ratio ~= b.ratio then
	-- 			return a.ratio > b.ratio
	-- 		end

	-- 		if a[1] == a[2] and b[1] ~= b[2] then
	-- 			return true
	-- 		end
	-- 		if a[1] == a[2] and b[1] == b[2] then
	-- 			return a[1] > b[1]
	-- 		end
	-- 	end)
	-- end
end

NoteCountReductor.preprocessLinePairs = function(self)
	self.linePairs = {}
	local linePairs = self.linePairs
	local lines = self.lines
	for linePairIndex = 0, #lines - 1 do
		local linePair = {}

		linePair.index = linePairIndex
		linePair.line1 = lines[linePairIndex]
		linePair.line2 = lines[linePairIndex + 1]

		linePairs[linePairIndex] = linePair

		linePair.line1.pair1 = linePairs[linePairIndex - 1]
		linePair.line1.pair2 = linePairs[linePairIndex]
		linePair.line2.pair1 = linePairs[linePairIndex]
		linePair.line2.pair2 = linePairs[linePairIndex + 1]

		self:preprocessLinePair(linePairIndex)
	end
end

NoteCountReductor.processLinePairs = function(self)
	for linePairIndex = 0, #self.linePairs do
		local linePair = self.linePairs[linePairIndex]

		local rates = {}
		for line2NoteCount = 1, self.targetMode do
			rates[#rates + 1] = {line2NoteCount, self:check(linePairIndex, line2NoteCount)}
		end

		local bestLine2NoteCount
		local bestRate = 0
		for k = 1, #rates do
			local line2NoteCount = rates[k][1]
			local rate = rates[k][2]
			if rate > bestRate then
				bestLine2NoteCount = line2NoteCount
				bestRate = rate
			end
		end

		linePair.bestLine2NoteCount = bestLine2NoteCount
		linePair.line2.reducedNoteCount = bestLine2NoteCount
	end
end

--[[
	This method is for recursionLimit = 0
]]
-- NoteCountReductor.processLinePairs = function(self)
-- 	local check = function(linePairIndex, line2NoteCount)
-- 		return self:check(linePairIndex, line2NoteCount)
-- 	end

-- 	SolutionSeeker.onForward = function(self, seeker)
-- 		local linePair = seeker.note
-- 		linePair.bestLine2NoteCount = seeker.lane
-- 		linePair.line2.reducedNoteCount = seeker.lane
-- 	end

-- 	SolutionSeeker.onBackward = function(self, seeker)
-- 		local linePair = seeker.note
-- 		linePair.bestLine2NoteCount = nil
-- 		linePair.line2.reducedNoteCount = nil
-- 	end

-- 	local status, err = SolutionSeeker:solve(self.linePairs, self.targetMode, check, 0)
-- 	assert(status, err)
-- end

NoteCountReductor.process = function(self, lines, columnCount, targetMode)
	self.lines = lines
	self.columnCount = columnCount
	self.targetMode = targetMode
	-- local Profiler = require("aqua.util.Profiler")
	-- local profiler = Profiler:new()
	-- profiler:start()

	--[[input:
		lines = {
			{
				combination,		-- jacks
				overlap,			-- jacks
				noteCount,			-- linePair.combinations
				maxReducedNoteCount,		-- linePair.combinations
				...
			}
		}
		self.targetMode, self.columnCount
	]]

	print("preprocessLinePairs")
	self:preprocessLinePairs()
	print("processLinePairs")
	self:processLinePairs()

	--[[output
		lines = {
			{
				...
				reducedNoteCount
			}
		}
	]]

	-- profiler:stop()
end

return NoteCountReductor
