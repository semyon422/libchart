local erfunc = require("libchart.erfunc")

local normalscore = {}

normalscore.samples_count = 0
normalscore.hit_count = 0
normalscore.miss_count = 0
normalscore.mean_sum = 0
normalscore.mean = 0
normalscore.variance_sum = 0
normalscore.variance = 0
normalscore.score_squared = 0
normalscore.score = 0
normalscore.score_adjusted = 0
normalscore.ratio_score = 0
normalscore.miss_addition = 0

function normalscore:new(ranges)
	assert(type(ranges) == "table", "ranges must be a table")
	local ns = {
		ranges = ranges,
		hit_counts = {},
		samples_counts = {},
	}
	for i = 1, #ranges do
		ns.hit_counts[i] = 0
		ns.samples_counts[i] = 0
	end
	return setmetatable(ns, {__index = self})
end

function normalscore:eq1i(sigma, i)
	local N = self.samples_count
	local range = self.ranges[i]
	local t_L, t_R = range[1], range[2]
	local H_i = self.hit_counts[i]
	local N_i = self.samples_counts[i]

	return N_i / (2 * N) * (
		erfunc.erf(t_R / (sigma * math.sqrt(2))) - erfunc.erf(t_L / (sigma * math.sqrt(2)))
	) - H_i / N
end

function normalscore:eq1(sigma)
	local sum = 0
	for i = 1, #self.ranges do
		sum = sum + self:eq1i(sigma, i)
	end
	return sum
end

function normalscore:eq1di(sigma, i)
	local range = self.ranges[i]
	local t_L, t_R = range[1], range[2]

	return 1 / (sigma ^ 2 * math.sqrt(2 * math.pi)) * (
		-t_R * math.exp(-(t_R / (sigma * math.sqrt(2))) ^ 2) +
		t_L * math.exp(-(t_L / (sigma * math.sqrt(2))) ^ 2)
	)
end

function normalscore:eq1d(sigma)
	local sum = 0
	for i = 1, #self.ranges do
		sum = sum + self:eq1di(sigma, i)
	end
	return sum
end

function normalscore:press(delta_time, range_index)
	local range = self.ranges[range_index]
	assert(range, "range_index out of range")
	local t_L, t_R = range[1], range[2]

	self.samples_count = self.samples_count + 1
	self.samples_counts[range_index] = self.samples_counts[range_index] + 1
	if delta_time >= t_L and delta_time <= t_R then
		self.hit_count = self.hit_count + 1
		self.hit_counts[range_index] = self.hit_counts[range_index] + 1
		self.mean_sum = self.mean_sum + delta_time
		self.variance_sum = self.variance_sum + delta_time ^ 2
		self.mean = self.mean_sum / self.hit_count
		self.variance = self.variance_sum / self.hit_count
	else
		self.miss_count = self.miss_count + 1
	end
end

function normalscore:update()
	local N = self.hit_count + self.miss_count

	if self.miss_count > 0 then
		local ranges = self.ranges
		local tau_0 = erfunc.erfinv(self.hit_count / N)

		local sum = 0
		local sum_weights = 0
		for i = 1, #ranges do
			local range = ranges[i]
			local t_L, t_R = range[1], range[2]
			sum = sum + (t_R - t_L) / (2 * tau_0 * math.sqrt(2)) * self.hit_counts[i]
			sum_weights = sum_weights + self.hit_counts[i]
		end
		local sigma_m = sum / sum_weights

		local x
		local k = 1
		repeat
			x = sigma_m
			sigma_m = sigma_m - self:eq1(sigma_m) / self:eq1d(sigma_m)
			k = k + 1
		until x == sigma_m or k > 20
		self.ratio_score = sigma_m

		local sum_NdT = 0
		for i = 1, #ranges do
			local range = ranges[i]
			local t_L, t_R = range[1], range[2]
			local tau_L = t_L / (sigma_m * math.sqrt(2))
			local tau_R = t_R / (sigma_m * math.sqrt(2))
			sum_NdT = sum_NdT +
				(tau_R * math.exp(-tau_R ^ 2) - tau_L * math.exp(-tau_L ^ 2)) /
				math.sqrt(math.pi) * self.samples_counts[i]
		end

		self.miss_addition = sigma_m ^ 2 * (self.miss_count + sum_NdT) / N
	end

	local score_squared = self.variance_sum / N + self.miss_addition

	self.score_squared = score_squared
	self.score = math.sqrt(score_squared)
	self.score_adjusted = math.sqrt(score_squared - self.mean ^ 2)
end

return normalscore
