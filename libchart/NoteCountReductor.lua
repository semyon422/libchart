local NoteCountReductor = {}

NoteCountReductor.new = function(self)
	local noteCountReductor = {}

	setmetatable(noteCountReductor, self)
	self.__index = self

	return noteCountReductor
end

local recursionLimit = 8
NoteCountReductor.check = function(self, linePairIndex, line2NoteCount)
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

	local combination = linePair.combinations[prevLinePair.bestLine2NoteCount][line2NoteCount]

	if not combination then
		return 0
	end

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
	local linePairs = self.linePairs
	local pair = linePairs[linePairIndex]

	local jackCount = self:getJackCount(linePairIndex)
	pair.jackCount = jackCount

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
					ratio = 1 / ratio -- ratio is from [0; 1], greater is better
				end

				combination.ratio = ratio
				combination.sum = j + k
			end
		end
	end
	pair.combinations = combinations

	if #combinations == 0 then
		local subCombinations = {}
		combinations[0] = subCombinations
		for k = 1, pair.line2.maxReducedNoteCount do
			subCombinations[k] = {
				[1] = 0,
				[2] = k,
				ratio = 1,
				sum = k
			}
		end
	end
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
	local linePairs = self.linePairs
	for linePairIndex = 0, #self.linePairs do
		local linePair = linePairs[linePairIndex]

		local rateCases = {}
		for line2NoteCount = 1, self.targetMode do
			local rateCase = {}
			rateCase.rate = self:check(linePairIndex, line2NoteCount)
			rateCase.combination = linePair.combinations[linePair.line1.reducedNoteCount][line2NoteCount]
			rateCases[line2NoteCount] = rateCase
		end

		local bestLine2NoteCount = 1
		local bestCombination = rateCases[1].combination
		local bestRate = rateCases[1].rate
		for line2NoteCount = 2, self.targetMode do
			local rateCase = rateCases[line2NoteCount]
			local rate = rateCase.rate
			local combination = rateCase.combination

			if combination then
				local currentIsBetter = false
				if rate > bestRate then
					currentIsBetter = true
				elseif rate == bestRate then
					if combination.ratio ~= bestCombination.ratio then
						currentIsBetter = combination.ratio > bestCombination.ratio
					end
					if combination[1] == combination[2] and bestCombination[1] == bestCombination[2] then
						currentIsBetter = combination[1] > bestCombination[1]
					end
				end
				if currentIsBetter then
					bestLine2NoteCount = line2NoteCount
					bestRate = rate
					bestCombination = combination
				end
			end
		end

		linePair.bestLine2NoteCount = bestLine2NoteCount
		linePair.line2.reducedNoteCount = bestLine2NoteCount
	end
end

--[[
	This method is for recursionLimit = 0
	Old, need rework
]]
-- NoteCountReductor.processLinePairs = function(self)
--	local SolutionSeeker = require("libchart.SolutionSeeker")
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
