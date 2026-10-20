-- Peggle Forever: hero roster and per-hero data helpers.
-- Loaded before Peggle.lua. Everything hangs off the shared `config` table.
local AddOn, config = ...

-- Compatibility fallbacks for legacy globals missing on newer clients.
if not MouseIsOver then
	MouseIsOver = function(frame, ...)
		return frame and frame:IsMouseOver(...)
	end
end
if not getglobal then
	getglobal = function(name)
		return _G[name]
	end
end
if not SetDesaturation then
	SetDesaturation = function(texture, desaturate)
		texture:SetDesaturated(desaturate)
	end
end

local TALENT_SLOTS = 15
config.TALENT_SLOTS = TALENT_SLOTS

-- power: which engine mechanic the hero's green-peg power uses.
--   "guide" = Super Guide family (aim preview for several shots)
--   anything else = unique peg-hit pattern implemented in Peggle.lua (config.HeroPower):
--   "blast" (plain explosion), "strike" and "quake" (kept for later heroes), "stars", "bomb", "chain", "stomp",
--   plus charge/ball powers: "pierce", "shield", "hex"
-- Power tuning knobs, read by the power code in Peggle.lua (devtools/tune.py overrides these).
config.Balance = {
	pierce = { pegs = 8, cleave = 65, whirlwind = 35 },
	shield = { charges = 1, shards = 3, orangeBias = .7 },
	stars = { count = 4, bias = .45, eclipseExtra = 0 },
	bomb = { radius = 1.1, clusters = 2, clusterRadius = .6 },
	chain = { hops = 6, fork = .35, orangeBias = .5, totemRadius = 40 },
	guide = { shots = 3, arrows = 3, orangeBias = .7, barrage = 2 },
	stomp = { radius = 1.45, speed = 170, rageRadius = 1.15, rageSpeed = 1.3, aftershock = .85 },
	hex = { count = 5, orangeBias = 1, recurse = 2, splash = 40, baseSplash = 0, recurseBall = .7 },
}
local B = config.Balance

config.heroes = {
	{
		id = 1, display = 5566, modelFile = "Creature\\Bolvar\\Bolvar.m2", short = "Bolvar", portrait = 1360714, portraitPath = "Interface\\DialogFrame\\UI-Dialog-Boss-Bolvar", sound = "file:568646", voice = "file:545248", npc = 1748, name = "Bolvar Fordragon", title = "Highlord, Regent of Stormwind", race = "Human", faction = "Alliance",
		icon = "Interface\\Icons\\Ability_Rogue_Ambush", raceAtlas = "raceicon-human-male",
		power = "pierce", powerName = "HEROIC STRIKE",
		powerDesc = "Hitting a green peg charges your next shot: the ball keeps its normal arc but smashes through up to "..B.pierce.pegs.." pegs instead of bouncing, cleaving the pegs around each one, and leaps back up once if it falls with smashes left.",
	},
	{
		id = 2, portrait = 236248, portraitPath = "Interface\\DialogFrame\\UI-Dialog-Boss-Magni", sound = "file:568743", voice = "file:553258", npc = 2784, name = "Magni Bronzebeard", title = "Speaker of the Earth", race = "Dwarf", faction = "Alliance",
		icon = "Interface\\Icons\\Spell_Nature_StoneSkinTotem", raceAtlas = "raceicon-dwarf-male",
		power = "shield", powerName = "EARTH SHIELD",
		powerDesc = "Hitting a green peg raises a stone shield that bounces back the next ball that would be lost, and "..B.shield.shards.." stone shards strike orange pegs when it does.",
	},
	{
		id = 3, portrait = 236256, portraitPath = "Interface\\DialogFrame\\UI-Dialog-Boss-Tyrande", sound = "file:569361", voice = "file:562979", npc = 7999, name = "Tyrande Whisperwind", title = "High Priestess of Elune", race = "Night Elf", faction = "Alliance",
		icon = "Interface\\Icons\\Spell_Arcane_StarFire", raceAtlas = "raceicon-nightelf-female",
		power = "stars", powerName = "STARFALL",
		powerDesc = "Hitting a green peg calls down a shower of "..B.stars.count.." stars over a moment, favoring your orange pegs.",
	},
	{
		id = 4, portrait = 236244, portraitPath = "Interface\\DialogFrame\\UI-Dialog-Boss-Mekkatorque", sound = "file:569406", voice = "file:551919", npc = 7937, name = "Gelbin Mekkatorque", title = "High Tinker of Gnomeregan", race = "Gnome", faction = "Alliance",
		icon = "Interface\\Icons\\Spell_Fire_SelfDestruct", raceAtlas = "raceicon-gnome-male",
		power = "bomb", powerName = "THORIUM GRENADE",
		powerDesc = "Hitting a green peg plants a bomb that detonates after a short fuse, plus two cluster bombs lobbed onto nearby pegs.",
	},
	{
		id = 5, portrait = 236254, portraitPath = "Interface\\DialogFrame\\UI-Dialog-Boss-Thrall", sound = "file:1715011", voice = "file:562185", npc = 4949, name = "Thrall", title = "Warchief of the Horde", race = "Orc", faction = "Horde",
		icon = "Interface\\Icons\\Spell_Nature_ChainLightning", raceAtlas = "raceicon-orc-male",
		power = "chain", powerName = "CHAIN LIGHTNING",
		powerDesc = "Hitting a green peg fires lightning that jumps from peg to peg up to "..B.chain.hops.." times, often seeking orange pegs and sometimes forking.",
	},
	{
		id = 6, portrait = 236253, portraitPath = "Interface\\DialogFrame\\UI-Dialog-Boss-Sylvanas", sound = "file:1594754", voice = "file:561297", npc = 10181, name = "Sylvanas Windrunner", title = "Banshee Queen", race = "Undead", faction = "Horde",
		icon = "Interface\\Icons\\Ability_TheBlackArrow", raceAtlas = "raceicon-undead-female",
		power = "guide", powerName = "BLACK ARROW",
		powerDesc = "Hitting a green peg gives you a guide line for your next "..B.guide.shots.." shots and fires "..B.guide.arrows.." shadow arrows, mostly at orange pegs.",
	},
	{
		id = 7, portrait = 236238, portraitPath = "Interface\\DialogFrame\\UI-Dialog-Boss-Cairne", sound = "file:569222", voice = "file:545807", npc = 3057, name = "Cairne Bloodhoof", title = "High Chieftain of the Tauren", race = "Tauren", faction = "Horde",
		icon = "Interface\\Icons\\Ability_WarStomp", raceAtlas = "raceicon-tauren-male",
		power = "stomp", powerName = "WAR STOMP",
		powerDesc = "Hitting a green peg stomps the ground: a shockwave ripples outward and hits each peg as it passes.",
	},
	{
		id = 8, portrait = 236257, portraitPath = "Interface\\DialogFrame\\UI-Dialog-Boss-Voljin", sound = "file:569079", voice = "file:563872", npc = 10540, name = "Vol'jin", title = "Leader of the Darkspear", race = "Troll", faction = "Horde",
		icon = "Interface\\Icons\\Spell_Shadow_Curse", raceAtlas = "raceicon-troll-male",
		power = "hex", powerName = "HEX",
		powerDesc = "Hitting a green peg curses "..B.hex.count.." pegs, favoring orange. When the ball hits any cursed peg, they all detonate.",
	},
}

