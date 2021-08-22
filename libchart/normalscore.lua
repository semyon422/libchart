local erfunc = require("libchart.erfunc")

local normalscore = {}

normalscore.hit_count = 0
normalscore.miss_count = 0
normalscore.mean_sum = 0
normalscore.accuracy_sum = 0
normalscore.mean = 0
normalscore.deviation = 0
normalscore.score = 0

function normalscore:new()
	return setmetatable({}, {__index = self})
end

function normalscore:hit(delta_time, hit_timing_window)
	if math.abs(delta_time) <= hit_timing_window then
		self.mean_sum = self.mean_sum + delta_time
		self.accuracy_sum = self.accuracy_sum + delta_time ^ 2
		self.hit_count = self.hit_count + 1
		self.mean = self.mean_sum / self.hit_count
		self.deviation = self.accuracy_sum / self.hit_count
	else
		self.miss_count = self.miss_count + 1
	end

	if self.miss_count == 0 then
		local score_squared = self.accuracy_sum / self.hit_count
		self.score = math.sqrt(score_squared)
		self.score_adjusted = math.sqrt(score_squared - self.mean ^ 2)
		return
	end

	local N = self.hit_count + self.miss_count
	local s = erfunc.erfinv(self.hit_count / N)

	local score_squared =
		self.accuracy_sum / N +
		(hit_timing_window / s) ^ 2 * (1 + 2 * s / math.sqrt(math.pi) * math.exp(-s ^ 2) - self.hit_count / N) / 2

	self.score = math.sqrt(score_squared)
	self.score_adjusted = math.sqrt(score_squared - self.mean ^ 2)
end

return normalscore
