local SequenceAccumulator = {}

local SequenceAccumulator_metatable = {}
SequenceAccumulator_metatable.__index = SequenceAccumulator

SequenceAccumulator.new = function(self)
	local sa = {}
	
	sa.sequences = {}
	
	setmetatable(sa, SequenceAccumulator_metatable)
	
	return sa
end

SequenceAccumulator.add = function(self, sequence)
	table.insert(self.sequences, sequence)
end

SequenceAccumulator.get = function(self)
	return self.sequences
end

return SequenceAccumulator