function config.GetHero(id)
	return id and config.heroes[id] or nil
end

local function zeroTable()
	local t = {}
	for i = 1, TALENT_SLOTS do
		t[i] = 0
	end
	return t
end

-- Talent ranks (array of TALENT_SLOTS numbers) for the active hero. Without an
-- active hero a throw-away zero table is returned so callers never error.
function config.ActiveTalents()
	local id = config.activeHero
	if not id or not PeggleForeverData or not PeggleForeverData.newData then
		return zeroTable()
	end
	local data = PeggleForeverData.newData
	data.heroTalents = data.heroTalents or {}
	local t = data.heroTalents[id]
	if not t then
		t = zeroTable()
		data.heroTalents[id] = t
	end
	for i = 1, TALENT_SLOTS do
		t[i] = t[i] or 0
	end
	return t
end

---------------------------------------------------------------- hero talent trees
-- Slots 1-8 are the universal passives (defined in Peggle.lua). Slots 9-15 are hero-specific:
--   9  signature scaling (5 ranks)      10, 11  one-rank perks      12, 13  three-rank perks
--   14, 15 capstones (1 rank each; unlock after 25 points are spent)
-- Tier / max rank / prerequisite for the extra slots (slots 1-11 live in the b[] table in Peggle.lua).
config.TREE_DEFS = {
	[1] = { 0, 5, 0 }, [2] = { 0, 5, 0 },
	[3] = { 1, 2, 0 }, [4] = { 1, 5, 0 }, [5] = { 1, 3, 0 },
	[6] = { 2, 5, 0 }, [7] = { 2, 5, 0 },
	[8] = { 3, 5, 0 }, [9] = { 3, 5, 0 },
	[10] = { 4, 1, 8 }, [11] = { 4, 1, 9 },
	[12] = { 4, 3, 10 }, [13] = { 4, 3, 11 },
	[14] = { 5, 1, 12 }, [15] = { 5, 1, 13 },
}
-- Cost in talent points of one rank, by tier: the further down the tree, the more a rank costs.
-- With 23 levels a hero earns up to 46 points, which covers about half of the 90 points the tree
-- costs, so every build has to choose which branches to fund and only one capstone path is reachable.
local TIER_COST = { [0] = 1, 1, 2, 2, 3, 3 }
function config.TierCost(tier)
	return TIER_COST[tier] or 3
end
-- The shared Legacy tree uses the first 11 slots (the original Peggle talents).
config.LEGACY_SLOTS = 11

local function icon(name)
	return "Interface\\Icons\\" .. name
end

-- Shared effect types, read through config.Mod(mod).
local GENERIC = {
	echo = { per = 35, desc = "Using your power has a %d%% chance to trigger it a second time." },
	regreen = { per = 40, desc = "Using your power has a %d%% chance to turn a random blue peg into a green peg." },
	crit = { per = 10, desc = "Pegs hit by your power have a %d%% chance to crit." },
	freeball = { per = 8, desc = "Using your power has a %d%% chance to grant a free ball." },
	fever = { per = 30, desc = "Using your power has a %d%% chance to light a fever notch." },
	style = { per = 8, desc = "Style shots score %d%% more points." },
	powerScore = { per = 10, desc = "Pegs hit by your power score %d%% more points." },
	startRegreen = { per = 50, desc = "Each rank gives a %d%% chance to start each level with an extra green peg." },
	bucket = { per = 10, desc = "The end-of-level bucket scores %d%% more points." },
	feverStart = { per = 1, desc = "Start each level with %d fever notch(es) lit." },
	coin = { per = 8, desc = "When you miss every peg, you have a %d%% chance of a free ball." },
}

