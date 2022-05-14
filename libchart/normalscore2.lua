local erfunc = require("libchart.erfunc")

local normalscore = {}

normalscore.t_L = -1
normalscore.t_R = 1
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

function normalscore:new()
	return setmetatable({}, {__index = self})
end

function normalscore:eq1(sigma)
    return 1 / 2 * (
		erfunc.erf(self.t_R / (sigma * math.sqrt(2))) - erfunc.erf(self.t_L / (sigma * math.sqrt(2)))
	) - self.hit_count / (self.hit_count + self.miss_count)
end

function normalscore:eq1d(sigma)
    return 1 / (sigma ^ 2 * math.sqrt(2 * math.pi)) * (
        -self.t_R * math.exp(-(self.t_R / (sigma * math.sqrt(2))) ^ 2) +
        self.t_L * math.exp(-(self.t_L / (sigma * math.sqrt(2))) ^ 2)
    )
end

function normalscore:press(delta_time)
	local t_L = self.t_L
	local t_R = self.t_R
	self.samples_count = self.samples_count + 1
	if delta_time >= t_L and delta_time <= t_R then
		self.hit_count = self.hit_count + 1
		self.mean_sum = self.mean_sum + delta_time
		self.variance_sum = self.variance_sum + delta_time ^ 2
		self.mean = self.mean_sum / self.hit_count
		self.variance = self.variance_sum / self.hit_count
	else
		self.miss_count = self.miss_count + 1
	end
end

function normalscore:update()
	local t_L = self.t_L
	local t_R = self.t_R
	local N = self.hit_count + self.miss_count

	if self.miss_count > 0 then
		local miss_ratio = self.miss_count / N
		local tau_0 = erfunc.erfinv(self.hit_count / N)
		if t_L + t_R == 0 then
			self.ratio_score = t_R / (tau_0 * math.sqrt(2))
			self.miss_addition = (t_R / tau_0) ^ 2 * (miss_ratio + 2 * tau_0 / math.sqrt(math.pi) * math.exp(-tau_0 ^ 2)) / 2
		else
			local x
			local sigma_m = (t_R - t_L) / (2 * tau_0 * math.sqrt(2))
			local i = 1
			repeat
				x = sigma_m
				sigma_m = sigma_m - self:eq1(sigma_m) / self:eq1d(sigma_m)
				i = i + 1
			until x == sigma_m or i > 20
			self.ratio_score = sigma_m

			local tau_L = t_L / (sigma_m * math.sqrt(2))
			local tau_R = t_R / (sigma_m * math.sqrt(2))
			self.miss_addition = sigma_m ^ 2 * (miss_ratio + 1 / math.sqrt(math.pi) * (
				tau_R * math.exp(-tau_R ^ 2) - tau_L * math.exp(-tau_L ^ 2)
			))
		end
	end
	local score_squared = self.variance_sum / N + self.miss_addition

	self.score_squared = score_squared
	self.score = math.sqrt(score_squared)
	self.score_adjusted = math.sqrt(score_squared - self.mean ^ 2)
end

return normalscore
