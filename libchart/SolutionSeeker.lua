local SolutionSeeker = {}

local sortRates = function(a, b)
	return a[2] > b[2]
end

SolutionSeeker.solve = function(self, notes, laneCount, check)
	local noteIndex = 1
	while true do
		local note = notes[noteIndex]
		if not note then
			break
		end
		
		local lanes = note.lanes
		if not lanes then
			lanes = {}
			note.lanes = lanes
			for lane = 1, laneCount do
				lanes[#lanes + 1] = 0
			end
		end

		local rates = note.rates
		if not note.rates then
			rates = {}
			note.rates = rates
			for lane = 1, laneCount do
				rates[#rates + 1] = {lane, check(noteIndex, lane)}
			end
			table.sort(rates, sortRates)
		end

		for k = 1, #rates do
			local lane = rates[k][1]
			local rate = rates[k][2]
			if lanes[lane] == 0 and rate > 0 then
				lanes[lane] = 1
				note.lane = lane
				break
			end
		end
		if note.lane then
			print("forward", noteIndex, note.lane)
			noteIndex = noteIndex + 1
		else
			-- for i = 1, laneCount do
			-- 	print(rates[i][1], rates[i][2])
			-- end
			-- io.read()
			note.lanes = nil
			note.rates = nil
			local prevNote = notes[noteIndex - 1]
			if not prevNote then
				break
			end
			prevNote.lanes[prevNote.lane] = -1
			prevNote.lane = nil
			noteIndex = noteIndex - 1
			print("back" .. noteIndex, unpack(prevNote.lanes))
		end
	end
	if noteIndex == 1 then
		return false, "Can not solve"
	else
		return true
	end
end

return SolutionSeeker
