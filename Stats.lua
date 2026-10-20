-- Peggle Forever: lifetime statistics (account-wide, with per-hero breakdowns) and the Stats page.
-- Loaded after Heroes.lua and before Peggle.lua. Peggle.lua calls the on* hooks and builds the page.
local AddOn, config = ...

local Stats = {}
config.Stats = Stats

local function newHero()
	return { started = 0, beaten = 0, perfect = 0, shots = 0, score = 0, best = 0, powers = 0, time = 0 }
end

-- The saved table, created and repaired on demand so old saves just start counting from now.
function Stats.Data()
	local data = PeggleForeverData and PeggleForeverData.newData
	if not data then
		return nil
	end
	local s = data.stats
	if not s then
		s = {}
		data.stats = s
	end
	local defaults = {
		started = 0, beaten = 0, perfect = 0, failed = 0, shots = 0, pegs = 0, freeBalls = 0,
		score = 0, fever = 0, style = 0, talent = 0, time = 0, powers = 0,
		streak = 0, bestStreak = 0, balls = 0,
	}
	for k, v in pairs(defaults) do
		s[k] = s[k] or v
	end
	s.bestBall = s.bestBall or { score = 0 }
	s.bestLevel = s.bestLevel or { score = 0 }
	s.fastest = s.fastest or { shots = 0 }
	s.hero = s.hero or {}
	s.levels = s.levels or {}
	return s
end

local function heroData(s, id)
	if not id then
		return nil
	end
	s.hero[id] = s.hero[id] or newHero()
	local h = s.hero[id]
	for k, v in pairs(newHero()) do
		h[k] = h[k] or v
	end
	return h
end

local run = {}      -- the level in progress

function Stats.onStart(level)
	local s = Stats.Data()
	if not s then
		return
	end
	run = { level = level, hero = config.activeHero, t0 = GetTime(), ballStart = 0, active = true }
	s.started = s.started + 1
	s.levels[level] = (s.levels[level] or 0) + 1
	local h = heroData(s, run.hero)
	if h then
		h.started = h.started + 1
	end
end

-- A ball was just launched; `score` is the level score so far.
function Stats.onShot(score)
	if run.active then
		run.ballStart = score or 0
		run.shooting = true
	end
end

-- The ball is done (the next one is loading, or the level ended).
function Stats.onBallEnd(score)
	if not (run.active and run.shooting) then
		return
	end
	run.shooting = false
	local s = Stats.Data()
	local gained = (score or 0) - run.ballStart
	s.balls = s.balls + 1
	if gained > s.bestBall.score then
		s.bestBall = { score = gained, hero = run.hero, level = run.level }
	end
end

function Stats.onPower()
	if not run.active then
		return
	end
	local s = Stats.Data()
	s.powers = s.powers + 1
	local h = heroData(s, run.hero)
	if h then
		h.powers = h.powers + 1
	end
end

-- The level is over. `roundStats` is the addon's per-level array:
-- {shots, free balls, pegs hit, talent score, fever score, style points, pegs total}.
function Stats.onEnd(score, won, perfect, roundStats)
	if not run.active then
		return
	end
	Stats.onBallEnd(score)
	run.active = false
	local s = Stats.Data()
	local h = heroData(s, run.hero)
	local elapsed = math.max(0, GetTime() - (run.t0 or GetTime()))
	local shots = roundStats and roundStats[1] or 0
	s.time = s.time + elapsed
	s.shots = s.shots + shots
	s.freeBalls = s.freeBalls + (roundStats and roundStats[2] or 0)
	s.pegs = s.pegs + (roundStats and roundStats[3] or 0)
	s.talent = s.talent + (roundStats and roundStats[4] or 0)
	s.fever = s.fever + (roundStats and roundStats[5] or 0)
	s.style = s.style + (roundStats and roundStats[6] or 0)
	s.score = s.score + (score or 0)
	if (score or 0) > s.bestLevel.score then
		s.bestLevel = { score = score, hero = run.hero, level = run.level }
	end
	if h then
		h.shots = h.shots + shots
		h.score = h.score + (score or 0)
		h.time = h.time + elapsed
		if (score or 0) > h.best then
			h.best = score
		end
	end
	if won then
		s.beaten = s.beaten + 1
		s.streak = s.streak + 1
		if s.streak > s.bestStreak then
			s.bestStreak = s.streak
		end
		if h then
			h.beaten = h.beaten + 1
		end
		if perfect then
			s.perfect = s.perfect + 1
			if h then
				h.perfect = h.perfect + 1
			end
		end
		if s.fastest.shots == 0 or shots < s.fastest.shots then
			s.fastest = { shots = shots, hero = run.hero, level = run.level }
		end
	else
		s.failed = s.failed + 1
		s.streak = 0
	end
end