local function gen(modName, name, iconName, max, per)
	local g = GENERIC[modName]
	return { name = name, icon = icon(iconName), max = max, per = per or g.per, mod = modName, desc = g.desc }
end

local function special(name, iconName, max, per, modName, desc)
	return { name = name, icon = icon(iconName), max = max, per = per, mod = modName, desc = desc }
end

config.HERO_TALENTS = {
	-- 1 Bolvar Fordragon: Heroic Strike (piercing shot)
	[1] = {
		[9] = special("Cleave", "Ability_Warrior_Cleave", 5, 8, "cleaveRadius", "Heroic Strike cleaves %d more range around each smashed peg."),
		[10] = gen("echo", "Charge", "Ability_Warrior_Charge", 1),
		[11] = gen("regreen", "Rallying Cry", "Ability_Warrior_BattleShout", 1),
		[12] = gen("crit", "Rend", "Ability_Rogue_Eviscerate", 3),
		[13] = gen("freeball", "Blessing of Might", "Spell_Holy_FistOfJustice", 3),
		[14] = special("Whirlwind", "Ability_Whirlwind", 1, 1, "pierceSplash", "Heroic Strike cleaves a much wider area around each smashed peg."),
		[15] = special("Titan's Grip", "INV_Sword_48", 1, 1, "pierceDouble", "Heroic Strike smashes twice as many pegs and can leap a second time."),
	},
	-- 2 Magni Bronzebeard: Earth Shield (ball save)
	[2] = {
		[9] = special("Earth Shock", "Spell_Nature_StoneClawTotem", 5, .5, "shardCount", "When your shield saves a ball, %d stone shards hit random pegs."),
		[10] = gen("regreen", "Mountain King", "Spell_Nature_EarthShock", 1),
		[11] = gen("echo", "Devotion Aura", "Spell_Holy_DevotionAura", 1),
		[12] = gen("freeball", "Find Treasure", "INV_Misc_Coin_01", 3),
		[13] = gen("crit", "Runic Power", "Spell_Nature_WispSplode", 3),
		[14] = special("Stoneform", "Spell_Shadow_UnholyStrength", 1, 1, "stoneform", "A ball saved by your shield turns to stone and pierces its next 4 pegs."),
		[15] = special("Earthquake", "Spell_Nature_EarthQuake", 1, 1, "rebuke", "When your shield saves a ball, a shockwave ripples out from it."),
	},
	-- 3 Tyrande Whisperwind: Starfall
	[3] = {
		[9] = special("Elune's Grace", "Spell_Arcane_StarFire", 5, .5, "starCount", "Starfall calls down %d additional stars."),
		[10] = gen("regreen", "Mark of the Wild", "Spell_Nature_Regeneration", 1),
		[11] = gen("echo", "Moonkin Aura", "Spell_Frost_ManaBurn", 1),
		[12] = gen("crit", "Searing Light", "Spell_Holy_SearingLight", 3),
		[13] = gen("fever", "Shadowmeld", "Ability_Ambush", 3),
		[14] = special("Moonfire", "Spell_Nature_StarFall", 1, 1, "starSplash", "Each star also scorches the pegs right next to where it lands."),
		[15] = special("Lunar Eclipse", "Spell_Nature_Sleep", 1, 1, "eclipse", "Starfall always targets orange pegs."),
	},
	-- 4 Gelbin Mekkatorque: Thorium Grenade
	[4] = {
		[9] = special("Dense Dynamite", "INV_Misc_Bomb_06", 5, 5, "bombRadius", "Your bombs have a %d%% larger blast radius."),
		[10] = gen("echo", "Goblin Sapper Charge", "Spell_Fire_SelfDestruct", 1),
		[11] = gen("regreen", "Gnomish Engineer", "INV_Gizmo_02", 1),
		[12] = gen("crit", "Hi-Explosive Bomb", "INV_Misc_Bomb_07", 3),
		[13] = gen("freeball", "Gnomish Shrink Ray", "INV_Gizmo_09", 3),
		[14] = special("Arcane Bomb", "Spell_Shadow_MindBomb", 1, 2, "bombClusters", "Thorium Grenade lobs %d extra cluster bombs."),
		[15] = special("Explosive Sheep", "Spell_Nature_Polymorph", 1, 1, "bombDouble", "Your main bomb is 40%% larger and explodes a second time."),
	},
	-- 5 Thrall: Chain Lightning
	[5] = {
		[9] = special("Lightning Mastery", "Spell_Nature_Lightning", 5, .7, "hops", "Chain Lightning jumps %d additional times."),
		[10] = gen("echo", "Lightning Shield", "Spell_Nature_LightningShield", 1),
		[11] = gen("regreen", "Reincarnation", "Spell_Nature_Reincarnation", 1),
		[12] = gen("crit", "Elemental Fury", "Spell_Fire_Volcano", 3),
		[13] = gen("fever", "Maelstrom", "Spell_Nature_UnrelentingStorm", 3),
		[14] = special("Elemental Mastery", "Spell_Nature_ChainLightning", 1, 1, "forkAll", "Chain Lightning always forks to a second peg."),
		[15] = special("Windfury Totem", "Spell_Nature_Windfury", 1, 1, "totem", "Each peg struck by lightning also shocks the pegs right next to it."),
	},
	-- 6 Sylvanas Windrunner: Black Arrow (guide shots)
	[6] = {
		[9] = special("Dark Ranger", "INV_Weapon_Bow_08", 5, .6, "arrowCount", "Black Arrow fires %d additional shadow arrows."),
		[10] = gen("regreen", "Haunt", "Ability_Warlock_Haunt", 1),
		[11] = gen("freeball", "Psychic Scream", "Spell_Shadow_PsychicScream", 1, 15),
		[12] = gen("crit", "Piercing Shots", "Ability_Marksmanship", 3),
		[13] = gen("fever", "Shadow Embrace", "Spell_Shadow_ShadowWard", 3),
		[14] = special("Aimed Shot", "INV_Spear_07", 1, 25, "guideCrit", "Your guided shots have a %d%% chance to crit."),
		[15] = special("Multi-Shot", "Ability_UpgradeMoonGlaive", 1, 1, "barrage", "Using Black Arrow also fires 2 more shadow arrows."),
	},
	-- 7 Cairne Bloodhoof: War Stomp
	[7] = {
		[9] = special("Endurance", "Spell_Nature_UnyeildingStamina", 5, 4, "stompRadius", "War Stomp has a %d%% larger radius."),
		[10] = gen("echo", "Shockwave", "Ability_WarStomp", 1),
		[11] = gen("regreen", "Ghost Wolf", "Spell_Nature_SpiritWolf", 1),
		[12] = gen("crit", "Thunder Clap", "Spell_Nature_ThunderClap", 3),
		[13] = gen("freeball", "Skinning", "INV_Misc_Pelt_Wolf_01", 3),
		[14] = special("Aftershock", "Spell_Nature_Earthquake", 1, 1, "aftershock", "War Stomp sends a second, weaker shockwave."),
		[15] = special("Bestial Wrath", "Ability_Druid_FerociousBite", 1, 1, "stompRage", "War Stomp is 25%% larger and its shockwave travels faster."),
	},
	-- 8 Vol'jin: Hex
	[8] = {
		[9] = special("Curse of Agony", "Spell_Shadow_CurseOfSargeras", 5, 1.3, "hexCount", "Hex curses %d additional pegs."),
		[10] = gen("echo", "Snake Trap", "Ability_Hunter_SnakeTrap", 1),
		[11] = gen("regreen", "Curse of Weakness", "Spell_Shadow_CurseOfMannoroth", 1),
		[12] = gen("crit", "Shadow Word: Pain", "Spell_Shadow_ShadowWordPain", 3),
		[13] = gen("freeball", "Berserking", "Racial_Troll_Berserk", 3),
		[14] = special("Curse of Tongues", "Spell_Shadow_CurseOfTounges", 1, 1, "hexSplash", "Cursed pegs detonate with a splash that hits the pegs next to them."),
		[15] = special("Voodoo Shuffle", "Spell_Shadow_UnholyFrenzy", 1, 1, "hexRecurse", "When cursed pegs detonate, "..B.hex.recurse.." new pegs are cursed and you have a "..math.floor(B.hex.recurseBall * 100 + .5).."%% chance of a free ball."),
	},
}

