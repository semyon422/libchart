package.loaded["libchart.erfunc"] = require("erfunc")
local normalscore = require("normalscore3")

local ns = normalscore:new()

local function norm_values(n, mu, sigma)
	math.randomseed(0)
	local values = {}

	while true do
		local u, v
		local s = 0
		while s == 0 or s >= 1 do
			u = math.random() * 2 - 1
			v = math.random() * 2 - 1
			s = u ^ 2 + v ^ 2
		end

		local z_0 = u * math.sqrt(-2 * math.log(s) / s)
		local z_1 = v * math.sqrt(-2 * math.log(s) / s)

		values[#values + 1] = z_0 * sigma + mu
		if #values == n then break end
		values[#values + 1] = z_1 * sigma + mu
		if #values == n then break end
	end

	return values
end

local function press(t, range, name)
	if t >= range[1] and t <= range[2] then
		ns:hit(name, t)
		return
	end
	ns:miss(name)
end

local sigma = 0.02
local mu = 1000

local values1 = norm_values(1e6, mu, sigma)
local range1 = {-0.02 + mu, 0.02 + mu}
for _, v in ipairs(values1) do
	press(v, range1, "range1")
end

local values2 = norm_values(1e6, mu, sigma)
local range2 = {-0.03 + mu, 0.03 + mu}
for _, v in ipairs(values2) do
	press(v, range2, "range2")
end

ns:update()

assert(math.abs(ns.score - sigma) / sigma < 0.01)
assert(ns.ranges.range1[1] > 0 and ns.ranges.range1[2] > 0)