---------------------------------------------------------------- derived numbers
local function fmtNumber(n)
	n = math.floor((n or 0) + .5)
	local str = tostring(n)
	while true do
		local k
		str, k = string.gsub(str, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return str
end
Stats.FormatNumber = fmtNumber

local function fmtTime(seconds)
	seconds = math.floor(seconds or 0)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if h > 0 then
		return string.format("%dh %dm", h, m)
	end
	return string.format("%dm %ds", m, seconds % 60)
end

-- Cuts long text so it never runs past the page: "Valley of Heroes" -> "Valley of He..."
local function fit(str, maxChars)
	str = tostring(str or "")
	if #str <= maxChars then
		return str
	end
	return string.sub(str, 1, maxChars - 3) .. "..."
end
Stats.Fit = fit

local function levelName(level)
	local name = config.LEVEL_NAMES and config.LEVEL_NAMES[level]
	return name or ("Level " .. tostring(level))
end

local function heroName(id)
	local hero = id and config.GetHero(id)
	return hero and (hero.short or hero.name:match("^(%S+)") or hero.name) or "-"
end

local function spentPoints(ranks, slots)
	local total = 0
	for i = 1, slots do
		total = total + (ranks[i] or 0) * config.TierCost(config.TREE_DEFS[i][1])
	end
	return total
end

-- Rows for the page: a list of {title, {{label, value}, ...}}. Also used by the tests.
function Stats.Build()
	local s = Stats.Data()
	if not s then
		return {}
	end
	local played = math.max(1, s.beaten + s.failed)
	local heroes = config.heroes
	-- favourites
	local mostPlayed, mostPlayedN, bestRate, bestRateId, mostPowers, mostPowersN = nil, 0, -1, nil, nil, 0
	local earned, spent = 0, 0
	for id = 1, #heroes do
		local h = s.hero[id]
		if h then
			if h.started > mostPlayedN then
				mostPlayed, mostPlayedN = id, h.started
			end
			if h.started >= 3 then
				local rate = h.beaten / h.started
				if rate > bestRate then
					bestRate, bestRateId = rate, id
				end
			end
			if h.powers > mostPowersN then
				mostPowers, mostPowersN = id, h.powers
			end
		end
		earned = earned + config.HeroPoints(id)
		local ranks = PeggleForeverData.newData.heroTalents and PeggleForeverData.newData.heroTalents[id]
		if ranks then
			spent = spent + spentPoints(ranks, config.TALENT_SLOTS)
		end
	end
	local legacyEarned = config.AccountPoints()
	local legacySpent = spentPoints(config.LegacyTalents(), config.LEGACY_SLOTS)
	local mastered, favLevel, favLevelN = 0, nil, 0
	for lv, n in pairs(s.levels) do
		if n > favLevelN then
			favLevel, favLevelN = lv, n
		end
	end
	local scores = PeggleForeverData.newData.heroLevels or {}
	for lv = 1, #config.LEVELS do
		for id = 1, #heroes do
			local row = scores[id] and scores[id][lv]
			if row and row.progress == 3 then
				mastered = mastered + 1
			end
		end
	end
	local function where(rec)
		if not rec or (rec.score or rec.shots or 0) == 0 then
			return "-"
		end
		return string.format("%s, level %d", heroName(rec.hero), rec.level or 0)
	end
	local sections = {}
	sections[#sections + 1] = { "Overall", {
		{ "Levels played", fmtNumber(s.started) },
		{ "Levels beaten", fmtNumber(s.beaten) },
		{ "Perfect clears", fmtNumber(s.perfect) },
		{ "Win rate", string.format("%d%%", math.floor(100 * s.beaten / played + .5)) },
		{ "Average score", fmtNumber(s.score / played) },
		{ "Total score", fmtNumber(s.score) },
		{ "Shots fired", fmtNumber(s.shots) },
		{ "Pegs popped", fmtNumber(s.pegs) },
		{ "Free balls earned", fmtNumber(s.freeBalls) },
		{ "Time played", fmtTime(s.time) },
	} }
	sections[#sections + 1] = { "Records", {
		{ "Best single ball", fmtNumber(s.bestBall.score) },
		{ "  by", where(s.bestBall) },
		{ "Best level score", fmtNumber(s.bestLevel.score) },
		{ "  by", where(s.bestLevel) },
		{ "Fewest shots to clear", s.fastest.shots > 0 and tostring(s.fastest.shots) or "-" },
		{ "Longest win streak", tostring(s.bestStreak) },
	} }
	sections[#sections + 1] = { "Progress", {
		{ "Hero talent points earned", string.format("%d (%d spent)", earned, spent) },
		{ "Legacy points earned", string.format("%d (%d spent)", legacyEarned, legacySpent) },
		{ "Levels mastered (all heroes)", string.format("%d of %d", mastered, #config.LEVELS * #heroes) },
		{ "Most played hero", mostPlayed and string.format("%s (%d)", heroName(mostPlayed), mostPlayedN) or "-" },
		{ "Best win rate", bestRateId and string.format("%s (%d%%)", heroName(bestRateId), math.floor(bestRate * 100 + .5)) or "-" },
		{ "Most powers used", mostPowers and string.format("%s (%d)", heroName(mostPowers), mostPowersN) or "-" },
		{ "Favourite level", favLevel and string.format("%s (%d)", fit(levelName(favLevel), 15), favLevelN) or "-" },
		{ "Powers triggered", fmtNumber(s.powers) },
	} }
	return sections
end

-- Per-hero table rows: {name, played, win%, best score, powers}
function Stats.HeroRows()
	local s = Stats.Data()
	local rows = {}
	for id = 1, #config.heroes do
		local h = s and s.hero[id] or nil
		local played = h and h.started or 0
		local rate = (h and played > 0) and string.format("%d%%", math.floor(100 * h.beaten / played + .5)) or "-"
		rows[#rows + 1] = {
			heroName(id), tostring(played), rate, h and h.best > 0 and fmtNumber(h.best) or "-", tostring(h and h.powers or 0),
		}
	end
	return rows
end

---------------------------------------------------------------- the page
-- Builds the Stats page as a child of `parent` (the same size and look as About / Credits).
function Stats.BuildPage(parent, backdrop, level)
	local f = CreateFrame("Frame", "", parent, config.backdroptmpl)
	f:SetPoint("TopLeft", 5, -9)
	f:SetPoint("BottomRight", -4, 4)
	f:SetBackdrop(backdrop)
	f:SetBackdropColor(0, 0, 0, .5)
	f:SetBackdropBorderColor(1, 1, 1)
	f:SetFrameLevel(level)
	f:Hide()

	local function text(size, r, g, b, justify, width)
		local fs = f:CreateFontString(nil, "Overlay")
		fs:SetFont(STANDARD_TEXT_FONT, size, "Outline")
		fs:SetTextColor(r, g, b)
		fs:SetJustifyH(justify or "LEFT")
		if width then
			fs:SetWidth(width)
		end
		return fs
	end

	-- heading follows the colour scheme like the other pages
	local title = f:CreateFontString(nil, "Overlay")
	title:SetFont(config.fontHeading, 40, "Outline")
	title:SetText("STATS")
	title:SetPoint("Top", 0, -20)
	config.headers[#config.headers + 1] = title
	title:SetTextColor(config.HeaderColor())

	local pool = {}
	local function put(index, size, r, g, b, justify, width)
		local fs = pool[index]
		if not fs then
			fs = text(size, r, g, b, justify, width)
			pool[index] = fs
		end
		return fs
	end

	function f.Refresh()
		local sections = Stats.Build()
		local used = 0
		local leftY, rightY = 76, 76
		local layout = { { 1, "left" }, { 2, "left" }, { 3, "right" } }
		local half = f:GetWidth() / 2
		for _, entry in ipairs(layout) do
			local section = sections[entry[1]]
			if section then
				local x = (entry[2] == "left") and 24 or (half + 8)
				local y = (entry[2] == "left") and leftY or rightY
				used = used + 1
				local head = put(used, 16, 1, 1, 0, "LEFT")
				head:ClearAllPoints()
				head:SetPoint("TopLeft", x, -y)
				head:SetText(section[1])
				y = y + 22
				for _, row in ipairs(section[2]) do
					used = used + 1
					local label = put(used, 12, .85, .85, .85, "LEFT")
					label:ClearAllPoints()
					label:SetPoint("TopLeft", x + 8, -y)
					label:SetText(row[1])
					used = used + 1
					local value = put(used, 12, 1, .85, .1, "LEFT")
					value:ClearAllPoints()
					value:SetPoint("TopLeft", x + ((entry[2] == "left") and 150 or 190), -y)
					value:SetText(row[2])
					y = y + 15
				end
				if entry[2] == "left" then
					leftY = y + 12
				else
					rightY = y + 12
				end
			end
		end
		-- per-hero table under the progress rows
		local x, y = half + 8, rightY
		used = used + 1
		local head = put(used, 16, 1, 1, 0, "LEFT")
		head:ClearAllPoints()
		head:SetPoint("TopLeft", x, -y)
		head:SetText("Heroes")
		y = y + 20
		local cols = { 0, 72, 116, 152, 228 }
		local labels = { "Hero", "Played", "Win", "Best score", "Powers" }
		for c = 1, 5 do
			used = used + 1
			local fs = put(used, 11, .6, .6, .6, "LEFT")
			fs:ClearAllPoints()
			fs:SetPoint("TopLeft", x + 8 + cols[c], -y)
			fs:SetText(labels[c])
		end
		y = y + 15
		for _, row in ipairs(Stats.HeroRows()) do
			for c = 1, 5 do
				used = used + 1
				local fs = put(used, 11, c == 1 and 1 or .85, c == 1 and 1 or .85, c == 1 and 1 or .85, "LEFT")
				fs:ClearAllPoints()
				fs:SetPoint("TopLeft", x + 8 + cols[c], -y)
				fs:SetText(row[c])
			end
			y = y + 13
		end
		for i = used + 1, #pool do
			pool[i]:SetText("")
		end
	end

	f:SetScript("OnShow", function()
		f.Refresh()
	end)
	return f
end