-- Slots 1-8 for every hero: shared effect types with names inspired by the hero.
-- {style 5 ranks, powerScore 5, startRegreen 2, bucket 5, feverStart 3, coin 5, fever 5, crit 5}
local BASIC_TYPES = {
	{ "style", 5, 8 }, { "powerScore", 5, 10 }, { "startRegreen", 2, 50 }, { "bucket", 5, 10 },
	{ "feverStart", 3, 1 }, { "coin", 5, 8 }, { "fever", 5, 6 }, { "crit", 5, 5 },
}
local BASIC = {
	[1] = { { "Rampage", "Ability_Warrior_Rampage" }, { "Inner Rage", "Ability_Warrior_InnerRage" },
		{ "Last Stand", "Spell_Holy_AshesToAshes" }, { "Blessing of Kings", "Spell_Magic_MageArmor" },
		{ "Battle Shout", "Ability_Warrior_BattleShout" }, { "Divine Favor", "Spell_Holy_Heal" },
		{ "Prayer of Fortitude", "Spell_Holy_PrayerOfFortitude" }, { "Cruelty", "INV_Sword_61" } },
	[2] = { { "Mace Specialization", "INV_Mace_01" }, { "Earthbind Totem", "Spell_Nature_StrengthOfEarthTotem02" },
		{ "Mining", "INV_Pick_02" }, { "Jewelcrafting", "INV_Misc_Gem_Diamond_01" },
		{ "Flame Shock", "Spell_Fire_Fire" }, { "Prospecting", "INV_Misc_Gem_Opal_01" },
		{ "Cooking", "INV_Drink_05" }, { "Archaeology", "INV_Misc_Bone_03" } },
	[3] = { { "Power Word: Shield", "Spell_Holy_PowerWordShield" }, { "Lunar Guidance", "Ability_Druid_LunarGuidance" },
		{ "Force of Nature", "Spell_Nature_ForceOfNature" }, { "Healing Touch", "Spell_Nature_HealingTouch" },
		{ "Faerie Fire", "Spell_Nature_FaerieFire" }, { "Moonglow", "Spell_Nature_MoonGlow" },
		{ "Hymn of Hope", "Spell_Holy_DivineHymn" }, { "Eagle Eye", "Ability_Hunter_EagleEye" } },
	[4] = { { "Gnomish Battle Chicken", "Spell_Magic_PolymorphChicken" }, { "Mechanical Dragonling", "INV_Misc_Head_Dragon_01" },
		{ "Large Seaforium Charge", "INV_Misc_Urn_01" }, { "Engineering", "Trade_Engineering" },
		{ "Flame Deflector", "INV_Gizmo_01" }, { "Field Repair Bot 74A", "INV_Egg_05" },
		{ "Gnomish Alarm-O-Bot", "INV_Misc_EngGizmos_13" }, { "Gnomish Death Ray", "INV_Gizmo_08" } },
	[5] = { { "Warchief's Blessing", "INV_Misc_Horn_01" }, { "Stormstrike", "Spell_Holy_SealOfMight" },
		{ "Call of the Elements", "INV_Misc_Horn_03" }, { "Blood Fury", "Racial_Orc_BerserkerStrength" },
		{ "Fire Nova", "Spell_Fire_SealOfFire" }, { "Far Sight", "Spell_Nature_FarSight" },
		{ "Heroism", "Spell_Nature_BloodLust" }, { "Doomhammer's Edge", "INV_Hammer_01" } },
	[6] = { { "Dark Ritual", "Spell_Shadow_DarkRitual" }, { "Trueshot Aura", "Ability_TrueShot" },
		{ "Will of the Forsaken", "Spell_Shadow_RaiseDead" }, { "Cannibalize", "Ability_Racial_Cannibalize" },
		{ "Frost Nova", "Spell_Frost_FrostNova" }, { "Fear", "Spell_Shadow_Possession" },
		{ "Mind Control", "Spell_Shadow_ShadowWordDominate" }, { "Sniper Training", "Ability_Hunter_SniperShot" } },
	[7] = { { "Nature Resistance", "Spell_Nature_ResistNature" }, { "Strength of Earth Totem", "Spell_Nature_EarthBindTotem" },
		{ "Bear Form", "Ability_Racial_BearForm" }, { "Cultivation", "INV_Misc_Coin_03" },
		{ "Flare", "Spell_Fire_Flare" }, { "Raptor Strike", "Ability_MeleeDamage" },
		{ "Heal", "Spell_Holy_Heal02" }, { "Sunder Armor", "Ability_Warrior_Sunder" } },
	[8] = { { "Regeneration", "Spell_Nature_Regenerate" }, { "Shadow Bolt", "Spell_Shadow_ShadowBolt" },
		{ "Beast Slaying", "INV_Misc_Bone_01" }, { "Pick Pocket", "INV_Misc_Coin_04" },
		{ "Fireball", "Spell_Fire_Fireball" }, { "Herbalism", "INV_Misc_Herb_18" },
		{ "Bloodlust", "Spell_Nature_BloodLust" }, { "Hawk Eye", "Ability_Hunter_SniperShot" } },
}
for id, list in pairs(BASIC) do
	for slot = 1, 8 do
		local ty = BASIC_TYPES[slot]
		config.HERO_TALENTS[id][slot] = gen(ty[1], list[slot][1], list[slot][2], ty[2], ty[3])
	end
