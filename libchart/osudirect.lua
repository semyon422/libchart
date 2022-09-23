local osudirect = {}

--[[
	Modes (r):
	4 All
	0 Ranked
	7 Ranked (Played)
	3 Qualified
	2 Pending/Help
	5 Graveyard

	Search (q):
	Newest
	Top Rated
	Most Played
]]
function osudirect.search(q, r, p)
	return ("/web/osu-search.php?m=3&q=%s&r=%s&p=%s"):format(q, r or 4, p or 0)
end

function osudirect.download(setId)
	return ("/d/%s"):format(setId)
end

function osudirect.thumbnail(setId, large)
	return ("/thumb/%s%s.jpg"):format(setId, large and "l" or "")
end

function osudirect.card(setId, large)
	return ("/beatmaps/%s/covers/card%s.jpg"):format(setId, large and "@2x" or "")
end

function osudirect.cover(setId, large)
	return ("/beatmaps/%s/covers/cover%s.jpg"):format(setId, large and "@2x" or "")
end

function osudirect.preview(setId)
	return ("/preview/%s.mp3"):format(setId)
end

local SubmissionStatus = {
	["1"] = "ranked",
	["2"] = "approved",
	["3"] = "qualified",
}

local function parseBeatmap(line)
	local l = line:split("|")

	local beatmap = {}
	beatmap.serverFilename = l[1]
	beatmap.artist = l[2]
	beatmap.title = l[3]
	beatmap.creator = l[4]

	local status = l[5]
	beatmap.submissionStatus = SubmissionStatus[status] or "pending"

	beatmap.rating = l[6]
	beatmap.lastupdate = l[7]

	beatmap.setId = tonumber(l[8])
	beatmap.threadid = tonumber(l[9])
	beatmap.hasVideo = l[10] == "1"
	beatmap.hasStoryboard = l[11] == "1"
	beatmap.filesize = tonumber(l[12])  -- 1337

	if beatmap.hasVideo and #l[13] > 0 then
		beatmap.filesize_novideo = tonumber(l[13])
	end
	if 13 < #l then
		local difficulties = l[14]:split(",")
		beatmap.difficulties = {}
		for i, subline in ipairs(difficulties) do
			local tooltip, mode = subline:match("^(.+)@(.-)$")
			if tooltip and tonumber(mode) == 3 then
				local name, sr, bpm, cs, length = tooltip:match("^(.+) %((.+)★~(.+)♫~.+~.+~CS(.+)~.+~(.+)%)$")
				if not name then
					name, sr = tooltip:match("^(.+) %?(.+)$")
					bpm, cs, length = 0, "_", 0
				end
				table.insert(beatmap.difficulties, {
					name = name or tooltip,
					sr = tonumber(sr) or 0,
					bpm = tonumber(bpm) or 0,
					cs = cs or "_",
					length = length or 0,
					beatmap = beatmap,
				})
			end
		end
		table.sort(beatmap.difficulties, function(a, b)
			return a.sr < b.sr
		end)
	end

	return beatmap
end

function osudirect.parse(response)
	local lines = response:split("\n")

	local status = tonumber(lines[1])
	if not status then
		return false
	end
	if status < 0 then
		return false, lines[2]
	end

	local beatmaps = {}
	for i = 2, #lines do
		if #lines[i] > 0 then
			table.insert(beatmaps, parseBeatmap(lines[i]))
		end
	end

	return beatmaps
end

return osudirect
