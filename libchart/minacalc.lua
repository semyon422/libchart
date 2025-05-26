local ffi = require("ffi")
local bit = require("bit")

---@class minacalc.NoteInfo
---@field notes integer
---@field rowTime number

---@class minacalc.Ssr
---@field overall number
---@field stream number
---@field jumpstream number
---@field handstream number
---@field stamina number
---@field jackspeed number
---@field chordjack number
---@field technical number

---@class minacalc.MsdForAllRates
---@field msds {[integer]: minacalc.Ssr}

---@class minacalc.CalcHandle

---@class minacalc.Minacalc
---@field calc_version fun(): integer
---@field create_calc fun(): minacalc.CalcHandle
---@field destroy_calc fun(handle: minacalc.CalcHandle)
---@field calc_msd fun(calc: minacalc.CalcHandle, rows: minacalc.NoteInfo[], num_rows: integer, keycount: integer): minacalc.MsdForAllRates
---@field calc_ssr fun(calc: minacalc.CalcHandle, rows: minacalc.NoteInfo[], num_rows: integer, music_rate: number, score_goal: number, keycount: integer): minacalc.Ssr

ffi.cdef [[
	typedef struct NoteInfo {
		unsigned int notes;
		float rowTime;
	} NoteInfo;

	typedef struct CalcHandle {} CalcHandle;

	typedef struct Ssr {
		float overall;
		float stream;
		float jumpstream;
		float handstream;
		float stamina;
		float jackspeed;
		float chordjack;
		float technical;
	} Ssr;

	typedef struct MsdForAllRates {
		// one for each full-rate from 0.7 to 2.0 inclusive
		Ssr msds[14];
	} MsdForAllRates;

	int calc_version();

	CalcHandle *create_calc();

	void destroy_calc(CalcHandle *calc);

	MsdForAllRates calc_msd(CalcHandle *calc, const NoteInfo *rows, size_t num_rows, const unsigned int keycount);
	Ssr calc_ssr(CalcHandle *calc, NoteInfo *rows, size_t num_rows, float music_rate, float score_goal, const unsigned int keycount);
]]

---@type minacalc.Minacalc
local lib = ffi.load("minacalc")

local calc_handle = lib.create_calc()

local minacalc = {}

---@param notes {time: number, column: integer}[]
---@param columns integer
---@param rate number
---@param accuracy number?
---@return minacalc.Ssr
function minacalc.calc(notes, columns, rate, accuracy)
	accuracy = accuracy or 0.93

	---@type {[number]: integer}
	local rows_map = {}

	for _, note in ipairs(notes) do
		local time = note.time
		local row = rows_map[time]
		rows_map[time] = bit.bor(row or 0, bit.lshift(1, note.column - 1))
	end

	---@type minacalc.NoteInfo[]
	local rows = {}

	for time, _notes in pairs(rows_map) do
		table.insert(rows, {
			rowTime = time,
			notes = _notes,
		})
	end

	table.sort(rows, function(a, b)
		return a.rowTime < b.rowTime
	end)

	---@type minacalc.NoteInfo[]
	local _rows = ffi.new("NoteInfo[?]", #rows, rows)

	columns = math.ceil(columns / 2) * 2
	local ssr = lib.calc_ssr(calc_handle, _rows, #rows, rate, accuracy, columns)

	return {
		overall = ssr.overall,
		stream = ssr.stream,
		jumpstream = ssr.jumpstream,
		handstream = ssr.handstream,
		stamina = ssr.stamina,
		jackspeed = ssr.jackspeed,
		chordjack = ssr.chordjack,
		technical = ssr.technical,
	}
end

return minacalc