end

-- The talent definition for a slot on the active hero (nil for the universal slots 1-8).
function config.HeroTalent(slot)
	local set = config.activeHero and config.HERO_TALENTS[config.activeHero]
	return set and set[slot] or nil
end

-- Ranks of the shared Legacy tree (the original 11 talents), account-wide.
function config.LegacyTalents()
	local data = PeggleForeverData.newData
	data.legacyTalents = data.legacyTalents or {}
	local t = data.legacyTalents
	for i = 1, config.LEGACY_SLOTS do
		t[i] = t[i] or 0
	end
	return t
end

-- Legacy points: 1 for every level that any hero has beaten with BOTH challenges, plus 1 more when
-- every hero has done so (max 2 per level).
function config.AccountPoints()
	local data = PeggleForeverData and PeggleForeverData.newData
	local levels = data and data.heroLevels
	if not levels then
		return 0
	end
	local points = 0
	for i = 1, #config.LEVELS do
		local any, all = false, true
		for id = 1, #config.heroes do
			local scores = levels[id]
			if scores and scores[i] and scores[i].progress == 3 then
				any = true
			else
				all = false
			end
		end
		if any then points = points + 1 end
		if all then points = points + 1 end
	end
	return points
end

-- Total of (rank x per-rank value) over the active hero's talents of this effect type.
function config.Mod(modName)
	if config.talentsOff or not config.activeHero then
		return 0
	end
	local set = config.HERO_TALENTS[config.activeHero]
	local ranks = config.ActiveTalents()
	local total = 0
	for slot, def in pairs(set) do
		if def.mod == modName then
			total = total + (ranks[slot] or 0) * def.per
		end
	end
	return total
end

-- The hero trees became fully hero-specific and the old talents moved to the shared Legacy tree:
-- refund every hero talent once (talentVersion 4: ranks now cost more points deeper in the tree).
function config.MigrateTalents()
	local data = PeggleForeverData.newData
	if data.talentVersion ~= 4 then
		data.talentVersion = 4
		data.heroTalents = {}
		data.legacyTalents = {}
	end
