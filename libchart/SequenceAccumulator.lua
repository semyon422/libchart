local class = require("class")

local SequenceAccumulator = class()

function SequenceAccumulator:new()
	self.sequences = {}
end

function SequenceAccumulator:add(sequence)
	table.insert(self.sequences, sequence)
end

function SequenceAccumulator:get()
	return self.sequences
end

return SequenceAccumulator