end

-- Talent points a hero has earned (= the hero's level), from that hero's own level progress.
function config.HeroPoints(id)
	local data = PeggleForeverData and PeggleForeverData.newData
	local scores = data and data.heroLevels and data.heroLevels[id]
	if not scores then
		return 0
	end
	local points = 0
	for i = 1, #scores do
		local progress = scores[i] and scores[i].progress or 0
		if progress == 2 then
			points = points + 1
		elseif progress == 3 then
			points = points + 2
		end
	end
	return points
end

-- Point the shared `levelScores` slot at this hero's own level progress. The first hero ever
-- chosen inherits the old shared progress so nothing is lost.
function config.UseHeroLevels(id)
	local data = PeggleForeverData.newData
	data.heroLevels = data.heroLevels or {}
	data.heroRecent = data.heroRecent or {}
	data.heroTracking = data.heroTracking or {}
	local firstHero = not data.legacyLevels
	local t = data.heroLevels[id]
	if not data.heroRecent[id] then
		data.heroRecent[id] = (firstHero and PeggleForeverData.recent) or {}
	end
	if not data.heroTracking[id] then
		data.heroTracking[id] = (firstHero and PeggleForeverProfile.levelTracking) or {}
	end
	-- most recent scores and win/loss tracking follow the active hero too
	PeggleForeverData.recent = data.heroRecent[id]
	PeggleForeverProfile.levelTracking = data.heroTracking[id]
	if not t then
		if not data.legacyLevels and data.levelScores then
			t = data.levelScores
		else
			t = {}
		end
		data.legacyLevels = true
		data.heroLevels[id] = t
	end
	for i = 1, #config.LEVELS do
		if not t[i] then
			t[i] = { score = 0, progress = 0 }
		end
	end
	data.levelScores = t
	if config.RefreshLevelScores then
		config.RefreshLevelScores()
	end
end

-- Portrait for a hero on any texture: the hero's own 2D art (a file ID from the game client), else the
-- race crest if the client has it, else the power icon.
-- The NPC whose model a hero uses: a saved override (/peggle npc <hero> <npcID>), else the default.
function config.HeroNpc(hero)
	local over = PeggleForeverData and PeggleForeverData.settings and PeggleForeverData.settings.npcOverride
	return (over and over[hero.id]) or hero.npc
end

-- Puts the hero's 3D head model into `model` (a PlayerModel). Models load from the client's cache, which can
-- take a moment for NPCs you have not seen, so this asks the server for the NPC and retries a few times.
function config.LoadHeroModel(model, hero, onLoaded)
	if not (model and hero and config.HeroNpc(hero)) then
		return
	end
	if C_Timer and GameTooltip and not config.modelTip then
		config.modelTip = CreateFrame("GameTooltip", "PeggleModelTip", UIParent, "GameTooltipTemplate")
	end
	if config.modelTip then
		pcall(function()
			config.modelTip:SetOwner(UIParent, "ANCHOR_NONE")
			config.modelTip:SetHyperlink("unit:Creature-0-0-0-0-" .. config.HeroNpc(hero) .. "-0000000000")
		end)
	end
	model.loaded = nil
	model.heroNpc = config.HeroNpc(hero)
	model.attempt = 0
	-- Ways to load a model, tried in turn until one works: a creature display ID, a model file ID, the NPC.
	local methods = {}
	if hero.display then methods[#methods + 1] = "display" end
	if hero.modelFile then methods[#methods + 1] = "file" end
	methods[#methods + 1] = "npc"
	local function try()
		if model.heroNpc ~= config.HeroNpc(hero) then
			return true          -- the portrait was switched to another hero meanwhile
		end
		model.attempt = model.attempt + 1
		local method = methods[(model.attempt - 1) % #methods + 1]
		pcall(function()
			model:ClearModel()
			if method == "display" then
				model:SetDisplayInfo(hero.display)
			elseif method == "file" then
				if type(hero.modelFile) == "string" then
					model:SetModel(hero.modelFile)
				else
					model:SetModelByFileDataID(hero.modelFile)
				end
			else
				model:SetCreature(config.HeroNpc(hero))
			end
			model:SetPortraitZoom(1)
			local fix = PeggleForeverData and PeggleForeverData.settings and PeggleForeverData.settings.faceFix
			fix = (fix and fix[hero.id]) or hero.faceFix
			if fix and model.SetFacing then
				model:SetFacing(fix)
			end
		end)
		local id = model.GetModelFileID and model:GetModelFileID()
		if id == nil or id ~= 0 then
			model.loaded = true
			config.heroMethod = config.heroMethod or {}
			config.heroMethod[hero.id] = method
			if onLoaded then onLoaded() end
			return true
		end
		return false
	end
	try()
	if C_Timer and not model.loaded then
		for _, delay in ipairs({ .3, .8, 1.5, 2.5, 4, 6 }) do
			C_Timer.After(delay, function()
				if not model.loaded then try() end
			end)
		end
	end
end

-- The creature display ID of a hero's NPC, read from a small hidden model once it has loaded (cached).
config.heroDisplay = config.heroDisplay or {}
function config.WithDisplayID(hero, callback, onFail)
	if hero.display and not config.heroDisplay[hero.id] then
		config.heroDisplay[hero.id] = hero.display
	end
	local cached = config.heroDisplay[hero.id]
	if cached then
		callback(cached)
		return
	end
	local probe = config["probe" .. hero.id]
	if not probe then
		local ok, made = pcall(CreateFrame, "PlayerModel", nil, UIParent)
		if not (ok and made and made.GetDisplayInfo) then
			if onFail then onFail() end
			return
		end
		probe = made
		probe:SetSize(16, 16)
		probe:SetPoint("BottomLeft", UIParent, "BottomLeft", -64, -64)
		config["probe" .. hero.id] = probe
	end
	local function try()
		if config.heroDisplay[hero.id] then
			return true
		end
		pcall(function() probe:SetCreature(config.HeroNpc(hero)) end)
		local ok, did = pcall(probe.GetDisplayInfo, probe)
		if ok and did and did > 0 then
			config.heroDisplay[hero.id] = did
			callback(did)
			return true
		end
		return false
	end
	if not try() then
		if C_Timer then
			for _, delay in ipairs({ .3, 1, 2.5, 5 }) do
				C_Timer.After(delay, try)
			end
			C_Timer.After(8, function()
				if not config.heroDisplay[hero.id] and onFail then onFail() end
			end)
		elseif onFail then
			onFail()
		end
	end
end

-- Does this client render NPC heads into textures (which a round mask can clip)?
function config.TexturePortraits()
	if config.texturePortraits == nil then
		local ok, m = pcall(CreateFrame, "PlayerModel", nil, UIParent)
		config.texturePortraits = (SetPortraitTextureFromCreatureDisplayID ~= nil) and ok and m ~= nil and m.GetDisplayInfo ~= nil
	end
	return config.texturePortraits
end

-- Portrait for a hero on a texture. The texture always starts as the race crest (works on every client).
-- Unless `plain` is set it then becomes the hero's 3D head: a live PlayerModel laid over it (`modelSize` = side in
-- pixels), or, with `asTexture` (the round shooter portrait), the head rendered INTO the texture when the client can
-- so the round mask and mirroring work.
function config.SetPortrait(tex, hero, zoom, plain, modelSize, asTexture)
	zoom = zoom or .08
	tex.heroId = hero.id
	if hero.raceAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(hero.raceAtlas) then
		tex:SetAtlas(hero.raceAtlas)
	else
		tex:SetTexture(hero.icon)
	end
	tex:SetVertexColor(1, 1, 1)
	tex:SetAlpha(1)
	-- crop inwards so the edges of the icon never show inside round frames
	tex:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
	if plain or not config.HeroNpc(hero) then
		if tex.model then tex.model:Hide() end
		return
	end
	local function modelRoute()
		local model = tex.model
		if not model then
			local parent = tex:GetParent()
			local ok, made = pcall(CreateFrame, "PlayerModel", nil, parent)
			if not (ok and made) then
				return
			end
			model = made
			model:SetFrameLevel(parent:GetFrameLevel() + 2)
			tex.model = model
			if modelSize then
				-- a model cannot be clipped round: a square sized to sit inside the circle (the shooter socket)
				model:SetPoint("Center", tex, "Center")
				model:SetSize(modelSize, modelSize)
			else
				model:SetAllPoints(tex)
			end
		end
		model:Show()
		config.LoadHeroModel(model, hero, function()
			tex:SetAlpha(0)       -- the model replaces the crest
		end)
	end
	if asTexture and config.TexturePortraits() then
		if tex.model then tex.model:Hide() end
		config.WithDisplayID(hero, function(did)
			if tex.heroId ~= hero.id then
				return
			end
			SetPortraitTextureFromCreatureDisplayID(tex, did)
			if hero.flip then
				tex:SetTexCoord(1, 0, 0, 1)
			else
				tex:SetTexCoord(0, 1, 0, 1)
			end
			tex:SetAlpha(1)
		end, function()
			if tex.heroId == hero.id then modelRoute() end
		end)
		return
	end
	modelRoute()
end

-- Heroes planned for later (Skyborne). Portrait file IDs and greeting sound IDs supplied by the user.
config.futureHeroes = {
	{ name = "Elaadrin Evengale", title = "High Order Leader", faction = "Alliance", portrait = 6281401, voice = 6285101 },
	{ name = "Ayessa Dawnsinger", title = "Windshapers Leader", faction = "Horde", portrait = 6281402, voice = 6285102 },
}

-- /peggle portraits: shows every portrait source side by side so you can see which ones this client can load.
-- Rows: file ID, file path, race crest, 3D model of the NPC. "/peggle portraits crest|model" picks what the game uses.
function config.ShowPortraitTest(arg)
	if arg == "info" then
		print("Peggle Forever portrait info: SetPortraitTextureFromCreatureDisplayID = " .. tostring(SetPortraitTextureFromCreatureDisplayID ~= nil)
			.. ", PlayerModel:GetDisplayInfo = " .. tostring(config.probe1 and config.probe1.GetDisplayInfo ~= nil or "not created yet"))
		for _, hero in ipairs(config.heroes) do
			print("  " .. hero.name .. " npc " .. config.HeroNpc(hero) .. " display " .. tostring(config.heroDisplay[hero.id] or hero.display or "unknown")
				.. " loaded by: " .. tostring(config.heroMethod and config.heroMethod[hero.id] or "not yet"))
		end
		return
	end
	if arg == "crest" or arg == "model" then
		PeggleForeverData.settings.plainPortraits = (arg == "crest") or nil
		print("Peggle Forever: hero portraits now use " .. ((arg == "crest") and "the race crests" or "3D models") .. " (reload the UI to refresh every screen)")
		return
	end
	local f = config.portraitTest
	if not f then
		f = CreateFrame("Frame", nil, UIParent, config.backdroptmpl)
		f:SetSize(8 * 96 + 24, 4 * 96 + 70)
		f:SetPoint("Center")
		f:SetFrameStrata("DIALOG")
		f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
		f:SetBackdropColor(0, 0, 0, .9)
		f:SetBackdropBorderColor(1, .8, 0)
		f:EnableMouse(true)
		local title = f:CreateFontString(nil, "Overlay", "GameFontNormal")
		title:SetPoint("Top", 0, -8)
		title:SetText("Peggle Forever portrait test: rows are file ID, file path, race crest, 3D model. Green = this client cannot load it. Click to close.")
		f:SetScript("OnMouseDown", function(self) self:Hide() end)
		
		for i, hero in ipairs(config.heroes) do
			local x = 12 + (i - 1) * 96
			local function slot(row)
				local box = CreateFrame("Frame", nil, f)
				box:SetSize(90, 90)
				box:SetPoint("TopLeft", x, -34 - (row - 1) * 96)
				return box
			end
			local t1 = slot(1):CreateTexture(nil, "Artwork")
			t1:SetAllPoints()
			t1:SetTexture(hero.portrait)
			local t2 = slot(2):CreateTexture(nil, "Artwork")
			t2:SetAllPoints()
			t2:SetTexture(hero.portraitPath)
			local t3 = slot(3):CreateTexture(nil, "Artwork")
			t3:SetAllPoints()
			if hero.raceAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(hero.raceAtlas) then
				t3:SetAtlas(hero.raceAtlas)
			else
				t3:SetTexture(hero.icon)
			end
			local ok, model = pcall(CreateFrame, "PlayerModel", nil, slot(4))
			if ok and model then
				model:SetAllPoints()
				config.LoadHeroModel(model, hero)
			end
			local label = f:CreateFontString(nil, "Overlay", "GameFontHighlightSmall")
			label:SetPoint("Top", f, "TopLeft", x + 45, -34 - 4 * 96 + 2)
			label:SetText(hero.short or hero.name:match("^(%S+)"))
		end
		config.portraitTest = f
	end
	f:SetShown(not f:IsShown())
end

-- Wipes every hero, level and talent back to a brand new account (settings are kept).
function config.FullReset()
	local data = PeggleForeverData.newData
	data.heroLevels = {}
	data.heroRecent = {}
	data.heroTracking = {}
	data.heroTalents = {}
	data.legacyTalents = {}
	data.levelScores = {}
	data.talentData = nil
	data.legacyLevels = true
	data.legacyMigrated = true
	PeggleForeverData.recent = {}
	PeggleForeverProfile.hero = nil
	PeggleForeverProfile.levelTracking = {}
	config.activeHero = nil
	for i = 1, #config.LEVELS do
		data.levelScores[i] = { score = 0, progress = 0 }
	end
	if config.RefreshLevelScores then
		config.RefreshLevelScores()
	end
	if config.ResyncTalents then
		config.ResyncTalents()
	end
end

-- The hero for this character's race (UnitRace's English token), used until the player picks one;
-- other races (e.g. Skyborne, until they have heroes of their own) get a random hero of their faction. The
-- pick is seeded by the character's name, so it stays the same from session to session until one is chosen.
config.raceHeroes = { Human = 1, Dwarf = 2, NightElf = 3, Gnome = 4, Orc = 5, Scourge = 6, Undead = 6, Tauren = 7, Troll = 8 }
function config.RaceHero()
	local _, race = UnitRace("player")
	local id = race and config.raceHeroes[race]
	if not id then
		local faction = UnitFactionGroup("player")
		local pool = {}
		for _, hero in ipairs(config.heroes) do
			if hero.faction == faction then
				pool[#pool + 1] = hero.id
			end
		end
		if #pool == 0 then -- no faction yet (neutral): any hero
			for _, hero in ipairs(config.heroes) do
				pool[#pool + 1] = hero.id
			end
		end
		local name, seed = UnitName("player") or "", 0
		for i = 1, #name do
			seed = (seed * 31 + string.byte(name, i)) % 2147483647
		end
		id = pool[seed % #pool + 1]
	end
	return config.heroes[id] and id or nil
end

-- Make `id` the active hero for this WoW character. Returns true on success.
function config.SetHero(id)
	if not config.heroes[id] then
		return false
	end
	local data = PeggleForeverData.newData
	data.heroTalents = data.heroTalents or {}
	-- One-time carry-over of the old shared talents to the first hero chosen.
	if not data.legacyMigrated then
		data.legacyMigrated = true
		local old = data.talentData and data.talentData.activated
		if old and not data.heroTalents[id] then
			local t = zeroTable()
			for i = 1, 8 do
				t[i] = tonumber(old[i]) or 0
			end
			data.heroTalents[id] = t
		end
	end
	config.activeHero = id
	PeggleForeverProfile.hero = id
	config.UseHeroLevels(id)
	return true
end
