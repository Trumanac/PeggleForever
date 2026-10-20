local AddOn, config = ...
if config.disabled then return end -- the original Peggle add-on is loaded (see Levels.lua)
-- The original (minified) code assigns many names without `local` (tex, text, j, obj, the talent texture
-- tables, ...). Keep those in a private table so they cannot clash with Blizzard or other add-ons; only the
-- names below are real globals. Reads of anything else still fall through to _G.
do
	local public = {
		PeggleForeverData = true, PeggleForeverProfile = true, PeggleGameWindow = true,
		SLASH_PEGGLE1 = true, SLASH_PEGGLE2 = true, SLASH_PEGGLELOOT1 = true,
		AchievementShield_Desaturate = true, AchievementShield_Saturate = true, AchievementShield_OnLoad = true,
	};
	setfenv(1, setmetatable({}, {
		__index = _G,
		__newindex = function(env, k, v)
			if public[k] then
				_G[k] = v;
			else
				rawset(env, k, v);
			end
		end,
	}));
end
local LEVELS = config.LEVELS
local LEVEL_NAMES = config.LEVEL_NAMES

-- This recreates the AutoCastShineTemplate
-- source: https://github.com/p3lim-wow/Molinari/commit/ed1ab223c84ec643b37f936c4cc8d5184c7c0f01
-- add to config since we would otherwise exceed 200 local variable limit (someone needs to deobfuscate the code)
config.emulateAutoCastShineTemplateFrame = function(type, name, parent, template, id)
	-- template and id is not supported and setting it will raise an error
	if template or id then
		error("template and id is not supported")
	end

	local frame = CreateFrame(type, name, parent)
	local sparkles = {}

	for _ = 1, 4 do
		for mult = 3, 0, -1 do
			local spark = frame:CreateTexture(nil, 'OVERLAY')
			spark:SetPoint('CENTER')
			spark:SetSize(12 + (3 * mult), 12 + (3 * mult))
			spark:SetTexture("Interface\\Cooldown\\star4")
			spark:SetBlendMode('ADD')
			table.insert(sparkles, spark)
		end
	end

	frame.sparkles = sparkles

	return frame
end


config.backdroptmpl = BackdropTemplateMixin and "BackdropTemplate"
-- Peggle Forever is made for the WoW Forever client only (the TOC lists just its interface number).
-- Forever builds are 1.6x (interface 16000-19999); Classic Era (11xxx) and retail are not supported.
-- (Ketho's retail / Classic Era branches were removed; config.isForever is the only client check.)
config.interfaceVersion = select(4, GetBuildInfo()) or 0
config.isForever = config.interfaceVersion >= 16000 and config.interfaceVersion < 20000

-- Today's date. Uses whichever calendar call the client has (an API check, not a client-version check).
config.GetCompatDate = function()
	if C_DateAndTime.GetCurrentCalendarTime then
		local d = C_DateAndTime.GetCurrentCalendarTime()
		return d.weekday, d.month, d.monthDay, d.year
	else
		local d = C_DateAndTime.GetTodaysDate()
		return d.weekDay, d.month, d.day, d.year
	end
end

-- Addon messages are skipped while the client blocks chat messaging (only if it has such a lockdown).
config.SendAddonMessage = function(prefix, message, chatType, target)
	if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
		return
	end
	C_ChatInfo.SendAddonMessage(prefix, message, chatType, target)
end

disableSplashScreen = false

TALENT_BRANCH_TEXTURECOORDS = {
	up = {
		[1] = {0.12890625, 0.25390625, 0 , 0.484375},
		[-1] = {0.12890625, 0.25390625, 0.515625 , 1.0}
	},
	down = {
		[1] = {0, 0.125, 0, 0.484375},
		[-1] = {0, 0.125, 0.515625, 1.0}
	},
	left = {
		[1] = {0.2578125, 0.3828125, 0, 0.5},
		[-1] = {0.2578125, 0.3828125, 0.5, 1.0}
	},
	right = {
		[1] = {0.2578125, 0.3828125, 0, 0.5},
		[-1] = {0.2578125, 0.3828125, 0.5, 1.0}
	},
	topright = {
		[1] = {0.515625, 0.640625, 0, 0.5},
		[-1] = {0.515625, 0.640625, 0.5, 1.0}
	},
	topleft = {
		[1] = {0.640625, 0.515625, 0, 0.5},
		[-1] = {0.640625, 0.515625, 0.5, 1.0}
	},
	bottomright = {
		[1] = {0.38671875, 0.51171875, 0, 0.5},
		[-1] = {0.38671875, 0.51171875, 0.5, 1.0}
	},
	bottomleft = {
		[1] = {0.51171875, 0.38671875, 0, 0.5},
		[-1] = {0.51171875, 0.38671875, 0.5, 1.0}
	},
	tdown = {
		[1] = {0.64453125, 0.76953125, 0, 0.5},
		[-1] = {0.64453125, 0.76953125, 0.5, 1.0}
	},
	tup = {
		[1] = {0.7734375, 0.8984375, 0, 0.5},
		[-1] = {0.7734375, 0.8984375, 0.5, 1.0}
	},
};

TALENT_ARROW_TEXTURECOORDS = {
	top = {
		[1] = {0, 0.5, 0, 0.5},
		[-1] = {0, 0.5, 0.5, 1.0}
	},
	right = {
		[1] = {1.0, 0.5, 0, 0.5},
		[-1] = {1.0, 0.5, 0.5, 1.0}
	},
	left = {
		[1] = {0.5, 1.0, 0, 0.5},
		[-1] = {0.5, 1.0, 0.5, 1.0}
	},
};

local e = {};
e.versionString = C_AddOns.GetAddOnMetadata(AddOn, "Version");
e.versionID = 2.2;
-- Peggle Forever has its own addon-message prefix and protocol number, so it never talks to the original
-- Peggle addon (and the original never sees our duel / battle / loot messages). Bump e.ping whenever the
-- message format changes; players on an older Forever version then get the "old version" notice.
e.addonName = "PEGGLEFOREVER";
e.temp = {};
e.seconds = 60;
e.ping = 5;
e.debugMode = nil;
local t = function(...)
	if(e.debugMode)then
		print(...)
	end
end
e.GetBackdrop = function()
	return{bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tileSize = 16, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = 1, edgeSize = 16, insets = {top = 5, right = 5, left = 5, bottom = 5, }}
end
C_ChatInfo.RegisterAddonMessagePrefix(e.addonName);
--holds all the string data
e.locale = {
	["ABOUT"] = "ABOUT",
	["ABOUT_TEXT1"] = "The Peggle Institute has opened a branch in Azeroth!\n\n".."After we successfully brought the Bejeweled experience into ".."WoW, the PopCap Guild decided to tackle another of our favorite things: Peggle.\n\n".."We wanted something more competitive that we could use to settle ".."loot disputes and challenge each other while we waited for that ".."last raid member to log on. We've packed in some great touches ".."for the add-on version of Peggle, and now it's ready to be shared with the world!",
	["ABOUT_TEXT4"] = "Version ",
	["_BALL_SCORE"] = "+10,000",
	["BALLS_LEFT1"] = "%d BALLS LEFT",
	["BALLS_LEFT2"] = "LAST BALL!",
	["BEAT_THIS_LEVEL1"] = "Beat this level to earn\n+1 talent point!",
	["BEAT_THIS_LEVEL2"] = "Clear all pegs to earn\n+1 talent point!",
	["BEAT_THIS_LEVEL3"] = "+1 talent point earned\n(Beat level)",
	["BEAT_THIS_LEVEL4"] = "+1 talent point earned\n(Full clear)",
	["BRAG"] = "What channel would you like to brag to?",
	["CHALLENGE"] = "BATTLE",
	--["CHALLENGE_DETAILS"] = "BATTLE DETAIL",
	["CHALLENGE_DESC"] = "Select a battle to view its details\nor create a new battle",
	["CHALLENGE_DESC1"] = "Click a name to quickly add/remove it!",
	["CHALLENGE_DESC2"] = "|cFFFF8C00CHAT CHANNELS: Adding a custom chat channel will invite all in the chat channel at the time of battle creation. This will not invite offline users, nor users who do not have the addon installed.\n\nYou may only invite custom channels.",
	["CHALLENGE_DESC3"] = "Note: Offline users will not receive the battle until they come online while another invitee or you are also online.",
	["CHALLENGE_CAT1"] = "From:",
	["CHALLENGE_CAT2"] = "Level:",
	["CHALLENGE_CAT3"] = "Shots:",
	["CHALLENGE_CAT4"] = "Current Standing:",
	["CHALLENGE_CAT5"] = "Time Left:",
	["CHALLENGE_CAT6"] = "Note to Players:",
	["CHALLENGE_LIST"] = "Battle List",
	["CHALLENGE_DETAILS"] = "Battle Details",
	["CHALLENGE_DUR"] = "BATTLE DURATION",
	["CHALLENGE_GUILD1"] = "View Offline Guild Members",
	["CHALLENGE_GUILD2"] = "Sort by Online Status",
	["CHALLENGE_INVITE1"] = "|cFFFF8C00FRIENDS",
	["CHALLENGE_INVITE2"] = "|cFFFF8C00GUILD",
	["CHALLENGE_INVITE3"] = "|cFFFF8C00CHANNEL",
	["CHALLENGE_LIMIT"] = "Limit of 10 Active\nBattles at once",
	["CHALLENGE_NEW"] = "NEW BATTLE",
	["CHALLENGE_NONE"] = "NO BATTLE SELECTED",
	["CHALLENGE_RANK"] = "%d of %d",
	["CHALLENGE_SHOTS"] = "NUMBER OF SHOTS",
	["CHALLENGE_SORT_ONLINE"] = "Sort by Online Status",
	["CHALLENGE_REPLAYS"] = "NUMBER OF REPLAYS",
	["CHALLENGE_VIEW_OFFLINE"] = "View Offline Guild Members",
	["CHALLENGE_YOUR_STATUS"] = "Your Status:",
	["CHAR_SELECT"] = "CHARACTER SELECT",
	["CREDITS"] = "CREDITS",
	["CR_H1"] = "Original Add-On (PopCap Games)",
	["CR_B1"] = "Programmer: Michael Fromwiller\nProducer: T. Carl Kwoh\nArt: Tysen Henderson, Noah Maas\nLevel Design: Stephen Notley\nQA: Ed Miller, Eric Olson",
	["CR_H2"] = "Peggle Team",
	["CR_B2"] = "Sukhbir Sidhu, Brian Rothstein, Eric Tams, Jeremy Bilas, Walter Wilson, Matthew Holmberg",
	["CR_H3"] = "Special Thanks (Original)",
	["CR_B3"] = "Jason Kapalka, Dave Haas, Blizzard Entertainment, Jen Chess, Scott Lantz, Anthony Coleman",
	["CR_H4"] = "Based On",
	["CR_B4"] = "Peggle by PopCap Games, Inc.\nPeggle: World of Warcraft Edition (levels 14-23)",
	["CR_H5"] = "Community Updates",
	["CR_B5"] = "adamz01h, Ketho, Nimos, ZombieProtectionAgency, Andy1210, C0rn3j, chrisliebaer",
	["CR_H6"] = "Peggle Forever (Fan Edition)",
	["CR_B6"] = "SuperBirdy\nHeroes, talent trees, abilities, extra levels\nBlue Alliance buttons: darkenscale (Blue Buttons)",
	["CR_NOTE"] = "Unofficial fan project, not affiliated with PopCap, EA or Blizzard. Peggle and the original add-on were made by PopCap Games, Inc. (now part of Electronic Arts). See NOTICE.md.",
	["ABOUT_FAN"] = "Peggle Forever is an unofficial, free, non-commercial fan project. It is not made by, affiliated with or endorsed by PopCap, Electronic Arts or Blizzard Entertainment. Peggle and PopCap are trademarks of their owners; World of Warcraft is a trademark of Blizzard Entertainment. Levels 14-23 come from Peggle: World of Warcraft Edition.",
	["DUEL"] = "DUEL",
	["DUEL_BREAKDOWN1"] = "Your Score: %s",
	["DUEL_BREAKDOWN1a"] = "Opponent's Score: %s",
	["DUEL_BREAKDOWN2"] = "Talent: |cFFFFFFFF%s",
	["DUEL_BREAKDOWN3"] = "Style: |cFFFFFFFF%s",
	["DUEL_BREAKDOWN4"] = "Fever: |cFFFFFFFF%s",
	["DUEL_CHALLENGE"] = "%s has challenged you to a duel!",
	["DUEL_FORFEIT1"] = "|cFFFF0000You forfeited the duel!",
	["DUEL_FORFEIT2"] = "|cFFFF0000Opponent forfeited the duel!",
	["_DUEL_HISTORY"] = "Last 10 opponents:",
	["_DUEL_NO_HISTORY"] = "No one has been dueled!",
	["DUEL_OPP_WL"] = "Win/Loss vs %s: %d - %d",
	["DUEL_RESULTS"] = "DUEL RESULTS",
	["DUEL_RESULT1"] = "WAITING ON\n%s",
	["DUEL_RESULT2"] = "|cFF00FF00DEFEATED\n%s",
	["DUEL_RESULT3"] = "|cFFFF0000DEFEATED BY\n%s",
	["DUEL_RESULT4"] = "|cFFFF0000DUEL WAS\nFORFEITED",
	["DUEL_SCORE1"] = "Your Score: %s",
	["DUEL_SCORE2"] = "Opponent Score: %s",
	["DUEL_STATUS"] = "DUEL INVITE STATUS",
	["DUEL_STATUS1"] = "Sending duel invite...",
	["DUEL_STATUS2"] = "Waiting for user to accept duel request...",
	["DUEL_STATUS3"] = "User declined the duel request.",
	["DUEL_STATUS4"] = "That player does not have Peggle Forever turned on.",
	["DUEL_STATUS5"] = "User is currently being challenged. Try again in a few minutes.",
	["DUEL_STATUS6"] = "Challenger cancelled the duel.",
	["DUEL_TIME"] = "Duel time remaining: %s",
	["DUEL_TOTAL_WL"] = "Total Win/Loss: %d - %d",
	["DUEL_WAITING"] = "Your opponent is still playing...",
	["_EXPIRED"] = "Expired",
	["FORFEIT"] = "Forfeit",
	["_FREE_BALL"] = "FREE BALL!",
	["FREE_BALL2"] = "FREE\nBALL",
	["_FREE_BALL_DUEL"] = "BUCKET BONUS\n%s",
	["GENERATING_NAMES"] = "Generating name list for custom channels...",
	["HOW_TO_PLAY1"] = "Basic Gameplay",
	["HOW_TO_PLAY5"] = "Heroes",
	["HOW_TO_PLAY6"] = "Hero Talents",
	["HOW_TO_PLAY7"] = "Legacy & Points",
	["HOW_TO_PLAY8"] = "Stats & Options",
	["HOW_TO_PLAY2"] = "Duel Mode",
	["HOW_TO_PLAY2a"] = "Duel Mode lets you challenge another player to a 1-on-1 ten-ball game of Peggle. Choose a level, type in the name of the player you want to challenge and pick the hero you will both play as, then hit Play!\n\nBoth players need Peggle Forever (the original Peggle can't connect), and talents are always off so it is a fair fight: you use the chosen hero's ability, or the plain blast if you pick Standard. If they are already in another duel you can't challenge them until they are finished.\n\nDuel mode stores your last ten opponents as a handy drop-down so you can quickly get a rematch.",
	["HOW_TO_PLAY2b"] = "After each duel, the summary screen shows how you fared vs your opponent ".."and gives a breakdown of the point scoring. It also displays which character ".."your opponent used, as well as how many levels they've beaten or gotten a ".."100% clear on.",
	["HOW_TO_PLAY3"] = "Battle Mode",
	["HOW_TO_PLAY3a"] = "Battle Mode lets you set up special multiplayer contests with your friends and guildmates. Pick the level, how many shots each person gets, how long the battle runs, and the hero everyone plays as (or Standard, no hero). Talents are off, so everyone has the same base ability. Then send out invitations!\n\nClick the Battle Mode tab to select a Battle you've entered or create a new one. If you've already played it you can see the leaderboard, with the character each player used and how many levels they've beaten or 100% cleared.\n\nOpen a Battle and click Remove to drop it from your list. If you created it, Cancel Battle ends it for everyone and the others are told.",
	["HOW_TO_PLAY3b"] = "Battles that have run out of time will eventually decay off your list.",
	["HOW_TO_PLAY4"] = "Peggle Loot",
	["HOW_TO_PLAY4a"] = "Peggle Loot is a fun way to distribute loot in party or raid. ".."When activated, all players in the party or raid with the add-on will get the ".."option to play a single shot high score challenge for the item. Whoever scores ".."the highest wins the right to the item!\n\n".."Simply type |cFFFFFF00/peggleloot|r to ".."initiate the challenge. Optionally, you can also shift-click the item to add ".."an item link after the peggleloot command.",
	["HOW_TO_PLAY4b"] = "The addon will pick a random level, and then send that challenge to all members of the party or raid. They will have the option to play or pass. If they play, they get a single shot to score as many points as possible.\n\nTo make it fair, talents are disabled for the shot and everyone uses the same standard shooter. Players have 30 seconds to complete their shots from when the Peggle Loot challenge is activated.\n\nOnce all players have competed, their scores are shown and the winner declared! ",
	["INVITEES"] = "INVITEES",
	["INVITED"] = "|cFFFF8C00(%d INVITED)",
	["INVITE_PERSON"] = "INVITE INDIVIDUAL:",
	["INVITE_NOTE"] = "NOTE TO INVITEES",
	["LEGAL1"] = "(c) 2000, 2009 PopCap Games Inc. All right reserved",
	["LEGAL2"] = "(c) 2007, 2009 PopCap Games, Inc.  All rights reserved.  This application is ".."being made available free of charge for your personal, non-commercial entertainment "..'use, and is provided "as is", without any warranties.  PopCap Games, Inc. will have '.."no liability to you or anyone else if you choose to use it.  See readme.txt for details.",
	["_LEVEL_INFO"] = "Level %d: %s",
	["MENU"] = "MENU",
	["MOST_RECENT"] = "MOST RECENT:",
	["MOUSE_OVER"] = "Mouse over a talent for more information",
	["NEW"] = " |cffffff00(NEW!)",
	["_NEXT"] = "NEXT ",
	["NO_SCORE"] = "PLAY LEVEL TO EARN A SCORE!",
	["NOT_PLAYED"] = "Not yet played",
	["OPPONENT"] = "OPPONENT:",
	["OPPONENT_NOTE"] = "NOTE TO OPPONENT",
	["OPPONENT_NOTE2"] = "NOTE FROM OPPONENT",
	["OPT_TRANS_DEFAULT"] = "Mouse-on Transparency",
	["OPT_TRANS_MOUSE"] = "Mouse-off Transparency",
	["OPT_MINIMAP"] = "Show Mini-map Icon",
	["OPT_NEW_ON_FLIGHT"] = "New Game on Flight Start",
	["OPT_SOUNDS"] = "Sounds:",
	["OPT_SOUNDS_NORMAL"] = "Normal",
	["OPT_SOUNDS_QUIET"] = "Quiet",
	["OPT_SOUNDS_OFF"] = "Off",
	["OPT_LOCK"] = "Lock Window",
	["OPT_COLORBLIND"] = "Color Blind Mode",
	["OPT_HIDEOUTDATED"] = "Hide Old Chat Notifications",
	["OPT_HIGHFPS"] = "144FPS mode(up from 60)",
	["OPT_AUTO_OPEN"] = "Auto-Open:",
	["OPT_AUTO_OPEN1"] = "On Flight Start",
	["OPT_AUTO_OPEN2"] = "On Death",
	["OPT_AUTO_OPEN3"] = "On Log-in",
	["OPT_AUTO_OPEN4"] = "Peggle Duel Invite",
	["OPT_AUTO_CLOSE"] = "Auto-Close:",
	["OPT_AUTO_CLOSE1"] = "On Flight End",
	["OPT_AUTO_CLOSE2"] = "On Ready Check",
	["OPT_AUTO_CLOSE3"] = "On Enter Combat",
	["OPT_AUTO_CLOSE4"] = "Peggle Duel Complete",
	["OPT_AUTO_CLOSE5"] = "Peggle Loot Complete",
	["OPT_DUEL_INVITES"] = "Duel/Battle Invites:",
	["OPT_DUEL_INVITES1"] = "Chatbox Text Alert",
	["OPT_DUEL_INVITES2"] = "Raid Warning Text Alert",
	["OPT_DUEL_INVITES3"] = "Mini-map Icon Alert",
	["OPT_DUEL_INVITES4"] = "Auto-decline Duels",
	["OPTIONAL"] = "|cFFFF8C00(OPTIONAL)",
	["ORANGE_PEGS"] = "Orange\nPegs",
	["OUT_OF_DATE"] = "|cFFFFFFFFThis version of Peggle Forever is out of date! Download the latest version from where you got it to keep playing duels and Battles.|r",
	["_OUTDATED"] = "%s has invited you to a %s using an old version of this addon. Unfortunately, the versions are no longer compatible. Please ask them to upgrade to the latest version.",
	["_PEGS_HIT"] = "%s x %d |4PEG:PEGS",
	["_PEGGLE_ISSUE1"] = "[Peggle Forever] We're very sorry but it appears the battle data being saved is invalid and was not saved. Please report this error with as much detail as possible so we can fix it in future versions.",
	["PEGGLE_ISSUE2"] = "Part of the Peggle Forever add-on is corrupt. Please re-download Peggle Forever to fix this issue.",
	["PEGGLELOOT_DESC"] = "Highest Scoring Single Shot Wins",
	["_PEGGLELOOT_ISACTIVE"] = "Peggle Loot is already active! %d seconds remain in current challenge.",
	["_PEGGLELOOT_NOTIFY"] = "Peggle One-Shot Loot System Initialized for %s! Results released in 40 seconds. If you do not have the Peggle Forever add-on, you're missing out!",
	["_PEGGLELOOT_CHAT_REMAINING"] = "Peggle Loot results in %d seconds!",
	["_PEGGLELOOT_NOWINNER"] = "*** No winner found! ***",
	["PEGGLELOOT_REMAINING"] = "Time remaining: %d sec",
	["_PEGGLELOOT_RESULTS"] = "Peggle Loot Results:",
	["PEGGLELOOT_TITLE"] = "Peggle Loot Challenge",
	["_PEGGLELOOT_WINNER"] = "*** Winner: %s ***",
	["PERSONAL_BEST"] = "PERSONAL BEST:",
	["PERSONAL_BEST_PTS"] = "%s PTS",
	["_PUBLISH_SCORE"] = "[Peggle Forever]: %s just scored %s points on %s! Get the Peggle Forever add-on to beat their score!",
	["_PUBLISH_DUEL_W"] = "[Peggle Forever]: %s just defeated %s in a Peggle Duel! Get the Peggle Forever add-on to pit your skills against them!",
	["_PUBLISH_DUEL_L"] = "[Peggle Forever]: %s was just defeated by %s in a Peggle Duel! Get the Peggle Forever add-on to pit your skills against them!",
	["_PUBLISH_1"] = CHAT_MSG_GUILD,
	["_PUBLISH_2"] = CHAT_MSG_PARTY,
	["_PUBLISH_3"] = CHAT_MSG_RAID,
	["QUICK_PLAY"] = "QUICK PLAY",
	["PLAYING"] = "Playing",
	["_POINT_BOOST"] = "POINT BOOST!",
	["_POINTS_LEFT"] = "Points left to spend",
	["_RANK"] = "Rank (%d/%d)",
	["_REQUIRES_5"] = "|cFFFF0000Requires 5 points in %s.\n",
	["_REQUIRES_X"] = "|cFFFF0000Requires %d points in Peggle Talents.\n",
	["SELECT_LEVEL"] = "SELECT A LEVEL",
	["SCORE"] = "Score",
	["SCORE_BEST"] = "Best",
	["SCORE_TIME_LEFT"] = "Time Left: %s",
	["SCORES"] = "SCORES",
	["_SPECIAL_NAME1"] = "SUPER GUIDE",
	["_SPECIAL_NAME2"] = "SPACE BLAST",
	["_STYLE_COUNT"] = "+%s STYLE POINTS",
	["_STYLESHOT_1"] = "FREE BALL SKILLS!\n+",
	["_STYLESHOT_2"] = "LONG SHOT!\n+",
	["_STYLESHOT_3"] = "SUPER LONG SHOT!\n+",
	["_STYLESHOT_4"] = "MAD SKILLZ\n+",
	["_STYLESHOT_4a"] = "CRAZY MAD SKILLZ\n+",
	["_STYLESHOT_5"] = "EXTREME SLIDE!\n+",
	["_STYLESHOT_6"] = "ORANGE ATTACK!\n+",
	["_STYLESHOT_6a"] = "ORANGE ATTACK!\n+",
	["_SUMMARY_TITLE0"] = "NO MORE SHOTS",
	["_SUMMARY_TITLE1"] = "LEVEL COMPLETE",
	["_SUMMARY_TITLE2"] = "LEVEL FULLY CLEARED",
	["_SUMMARY_TITLE3"] = "LEVEL FINISHED",
	["_SUMMARY_TITLE4"] = "BATTLE FINISHED",
	["_SUMMARY_TITLE5"] = "LOOT SCORE SUBMITTED",
	["SUMMARY_SCORE_BEST"] = "Best Score On This Level: |cFFFFFFFF%s",
	["SUMMARY_SCORE_YOURS"] = "Score: |cFFFFFFFF%s",
	["SUMMARY_STAT1"] = "Shots:",
	["SUMMARY_STAT2"] = "Free Balls:",
	["SUMMARY_STAT3"] = "% Cleared:",
	["SUMMARY_STAT4"] = "Talent Score:",
	["SUMMARY_STAT5"] = "Fever Score:",
	["SUMMARY_STAT6"] = "Style Points:",
	["_TALENT1_NAME"] = "TWO-SIDED COIN",
	["_TALENT1_DESC"] = "Increases your chance of getting a free-ball when you don't hit any pegs by %d%%.",
	["_TALENT2_NAME"] = "STYLE FOR MILES",
	["_TALENT2_DESC"] = "Increases the points you receive for style shots by %d%%.",
	["_TALENT3_NAME"] = "A STEP AHEAD",
	["_TALENT3_DESC"] = "Your fever bonus meter starts with %d |4notch:notches; lit at the beginning of the match.",
	["_TALENT4_NAME"] = "THE ONLY CURE",
	["_TALENT4_DESC"] = "The points awarded by end of level Fever Buckets is increased by %d%%.",
	["_TALENT5_NAME"] = "PEG MARKSMAN",
	["_TALENT5_DESC"] = 'When you hit a peg, you have a %d%% chance to "crit" receiving 150%% of that peg\'s points.',
	["_TALENT6_NAME"] = "MORE COWBELL",
	["_TALENT6_DESC"] = "Purple pegs have a %d%% chance to increase your fever meter by 1.",
	["_TALENT7_NAME"] = "MISSION CRITICAL",
	["_TALENT7_DESC"] = "Your Crit pegs are worth %d%% of the original peg's value.",
	["_TALENT8_NAME"] = "Unintended Awesome",
	["_TALENT8_DESC"] = "When you hit a green peg, the purple peg has a %d%% chance of erupting in a small explosion, scoring itself and other nearby pegs.",
	["_TALENT9_NAME"] = "Infusion of Awesome",
	["_TALENT9_DESC"] = "Pegs hit with your special power have a %d%% chance to crit. (First two pegs hit with a guided ball OR all pegs hit with a space blast).",
	["_TALENT10_NAME"] = "ROLLING IGNITION",
	["_TALENT10_DESC"] = "When you hit a green peg and land the ball in the bucket in the same shot, one of your blue pegs is converted to a green peg.",
	["_TALENT11_NAME"] = "DOUBLE FISSION",
	["_TALENT11_DESC"] = "When you hit a purple peg, you score bonus points for each peg already hit in the shot as if you hit it again. These bonus points may not crit.",
	["TALENTS"] = "TALENTS",
	["TALENTS_DESC"] = "Talents are 'passive' abilities for your current hero",
	["_THE_ITEM"] = "the item",
	["_TOOLTIP_MINIMAP"] = "Left-click to show/hide game.\nRight-click to move icon.",
	["_TOTAL_MISS"] = "TOTAL MISS!",
	["_TURNS"] = " TURNS",
	["WIN_LOSS"] = "Win/Loss Record",
	["WIN_LOSS_LEVEL"] = "(On this level)",
	["WIN_LOSS_PLAYER"] = "W/L vs this opponent: %d - %d",
}
-- Name / description / icon for a talent slot: hero-specific for slots 9-15, universal otherwise.
config.TalentInfo = function(kind, slot)
	local def = (kind == "hero") and config.HeroTalent(slot) or nil;
	if def then
		return def.name, def.desc, def.icon, 0, def.per;
	end
	return e.locale["_TALENT"..slot.."_NAME"], e.locale["_TALENT"..slot.."_DESC"], e.artPath..(e.talentTex[slot] or "t_coin"), e.factors[slot * 2 - 1] or 0, e.factors[slot * 2] or 0;
end
e.factors = {0, 10, 0, 2, 0, 1, 0, 10, 0, 5, 0, 10, 150, 10, 0, 10, 0, 20, 0, 0, 0, 0}
local fe = nil;
local ht = -1;
local St = {["x"] = 0;
["y"] = 0;
["xVel"] = 0;
["yVel"] = 0};
local ce = 0;
local q = 0;
local Ke = 0;
local qe = 0;
local o = {};
local H;
local levelScoreData = {};
for i=1, #LEVELS * 2 do
	levelScoreData[i] = 0
end
local d;
local t;
local r;
-- Rebuilds the level score cache from the active hero's own progress.
config.RefreshLevelScores = function()
	local scores = PeggleForeverData.newData.levelScores
	for i = 1, #LEVELS do
		local entry = scores[i];
		local progress = entry and entry.progress or 0;
		levelScoreData[i] = (progress ~= 0) and entry.score or 0;
		levelScoreData[i + #LEVELS] = progress;
	end
	if t and t.levelList and t.levelList.UpdateList then
		t.levelList:UpdateList();
	end
end
local f = math.fmod;
local Se = math.abs;
local z = math.sqrt;
local I = math.sin;
local k = math.cos;
local i = math.floor;
local C = math.random;
local T = math.rad;
local xe = math.min;
local F = math.max;
local gt = math.deg;
local W = string.byte;
local O = string.char;
local c = string.sub;
local A = tonumber;
local D = tostring;
local u = table.remove;
local s = table.insert;
local B = {};
levelDataIndex = {};
levelDataIndex.id = 1;
levelDataIndex.animationType = 2;
levelDataIndex.objectType = 3;
levelDataIndex.x = 4;
levelDataIndex.y = 5;
levelDataIndex.rotation = 6;
levelDataIndex.animationTime = 7;
levelDataIndex.animationDelay = 8;
levelDataIndex.animValue1 = 9;
levelDataIndex.animValue2 = 10;
levelDataIndex.animValue3 = 11;
levelDataIndex.animValue4 = 12;
e.windowWidth = 662;
e.windowHeight = 548;
e.boardWidth = 554;
e.boardHeight = 464;
e.boardXYSections = 10;
e.sectionXSize = i(e.boardWidth / e.boardXYSections + .9);
e.sectionYSize = i(e.boardHeight / e.boardXYSections + .9);
e.ballWidth = 12;
e.ballHeight = 12;
e.ballRadius = 6;
e.pegWidth = 28 * .85;
e.pegHeight = 28 * .85;
e.pegRadius = 10 * .85;
e.brickWidth = 34 * .85;
e.brickHeight = 34 * .85;
e.brickRadius = 18 * .85;
e.catcherWidth = 138;
e.catcherHeight = 27;
e.catcherLoopTime = 6;
e.zoomDistance = 48;
e.addonPath = "Interface\\AddOns\\"..AddOn;
e.artPath = "Interface\\AddOns\\"..AddOn.."\\images\\";
-- Fonts: WoW's built-in Friz Quadrata for text and numbers, Morpheus for page headings (the classic
-- quest-title look). Languages with other alphabets use the client's standard font.
config.latinLocale = true;
do
	local loc = GetLocale and GetLocale() or "enUS";
	if(loc == "koKR")or(loc == "zhCN")or(loc == "zhTW")or(loc == "ruRU")then
		config.latinLocale = false;
	end
end
config.fontBody = config.latinLocale and "Fonts\\FRIZQT__.TTF" or (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF");
config.fontHeading = config.latinLocale and "Fonts\\MORPHEUS.TTF" or (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF");
-- Colour schemes: textures registered here swap to their _G (Horde, red) or _B (Alliance, blue) version.
config.skinned = {};
config.skins = {{"Original", ""}, {"Horde", "_G"}, {"Alliance", "_B"}};
-- Until the player picks an appearance in Options, it follows the character's faction (Alliance = blue,
-- otherwise Horde red); picking one saves it and it is kept from then on.
config.DefaultScheme = function()
	return (UnitFactionGroup and UnitFactionGroup("player") == "Alliance") and "Alliance" or "Horde";
end
config.SkinSuffix = function()
	local choice = PeggleForeverData and PeggleForeverData.settings and PeggleForeverData.settings.colorScheme or config.DefaultScheme();
	for _, v in ipairs(config.skins) do
		if v[1] == choice then
			return v[2];
		end
	end
	return "";
end
config.Skin = function(tex, base)
	if not tex.skinBase then
		tex.skinBase = base;
		config.skinned[#config.skinned + 1] = {tex, base};
	end
	tex:SetTexture(e.artPath..base..config.SkinSuffix(), base == "windowCoverCenter");
end
-- Button themes (the standard WoW red/gold panel button, recoloured per colour scheme).
config.buttonThemes = {
	[""] = {text = {1, .82, 0}, hover = {1, 1, 1}},
	-- tint x (desaturated button) + lift is aimed at the tab artwork: Horde ~ (207,88,58), Alliance ~ (70,121,210)
	-- `dark` darkens the button centre; an optional `lift` colour adds a thin glow ring (off for now).
	-- Horde: the stock red button. Alliance: the same button with a blue face (desaturated, then a blue wash inside the grey frame).
	["_G"] = {text = {1, 1, 1}, hover = {1, 1, 1}},
	["_B"] = {art = true, text = {1, 1, 1}, hover = {1, 1, 1}},
};
config.styledButtons = {};
-- Blue Alliance panel-button art: the stock button (same 128x32 layout, same grey frame) with a blue face.
config.buttonArt = {
	up = "Interface\\AddOns\\PeggleForever\\images\\btn_B_up.tga",
	down = "Interface\\AddOns\\PeggleForever\\images\\btn_B_down.tga",
	hl = "Interface\\AddOns\\PeggleForever\\images\\btn_B_hl.tga",
};
config.stockButtonArt = {
	up = 130828,
	down = "Interface\\Buttons\\UI-Panel-Button-Down",
	hl = 130826,
	off = "Interface\\Buttons\\UI-Panel-Button-Disabled",
};
-- Points the button's three slices at the right art for its current state. The stock template swaps the
-- textures itself when the mouse is pressed or the button is enabled/disabled, so this runs after those too.
config.ApplyButtonArt = function(btn)
	local alliance = btn.artTheme and not btn.dimmed;
	local set = alliance and config.buttonArt or config.stockButtonArt;
	local file;
	if btn.IsEnabled and not btn:IsEnabled() then
		file = alliance and set.up or set.off;
	elseif btn.GetButtonState and btn:GetButtonState() == "PUSHED" then
		file = set.down;
	else
		file = set.up;
	end
	local name = btn.GetName and btn:GetName();
	local regions = {btn.Left, btn.Middle, btn.Right};
	if name then
		regions = {btn.Left or _G[name.."Left"], btn.Middle or _G[name.."Middle"], btn.Right or _G[name.."Right"]};
	end
	for _, tex in pairs(regions) do
		if(type(tex) ~= "function")and tex.SetTexture then
			local l, r, tp, bt;
			if tex.GetTexCoord then
				local ulx, uly, llx, lly, urx, ury = tex:GetTexCoord();
				l, r, tp, bt = ulx, urx, uly, lly;
			end
			tex:SetTexture(file);
			if l and r and tp and bt and tex.SetTexCoord then
				tex:SetTexCoord(l, r, tp, bt);
			end
		end
	end
	if btn.GetHighlightTexture then
		local ok, hl = pcall(btn.GetHighlightTexture, btn);
		if ok and hl and(type(hl) ~= "function")and hl.SetTexture then
			local l, r, tp, bt;
			if hl.GetTexCoord then
				local ulx, uly, llx, lly, urx, ury = hl:GetTexCoord();
				l, r, tp, bt = ulx, urx, uly, lly;
			end
			hl:SetTexture(set.hl);
			if l and r and tp and bt and hl.SetTexCoord then
				hl:SetTexCoord(l, r, tp, bt);
			end
		end
	end
end
config.ButtonFontObject = function(kind, size, color)
	local suffix = config.SkinSuffix();
	local name = "PeggleBtnFont"..kind..(suffix == "" and "O" or string.sub(suffix, 2))..size;
	local fo = _G[name];
	if not fo then
		fo = CreateFont(name);
		fo:SetFont(config.fontBody, size, "OUTLINE");
	end
	fo:SetTextColor(color[1], color[2], color[3]);
	return fo;
end
-- Applies the current colour scheme to a panel button. `size` (font size) is optional.
config.StyleButton = function(btn, size)
	if size then
		btn.styleSize = size;
	end
	if not btn.styleRegistered then
		btn.styleRegistered = true;
		config.styledButtons[#config.styledButtons + 1] = btn;
	end
	local theme = config.buttonThemes[config.SkinSuffix()] or config.buttonThemes[""];
	btn.artTheme = theme.art and true or nil;
	if btn.dimmed then
		theme = {desat = true, tint = {.55, .55, .55}, text = {.6, .6, .6}, hover = {.6, .6, .6}};
	end
	local name = btn.GetName and btn:GetName();
	local regions = {btn.Left, btn.Middle, btn.Right};
	if name then
		regions[#regions + 1] = _G[name.."Left"];
		regions[#regions + 1] = _G[name.."Middle"];
		regions[#regions + 1] = _G[name.."Right"];
	end
	for _, getter in ipairs({"GetNormalTexture", "GetPushedTexture", "GetDisabledTexture"}) do
		if btn[getter] then
			local ok, tex = pcall(btn[getter], btn);
			if ok and tex then
				regions[#regions + 1] = tex;
			end
		end
	end
	for _, tex in pairs(regions) do
		if(type(tex) ~= "function")and tex.SetVertexColor then
			if tex.SetDesaturated then
				tex:SetDesaturated(theme.desat and true or false);
			end
			if theme.tint then
				tex:SetVertexColor(theme.tint[1], theme.tint[2], theme.tint[3]);
			else
				tex:SetVertexColor(1, 1, 1);
			end
		end
	end
	-- Alliance uses its own blue art; every other scheme gets the stock art back if it was swapped out
	if theme.art or btn.artHooked then
		if not btn.artHooked and btn.HookScript then
			btn.artHooked = true;
			for _, script in ipairs({"OnMouseDown", "OnMouseUp", "OnEnable", "OnDisable", "OnShow"}) do
				btn:HookScript(script, function()
					config.ApplyButtonArt(btn);
				end);
			end
		end
		config.ApplyButtonArt(btn);
	end
	-- the hover light (the stock one is red/yellow): recoloured per scheme
	if btn.GetHighlightTexture then
		local ok, hl = pcall(btn.GetHighlightTexture, btn);
		if ok and hl and(type(hl) ~= "function")and hl.SetVertexColor then
			local spec = theme.hl;
			if hl.SetDesaturated then
				hl:SetDesaturated((spec and spec.desat) and true or false);
			end
			if spec and spec.tint then
				hl:SetVertexColor(spec.tint[1], spec.tint[2], spec.tint[3]);
			else
				hl:SetVertexColor(1, 1, 1);
			end
		end
	end
	-- a faint additive colour wash over the whole face: richer, brighter colour without changing the frame
	if theme.wash and btn.CreateTexture then
		if not btn.wash then
			local wash = btn:CreateTexture(nil, "ARTWORK");
			wash:SetTexture("Interface\\Buttons\\WHITE8x8");
			wash:SetBlendMode("ADD");
			btn.wash = wash;
			-- the frame's rounded end caps and rim scale with the button height, so the wash is inset in
			-- proportion (a fixed inset let the square show over the grey frame on some buttons)
			btn.FitWash = function()
				local h = btn:GetHeight();
				if not h or h < 1 then
					h = 22;
				end
				local ix, iy = math.max(4, math.floor(h * .25 + .5)), math.max(4, math.floor(h * .18 + .5));
				wash:ClearAllPoints();
				wash:SetPoint("TopLeft", btn, "TopLeft", ix,  - iy);
				wash:SetPoint("BottomRight", btn, "BottomRight",  - ix, iy);
			end
			if btn.HookScript then
				btn:HookScript("OnSizeChanged", function()
					btn.FitWash();
				end);
			end
		end
		btn.FitWash();
		local w = theme.wash;
		btn.wash:SetVertexColor(w[1], w[2], w[3]);
		btn.wash:Show();
	elseif btn.wash then
		btn.wash:Hide();
	end
	if(theme.face or theme.dark or theme.lift)and btn.CreateTexture then
		if not btn.ring then
			local white = "Interface\\Buttons\\WHITE8x8";
			local dark = btn:CreateTexture(nil, "ARTWORK");
			dark:SetPoint("TopLeft", btn, "TopLeft", 4,  - 4);
			dark:SetPoint("BottomRight", btn, "BottomRight",  - 4, 4);
			dark:SetTexture(white);
			btn.dark = dark;
			btn.ring = {};
			-- {anchor 1, offset x, offset y, anchor 2, offset x, offset y, "w"/"h" size}: top, bottom, left, right strips
			local layout = {
				{"TopLeft", 1,  - 1, "TopRight",  - 1,  - 1, "h"},
				{"BottomLeft", 1, 1, "BottomRight",  - 1, 1, "h"},
				{"TopLeft", 1,  - 1, "BottomLeft", 1, 1, "w"},
				{"TopRight",  - 1,  - 1, "BottomRight",  - 1, 1, "w"},
			};
			for index, item in ipairs(layout) do
				local strip = btn:CreateTexture(nil, "ARTWORK");
				strip:SetTexture(white);
				strip:SetBlendMode("ADD");
				strip:SetPoint(item[1], btn, item[1], item[2], item[3]);
				strip:SetPoint(item[4], btn, item[4], item[5], item[6]);
				if(item[7] == "h")then
					strip:SetHeight(4);
				else
					strip:SetWidth(4);
				end
				btn.ring[index] = strip;
			end
		end
		local mult = PeggleForeverData.settings.buttonLift or 1;
		local lift = theme.lift or {0, 0, 0};
		local r, g, b = math.min(1, lift[1] * mult), math.min(1, lift[2] * mult), math.min(1, lift[3] * mult);
		if theme.face then
			local f = theme.face;
			if btn.dark.SetGradientAlpha then
				btn.dark:SetGradientAlpha("VERTICAL", f.bottom[1], f.bottom[2], f.bottom[3], f.alpha, f.top[1], f.top[2], f.top[3], f.alpha);
			elseif btn.dark.SetGradient and CreateColor then
				btn.dark:SetGradient("VERTICAL", CreateColor(f.bottom[1], f.bottom[2], f.bottom[3], f.alpha), CreateColor(f.top[1], f.top[2], f.top[3], f.alpha));
			else
				btn.dark:SetVertexColor((f.top[1] + f.bottom[1]) / 2, (f.top[2] + f.bottom[2]) / 2, (f.top[3] + f.bottom[3]) / 2, f.alpha);
			end
		else
			btn.dark:SetVertexColor(0, 0, 0, theme.dark or 0);
		end
		btn.dark:Show();
		-- gradient alpha: strongest at the outer edge, fading to nothing towards the middle
		local function fade(tex, orientation, outerFirst)
			local a1, a2 = outerFirst and 1 or 0, outerFirst and 0 or 1;
			if tex.SetGradientAlpha then
				tex:SetGradientAlpha(orientation, r, g, b, a1, r, g, b, a2);
			elseif tex.SetGradient and CreateColor then
				tex:SetGradient(orientation, CreateColor(r, g, b, a1), CreateColor(r, g, b, a2));
			else
				tex:SetVertexColor(r * .5, g * .5, b * .5);
			end
		end
		fade(btn.ring[1], "VERTICAL", false);        -- top strip: opaque at the top (max end)
		fade(btn.ring[2], "VERTICAL", true);         -- bottom strip: opaque at the bottom (min end)
		fade(btn.ring[3], "HORIZONTAL", true);       -- left strip: opaque at the left (min end)
		fade(btn.ring[4], "HORIZONTAL", false);      -- right strip: opaque at the right (max end)
		for _, strip in ipairs(btn.ring) do
			strip:SetShown(theme.lift ~= nil);
		end
	elseif btn.ring then
		btn.dark:Hide();
		for _, strip in ipairs(btn.ring) do
			strip:Hide();
		end
	end
	if btn.styleSize and CreateFont then
		btn:SetNormalFontObject(config.ButtonFontObject("N", btn.styleSize, theme.text));
		btn:SetHighlightFontObject(config.ButtonFontObject("H", btn.styleSize, theme.hover));
		btn:SetDisabledFontObject(config.ButtonFontObject("D", btn.styleSize, {.5, .5, .5}));
	else
		local fs = btn.GetFontString and btn:GetFontString();
		if fs then
			fs:SetTextColor(theme.text[1], theme.text[2], theme.text[3]);
		end
	end
end
config.ApplyButtonSkin = function()
	for _, btn in ipairs(config.styledButtons) do
		config.StyleButton(btn);
	end
end
-- Page headings (QUICK PLAY, TALENTS, ...) follow the colour scheme: blue, red for Horde, darker blue for Alliance.
config.headers = {};
config.headerColors = {[""] = {.05, .66, 1}, ["_G"] = {1, .22, .18}, ["_B"] = {.05, .35, .85}};
config.HeaderColor = function()
	local c = config.headerColors[config.SkinSuffix()] or config.headerColors[""];
	return c[1], c[2], c[3];
end
-- Selection highlight in the level / challenge lists: light blue (Original), red (Horde), darker blue (Alliance).
config.listHighlights = {};
config.listHighlightColors = {[""] = {.1, .75, 1}, ["_G"] = {1, .2, .1}, ["_B"] = {.1, .4, 1}};
config.ListHighlight = function(tex)
	if not tex.listHighlight then
		tex.listHighlight = true;
		config.listHighlights[#config.listHighlights + 1] = tex;
	end
	local c = config.listHighlightColors[config.SkinSuffix()] or config.listHighlightColors[""];
	tex:SetVertexColor(c[1], c[2], c[3]);
end
-- The Horde / Alliance PvP crest (the unit-frame faction symbol) in the window's top-left corner.
config.crestTextures = {["_G"] = "Interface\\TargetingFrame\\UI-PVP-Horde", ["_B"] = "Interface\\TargetingFrame\\UI-PVP-Alliance"};
config.UpdateFactionCrest = function()
	local win = _G.PeggleWindow;
	if not win then
		return;
	end
	if not config.crest then
		local holder = CreateFrame("Frame", nil, win);
		holder:SetFrameLevel(win:GetFrameLevel() + 60);
		local tex = holder:CreateTexture(nil, "Overlay");
		tex:SetAllPoints(holder);
		tex:SetTexCoord(0, .609375, 0, .640625);
		config.crest = holder;
		holder.tex = tex;
		-- easter egg: double-clicking the crest sounds the faction's call. Single clicks do nothing, and
		-- dragging from the crest moves the window as usual (a drag never counts as a click).
		holder:EnableMouse(true);
		holder:RegisterForDrag("LeftButton");
		holder:SetScript("OnDragStart", function(self)
			self.dragged = true;
			self.lastClick = nil;
			local start = win:GetScript("OnDragStart");
			if start then start(win) end
		end);
		holder:SetScript("OnDragStop", function()
			local stop = win:GetScript("OnDragStop");
			if stop then stop(win) end
		end);
		holder:SetScript("OnMouseDown", function(self)
			self.dragged = nil;
		end);
		holder:SetScript("OnMouseUp", function(self, button)
			if self.dragged or button ~= "LeftButton" then
				return;
			end
			local now = GetTime();
			if self.lastClick and(now - self.lastClick <= .4)then
				self.lastClick = nil;
				config.PlayCrestSound();
			else
				self.lastClick = now;
			end
		end);
	end
	-- size / position: /peggle crest <size> <x> <y> (saved)
	local lay = PeggleForeverData.settings.crestLayout or {42, -12, 15};
	config.crest:SetWidth(lay[1]);
	config.crest:SetHeight(lay[1]);
	config.crest:ClearAllPoints();
	config.crest:SetPoint("TopLeft", win, "TopLeft", lay[2], lay[3]);
	local path = config.crestTextures[config.SkinSuffix()];
	if path then
		config.crest.tex:SetTexture(path);
		config.crest:Show();
	else
		config.crest:Hide();
	end
end
-- Crest sounds (FileDataIDs from the game client). {file, name, seconds to play (cut short with a fade)}.
-- /peggle crestsound cycles through them for the crest that is showing; the choice is saved.
config.crestSounds = {
	Horde = {
		{1531445, "Arena war drums", 3},
		{569112, "Battleground warning (Horde)"},
		{568165, "Flag taken (Horde)"},
		{1036067, "Warsong war horn", 4},
		{568480, "Battleground victory (Horde)", 5},
	},
	Alliance = {
		{598079, "Alliance squire's horn"},
		{566064, "Ironforge dwarf horn", 4},
		{566564, "Stormwind bell toll", 5},
		{598187, "Alliance squire's horn (second call)"},
		{568320, "Battleground warning (Alliance)"},
		{569678, "Battleground victory (Alliance)", 5},
		{598724, "Strand of the Ancients victory (Alliance)", 5},
	},
};
config.CrestFaction = function()
	local suffix = config.SkinSuffix();
	return (suffix == "_G" and "Horde") or (suffix == "_B" and "Alliance") or nil;
end
config.PlayCrestSound = function()
	local faction = config.CrestFaction();
	local mode = config.SoundMode();
	if not(faction and mode)then
		return;
	end
	local list = config.crestSounds[faction];
	local saved = PeggleForeverData.settings.crestSound;
	if saved and saved.v ~= 3 then -- the Alliance list was reordered: start over at the new default
		saved.Alliance, saved.v = nil, 3;
	end
	local pick = saved and saved[faction] or 1;
	local entry = list[pick] or list[1];
	if config.crestHandle and StopSound then
		StopSound(config.crestHandle, 200); -- clicking again restarts it instead of stacking
	end
	local _, handle = PlaySoundFile(entry[1], (mode == "quiet") and "Ambience" or "SFX");
	config.crestHandle = handle;
	if handle and entry[3] and StopSound and C_Timer then
		C_Timer.After(entry[3], function()
			if config.crestHandle == handle then
				StopSound(handle, 800);
				config.crestHandle = nil;
			end
		end);
	end
	return entry;
end
config.ApplySkin = function()
	local suffix = config.SkinSuffix();
	config.UpdateFactionCrest();
	for _, tex in ipairs(config.listHighlights) do
		config.ListHighlight(tex);
	end
	for _, fs in ipairs(config.headers) do
		fs:SetTextColor(config.HeaderColor());
	end
	config.ApplyButtonSkin();
	for _, v in ipairs(config.skinned) do
		v[1]:SetTexture(e.artPath..v[2]..suffix, v[2] == "windowCoverCenter");
	end
end
e.soundPath = "Interface\\AddOns\\"..AddOn.."\\sounds\\";
e.boardBoundryBottom = 10
e.boardBoundryLeft = 10
e.boardBoundryTop = e.boardHeight - 2
e.boardBoundryRight = e.boardWidth - 2
e.cCount = 0;
e.maxBattles = 10;   -- active Battles one player can have created at once (each one is polled and pinged every few minutes)
e.artCut = {};
e.artCut["leftBorder"] = {0 / 512, 60 / 512, 0 / 512, 512 / 512};
e.artCut["rightBorder1"] = {0 / 256, 152 / 256, 0 / 512, 140 / 512};
e.artCut["rightBorder2"] = {85 / 256, 152 / 256, 140 / 512, 488 / 512};
e.artCut["rightBorder3"] = {0 / 256, 152 / 256, 488 / 512, 512 / 512};
e.artCut["topBorder"] = {60 / 512, 512 / 512, 0 / 512, 140 / 512};
e.artCut["bottomBorder"] = {60 / 512, 512 / 512, 488 / 512, 512 / 512};
e.artCut["powerLabel"] = {324 / 512, 506 / 512, 179 / 512, 203 / 512};
e.artCut["catcher"] = {100 / 512, 237 / 512, 413 / 512, 439 / 512};
e.artCut["catcherBack"] = {100 / 512, 237 / 512, 460 / 512, 486 / 512};
e.artCut["extraBallBarTop"] = {99 / 512, 110 / 512, 331 / 512, 347 / 512};
e.artCut["extraBallBar"] = {99 / 512, 110 / 512, 347 / 512, 363 / 512};
e.artCut["extraBallBarBot"] = {99 / 512, 110 / 512, 363 / 512, 379 / 512};
e.artCut["extraBallBottomCover"] = {99 / 512, 163 / 512, 383 / 512, 399 / 512};
e.artCut["extraBallTopCover"] = {167 / 512, 199 / 512, 373 / 512, 399 / 512};
e.artCut["ballLoader"] = {112 / 512, 135 / 512, 260 / 512, 379 / 512};
e.artCut["buttonInstantReplay"] = {144 / 512, 189 / 512, 260 / 512, 305 / 512};
e.artCut["glow"] = {139 / 512, 202 / 512, 258 / 512, 322 / 512};
e.artCut["catcherGlow"] = {255 / 512, 377 / 512, 429 / 512, 481 / 512};
e.artCut["feverBottomCover"] = {64 / 512, 98 / 512, 384 / 512, 399 / 512};
e.artCut["feverTopCover"] = {64 / 512, 98 / 512, 366 / 512, 381 / 512};
e.artCut["feverBar"] = {64 / 512, 95 / 512, 352 / 512, 364 / 512};
e.artCut["feverBarHighlight"] = {64 / 512, 95 / 512, 339 / 512, 351 / 512};
e.artCut["fever2x"] = {202 / 512, 248 / 512, 349 / 512, 370 / 512};
e.artCut["fever2xHighlight"] = {252 / 512, 298 / 512, 349 / 512, 370 / 512};
e.artCut["fever3x"] = {202 / 512, 248 / 512, 324 / 512, 345 / 512};
e.artCut["fever3xHighlight"] = {252 / 512, 298 / 512, 324 / 512, 345 / 512};
e.artCut["fever5x"] = {202 / 512, 248 / 512, 299 / 512, 320 / 512};
e.artCut["fever5xHighlight"] = {252 / 512, 298 / 512, 299 / 512, 320 / 512};
e.artCut["fever10x"] = {202 / 512, 248 / 512, 274 / 512, 295 / 512};
e.artCut["fever10xHighlight"] = {252 / 512, 298 / 512, 274 / 512, 295 / 512};
e.artCut["feverBonus10"] = {200 / 512, 313 / 512, 208 / 512, 258 / 512};
e.artCut["feverBonus50"] = {313 / 512, 423 / 512, 208 / 512, 258 / 512};
e.artCut["feverBonus100"] = {201 / 512, 313 / 512, 148 / 512, 205 / 512};
e.artCut["fever1"] = {0 / 512, 512 / 512, 92 / 256, 256 / 256};
e.artCut["fever2"] = {0 / 512, 512 / 512, 13 / 256, 92 / 256};
e.artCut["feverScore"] = {171 / 256, 256 / 256, 0 / 512, 268 / 512};
e.artCut["feverRay"] = {394 / 512, 452 / 512, 287 / 512, 481 / 512};
e.artCut["logoArt"] = {305 / 512, 390 / 512, 261 / 512, 426 / 512};
e.artCut["tabQuickPlay"] = {0 / 512, 118 / 512, 0 / 256, 64 / 256};
e.artCut["tabDuel"] = {118 / 512, 203 / 512, 0 / 256, 64 / 256};
e.artCut["tabChallenge"] = {203 / 512, 319 / 512, 0 / 256, 64 / 256};
e.artCut["tabTalents"] = {319 / 512, 416 / 512, 0 / 256, 64 / 256};
e.artCut["tabHowToPlay"] = {0 / 512, 141 / 512, 192 / 256, 256 / 256};
e.artCut["tabOptions"] = {416 / 512, 512 / 512, 0 / 256, 64 / 256};
e.artCut["buttonOkay"] = {0 / 256, 158 / 256, 0 / 256, 54 / 256};
e.artCut["buttonGo"] = {0 / 256, 158 / 256, 54 / 256, 108 / 256};
e.artCut["buttonResetTalents"] = {175 / 256, 219 / 256, 25 / 256, 182 / 256};
e.artCut["buttonNewChallenge"] = {0 / 256, 125 / 256, 109 / 256, 141 / 256};
e.artCut["buttonChallenge"] = {0 / 256, 175 / 256, 142 / 256, 183 / 256};
e.artCut["buttonRestartLevel"] = {0 / 256, 185 / 256, 184 / 256, 220 / 256};
e.artCut["buttonReturnToGame"] = {0 / 256, 185 / 256, 220 / 256, 256 / 256};
e.artCut["buttonAbandonGame"] = {220 / 256, 256 / 256, 70 / 256, 256 / 256};
e.artCut["buttonSound"] = {162 / 256, 182 / 256, 0 / 256, 20 / 256};
e.artCut["buttonMenu"] = {202 / 256, 256 / 256, 0 / 256, 20 / 256};
e.artCut["buttonClose"] = {235 / 256, 255 / 256, 19 / 256, 39 / 256};
e.artCut["buttonView"] = {191 / 256, 215 / 256, 186 / 256, 256 / 256};
e.artCut["buttonBack"] = {186 / 256, 256 / 256, 319 / 512, 343 / 512};
e.artCut["buttonAbout"] = {0 / 256, 44 / 256, 141 / 512, 298 / 512};
e.artCut["buttonCredits"] = {0 / 256, 44 / 256, 298 / 512, 457 / 512};
e.artCut["buttonPublish"] = {155 / 256, 199 / 256, 354 / 512, 480 / 512};
e.artCut["buttonDecline"] = {202 / 256, 256 / 256, 355 / 512, 512 / 512};
e.artCut["bannerBig1"] = {128 / 256, 256 / 256, 0 / 256, 183 / 256};
e.artCut["bannerBig2"] = {0 / 256, 128 / 256, 0 / 256, 183 / 256};
e.artCut["bannerSmall1"] = {0 / 512, 36 / 512, 467 / 512, 512 / 512};
e.artCut["bannerSmall2"] = {0 / 512, 36 / 512, 422 / 512, 467 / 512};
e.artCut["bannerSmall3"] = {0 / 512, 36 / 512, 377 / 512, 422 / 512};
e.artCut["howToPlay1"] = {0 / 512, 195 / 512, 0 / 512, 155 / 512};
e.artCut["howToPlay2"] = {197 / 512, 392 / 512, 0 / 512, 155 / 512};
e.artCut["howToPlay3"] = {0 / 512, 195 / 512, 155 / 512, 310 / 512};
e.artCut["howToPlay4"] = {197 / 512, 392 / 512, 155 / 512, 310 / 512};
e.artCut["howToPlay5"] = {0 / 512, 195 / 512, 311 / 512, 404 / 512};
e.artCut["howToPlay6"] = {194 / 512, 391 / 512, 311 / 512, 367 / 512};
e.artCut["howToPlay7"] = {194 / 512, 391 / 512, 405 / 512, 443 / 512};
e.artCut["howToPlay8"] = {0 / 512, 382 / 512, 444 / 512, 481 / 512};
e.artCut["popCap"] = {117 / 512, 187 / 512, 181 / 512, 251 / 512};
e.artCut["peggleBringer"] = {453 / 512, 512 / 512, 207 / 512, 487 / 512};
e.artCut["splashBringer"] = {60 / 512, 512 / 512, 368 / 512, 512 / 512};
e.artCut["exhibitA"] = {439 / 512, 512 / 512, 0 / 512, 373 / 512};
e.artCut["exhibitA2"] = {448 / 512, 512 / 512, 389 / 512, 453 / 512};
e.brickTex = {"blue", "red", "purple", "green"};
e.talentTex = {"t_coin", "t_style_for_miles", "t_a_step_ahead", "t_the_only_cure", "t_peg_marksmen", "t_more_cowbell", "t_mission_critical", "t_unintended_awesome", "t_infusion_of_awesome", "t_rolling_ignition", "t_double_fission", };
e.polygon = {{7,  - 11, 9,  - 4, 9, 3, 7, 10,  - 10, 3,  - 10,  - 4}, {7,  - 15, 10,  - 1, 7, 14,  - 10, 7,  - 9, 0,  - 10,  - 8}, {7,  - 13, 9,  - 6, 9, 5, 7, 12,  - 10, 7,  - 10,  - 8}, {8,  - 12, 9,  - 4, 9, 3, 8, 12,  - 9, 9,  - 8, 0,  - 9,  - 9}, {9,  - 14, 10,  - 6, 10, 5, 9, 14,  - 10, 11,  - 10,  - 11}, {8,  - 13, 9,  - 8, 9, 6, 8, 12,  - 10, 10,  - 10,  - 11}, {8,  - 15, 9,  - 7, 9, 6, 8, 15,  - 10, 13,  - 10,  - 13}, {8,  - 15, 9,  - 9, 9, 7, 8, 14,  - 9, 12,  - 9, 6,  - 9,  - 8,  - 9,  - 13}, {8,  - 15, 9,  - 6, 9, 5, 8, 13,  - 10, 11,  - 10, 6,  - 10,  - 7,  - 10,  - 13}, {8,  - 15, 9,  - 8, 9, 7, 8, 14,  - 10, 13,  - 10,  - 14}, {8,  - 15, 9,  - 8, 9, 7, 8, 15,  - 10, 14,  - 10,  - 14}, {9,  - 15, 9, 14,  - 9, 14,  - 9,  - 15}, }
e.temp1 = {1, 4, 5, 6};
e.temp2 = {1, 3, 4, 6};
e.temp3 = {1, 4, 5, 7};
e.temp4 = {1, 4, 5, 8};
e.temp5 = {1, 2, 3, 4};
e.polygonCorners = {e.temp1, e.temp2, e.temp1, e.temp3, e.temp1, e.temp1, e.temp1, e.temp4, e.temp4, e.temp1, e.temp1, e.temp5, }
e.temp1 = nil;
e.temp2 = nil;
e.temp3 = nil;
e.temp4 = nil;
e.temp5 = nil;
e.catcherPolygon = {49,  - 7, 51,  - 9, 73, 8, 51, 32,  - 51, 32,  - 74, 8,  - 51,  - 9,  - 49,  - 7,  - 49, 31, 49, 31};
e.ranks = {5, 4, 6, 5, 8, 6, 9, 7, 10, 8, 16, 9, 20, 10, }
e.polyTable = {};
e.dropInfo = {};
e.curvedBrick = {
	[0] = 12;
	[10] = 1;
	[20] = 2;
	[30] = 3;
	[40] = 4;
	[60] = 5;
	[80] = 6;
	[100] = 7;
	[120] = 8;
	[140] = 9;
	[160] = 10;
	[180] = 11;
}
e.starColors = {1, .3, .3, .3, 1, .3, .3, .3, 1, 1, 1, .3, 1, .3, 1, .3, 1, 1, 1, 1, 1, };
e.stats = {0, 0, 0, 0, 0, 0, 0};
e.oldUsers = {};
local b = {0, 5, 0, 0, 5, 0, 1, 2, 0, 1, 5, 0, 1, 3, 0, 2, 5, 0, 2, 5, 0, 3, 5, 0, 3, 5, 0, 4, 1, 8, 4, 1, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
e.commands = {"di", "dr", "dd", "da", "db", "df", "dc", "ping", "pong", "ccs", "csu", "csn", "cqr", "cqa", "cgc", "cnc", "cdn", "cdh", "cgs", "plg", "pls", "plp", "cxl", };
e.sounds = {"applause.ogg", "blank.ogg", "ball_add.ogg", "blank.ogg", "cannonshot.ogg", "coin_spin.ogg", "coin_freeball_denied.ogg", "extraball.ogg", "extraball2.ogg", "extraball3.ogg", "extremefever2.ogg", "feverhit.ogg", "blank.ogg", "fireworks2.ogg", "gapbonus1.ogg", "gong.ogg", "odetojoy.ogg", "peghit", "pegpop.ogg", "blank.ogg", "aah.ogg", "powerup_guide.ogg", "powerup_spaceblast.ogg", "rainbow.ogg", "scorecounter.ogg", "sigh.ogg", "timpaniroll.ogg", "xbump_mod2.ogg", "aah.ogg", };
e.SOUND_APPLAUSE = 1;
e.SOUND_AWARD = 2;
e.SOUND_BALL_ADD = 3;
e.SOUND_BUCKET_HIT = 4;
e.SOUND_BUCKET_BALL = 29;
e.SOUND_BUMPER = 28;
e.SOUND_COIN_SPIN = 6;
e.SOUND_COIN_DENIED = 7;
e.SOUND_EXTRABALL1 = 8;
e.SOUND_EXTRABALL2 = 9;
e.SOUND_EXTRABALL3 = 10;
e.SOUND_FEVER = 11;
e.SOUND_FEVER_HIT = 12;
e.SOUND_FIREWORK_POP = 13;
e.SOUND_FIREWORKS_START = 14;
e.SOUND_GAP_BONUS = 15;
e.SOUND_GONG = 16;
e.SOUND_ODETOJOY = 17;
e.SOUND_PEG_HIT = 18;
e.SOUND_PEG_POP = 19;
e.SOUND_PEG_SPARK = 20;
e.SOUND_POWERUP = 21;
e.SOUND_POWERUP_GUIDE = 22;
e.SOUND_POWERUP_BLAST = 23;
e.SOUND_RAINBOW = 24;
e.SOUND_SCORECOUNTER = 25;
e.SOUND_SHOT = 5;
e.SOUND_SIGH = 26;
e.SOUND_TIMPANI = 27;
e.channels = {"GUILD", "PARTY", "RAID"};
e.sentList = {};
e.onlineList = {};
e.offlineList = {};
e.currentView = {0, 0, 0, 0, 0, 0, {}, {}};
e.newInfo = {"id", "names", "namesWithoutChallenge", "creator", "note", "new", "elapsed", "ended", "removed", "played", "peggleLoot", "peggleLootNames", "peggleLootActive", "dirty"};
e.days = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
e.filterText = string.gsub(ERR_CHAT_PLAYER_NOT_FOUND_S, "%%s", "(.+)");
local se = 260;
local be = -248;
local Ee = .68;
local N = 270;
local ue = 270;
local Te = 1;
local st = (333 + 167);
local Je = (9 + 1) * (8 + 2);
local rt = 6 + 4;
local ct = 3 + 7;
local M = 1;
local a = 2;
local m = 3;
local le = 4;
e.ANI_NONE = 0;
e.ANI_LINE = 1;
e.ANI_CIRCLE = 2;
e.ANI_ROTATOR = 3;
e.ANI_LINE_ROTATOR = 4;
e.ANI_CIRCLE_ROT = 5;
config.ANI_CIRCLE_ROT_ID = 5;
local dt = 0;
local Xe = 1;
local nt = 2;
local me = 0;
local tt = 1;
local J = 1;
local Re = 1;
local G = 0;
local R = 0;
local X = 0;
local x = 0;
local re = 0;
local w = 0;
local je = 0;
local we = 0;
local he = 0;
local pe = 0;
local ge = 0;
local We = 0;
local te = 0;
local ye = "data";
local K = 0;
local oe = me;
local ne = nil;
local Ce = nil;
local Le = 0;
local De = 0;
local Pe;
local g
local v = 10;
local ae = 4;
local ze = 9;
local Ye = {};
local Qe = "";
local ee = 1;
local de = true;
local Q = false;
local Ie;
local y = {};
local l = {};
local Y;
local V;
PeggleForeverData = {};
PeggleForeverData.newData = {};
PeggleForeverData.newData = {["levelScores"] = {}, ["heroTalents"] = {}}
PeggleForeverData.settings = {
	mouseOnTrans = 1,
	mouseOffTrans = .6,
	showMinimapIcon = true,
	openFlightStart = false,
	openDeath = false,
	openLogIn = false,
	openDuel = true,
	closeFlightEnd = false,
	closeReadyCheck = true,
	closeCombat = true,
	closeDuelComplete = false,
	closePeggleLoot = false,
	highFPS = false,
	inviteChat = true,
	inviteRaid = false,
	inviteMinimap = true,
	inviteDecline = false,
	hideOutdated = false;
	soundVolume = 0,
	defaultPublish = "GUILD",
};
PeggleForeverData.version = e.versionID;
PeggleForeverData.recent = {};
PeggleForeverData.fresh = true; -- defaults; a saved file replaces the whole table
PeggleForeverProfile = {};
PeggleForeverProfile.fresh = true;
PeggleForeverProfile.challenges = {};
PeggleForeverProfile.version = e.versionID;
PeggleForeverProfile.lastDuels = {};
PeggleForeverProfile.levelTracking = {};
PeggleForeverProfile.duelTracking = {};
function o.MinuteDifference(h, u, S, a, i)
	local t, l, c, r = config.GetCompatDate()
	local d, s = GetGameTime();
	local n = 0;
	if(r - i > 1)then
		n = 525600;
	elseif(r - i >= 1)and(12 - a + l >= 12)then
		n = 525600;
	else
		local o, t
		local o = 0;
		if(a < l)then
			for n = a, l - 1 do
				t = e.days[n];
				if(n == 2)and(f(i, 4) == 0)then
					t = t + 1;
				end
				o = o + t;
			end
		elseif(a > l)then
			for n = a, 12 do
				t = e.days[n];
				if(n == 2)and(f(i, 4) == 0)then
					t = t + 1;
				end
				o = o + t;
			end
			for n = 1, l - 1 do
				t = e.days[n];
				if(n == 2)and(f(r, 4) == 0)then
					t = t + 1;
				end
				o = o + t;
			end
		end
		o = o - S + c;
		n = o * 24;
		n = n - h + d;
		n = n * 60;
		n = n - u + s;
	end
	return n
end
function o.TimeBreakdown(e)
	local t;
	t = i(e / 60);
	e = e - (t * 60);
	return t, e;
end
function o.TableFind(n, o)
	local t, e;
	for e = 1, #n do
		-- some names have their realm name appended and some don't
		-- so peggle would not find a specific names in Battle mode
		-- I don't know what else this function is used for, so check for a hyphen
		-- this hack can be buggy for players with the same name but different realm
		-- or players with a partial name match
		if strfind(n[e], "-") or strfind(o, "-") then
			local name = strmatch(o, "(.+)%-") or o
			if strfind(n[e], name) then
				t = e;
				break;
			end
		else
			if(n[e] == o)then
				t = e;
				break;
			end
		end
	end
	return t
end
function o.TableRemove(t, o)
	local e, e;
	local n = #t;
	local e = 1;
	for n = 1, n do
		if(t[e] == o)then
			u(t, e);
		else
			e = e + 1;
		end
	end
end
function o.TableInsertOnce(e, n, l)
	local o, t
	local o = #e;
	for o = 1, o do
		if(e[o] == n)then
			t = true;
		end
	end
	if not t then
		s(e, n);
		if l then
			table.sort(e)
		end
	end
	return not t;
end
function o.TablePack(e, ...)
	local t;
	for t = 1, select('#', ...)do
		s(e, (select(t, ...)));
	end
end
local function P(e)
	local e = string.gsub(e, "(%d)(%d%d%d)$", "%1,%2")
	local t
	while true do
		e, t = string.gsub(e, "(%d)(%d%d%d),", "%1,%2,")
		if t == 0 then
			break
		end
	end
	return e
end
local function E(n)
	-- the Peggle power-up blast is not played over a hero's own ability sound (same moment = within .5s)
	if(n == e.SOUND_POWERUP_BLAST or n == e.SOUND_POWERUP_GUIDE)and config.heroSoundAt and(GetTime() - config.heroSoundAt < .5)then
		return;
	end
	if(t.soundButton.off ~= 1)then
		local t = "";
		if(PeggleForeverData.settings.soundVolume == 1)then
			t = "q_";
		end
		if(type(n) == "number")then
			PlaySoundFile(e.soundPath..t..e.sounds[n]);
		else
			PlaySoundFile(e.soundPath..t..n);
		end
	end
end
do
	local setPortrait = config.SetPortrait;
	config.SetPortrait = function(tex, hero, zoom, plain, modelSize, asTexture)
		return setPortrait(tex, hero, zoom, plain or PeggleForeverData.settings.plainPortraits, modelSize, asTexture);
	end
end
-- Hero sounds are game-client sound IDs, so they follow the Sounds option: Normal plays on the SFX
-- channel (optionally boosted per hero), Quiet plays once on the Ambience channel (your Ambience volume
-- slider applies), Off or the sound button mutes them. /peggle boost <hero> <1-3> repeats a quiet sound.
config.SoundMode = function()
	if(t.soundButton.off == 1)or(PeggleForeverData.settings.soundVolume == 2)then
		return nil;
	end
	return (PeggleForeverData.settings.soundVolume == 1) and "quiet" or "normal";
end
-- A sound spec is a SoundKit ID (number, played with PlaySound), a file path, "file:<id>" / "kit:<id>",
-- or a list of specs (one is picked at random each time).
config.PlaySpec = function(spec, channel)
	if type(spec) == "table" then
		spec = spec[math.random(#spec)];
	end
	if type(spec) == "number" then
		PlaySound(spec, channel);
	elseif type(spec) == "string" then
		local kind, value = string.match(spec, "^(%a+):(%d+)$");
		if kind == "kit" then
			PlaySound(tonumber(value), channel);
		elseif kind == "file" then
			PlaySoundFile(tonumber(value), channel);
		else
			PlaySoundFile(spec, channel);
		end
	end
end
-- The sound for a hero: a saved override (/peggle snd use|add, /peggle setsound), else for the voice all of
-- the hero's real greetings from SoundList.lua (one at random), else the default in Heroes.lua.
config.HeroSoundSpec = function(hero, kind)
	local over = PeggleForeverData.settings.soundOverrides;
	over = over and over[hero.id] and over[hero.id][kind];
	if over and(type(over) ~= "table" or #over > 0)then
		return over;
	end
	if kind == "voice" and config.soundList and config.soundList[hero.id] then
		-- hand-picked lines (Bolvar has no greetings) first, then greetings, original-era ones preferred
		-- (newer expansions' files are named vo_<patch>_...)
		for _, cat in ipairs({"pick", "greet", "shout"})do
			local pool, newer = {}, {};
			for _, entry in ipairs(config.soundList[hero.id].voice) do
				if entry[2] == cat then
					local list = (cat == "greet" and string.match(entry[3], "^vo_")) and newer or pool;
					list[#list + 1] = "file:"..entry[1];
				end
			end
			if #pool > 0 or #newer > 0 then
				return (#pool > 0) and pool or newer;
			end
		end
	end
	return hero[kind.."Kit"] or hero[kind];
end
config.SpecText = function(spec)
	if type(spec) == "table" then
		return table.concat(spec, " / ");
	end
	return tostring(spec);
end
config.PlayHeroSound = function()
	local hero = config.GetHero(config.activeHero);
	local mode = config.SoundMode();
	if not(hero and mode)then
		return;
	end
	local spec = config.HeroSoundSpec(hero, "sound");
	if not spec then
		return;
	end
	local copies = 1;
	if(mode == "normal")then
		local boost = PeggleForeverData.settings.soundBoost;
		copies = (boost and boost[hero.id]) or 1;
	end
	for i = 1, copies do
		config.PlaySpec(spec, (mode == "quiet") and "Ambience" or "SFX");
	end
	config.heroSoundAt = GetTime();
	return true;
end
-- The hero's voice line (on choosing the hero and when a level starts, at most once every 15 seconds).
config.PlayHeroVoice = function(force)
	local hero = config.GetHero(config.activeHero);
	local mode = config.SoundMode();
	if not(hero and mode)then
		return;
	end
	local spec = config.HeroSoundSpec(hero, "voice");
	if not spec then
		return;
	end
	local now = GetTime();
	if not force and config.lastVoice and(now - config.lastVoice < 15)then
		return;
	end
	config.lastVoice = now;
	config.PlaySpec(spec, (mode == "quiet") and "Ambience" or "Dialog");
end
-- /peggle sounds: plays every hero's ability sound then voice line so they can be checked by ear.
config.TestSounds = function()
	local mode = config.SoundMode();
	if not mode then
		print("Peggle Forever: sounds are off.");
		return;
	end
	local when = 0;
	for _, hero in ipairs(config.heroes) do
		local first = hero;
		C_Timer.After(when, function()
			print("Peggle Forever sound test: "..first.name.." ability: "..config.SpecText(config.HeroSoundSpec(first, "sound")));
			config.PlaySpec(config.HeroSoundSpec(first, "sound"), (mode == "quiet") and "Ambience" or "SFX");
		end);
		C_Timer.After(when + 2.5, function()
			print("   "..first.name.." voice: "..config.SpecText(config.HeroSoundSpec(first, "voice")));
			config.PlaySpec(config.HeroSoundSpec(first, "voice"), (mode == "quiet") and "Ambience" or "Dialog");
		end);
		when = when + 7;
	end
end
-- /peggle snd: a sound auditioner.
--   hero <1-8> [voice|ability]  steps through that hero's real lines / spell sounds from SoundList.lua
--   n | p | r | +N | -N          next / previous / repeat / jump (in the hero list, or SoundKit IDs otherwise)
--   <id> | file <id>             play a SoundKit ID / a FileDataID (leaves the hero list)
--   run [from to] [secs]         auto-play the hero list (or a SoundKit range); stop halts it
--   use [voice|ability] [hero]   make the sound last played the hero's only one (saved)
--   add [voice|ability] [hero]   add it to the hero's pool (one is picked at random each time)
--   reset [voice|ability] [hero] | list
config.snd = {cur = 0, run = 0};
-- The full voice/ability list (every line found, with its words) is kept as text in SoundList.lua and only
-- turned into tables the first time /peggle snd needs it; the game itself only uses config.soundList.
config.SoundListFull = function()
	if not config.soundListFull and config.soundListSource then
		local chunk = loadstring("return "..config.soundListSource);
		config.soundListFull = chunk and chunk() or config.soundList;
		config.soundListSource = nil;
	end
	return config.soundListFull or config.soundList;
end
config.SndPlay = function()
	local st = config.snd;
	if st.list then
		local entry = st.list[st.pos];
		local ok = PlaySoundFile(entry[1], "Master");
		st.last = "file:"..entry[1];
		print("Peggle Forever snd: "..(config.heroes[st.hero].short or config.heroes[st.hero].name).." "..((st.kind == "sound") and "ability" or "voice").." "..st.pos.."/"..#st.list.."  ["..entry[2].."] "..entry[3].."  (file "..entry[1]..")"..(ok and "" or "  (nothing played)"));
		if entry[4] then
			print("   |cFFFFFFAA\""..entry[4].."\"|r");
		end
	elseif st.file then
		local ok = PlaySoundFile(st.file, "Master");
		st.last = "file:"..st.file;
		print("Peggle Forever snd: file "..st.file..(ok and "" or "  (nothing played)"));
	else
		local ok = PlaySound(st.cur, "Master");
		st.last = "kit:"..st.cur;
		print("Peggle Forever snd: kit "..st.cur..(ok and "" or "  (nothing played)"));
	end
end
-- "[voice|ability] [hero]" with the hero list's kind and hero as defaults
config.SndTarget = function(rest)
	local st = config.snd;
	local kind, hero = string.match(rest, "^(%a*)%s*(%d*)$");
	if kind == "ability" or kind == "sound" then
		kind = "sound";
	elseif kind == "voice" then
		kind = "voice";
	else
		kind = st.list and st.kind;
	end
	hero = tonumber(hero) or (st.list and st.hero);
	if kind and hero and config.heroes[hero] then
		return kind, hero;
	end
end
config.SndCommand = function(o)
	local st = config.snd;
	o = string.lower(o or "");
	local word, rest = string.match(o, "^(%S*)%s*(.*)$");
	if word == "stop" then
		st.run = st.run + 1;
		print("Peggle Forever snd: stopped.");
	elseif word == "hero" then
		local id, kind = string.match(rest, "^(%d+)%s*(%a*)$");
		id = tonumber(id);
		kind = (kind == "ability" or kind == "sound") and "sound" or "voice";
		local full = config.SoundListFull();
		local lists = full and id and full[id];
		if not(lists and #lists[kind] > 0)then
			print("Usage: /peggle snd hero <1-8> [voice|ability]");
			return;
		end
		st.run = st.run + 1;
		st.list, st.pos, st.hero, st.kind = lists[kind], 1, id, kind;
		local counts, order = {}, {};
		for _, entry in ipairs(st.list) do
			if not counts[entry[2]] then
				order[#order + 1] = entry[2];
			end
			counts[entry[2]] = (counts[entry[2]] or 0) + 1;
		end
		for i, cat in ipairs(order) do
			order[i] = cat.." "..counts[cat];
		end
		print("Peggle Forever snd: "..config.heroes[id].name.." "..((kind == "sound") and "ability sounds" or "voice lines")..": "..table.concat(order, ", ")..".  n / p to step, use or add to keep one.");
		config.SndPlay();
	elseif word == "run" then
		local from, to, secs = string.match(rest, "^(%d+)%s+(%d+)%s*([%d%.]*)$");
		from, to = tonumber(from), tonumber(to);
		secs = tonumber(secs) or tonumber(rest) or (st.list and 4) or 2.5;
		if not(from and to)and not st.list then
			print("Usage: /peggle snd run <from> <to> [seconds per sound]   (/peggle snd stop to halt)");
			return;
		end
		if from then
			st.list, st.file = nil, nil;
		end
		st.run = st.run + 1;
		local token = st.run;
		local function step()
			if token ~= st.run then
				return;
			end
			if st.list then
				config.SndPlay();
				if st.pos >= #st.list then
					return;
				end
				st.pos = st.pos + 1;
			else
				if from > to then
					return;
				end
				st.cur = from;
				config.SndPlay();
				from = from + 1;
			end
			C_Timer.After(secs, step);
		end
		step();
	elseif word == "use" or word == "add" or word == "reset" then
		local kind, hero = config.SndTarget(rest);
		if not kind then
			print("Usage: /peggle snd "..word.." <voice|ability> <hero 1-8>   (inside a hero list both can be left out)");
			return;
		end
		local over = PeggleForeverData.settings.soundOverrides or {};
		PeggleForeverData.settings.soundOverrides = over;
		over[hero] = over[hero] or {};
		local name = config.heroes[hero].name.." "..((kind == "sound") and "ability" or "voice");
		if word == "reset" then
			over[hero][kind] = nil;
			print("Peggle Forever snd: "..name.." back to the default.");
		elseif not st.last then
			print("Peggle Forever snd: play a sound first.");
		elseif word == "use" then
			over[hero][kind] = st.last;
			print("Peggle Forever snd: "..name.." = "..st.last.." (saved)");
		else
			local pool = over[hero][kind];
			if type(pool) ~= "table" then
				pool = {};
				over[hero][kind] = pool;
			end
			for _, spec in ipairs(pool) do
				if spec == st.last then
					print("Peggle Forever snd: already in the pool.");
					return;
				end
			end
			pool[#pool + 1] = st.last;
			print("Peggle Forever snd: added "..st.last.." to "..name.." ("..#pool.." in the pool, saved)");
		end
	elseif word == "list" then
		for id, hero in ipairs(config.heroes) do
			print(id.." "..hero.name..":  ability "..config.SpecText(config.HeroSoundSpec(hero, "sound"))..",  voice "..config.SpecText(config.HeroSoundSpec(hero, "voice")));
		end
	elseif word == "file" and tonumber(rest) then
		st.run = st.run + 1;
		st.list, st.file = nil, tonumber(rest);
		config.SndPlay();
	elseif word == "n" or word == "p" or word == "r" or word == "" or string.match(word, "^[%+%-]%d+$") then
		st.run = st.run + 1;
		local step = (word == "n" and 1) or (word == "p" and - 1) or tonumber(word) or 0;
		if st.list then
			st.pos = math.max(1, math.min(#st.list, st.pos + step));
		elseif st.file then
			st.file = math.max(1, st.file + step);
		elseif st.cur == 0 and step == 0 then
			return;
		else
			st.cur = math.max(1, st.cur + step);
		end
		config.SndPlay();
	elseif tonumber(word) then
		st.run = st.run + 1;
		st.list, st.file = nil, nil;
		st.cur = tonumber(word);
		config.SndPlay();
	else
		print("/peggle snd hero <1-8> [voice|ability] | n | p | r | +N | -N | <kit id> | file <id> | run | stop | use | add | reset | list");
	end
end
local function Oe(e)
	e.animated = nil;
	if(e.isPeg)then
		s(d.pegQueue, e);
	else
		s(d.brickQueue, e);
	end
end
local function Ze(o, t)
	local t = t or e.polygon[e.curvedBrick[o.radius]];
	local n, l, a
	local r = k(T(o.rotation - 135));
	local i = I(T(o.rotation - 135));
	for n = 1, #t, 2 do
		l = r * t[n] - i * t[n + 1];
		a = i * t[n] + r * t[n + 1];
		e.polyTable[n] = l + o.x
		e.polyTable[n + 1] = a + o.y
	end
	e.polyTable[#t + 1] = nil;
	return#t;
end
local function S(n, l)
	local t = 0;
	local o, e;
	local o = #n - 1;
	for l = 1, #n do
		e = W(n, l);
		if(e >= 96)then
			e = e - 96;
		else
			e = e - (48 - 27)
		end
		t = t + (e * (70 ^ (o)));
		o = o - 1;
	end
	if(l == true)then
		t = t - i((70 ^ #n) / 2);
	end
	return t;
end
local function Fe(o)
	local t = GetTime();
	local t, l;
	local block = 1;
	local level = o;
	ee = o;
	B = {};
	while(block <= #LEVELS[level])do
		t = {};
		t.animationType = LEVELS[level][block][levelDataIndex.animationType];
		t.objectType = LEVELS[level][block][levelDataIndex.objectType];
		t.x = LEVELS[level][block][levelDataIndex.x]
		t.y = LEVELS[level][block][levelDataIndex.y]
		if(t.objectType == Xe) or (t.objectType == nt)then
			l = LEVELS[level][block][levelDataIndex.rotation];
			t.radius = i(l / 1e3) - 100;
			t.rotation = l - ((t.radius + 100) * 1e3);
		else
			t.radius = 60;
			t.rotation = 0;
		end
		if(t.animationType ~= e.ANI_NONE)then
			t.time = LEVELS[level][block][levelDataIndex.animationTime];
			l = LEVELS[level][block][levelDataIndex.animationDelay];
			local e = f(l, 10);
			if(e > 1)then
				t.reverser = true;
			end
			if(e == 1)or(e == 3)then
				t.active = true;
			end
			t.timeOffset = (l - e) / 10 / 4;
			t.value1 = LEVELS[level][block][levelDataIndex.animValue1];
			t.value2 = LEVELS[level][block][levelDataIndex.animValue2];
			t.value3 = LEVELS[level][block][levelDataIndex.animValue3];
			t.value4 = LEVELS[level][block][levelDataIndex.animValue4];
		else
			t.animationType = 0;
			t.value1 = 0;
			t.value2 = 0;
			t.value3 = 0;
			t.value4 = 0;
			t.reverser = true;
			t.active = true;
			t.time = 1;
			t.timeOffset = 0;
		end
		block = block + 1
		s(B, t);
	end
end
local function h(t, o, l)
	local n;
	local e = "";
	if(l == true)then
		t = t + i((70 ^ o) / 2);
	end
	while true do
		n = f(t, 70);
		if(n < 27)then
			e = O(96 + n)..e;
		else
			e = O(48 + (n - 27))..e;
		end
		if(t >= 70)then
			t = i(t / 70);
		else
			break;
		end
	end
	if(#e < o)then
		e = string.rep(O(96), (o - #e))..e;
	end
	return e;
end
local function p(c, e)
	local d, l, t;
	local o = e or 0;
	local n = e or 0;
	local e, a, t, i, r;
	d = #c;
	for t = 1, d do
		l = W(c, t);
		if(f(t, 2) == 0)then
			n = n + l;
		else
			o = o + l;
		end
	end
	e = f(n, 10);
	a = f(n - e, 100) / 10;
	t = f(o, 10);
	i = f(o - t, 100) / 10;
	r = f(e + a + t + i, 10);
	return e, a, t, i, r
end
local function U(e, t)
	local t = t or 0;
	local a, o, n, l, t = p(e, t);
	return h(1e5 + t * 1e4 + l * 1e3 + n * 100 + o * 10 + a, 3)..e;
end
local function L(e, t)
	if(type(e) ~= "string")or(#e < 4)then
		return;
	end
	local s = c(e, 1, 3);
	local n = c(e, 4);
	t = t or 0;
	local h, u, f, d, r = p(n, t);
	local i, a, t, o, l;
	local e = D(S(s));

	i = A(c(e, 6, 6));
	a = A(c(e, 5, 5));
	t = A(c(e, 4, 4));
	o = A(c(e, 3, 3));
	l = A(c(e, 2, 2));

	if((i == h)and(a == u)and(t == f)and(o == d)and(l == r))then
		return n;
	end
end
local function p(t)
	t = string.match(t, "(.*)%-(.*)") or t
	local n, e = 0, 0;
	for n = 1, #t do
		e = e + W(t, n);
	end
	return e;
end
local function _e()
	local n = 0;
	local e, o = 0, 0;
	local scores = PeggleForeverData.newData.levelScores
	local i;
	for i = 1, #scores do
		if(scores[i].progress == 2)then
			e = e + 1;
			n = n + 1;
		end

		if(scores[i].progress == 3)then
			e = e + 1;
			o = o + 1;
			n = n + 2;
		end
	end
	return n, e, o;
end
local function et()
	-- The shared Legacy tree's ranks live in b[34..44] because the original talent effects read them there.
	-- The hero tree's ranks are read through config.Mod.
	local total = 0;
	local ranks = config.LegacyTalents();
	for slot = 1, config.LEGACY_SLOTS do
		-- duels switch every talent off (config.talentsOff), so both players play with the same kit
		b[33 + slot] = config.talentsOff and 0 or (ranks[slot] or 0);
		total = total + (ranks[slot] or 0);
	end
	return total;
end
config.TreePoints = function(kind)
	local ranks, slots, earned;
	if(kind == "legacy")then
		ranks, slots, earned = config.LegacyTalents(), config.LEGACY_SLOTS, config.AccountPoints();
	else
		ranks, slots, earned = config.ActiveTalents(), config.TALENT_SLOTS, config.HeroPoints(config.activeHero);
	end
	local spent = 0;
	for i = 1, slots do
		spent = spent + (ranks[i] or 0) * config.TierCost(config.TREE_DEFS[i][1]);
	end
	return earned, spent;
end
local function Ge(kind)
	kind = kind or config.treeKind or "hero";
	et();
	local heroEarned, heroSpent = config.TreePoints("hero");
	local legacyEarned, legacySpent = config.TreePoints("legacy");
	if(heroEarned > heroSpent)or(legacyEarned > legacySpent)then
		t.sparks:Show();
	else
		t.sparks:Hide();
	end
	local earned, spent = config.TreePoints(kind);
	return earned - spent, spent, earned;
end
local function Ue(kind, slot)
	local ranks = (kind == "legacy") and config.LegacyTalents() or config.ActiveTalents();
	local def = config.TREE_DEFS[slot];
	return ranks[slot] or 0, def[2], def[1], def[3];
end
local function Ve()
	local frame = t.catagoryScreen.frames[4];
	if not frame.tree or not frame.tree.legacyNode then
		return;
	end
	if config.RefreshHeroHeader then
		config.RefreshHeroHeader();
	end
	local current = config.treeKind or "hero";
	local currentLeft = Ge(current);
	if(current == "legacy")then
		frame.pointsLeft:SetText("Legacy points left: |cFFFFFFFF"..currentLeft);
	else
		frame.pointsLeft:SetText(e.locale["_POINTS_LEFT"]..": |cFFFFFFFF"..currentLeft);
	end
	local sets = {hero = frame.tree.node, legacy = frame.tree.legacyNode};
	for kind, nodes in pairs(sets) do
		local left, spent = Ge(kind);
		for slot = 1, #nodes do
			local rank, max, tier, prereq = Ue(kind, slot);
			local node = nodes[slot];
			local _, _, iconPath = config.TalentInfo(kind, slot);
			node.icon:SetTexture(iconPath);
			node.rank:SetText(rank);
			local cr, cg, cb;
			if(rank == max)then
				cr, cg, cb = 1, .82, 0;
			elseif(spent >= tier * 5)then
				cr, cg, cb = 0, 1, 0;
			else
				cr, cg, cb = .5, .5, .5;
			end
			if(prereq > 0)then
				local prank, pmax = Ue(kind, prereq);
				if(prank >= pmax)and(((spent >= tier * 5)and(left >= config.TierCost(tier)))or(rank > 0))then
					nodes[prereq].arrowDown:SetTexCoord(unpack(TALENT_BRANCH_TEXTURECOORDS.down[1]));
					node.arrowTop:SetTexCoord(unpack(TALENT_ARROW_TEXTURECOORDS.top[1]));
				else
					cr, cg, cb = .5, .5, .5;
					nodes[prereq].arrowDown:SetTexCoord(unpack(TALENT_BRANCH_TEXTURECOORDS.down[ - 1]));
					node.arrowTop:SetTexCoord(unpack(TALENT_ARROW_TEXTURECOORDS.top[ - 1]));
				end
			end
			if(left < config.TierCost(tier))and(rank == 0)then
				cr, cg, cb = .5, .5, .5;
			end
			if(cr == .5)then
				SetDesaturation(node.icon, true);
				node.rank:Hide();
				node.border:SetVertexColor(cr, cg, cb);
			else
				SetDesaturation(node.icon, false);
				node.rank:Show();
				node.rank:SetVertexColor(cr, cg, cb);
				node.border:SetVertexColor(cr, cg, cb);
			end
		end
	end
end
local function xt(button)
	local kind = button.kind or "hero";
	if(kind == "hero")and not config.activeHero then
		t.charScreen:Show();
		return;
	end
	local left, spent = Ge(kind);
	local slot = button:GetID();
	local rank, max, tier, prereq = Ue(kind, slot);
	local cost = config.TierCost(tier);
	if(left >= cost)then
		if(spent >= tier * 5)and(rank < max)then
			local allowed = true;
			if(prereq > 0)then
				local prank, pmax = Ue(kind, prereq);
				allowed = (prank >= pmax);
			end
			if allowed then
				local ranks = (kind == "legacy") and config.LegacyTalents() or config.ActiveTalents();
				ranks[slot] = rank + 1;
				et();
				Ve();
				button:GetScript("OnEnter")(button);
			end
		end
	end
end
local function ot(t, r)
	local l, o, a;
	local n, i, d, d;
	if(r)then
		local e = S(c(t, 1, 2)) - 1;
		n = e;
		i = S(c(t, 3));
	else
		_, l, o = _e();
		a = h(l + ((oe * 20 + 10 + o) * 100) + 1, 2);
		n = U(a..h(t, 4), p(e.name));
	end
	return n, i;
end
local function lt(l, n, o)
	local d
	if(l)then
		local r;
		if(o ~= 0)then
			local l = PeggleForeverData.newData.levelScores[n]['progress'];
			if(l == 0)then
				r = true;
			end
			if(l < o)then
				PeggleForeverData.newData.levelScores[n]['progress'] = o
				levelScoreData[n + #LEVELS] = o
			end
		end
		local i = PeggleForeverData.newData.levelScores[n]['score'];
		if(l > i)or(r)then
			PeggleForeverData.newData.levelScores[n]['score'] = l
			levelScoreData[n] = l;
		end
		if(t.duelStatus == 3)then
			local n = t.catagoryScreen.frames[2];
			local o, l, a = _e();
			local o = h(l + ((oe * 20 + 10 + a) * 100) + 1, 2)
			o = o..h(w, 4)..h(e.stats[4], 4)..h(e.stats[5], 4)..h(e.stats[6], 4);
			local o = U(o, p(e.name));
			n.player1.value1 = e.stats[4];
			n.player1.value2 = e.stats[6];
			n.player1.value3 = e.stats[5];
			n.player1.value4 = oe + 1;
			n.player1.value5 = l;
			n.player1.value6 = a;
			n.player1.value = w;
			config.SendAddonMessage(t.network.prefix, e.commands[6].."+"..o, "WHISPER", n.name2:GetText());
			n:UpdateWinners();
			if(PeggleForeverData.settings.closeDuelChallenge == true)then
				t.duelStatus = nil;
				t:Hide();
			end
		end
	end
	return d;
end
local function Me(i, n)
	local n = n or e.extraInfo;
	local l = L(n[g], p(n.creator));
	local a;
	local o = o.TableFind(n.names, e.name);
	if(o)then
		if(l)then
			if(i)then
				n.played = true;
				n.new = nil;
				a = ot(i);
				l = U((c(l, 1, 68 + (o - 1) * 6)..c(a, 4)..c(l, 69 + o * 6)), p(n.creator));
				n[g] = l;
			else
				a = c(l, 69 + (o - 1) * 6, 68 + o * 6)
			end
			if(n.serverName)then
				config.SendAddonMessage(t.network.prefix, e.commands[19].."+"..n.id.."+"..a, "WHISPER", n.serverName);
			end
		else
			print(e.locale["_PEGGLE_ISSUE1"]);
		end
	end
end
local function ke(t, n)
	local t = i(t / e.sectionXSize) + 1;
	local n = i(n / e.sectionYSize) + 1;
	if(t < 1)or(t > e.boardXYSections)then
		t, n = nil, nil;
	elseif(n < 1)or(n > e.boardXYSections)then
		t, n = nil, nil;
	end
	return t, n;
end
local function Ne(n, e, t)
	if not e then
		e, t = ke(n.x, n.y)
	end
	if(e == nil)then
		return
	end
	local o;
	for o = 1, #y[t][e]do
		if(n == y[t][e][o])then
			return;
		end
	end
	s(y[t][e], n);
end
local function ve(n, e, t)
	if not e then
		e, t = ke(n.x, n.y)
	end
	if not e then
		return;
	end
	local o;
	for o = 1, #y[t][e]do
		if(n == y[t][e][o])then
			u(y[t][e], o);
			return;
		end
	end
end
local function He(e)
	local t
	if(e.reverser)then
		t = 1 - (k(2 * math.pi * e.elapsed / e.loopTime) + 1) / 2;
	else
		t = e.elapsed / e.loopTime;
	end
	local n;
	local o;
	if(e.value4)and(e.value4 > 0)then
		n = e.value4 *  - k(T(e.value3));
		o = e.value4 *  - I(T(e.value3));
	else
		n = e.startX - e.value1;
		o = e.startY - e.value2;
	end
	e.x = e.startX - t * n;
	e.y = e.startY - t * o;
end
local function at(e)
	local n = k(T(360 * e.elapsed / e.loopTime)) * (e.value1 + (20 - 3) / 2) * .85;
	local t = I(T(360 * e.elapsed / e.loopTime)) * (e.value2 + (20 - 3) / 2) * .85;
	-- value3 tilts the ellipse (degrees); the original circle levels leave it at 0
	local tilt = T(e.value3 or 0);
	if(tilt ~= 0)then
		n, t = n * k(tilt) - t * I(tilt), n * I(tilt) + t * k(tilt);
	end
	e.x = e.startX + n;
	e.y = e.startY + t;
end
local function Ae(e)
	if(e.isBrick == true)then
		-- value4 keeps a brick's own angle relative to its orbit (rings imported from the desktop game)
		local delta = (e.moveType == config.ANI_CIRCLE_ROT_ID) and (e.value4 or 0) or 0;
		e.rotation = f(e.elapsed / e.loopTime * 360 + 135 + delta, 360);
		d:RotateTexture(e.texture, i(e.rotation), .5, .5)
	end
end
local function bt(o, t, n)
	if(t.moveType > 0)then
		t.elapsed = t.elapsed + n;
		if(t.elapsed > t.loopTime)then
			t.elapsed = f(t.elapsed, t.loopTime);
		end
		local n, l = ke(t.x, t.y);
		if(t.moveType == e.ANI_LINE)then
			He(t);
		elseif(t.moveType == e.ANI_CIRCLE)then
			at(t);
		elseif(t.moveType == e.ANI_ROTATOR)then
			Ae(t);
		elseif(t.moveType == e.ANI_LINE_ROTATOR)then
			He(t);
			Ae(t);
		elseif(t.moveType == e.ANI_CIRCLE_ROT)then
			at(t);
			Ae(t);
		end
		local o, e = ke(t.x, t.y);
		if(o ~= n)or(e ~= l)then
			if(n)then
				ve(t, n, l);
			end
			Ne(t, o, e);
		end
		t:SetPoint("Center", r, "Bottomleft", t.x, t.y);
		if t.inactive then
			t.moveType = 0;
			t.inactive = nil;
		end
	end
end
local function Et(o, n)
	if(n == "RightButton")and((Q == true)or(G >= R))then
		e.speedy = true;
		return;
	end
	if(Q == false)or(t.charScreen:IsShown())or(t.summaryScreen:IsShown())or(t.gameMenu:IsShown())then
		return;
	end
	if(t.roundBalls.elapsed < 3.2)then
		t.roundBalls.elapsed = 3.2;
	end
	e.speedy = nil;
	Q = false;
	te = te - 1;
	t.ballTracker.ballDisplay:SetText(te);
	local n, o;
	n = 64 * k(T(N));
	o = 64 * I(T(N));
	n = (e.boardWidth / 2) + 1
	o = (e.boardHeight - 16) - 20
	E(e.SOUND_SHOT);
	d:SpawnBall(n, o, N, se);
	e.OnShot();
	d:SpawnParticleGen(n, o + 4, .2, .3, .005, ue - 1, ue + 1, 10, 13, 0, "spark", 1, 1, .8)
	for t = 1, 10 do
		r.trail[t]:Hide();
	end
	e.stats[1] = e.stats[1] + 1;
	config.Stats.onShot(w);
	t.shooter.ball:Hide();
	for e = 1, ce do
		getglobal("polyLine"..e):Hide();
	end
	for e = 1, q do
		getglobal("pathPiece"..e):Hide();
	end
	ne = nil;
	if(K > 0)then
		ne = true;
		K = K - 1;
		if(K == 0)then
			Te = 1;
			t.powerLabel:Hide();
		end
	end
	fe = nil;
	if(K > 0)and(oe == me)then
		fe = true;
		t.powerLabel.text:SetText(ye.." "..K);
	end
	local n = R - G;
	x = -30;
	for t = 1, #e.ranks, 2 do
		if(n >= e.ranks[t])then
			x =  - e.ranks[t + 1];
		end
	end
	re = 0;
	Ce = nil;
end
local function it()
	local o, o, o, a, n;
	local o = d.animationStack;
	local i = 0;
	local c = 0;
	roundOver = true;
	local r = "";
	a = 1;
	r = "";
	if(PeggleForeverData.settings.colorBlindMode)then
		r = "_";
	end
	for t = 1, #o do
		n = o[a];
		if(n.id == m)then
			i = i + 1;
			n.id = M;
			if(n.isPeg)then
				n.texture:SetTexCoord(0 + ((M - 1) * .25), (M * .25), 0, .5);
			else
				n.texture:SetTexture(e.artPath..e.brickTex[M].."Brick"..e.curvedBrick[n.radius]..r);
			end
		end
		if(n.hit == true)then
			if(ne == 1)and(n.id == le)and(b[33 + 10] == 1)then
				c = c + 1;
			end
			ve(n);
			Oe(u(o, a))
		else
			a = a + 1;
			if(n.required == true)then
				if(G == (R - 1))then
					d.lastPeg = n;
				end
				roundOver = false;
			end
		end
	end
	o = y;
	for t = 1, #o do
		for a = 1, #o[t]do
			for d = 1, #o[t][a]do
				n = o[t][a][d];
				if(n.id == m)then
					i = i + 1;
					n.id = M;
					if(n.isPeg)then
						n.texture:SetTexCoord(0 + ((M - 1) * .25), (M * .25), 0, .5);
					else
						n.texture:SetTexture(e.artPath..e.brickTex[M].."Brick"..e.curvedBrick[n.radius]..r);
					end
				end
				if(n.id == M)then
					s(l, n);
				end
			end
		end
	end
	for t = 1, i + c do
		if(#l > 0)then
			n = u(l, C(1, #l));
			if(t <= c)then
				n.id = le;
			else
				n.id = m;
			end
			if(n.isPeg)then
				n.texture:SetTexCoord(0 + ((n.id - 1) * .25), (n.id * .25), 0, .5);
			else
				n.texture:SetTexture(e.artPath..e.brickTex[n.id].."Brick"..e.curvedBrick[n.radius]..r);
			end
		end
	end
	table.wipe(l);
	if(roundOver == true)and(de == false)then
		recent = "r".."ec".."ent";
		de = true;
		Ie:SetText(P(w));
		V[recent][ee] = w;
		local n = 2;
		if(e.stats[3] == e.stats[7])then
			n = 3;
		end
		config.Stats.onEnd(w, true, n == 3, e.stats);
		local o = lt(w, ee, n);
		d.temp1 = o
		d.temp2 = n;
		if(e[e.newInfo[11]])then
			t.network:Send(e.commands[21], e[e.newInfo[11]].."+"..U(h(w, 4), p(e.name)), "WHISPER", e[e.newInfo[11].. 4])
			if not e[e.newInfo[12]]then
				e[e.newInfo[11]] = nil;
			end
		elseif(e.extraInfo)then
			Me(w);
		end
	end
end
local function Ae(o, h, p, T)
	Qe = o;
	e.extraInfo = h;
	de = false;
	e.speedy = nil;
	r.fineX = nil;
	r.fineY = nil;
	d.feverUp = nil;
	d.temp1 = nil;
	d.temp2 = nil;
	t.bonusBar1:Hide();
	t.bonusBar2:Hide();
	t.bonusBar3:Hide();
	t.bonusBar4:Hide();
	t.bonusBar5:Hide();
	t.catcher:Show();
	t.catcherBack:Show();
	t.catcher:SetAlpha(1);
	t.fever1:Hide();
	t.fever2:Hide();
	t.fever3:Hide();
	t.feverPegScore:Hide();
	t.rainbow:Hide();
	t.roundPegs.elapsed = nil;
	t.roundPegs:Hide();
	t.roundPegScore:Hide();
	t.roundBonusScore:Hide();
	t.roundPegs:SetAlpha(1);
	t.roundPegScore:SetAlpha(1);
	t.roundBonusScore:SetAlpha(1);
	t.powerLabel:Hide();
	t.banner:Hide();
	t.banner.tex:Hide();
	local i, i, i, n;
	local x = t.bestScore;
	for e = 1, #y do
		for t = 1, #y[e]do
			for n = 1, #y[e][t]do
				u(y[e][t], 1);
			end
		end
	end
	for e = 1, #d.animationStack do
		n = u(d.animationStack, 1);
		Oe(n);
		n:Hide();
	end
	for e = 1, #d.activeBallStack do
		n = u(d.activeBallStack, 1);
		n.animated = nil;
		s(d.ballQueue, n);
		n:Hide();
		for e = 1, 30 do
			n["trail"..e]:Hide();
		end
	end
	for e = 1, #d.activePointTextStack do
		n = u(d.activePointTextStack, 1);
		n:Hide();
		s(d.pointTextQueue, n);
	end
	for e = 1, #d.activeParticleGens do
		n = u(d.activeParticleGens, 1);
		s(d.particleGenQueue, n);
	end
	for e = 1, #d.activeParticles do
		n = u(d.activeParticles, 1);
		n:Hide();
		s(d.particleQueue, n);
	end
	for e = 1, 10 do
		r.trail[e]:Hide();
	end
	for e = 1, ce do
		getglobal("polyLine"..e):Hide();
	end
	for e = 1, q do
		getglobal("pathPiece"..e):Hide();
	end
	for e = 1, #d.hitPegStack do
		u(d.hitPegStack, 1);
	end
	for e = 1, #t.ballTracker.ballStack do
		n = u(t.ballTracker.ballStack, 1);
		n:Hide();
		s(t.ballTracker.ballQueue, n);
	end
	Fe(o);
	r.background:SetTexture(e.artPath.."bg"..ee);
	local f, o, i
	if(h)then
		o = c(h[g], 13 + 3, 68 + 3);
		f = {};
		for e = 1, 28 do
			f[e] = S(c(o, (e - 1) * 2 + 1, e * 2));
		end
	elseif(p)then
		o = p;
		f = {};
		for e = 1, 28 do
			f[e] = S(c(o, (e - 1) * 2 + 1, e * 2));
		end
	end
	R = 0;
	local i = "";
	if(PeggleForeverData.settings.colorBlindMode)then
		i = "_";
	end
	local o;
	for l = 1, #B do
		o = B[l];
		if(o.objectType == dt)then
			n = d:SpawnPeg(o.x, o.y, M, 0, 0, o.animationType, o.time * (o.timeOffset / 100), o.time, o.value1, o.value2, o.value3, o.value4);
		elseif(o.objectType == Xe)then
			n = d:SpawnBrick(o.x, o.y, M, o.rotation, o.radius, o.animationType, o.time * (o.timeOffset / 100), o.time, o.value1, o.value2, o.value3, o.value4);
		elseif(o.objectType == nt)then
			n = d:SpawnBrick(o.x, o.y, M, o.rotation, 0, o.animationType, o.time * (o.timeOffset / 100), o.time, o.value1, o.value2, o.value3, o.value4);
		end
		n.reverser = o.reverser;
		if not o.active then
			n.inactive = true;
		end
		d:UpdateMover(n, 0);
		Ne(n);
		if(h)or(p)then
			for t = 1, 28 do
				if(l == f[t])then
					if(t <= 25)then
						n.id = a;
						n.required = true;
						R = R + 1;
						if(n.isPeg)then
							n.texture:SetTexCoord(0 + ((a - 1) * .25), (a * .25), 0, .5);
						else
							n.texture:SetTexture(e.artPath..e.brickTex[a].."Brick"..e.curvedBrick[n.radius]);
						end
					elseif(t < 28)then
						n.id = le;
						if(n.isPeg)then
							n.texture:SetTexCoord(0 + ((le - 1) * .25), (le * .25), 0, .5);
						else
							n.texture:SetTexture(e.artPath..e.brickTex[le].."Brick"..e.curvedBrick[n.radius]..i);
						end
					else
						n.id = m;
						if(n.isPeg)then
							n.texture:SetTexCoord(0 + ((m - 1) * .25), (m * .25), 0, .5);
						else
							n.texture:SetTexture(e.artPath..e.brickTex[m].."Brick"..e.curvedBrick[n.radius]..i);
						end
					end
				end
			end
		end
	end
	B = nil;
	Re = 1;
	je = 0;
	we = 0;
	he = 0;
	pe = 0;
	ge = 0;
	We = 0;
	te = 0;
	w = 0;
	G = 0;
	K = 0;
	Le = 0;
	De = 0;
	fe = nil;
	Pe = nil;
	d.sigh = nil;
	e.stats[1] = 0;
	e.stats[2] = 0;
	e.stats[3] = 0;
	e.stats[4] = 0;
	e.stats[5] = 0;
	e.stats[6] = 0;
	e.stats[7] = #d.animationStack;
	if not t.duelStatus and not T then -- duels and Peggle Loot shots are not counted in Stats
		config.Stats.onStart(ee);
	end
	-- after this function has settled the round's hero (a match hero, or none for Standard / Peggle Loot)
	C_Timer.After(0, function()
		if config.heroMode ~= "blast" then
			config.PlayHeroVoice();
		end
	end);
	Te = 1;
	J = 1;
	Ie:SetText(We);
	d.lastPeg = nil;
	Q = false;
	x:SetText(P(levelScoreData[ee]));
	r:ClearAllPoints();
	r:SetPoint("center");
	r:SetScale(1);
	t.feverTracker.barFlashUpdate = nil;
	t.roundPegs.elapsed = nil;
	t.ballTracker:UpdateDisplay(3);
	if(t.ballTracker.ball)then
		t.ballTracker.ball:Hide();
		t.ballTracker.ball.loading = nil;
	end
	t.ballTracker.active = nil;
	table.wipe(t.ballTracker.actionQueue);
	t.ballTracker.fastAdd = true;
	local o = 4 + 6;
	if(h)then
		o = e.currentView[4];
		t.bestScoreCaption:SetText(t.bestScoreCaption.caption1)
		t.bestScore:Show()
	elseif(T)then
		o = 1;
		t.bestScoreCaption:SetFormattedText(t.bestScoreCaption.caption3, "30")
		t.bestScore:Hide()
	elseif(p)then
		t.bestScoreCaption:SetFormattedText(t.bestScoreCaption.caption2, "4m 59s")
		t.bestScore:Hide()
	else
		t.bestScoreCaption:SetText(t.bestScoreCaption.caption1)
		t.bestScore:Show()
	end
	for e = 1, o do
		t.ballTracker:UpdateDisplay(2);
	end
	t.ballTracker:UpdateDisplay(1);
	t.feverTracker:UpdateDisplay(1);
	t.catcher.elapsed = e.catcherLoopTime / 4;
	He(t.catcher);
	if not(h or p)then
		local t = y;
		for e = 1, #t do
			for o = 1, #t[e]do
				for a = 1, #t[e][o]do
					n = t[e][o][a];
					s(l, n);
				end
			end
		end
		for t = 1, 25 do
			if(#l > 0)then
				n = u(l, math.random(1, #l));
				n.id = a;
				n.required = true;
				R = R + 1;
				if(n.isPeg)then
					n.texture:SetTexCoord(0 + ((a - 1) * .25), (a * .25), 0, .5);
				else
					n.texture:SetTexture(e.artPath..e.brickTex[a].."Brick"..e.curvedBrick[n.radius]);
				end
			end
		end
		local t;
		local o;
		local a = (ae * 9) ^ 2;
		for r = 1, 2 do
			if(#l > 0)then
				n = u(l, C(1, #l));
				o = nil;
				while(o == nil)do
					if(t)then
						if(((n.x - t.x) ^ 2) + ((n.y - t.y) ^ 2)) < a then
							if(#l > 0)then
							n = u(l, C(1, #l));
							end
						else
						o = true;
						end
					else
						t = n;
						o = true;
					end
				end
				n.id = le;
				if(n.isPeg)then
					n.texture:SetTexCoord(0 + ((le - 1) * .25), (le * .25), 0, .5);
				else
					n.texture:SetTexture(e.artPath..e.brickTex[le].."Brick"..e.curvedBrick[n.radius]..i);
				end
			end
		end
		for t = 1, 1 do
			if(#l > 0)then
				i = "";
				if(PeggleForeverData.settings.colorBlindMode)then
					i = "_";
				end
				n = u(l, C(1, #l));
				n.id = m;
				if(n.isPeg)then
					n.texture:SetTexCoord(0 + ((m - 1) * .25), (m * .25), 0, .5);
				else
					n.texture:SetTexture(e.artPath..e.brickTex[m].."Brick"..e.curvedBrick[n.radius]..i);
				end
			end
		end
		it();
	end
	if(T)then
		K = 0;
		oe = tt;
		ye = e.locale["_SPECIAL_NAME2"];
		config.heroMode = "blast";
		config.talentsOff = true;
		t.charScreen:Hide();
		t.shooter.face:SetTexture(e.artPath.."char"..(oe + 1).."Face");
		e[e.newInfo[13]] = true;
	else
		-- duels and Battles are fair fights: no hero or Legacy talents for anyone, and everybody plays as the match's
		-- hero (or with the plain blast power when "no hero" was chosen)
		local fair = (h or p) and true or false;
		local matchHero = 0;
		if fair then
			matchHero = (h and config.ChallengeHero and config.ChallengeHero(h)) or (p and config.DuelHero and config.DuelHero()) or 0;
		end
		if config.matchSaved and not(fair and matchHero > 0)then
			config.activeHero = config.matchSaved.hero;
			config.matchSaved = nil;
		end
		config.talentsOff = fair;
		if fair and matchHero == 0 then
			K = 0;
			oe = tt;
			ye = e.locale["_SPECIAL_NAME2"];
			e.ResetPowerState();
			config.heroMode = "blast";
			t.charScreen:Hide();
			t.shooter.face:SetTexture(e.artPath.."char"..(oe + 1).."Face");
			t.shooter.face:SetTexCoord(0, 1, 0, 1);
			et();
		else
			if fair then
				if not config.matchSaved then
					config.matchSaved = {hero = config.activeHero};
				end
				config.activeHero = matchHero;
			end
			if config.activeHero then
				config.ApplyHero();
			else
				t.charScreen:Show();
			end
		end
		e[e.newInfo[13]] = nil;
		t.peggleLootTimer.remaining = -100;
	end
	config.OnLevelStart();
	if not e[e.newInfo[13]]then
		for e = 1, b[33 + 3] + config.Mod("feverStart")do
			t.feverTracker:UpdateDisplay(3);
		end
	end
	t.feverTracker:UpdateDisplay(2, 5);
	collectgarbage();
end
local function Oe(o, s, r)
	local a = 0;
	if not e[e.newInfo[13]]then
		a = b[33 + 2] + config.Mod("style") / 2;
	end
	local l = 1e3
	a = (1 + a * .02);
	local n;
	local c = "_ST".."YLE".."SHO".."T_"..D(o);
	if(o == 1)then
		if((ne == 1)and(#d.hitPegStack == 1))or(ne == 2)then
			n = 5 * l;
		end
	elseif(o == 2)then
		n = 25 * l;
	elseif(o == 3)then
		n = 50 * l;
	elseif(o == 4)then
		if(ne == 1)and(#d.hitPegStack > 0)then
			Le = Le + 1;
			if(Le == 5)and(De == 0)then
				De = 1;
				n = 25 * l;
				if(ne == 1)and(#d.hitPegStack == 1)then
					r = r + 10;
				end
			elseif(Le == 10)and(De == 1)then
				De = 2;
				n = 100 * l;
				c = c.."a";
				if(ne == 1)and(#d.hitPegStack == 1)then
					r = r + 10;
				end
			end
		else
			Le = 0;
		end
	elseif(o == 5)then
		if(re >= 12)then
			n = 50 * l;
			re = 0;
		end
	elseif(o == 6)then
		if(x >= 0)then
		n = 50 * l;
		x = -30;
		end
	end
	if(n)then
		ge = ge + i(n * a);
		pe = pe + i(n);
		d:SpawnText(t.catcher, e.locale[c]..P(i(n * a)), .4, 1, 1, 0, 0, s, r);
		return true;
	end
end
local function Ne(n, S, o)
	if n.hexed then
		e.HexTrigger(n);
	end
	local l = 0;
	local f = Re;
	local r = 0;
	local u = 0;
	local h = 1;
	local c = "";
	if not e[e.newInfo[13]]then
		u = (b[33 + 5] * 5);
		if(o)and(o > 0)then
			u = o;
		end
		if e.critBonus and(e.critBonus > 0)then
			u = u + e.critBonus;
			e.critBonus = 0;
		end
		if(oe == me)and(ne == true)and(#d.hitPegStack < 2)then
			u = b[33 + 9] * 20 + config.Mod("guideCrit");
		end
		if not S then
			if(C(1, 100) <= u)then
				h = 1.5 + b[33 + 7] * .1;
				d:SpawnGlow(n, true);
			end
		end
	end
	if(G >= R)then
		f = 55 + 45;
	end
	if(Ce)and(Ce.id ~= M)and(n.id ~= M)then
		distance = z((Ce.x - n.x) ^ 2 + (Ce.y - n.y) ^ 2);
		if(distance >= (.66 * e.boardWidth))then
			Oe(3, n.x, n.y)
		elseif(distance >= (.33 * e.boardWidth))then
			Oe(2, n.x, n.y)
		end
		Ce = n;
	end
	if(n.id == a)then
		l = l + Je;
		if not S then
			G = G + 1;
			t.feverTracker:UpdateDisplay(3);
		end
		x = x + 1;
		Oe(6, n.x, n.y)
		if(G == (R - 1))then
			local t = d.animationStack;
			local e;
			for n = 1, #t do
				e = t[n];
				if(e.id == a)and not(e.hit)then
					d.lastPeg = e;
					break;
				end
			end
		end
	elseif(n.id == m)then
		E(e.SOUND_POWERUP);
		if(G >= R)then
			l = l + Je
		else
			l = l + st
		end
		if(o)and(o ~= 0)then
			d:SpawnText(n, e.locale["_TALENT8_NAME"], 1, .5, 1, 0, 40, n.x, n.y, .35);
		else
			d:SpawnText(n, e.locale["_POINT_BOOST"], 1, .5, 1, 0, 40, n.x, n.y, .35);
		end
		if not e[e.newInfo[13]]then
			if(b[33 + 6] > 0)then
				if(C(1, 100) < (b[33 + 6] * 10))then
					t.feverTracker:UpdateDisplay(3);
				end
			end
			if(b[33 + 11] > 0)then
				local t, e;
				for t = 1, #d.hitPegStack do
					e = d.hitPegStack[t];
					Ne(e, true);
				end
			end
		end
	elseif(n.id == le)then
		l = l + ct;
		if not S then
			local l, o, i, r;
			local l = (ae * 5);
			if not e[e.newInfo[13]]then
				if(C(1, 100) < (b[33 + 8] * 10))then
					r = true;
				end
			end
			if(oe == me)then
				if not config.PlayHeroSound()then -- no hero (Standard): Peggle's own guide sound
					E(e.SOUND_POWERUP_GUIDE);
				end
				config.FX.Ring(n.x, n.y, .7, .3, 1, 10, 85, .55);
				config.FX.Burst(n.x, n.y, .7, .35, 1, 9, 60);
				K = K + config.Balance.guide.shots + config.IntMod("guideShots");
				config.AfterPower("guide", n, 0);
				d:SpawnText(n, ye.."\n"..e.locale["_NEXT"]..K..e.locale["_TURNS"], .5, 1, .5, 0, 40, n.x, n.y, .35);
				t.powerLabel.text:SetText(ye.." "..K);
				t.powerLabel:Show();
				Te = 2;
				fe = true;
			else
				d:SpawnText(n, ye, .5, 1, .5, 0, 40, n.x, n.y, .35);
				l = (l * 2);
				if(config.heroMode)and(config.heroMode ~= "blast")then
					local crit = 0;
					if not e[e.newInfo[13]]then
						crit = b[33 + 9] * 20;
					end
					config.HeroPower(config.heroMode, n, crit);
				else
					i = true;
					d:SpawnGlow(n, nil, 2);
				end
			end
			if(i)then
				E(e.SOUND_POWERUP_BLAST);
				l = l ^ 2;
				d:SpawnGlow(n, nil, 2);
				local t = 0;
				if not e[e.newInfo[13]]then
					t = b[33 + 9] * 20;
				end
				if(oe == me)then
					t = 0;
				end
				for i = 1, #d.animationStack do
					o = d.animationStack[i];
					if not o.hit then
						if(((n.x - o.x) ^ 2 + (n.y - o.y) ^ 2) <= l)then
							o.hit = true;
							Ne(o, nil, t);
							if(o.isBrick)then
								c = "";
								if(PeggleForeverData.settings.colorBlindMode)and(o.id > a)then
									c = "_";
								end
								o.texture:SetTexture(e.artPath..e.brickTex[o.id].."Brick"..e.curvedBrick[o.radius].."a"..c);
							else
								o.texture:SetTexCoord(0 + ((o.id - 1) * .25), (o.id * .25), .5, 1);
							end
						end
					end
				end
			end
			if(r)then
				E(e.SOUND_POWERUP_BLAST);
				l = (ae * 5) ^ 2;
				local i = 0;
				local t;
				for e = 1, #d.animationStack do
					o = d.animationStack[e];
					if(o.id == m)then
						t = o;
						break;
					end
				end
				if(t)then
					d:SpawnGlow(t, nil, 1);
					for n = 1, #d.animationStack do
						o = d.animationStack[n];
						if not o.hit then
							if(((t.x - o.x) ^ 2 + (t.y - o.y) ^ 2) <= l)then
								o.hit = true;
								Ne(o, nil, i);
								if(o.isBrick)then
									c = "";
									if(PeggleForeverData.settings.colorBlindMode)and(o.id > a)then
										c = "_";
									end
									o.texture:SetTexture(e.artPath..e.brickTex[o.id].."Brick"..e.curvedBrick[o.radius].."a"..c);
								else
									o.texture:SetTexCoord(0 + ((o.id - 1) * .25), (o.id * .25), .5, 1);
								end
							end
						end
					end
				end
			end
		end
	else
		l = l + rt;
	end
	if not S then
		d:SpawnGlow(n);
		We = We + 1;
		s(d.hitPegStack, n);
		e.stats[3] = e.stats[3] + 1;
		local n, o;
		if(e.stats[3] == e.stats[7])then
			n = t.bonusBar3.coord;
			o = i((n[4] - n[3]) * 512 + .5);
			t.bonusBar1:SetTexCoord(unpack(n));
			t.bonusBar1:SetHeight(o);
			t.bonusBar2:SetTexCoord(unpack(n));
			t.bonusBar2:SetHeight(o);
			t.bonusBar3:SetTexCoord(unpack(n));
			t.bonusBar3:SetHeight(o);
			t.bonusBar4:SetTexCoord(unpack(n));
			t.bonusBar4:SetHeight(o);
			t.bonusBar5:SetTexCoord(unpack(n));
			t.bonusBar5:SetHeight(o);
			t.fever2:Show();
		else
			n = t.bonusBar1.coord;
			o = i((n[4] - n[3]) * 512 + .5);
			t.bonusBar1:SetTexCoord(unpack(n));
			t.bonusBar1:SetHeight(o);
			t.bonusBar5:SetTexCoord(unpack(n));
			t.bonusBar5:SetHeight(o);
			n = t.bonusBar2.coord;
			o = i((n[4] - n[3]) * 512 + .5);
			t.bonusBar2:SetTexCoord(unpack(n));
			t.bonusBar2:SetHeight(o);
			t.bonusBar4:SetTexCoord(unpack(n));
			t.bonusBar4:SetHeight(o);
			n = t.bonusBar3.coord;
			t.bonusBar3:SetTexCoord(unpack(n));
			t.bonusBar3:SetHeight(i((n[4] - n[3]) * 512 + .5));
		end
		r = #d.hitPegStack;
		if(r < 19)then
			if(t.range == 1)then
				local t = -12 + r;
				if(t < 0)then
					E(e.sounds[e.SOUND_PEG_HIT].."_plus4b"..D(t)..".ogg");
				else
					E(e.sounds[e.SOUND_PEG_HIT].."_plus4b+"..D(t)..".ogg");
				end
			elseif(t.range == 2)then
				E(e.sounds[e.SOUND_PEG_HIT].."_plus_mega9.ogg");
			else
				E(e.sounds[e.SOUND_PEG_HIT].."x"..r..".ogg");
			end
		else
			if(t.range == 1)then
				local t = -12 + r;
				if(t > 9)then
					t = 9;
				end
				E(e.sounds[e.SOUND_PEG_HIT].."_plus4b+"..D(t)..".ogg");
			elseif(t.range == 2)then
				E(e.sounds[e.SOUND_PEG_HIT].."_plus_mega9.ogg");
			else
				E(e.sounds[e.SOUND_PEG_HIT].."x18.ogg");
			end
		end
	end
	r = #d.hitPegStack;
	we = we + (l * f)
	local e = we * r;
	l = i(l * f * h * (1 + (config.powerScore or 0) / 100));
	he = he + l;
	je = (he * r);
	if(S)then
		d:SpawnText(n, l, nil, nil, nil, nil, nil, n.x + 3, n.y + 3, .1, (h ~= 1));
	else
		d:SpawnText(n, l, nil, nil, nil, nil, nil, nil, nil, nil, (h ~= 1));
	end
	t.ballTracker:UpdateDisplay(4, e);
end
-- Hero ability visual effects: a small pool of textures that grow/fade/travel on the board.
config.FX = { pool = {}, active = {}, clock = 0 };
do
local FX = config.FX;
local function fxHost()
	if not FX.frame then
		local f = CreateFrame("Frame", nil, r.foreground);
		f:SetAllPoints(r.foreground);
		f:SetFrameLevel(r.foreground:GetFrameLevel() + 8);
		f:SetScript("OnUpdate", function(self, dt)
			FX.Update(dt);
		end);
		FX.frame = f;
	end
	return FX.frame;
end
local function fxAdd(spec)
	local tex = table.remove(FX.pool);
	if not tex then
		tex = fxHost():CreateTexture(nil, "OVERLAY");
	end
	tex:SetTexture(spec.tex or (e.artPath.."fx_glow"));
	tex:SetBlendMode(spec.blend or "ADD");
	tex:SetVertexColor(spec.r or 1, spec.g or 1, spec.b or 1);
	if spec.crop then
		tex:SetTexCoord(spec.crop, 1 - spec.crop, spec.crop, 1 - spec.crop);
	else
		tex:SetTexCoord(0, 1, 0, 1);
	end
	if tex.SetRotation then
		tex:SetRotation(spec.rot or 0);
	end
	tex:Hide();
	spec.t = tex;
	spec.age = - (spec.delay or 0);
	FX.active[#FX.active + 1] = spec;
end
FX.Update = function(dt)
	FX.clock = FX.clock + dt;
	local tl = FX.timers;
	local ti = 1;
	while ti <= #tl do
		local tm = tl[ti];
		tm.t = tm.t - dt;
		if tm.t <= 0 then
			table.remove(tl, ti);
			tm.fn();
		else
			ti = ti + 1;
		end
	end
	-- Hex: pulsing green mark on every cursed peg
	local marks = e.hexList;
	if marks then
		for i = 1, #marks do
			local o = marks[i];
			local tex = FX.hexTex[i];
			if not tex then
				tex = fxHost():CreateTexture(nil, "OVERLAY");
				tex:SetTexture(e.artPath.."fx_rune");
				tex:SetBlendMode("ADD");
				tex:SetVertexColor(.7, .3, 1);
				FX.hexTex[i] = tex;
			end
			if o.hexed and not o.hit then
				local size = 44 + 6 * math.sin(FX.clock * 6 + i);
				if tex.SetRotation then
					tex:SetRotation(FX.clock * 1.6 + i);
				end
				tex:ClearAllPoints();
				tex:SetPoint("Center", r, "BottomLeft", o.x, o.y);
				tex:SetWidth(size);
				tex:SetHeight(size);
				tex:SetAlpha(.9);
				tex:Show();
			else
				tex:Hide();
			end
		end
		for i = #marks + 1, #FX.hexTex do
			FX.hexTex[i]:Hide();
		end
	end
	-- Heroic Strike: golden afterimage behind the piercing ball
	local pb = e.pierceBall;
	if pb and pb.y and pb.y > 0 then
		FX.trailT = (FX.trailT or 0) + dt;
		if FX.trailT > .035 then
			FX.trailT = 0;
			FX.Glow(pb.x, pb.y, 1, .8, .25, 26, .22);
		end
	end
	if FX.shieldTex and FX.shieldOn then
		FX.shieldTex:SetAlpha(.5 + .2 * math.sin(FX.clock * 5));
	end
	local list = FX.active;
	local i = 1;
	while i <= #list do
		local s = list[i];
		s.age = s.age + dt;
		if s.age >= s.life then
			s.t:Hide();
			FX.pool[#FX.pool + 1] = s.t;
			table.remove(list, i);
			if s.onDone then
				s.onDone();
			end
		else
			if s.age >= 0 then
				local p = s.age / s.life;
				local x = s.x + ((s.x2 or s.x) - s.x) * p;
				local y = s.y + ((s.y2 or s.y) - s.y) * p;
				s.t:ClearAllPoints();
				s.t:SetPoint("Center", r, "BottomLeft", x, y);
				s.t:SetWidth(s.w0 + (s.w1 - s.w0) * p);
				s.t:SetHeight(s.h0 + (s.h1 - s.h0) * p);
				s.t:SetAlpha((s.a0 or 1) * (s.hold and 1 or (1 - p * p)));
				s.t:Show();
			end
			i = i + 1;
		end
	end
end
FX.timers = {};
FX.After = function(delay, fn)
	FX.timers[#FX.timers + 1] = {t = delay, fn = fn};
end
-- a textured sprite that flies from (x1,y1) to (x2,y2) at full opacity, then calls onDone
FX.Missile = function(x1, y1, x2, y2, tex, cr, cg, cb, size, life, delay, onDone)
	fxAdd({tex = tex, crop = (tex and tex:find("Icons")) and .07 or nil, blend = "BLEND", hold = true, x = x1, y = y1, x2 = x2, y2 = y2, w0 = size, w1 = size, h0 = size, h1 = size,
		r = cr, g = cg, b = cb, life = life, delay = delay, onDone = onDone});
end
-- jagged lightning bolt: 4 beam segments with sideways jitter, blue body + white core
FX.Bolt = function(x1, y1, x2, y2, delay)
	local dx, dy = x2 - x1, y2 - y1;
	local len = math.max(math.sqrt(dx * dx + dy * dy), 1);
	local nx, ny = - dy / len, dx / len;
	local px, py = x1, y1;
	for k = 1, 4 do
		local f = k / 4;
		local qx, qy = x1 + dx * f, y1 + dy * f;
		if k < 4 then
			local j = (math.random() - .5) * 18;
			qx, qy = qx + nx * j, qy + ny * j;
		end
		FX.Beam(px, py, qx, qy, .4, .7, 1, 7, .35, delay);
		FX.Beam(px, py, qx, qy, 1, 1, 1, 2.5, .35, delay);
		px, py = qx, qy;
	end
end
FX.hexTex = {};
FX.Clear = function()
	FX.timers = {};
	for i = #FX.active, 1,  - 1 do
		FX.active[i].t:Hide();
		FX.pool[#FX.pool + 1] = FX.active[i].t;
		FX.active[i] = nil;
	end
	FX.SetShield(false);
	for i = 1, #FX.hexTex do
		FX.hexTex[i]:Hide();
	end
end
-- hollow shockwave ring with a soft flash in the middle
FX.Ring = function(x, y, cr, cg, cb, s0, s1, life, delay)
	life = life or .45;
	fxAdd({tex = e.artPath.."fx_ring", x = x, y = y, w0 = s0, w1 = s1, h0 = s0, h1 = s1, r = cr, g = cg, b = cb, life = life, delay = delay});
	fxAdd({x = x, y = y, w0 = s1 * .5, w1 = s1 * .8, h0 = s1 * .5, h1 = s1 * .8, r = cr, g = cg, b = cb, a0 = .55, life = life * .6, delay = delay});
end
-- soft glow blob
FX.Glow = function(x, y, cr, cg, cb, size, life, delay)
	fxAdd({x = x, y = y, w0 = size, w1 = size * 1.4, h0 = size, h1 = size * 1.4, r = cr, g = cg, b = cb, a0 = .8, life = life or .3, delay = delay});
end
-- four-point impact flare
FX.Flare = function(x, y, cr, cg, cb, size, life, delay)
	fxAdd({tex = e.artPath.."fx_flare", x = x, y = y, w0 = size * .5, w1 = size, h0 = size * .5, h1 = size, rot = math.random() * .6,
		r = cr, g = cg, b = cb, life = life or .3, delay = delay});
end
-- crescent slash mark
FX.Slash = function(x, y, rot, cr, cg, cb, size, life)
	fxAdd({tex = e.artPath.."fx_slash", x = x, y = y, w0 = size * .6, w1 = size, h0 = size * .6, h1 = size, rot = rot or 0,
		r = cr, g = cg, b = cb, life = life or .25});
end
-- straight bolt between two points (thick core fades and thins)
FX.Beam = function(x1, y1, x2, y2, cr, cg, cb, thick, life, delay)
	local dx, dy = x2 - x1, y2 - y1;
	local len = math.sqrt(dx * dx + dy * dy);
	fxAdd({tex = e.artPath.."fx_bolt", x = (x1 + x2) / 2, y = (y1 + y2) / 2, w0 = len, w1 = len, h0 = thick * 3, h1 = thick * 1.1,
		rot = math.atan2(dy, dx), r = cr, g = cg, b = cb, life = life or .35, delay = delay});
end
-- a star that streaks down onto (tx, ty)
FX.Star = function(tx, ty, cr, cg, cb, life, delay, onDone)
	fxAdd({tex = e.artPath.."star", x = tx + 60, y = e.boardHeight + 20, x2 = tx, y2 = ty, w0 = 26, w1 = 16, h0 = 26, h1 = 16,
		r = cr, g = cg, b = cb, life = life or .3, delay = delay, onDone = onDone});
end
FX.Burst = function(x, y, cr, cg, cb, count, speed)
	for k = 1, count or 8 do
		d:SpawnParticle(x, y, .5, math.random(0, 359), (speed or 50) * (.6 + math.random() * .8),  - .8, "spark", cr, cg, cb);
	end
end
-- persistent pulsing bar along the bottom while Earth Shield is up
FX.SetShield = function(on)
	if on and not FX.shieldTex then
		local tex = fxHost():CreateTexture(nil, "OVERLAY");
		tex:SetTexture(e.artPath.."fx_bar");
		tex:SetBlendMode("ADD");
		tex:SetVertexColor(.95, .7, .3);
		tex:SetWidth(e.boardWidth);
		tex:SetHeight(26);
		tex:SetPoint("Center", r, "BottomLeft", e.boardWidth / 2, e.boardBoundryBottom + 3);
		FX.shieldTex = tex;
	end
	FX.shieldOn = on;
	if FX.shieldTex then
		if on then
			FX.shieldTex:Show();
		else
			FX.shieldTex:Hide();
		end
	end
end
end -- do (FX locals)
-- Hero power state (charges for the ball-modifying powers). Stored on `e` so the physics
-- functions, which already reference `e`, can reach it without extra upvalues.
e.pierceCharges = 0;
e.shieldCharges = 0;
e.pierceLeft = 0;
e.pierceBall = nil;
e.PIERCE_PEGS = config.Balance.pierce.pegs;
e.Mod = function(name)
	return config.Mod(name);
end
e.hexList = {};
e.ResetPowerState = function()
	for i = 1, #e.hexList do
		e.hexList[i].hexed = nil;
	end
	e.hexList = {};
	e.pierceCharges = 0;
	e.shieldCharges = 0;
	e.pierceLeft = 0;
	e.pierceBall = nil;
	if t and t.powerLabel and config.heroMode ~= "guide" then
		t.powerLabel:Hide();
	end
	if r and r.foreground then
		config.FX.Clear();
	end
end
e.UpdatePowerLabel = function()
	local count;
	if(config.heroMode == "pierce")then
		count = e.pierceCharges;
		if e.pierceBall and((e.pierceLeft or 0) > 0)then
			-- while the strike is in flight, show how many smashes it has left
			if t and t.powerLabel then
				t.powerLabel.text:SetText(ye.." "..e.pierceLeft);
				t.powerLabel:Show();
			end
			return;
		end
	elseif(config.heroMode == "shield")then
		count = e.shieldCharges;
	end
	if(config.heroMode == "shield")and r and r.foreground then
		config.FX.SetShield(e.shieldCharges > 0);
	end
	if count and t and t.powerLabel then
		if(count > 0)then
			t.powerLabel.text:SetText(ye.." "..count);
			t.powerLabel:Show();
		else
			t.powerLabel:Hide();
		end
	end
end
-- Hex: hitting any cursed peg detonates all the other cursed pegs, one after another.
e.HexTrigger = function(peg)
	peg.hexed = nil;
	local targets = {};
	for i = 1, #e.hexList do
		local o = e.hexList[i];
		if o.hexed then
			o.hexed = nil;
			if o ~= peg and not o.hit then
				targets[#targets + 1] = o;
			end
		end
	end
	local radius = (config.Balance.hex.baseSplash or 0);
	if config.Mod("hexSplash") > 0 then
		radius = math.max(radius, config.Balance.hex.splash or 28);
	end
	local splash = radius > 0;
	local function around(p)
		local stack = d.animationStack;
		for k = 1, #stack do
			local o = stack[k];
			if not o.hit and(((o.x - p.x) ^ 2 + (o.y - p.y) ^ 2) <= radius ^ 2)then
				config.PowerHit(o, 0);
			end
		end
	end
	if splash then
		config.FX.Ring(peg.x, peg.y, .7, .3, 1, 10, 56, .3);
		around(peg);
	end
	for k, o in ipairs(targets) do
		config.FX.Beam(peg.x, peg.y, o.x, o.y, .65, .25, 1, 6, .5);
		config.FX.Flare(o.x, o.y, .7, .3, 1, 64, .4, .12 * k);
		config.FX.After(.12 * k, function()
			config.PowerHit(o, 0);
			if splash then
				config.FX.Ring(o.x, o.y, .7, .3, 1, 10, 56, .3);
				around(o);
			end
		end);
	end
	if(config.Mod("hexRecurse") > 0)and(#targets > 0)then
		config.FX.After(.12 * #targets + .25, function()
			local stack = d.animationStack;
			local list = {};
			for k = 1, #stack do
				local o = stack[k];
				if o.isPeg and not o.hit and not o.hexed then
					list[#list + 1] = o;
				end
			end
			for k = 1, (config.Balance.hex.recurse or 2) do
				if #list == 0 then
					break;
				end
				local o = table.remove(list, math.random(1, #list));
				o.hexed = true;
				e.hexList[#e.hexList + 1] = o;
				config.FX.Flare(o.x, o.y, .7, .3, 1, 60, .5);
			end
		end);
	end
	if #targets > 0 then
		config.PlayHeroSound();
		if(config.Mod("hexRecurse") > 0)and(math.random() < (config.Balance.hex.recurseBall or 0))then
			t.ballTracker:UpdateDisplay(2);
			d:SpawnText(t.catcher, "FREE BALL!", .3, 1, .3, 0, 40, peg.x, peg.y + 30, .35);
		end
	end
end
-- Called right after a ball is fired: arms the piercing ball if a charge is stored.
e.OnShot = function()
	e.pierceBall = nil;
	if(config.heroMode == "pierce")and(e.pierceCharges > 0)then
		e.pierceCharges = e.pierceCharges - 1;
		local balls = d.activeBallStack;
		e.pierceBall = balls[#balls];
		e.pierceTotal = (config.Balance.pierce.pegs + config.IntMod("pierceCount")) * ((config.Mod("pierceDouble") > 0) and 2 or 1);
		e.pierceLeft = e.pierceTotal;
		e.UpdatePowerLabel();
		if e.pierceBall then
			-- the strike follows the normal aim arc; it smashes through pegs instead of bouncing
			e.pierceBall.leapt = nil;
			e.pierceBall.leaps = 0;
			config.PlayHeroSound();
			d:SpawnText(e.pierceBall, "HEROIC STRIKE!", 1, .8, .2, 0, 40, e.pierceBall.x, e.pierceBall.y, .35);
		end
	end
end
-- True when the ball should pass through this peg instead of bouncing.
e.PierceCheck = function(ball, peg)
	e.critBonus = 0;
	if(ball ~= e.pierceBall)or not peg.isPeg then
		return false;
	end
	if peg.pierced then
		return true;
	end
	if peg.hit then
		return false;
	end
	if(e.pierceLeft > 0)then
		e.pierceLeft = e.pierceLeft - 1;
		peg.pierced = true;
		e.critBonus = config.Mod("crit");
		if(config.heroMode == "pierce")then
			e.UpdatePowerLabel();
		end
		local cleave = (config.Balance.pierce.cleave or 0) + config.Mod("cleaveRadius") + ((config.Mod("pierceSplash") > 0) and config.Balance.pierce.whirlwind or 0);
		if(cleave > 0)then
			local stack = d.animationStack;
			for k = 1, #stack do
				local o = stack[k];
				if(o ~= peg)and not o.hit and(((o.x - peg.x) ^ 2 + (o.y - peg.y) ^ 2) <= cleave ^ 2)then
					config.PowerHit(o, 0);
				end
			end
		end
		config.FX.Flare(peg.x, peg.y, 1, .85, .35, 52, .3);
		config.FX.Slash(peg.x, peg.y, math.atan2(ball.yVel, ball.xVel), 1, .85, .35, 46, .25);
		config.FX.Burst(peg.x, peg.y, 1, .85, .3, 5, 60);
		return true;
	end
	return false;
end
-- Heroic Leap: a strike ball that falls off the bottom with smashes left leaps back up once.
e.PierceLeap = function(ball, board)
	if(config.heroMode ~= "pierce")or(ball ~= e.pierceBall)or((e.pierceLeft or 0) <= 0)then
		return false;
	end
	local maxLeaps = (config.Mod("pierceDouble") > 0) and 2 or 1;
	if((ball.leaps or 0) >= maxLeaps)then
		return false;
	end
	ball.leaps = (ball.leaps or 0) + 1;
	ball.leapt = true;
	ball.y = e.boardBoundryBottom + 14;
	ball.yVel = math.max(math.abs(ball.yVel) * .95, 330);
	board:SpawnText(ball, "HEROIC LEAP!", 1, .8, .2, 0, 50, ball.x, 40, .35);
	config.FX.Ring(ball.x, e.boardBoundryBottom + 6, 1, .85, .3, 20, 130, .4);
	config.FX.Burst(ball.x, e.boardBoundryBottom + 6, 1, .85, .3, 12, 80);
	E(e.SOUND_POWERUP_BLAST);
	return true;
end
-- A talent value rounded to a whole number at random (2.4 gives 2 or 3, averaging 2.4).
config.IntMod = function(name)
	local v = config.Mod(name);
	local f = math.floor(v);
	if math.random() < v - f then
		f = f + 1;
	end
	return f;
end
-- Removes and returns one peg from `list`, preferring orange pegs with probability `bias`.
config.PickPeg = function(list, bias)
	local idx;
	if(bias or 0) > 0 and math.random() < bias then
		local oranges = {};
		for j = 1, #list do
			if list[j].id == 2 then
				oranges[#oranges + 1] = j;
			end
		end
		if #oranges > 0 then
			idx = oranges[math.random(1, #oranges)];
		end
	end
	return table.remove(list, idx or math.random(1, #list));
end
-- Called when a ball would be lost off the bottom: Earth Shield bounces it back up once per charge.
e.ShieldSave = function(ball, board)
	if(config.heroMode ~= "shield")or(e.shieldCharges <= 0)or(G >= R)then
		return false;
	end
	e.shieldCharges = e.shieldCharges - 1;
	ball.y = e.boardBoundryBottom + 14;
	ball.yVel = math.max(math.abs(ball.yVel) * .95, 330);
	board:SpawnParticleGen(ball.x, 0, 1.5, 1.2, .03, 80, 100, 30, 40,  - 2, "star");
	board:SpawnText(ball, "EARTH SHIELD!", .8, .6, .3, 0, 60, ball.x, 40, .35);
	config.FX.Ring(ball.x, e.boardBoundryBottom + 6, .9, .7, .3, 20, 150, .5);
	config.FX.Beam(0, e.boardBoundryBottom + 5, e.boardWidth, e.boardBoundryBottom + 5, 1, .9, .5, 14, .45);
	config.FX.Burst(ball.x, e.boardBoundryBottom + 6, .9, .7, .3, 14, 80);
	local shards = (config.Balance.shield.shards or 0) + config.IntMod("shardCount");
	if(shards > 0)then
		local stack = board.animationStack;
		local list = {};
		for k = 1, #stack do
			if not stack[k].hit then
				list[#list + 1] = stack[k];
			end
		end
		for k = 1, shards do
			if #list == 0 then
				break;
			end
			local o = config.PickPeg(list, config.Balance.shield.orangeBias);
			local delay = (k - 1) * .06;
			config.FX.Beam(ball.x, e.boardBoundryBottom + 6, o.x, o.y, .9, .7, .3, 4, .3, delay);
			config.FX.Flare(o.x, o.y, 1, .8, .4, 40, .3, delay);
			config.FX.After(delay, function()
				config.PowerHit(o, 0);
			end);
		end
	end
	if(config.Mod("stoneform") > 0)then
		e.pierceBall = ball;
		e.pierceLeft = 4;
		board:SpawnText(ball, "STONEFORM!", .8, .7, .4, 0, 50, ball.x, 60, .35);
	end
	if(config.Mod("rebuke") > 0)then
		config.Ripple(ball.x, e.boardBoundryBottom + 20, 100, 200, 0);
	end
	E(e.SOUND_POWERUP_BLAST);
	e.UpdatePowerLabel();
	return true;
end
-- Debug/test accessor (used by devtools): the live game board object.
config.getBoard = function()
	return d;
end
config.getScore = function()
	return w, te, Q;
end
config.getAim = function()
	return N, ue;
end
config.getState = function()
	return e;
end
-- Marks a peg/brick as hit by a hero power and scores it through Ne.
config.PowerHit = function(o, crit)
	if o.hit then
		return false;
	end
	o.hit = true;
	config.powerScore = config.Mod("powerScore");
	Ne(o, nil, crit);
	config.powerScore = 0;
	if(o.isBrick)then
		local suffix = "";
		if(PeggleForeverData.settings.colorBlindMode)and(o.id > 2)then
			suffix = "_";
		end
		o.texture:SetTexture(e.artPath..e.brickTex[o.id].."Brick"..e.curvedBrick[o.radius].."a"..suffix);
	else
		o.texture:SetTexCoord(0 + ((o.id - 1) * .25), (o.id * .25), .5, 1);
	end
	return true;
end
-- Expanding shockwave: each peg is hit as the wave front reaches it (used by War Stomp and Earthen Rebuke).
config.bombIcon = function(big)
	return big and (e.artPath.."Inv_misc_bomb_08") or (e.artPath.."Inv_misc_bomb_04");
end
config.Ripple = function(x, y, radius, speed, crit)
	local stack = d.animationStack;
	local FX = config.FX;
	local travel = radius / speed;
	FX.Ring(x, y, .85, .65, .35, 24, radius * 2, travel);
	FX.Ring(x, y, .7, .5, .25, 14, radius * 1.6, travel * .9, .08);
	for k = 0, 9 do
		local a = math.rad(k * 36 + math.random(0, 20));
		FX.Beam(x, y, x + math.cos(a) * radius, y + math.sin(a) * radius, .45, .3, .15, 5, travel * 1.3);
	end
	FX.Burst(x, y, .7, .55, .35, 14, 80);
	for k = 1, #stack do
		local o = stack[k];
		if not o.hit then
			local dd = math.sqrt((o.x - x) ^ 2 + (o.y - y) ^ 2);
			if dd <= radius then
				FX.After(dd / speed, function()
					if config.PowerHit(o, crit) then
						FX.Burst(o.x, o.y, .7, .55, .35, 3, 40);
					end
				end);
			end
		end
	end
end
-- Shadow Barrage (Sylvanas capstone): 4 shadow arrows strike random pegs.
config.Barrage = function(n, crit, count)
	local stack = d.animationStack;
	local FX = config.FX;
	local list = {};
	for k = 1, #stack do
		if not stack[k].hit then
			list[#list + 1] = stack[k];
		end
	end
	for k = 1, (count or 4) do
		if #list == 0 then
			break;
		end
		local o = config.PickPeg(list, config.Balance.guide.orangeBias);
		local delay = (k - 1) * .1;
		FX.Beam(n.x, n.y, o.x, o.y, .6, .3, 1, 4, .3, delay);
		FX.Flare(o.x, o.y, .7, .4, 1, 44, .3, delay);
		FX.After(delay, function()
			config.PowerHit(o, crit);
		end);
	end
end
-- Unique hero power patterns. `n` is the green peg that was hit. Talents change the numbers via config.Mod.
config.HeroPowerCore = function(mode, n, crit)
	local stack = d.animationStack;
	local hitPeg = config.PowerHit;
	local FX = config.FX;
	local Mod = config.Mod;
	local baseRadius = ae * 10;
	local B = config.Balance;
	local function dist(a, b)
		return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2);
	end
	local function inRadius(cx, cy, radius)
		for k = 1, #stack do
			local o = stack[k];
			if not o.hit and ((cx - o.x) ^ 2 + (cy - o.y) ^ 2) <= radius ^ 2 then
				hitPeg(o, crit);
			end
		end
	end
	local function unhit(filter)
		local list = {};
		for k = 1, #stack do
			local o = stack[k];
			if not o.hit and (not filter or filter(o)) then
				list[#list + 1] = o;
			end
		end
		return list;
	end
	local function pick(list)
		return table.remove(list, math.random(1, #list));
	end
	config.PlayHeroSound(); -- every hero's green peg plays their own ability sound (Bolvar's again when he strikes)
	if(mode == "bomb")then
		-- Thorium Grenade: a bomb is planted on the green peg and goes off after a short fuse;
		-- cluster bombs are lobbed onto nearby pegs and go off a moment later.
		local scale = (1 + Mod("bombRadius") / 100) * ((Mod("bombDouble") > 0) and 1.4 or 1);
		local function plant(x, y, radius, fuse, size, double)
			FX.Missile(x, y, x, y, config.bombIcon(size > 12), 1, 1, 1, size * 1.7, fuse, 0, function()
				FX.Ring(x, y, 1, .55, .1, 14, radius * 2.6, .45);
				FX.Flare(x, y, 1, .85, .4, radius * 2.4, .3);
				FX.Glow(x, y, 1, .6, .15, radius * 2, .35);
				FX.Burst(x, y, 1, .7, .2, 10, 80);
				inRadius(x, y, radius);
				if double then
					FX.After(.45, function()
						FX.Ring(x, y, 1, .5, .1, 14, radius * 2.4, .4);
						FX.Flare(x, y, 1, .8, .3, radius * 2.2, .3);
						inRadius(x, y, radius * .9);
					end);
				end
			end);
			for k = 1, math.floor(fuse / .15) do
				FX.After(k * .15, function()
					FX.Glow(x, y, 1, .3, .1, size * (1.8 + .12 * k), .2);
					FX.Burst(x, y + size * .5, 1, .85, .3, 2, 35);
				end);
			end
		end
		plant(n.x, n.y, baseRadius * B.bomb.radius * scale, .8, 16, Mod("bombDouble") > 0);
		local near = unhit(function(o)
			local dd = dist(o, n);
			return dd >= 40 and dd <= 150;
		end);
		for k = 1, B.bomb.clusters + config.IntMod("bombClusters") do
			if #near == 0 then
				break;
			end
			local o = pick(near);
			local ox, oy = o.x, o.y;
			FX.Missile(n.x, n.y, ox, oy, config.bombIcon(false), 1, 1, 1, 19, .3, 0, function()
				plant(ox, oy, baseRadius * B.bomb.clusterRadius * (1 + Mod("bombRadius") / 100), .45 + k * .1, 11);
			end);
		end
	elseif(mode == "stomp")then
		-- War Stomp: a shockwave ripples outward and hits each peg as the wave front reaches it.
		local rage = Mod("stompRage") > 0;
		local radius = baseRadius * B.stomp.radius * (1 + Mod("stompRadius") / 100) * (rage and B.stomp.rageRadius or 1);
		local speed = B.stomp.speed * (rage and B.stomp.rageSpeed or 1);
		config.Ripple(n.x, n.y, radius, speed, crit);
		if Mod("aftershock") > 0 then
			FX.After(radius / speed + .25, function()
				config.Ripple(n.x, n.y, radius * B.stomp.aftershock, speed, crit);
			end);
		end
	elseif(mode == "chain")then
		-- Chain Lightning: a visible bolt jumps from peg to peg, sometimes forking.
		local from, delay, claimed = n, 0, {};
		local forkChance = (Mod("forkAll") > 0) and 1 or B.chain.fork;
		local totem = Mod("totem") > 0;
		local function nearest(origin, maxDist)
			local best, bestDist;
			local wantOrange = math.random() < (B.chain.orangeBias or 0);
			for k = 1, #stack do
				local o = stack[k];
				if not o.hit and not claimed[o] and(not wantOrange or o.id == 2)then
					local dd = dist(origin, o);
					if dd <= maxDist and (not bestDist or dd < bestDist) then
						best, bestDist = o, dd;
					end
				end
			end
			return best;
		end
		local function arc(a, b, when)
			claimed[b] = true;
			FX.Bolt(a.x, a.y, b.x, b.y, when);
			FX.Flare(b.x, b.y, .7, .9, 1, 50, .28, when);
			FX.After(when, function()
				hitPeg(b, crit);
				if totem then
					FX.Ring(b.x, b.y, .5, .8, 1, 10, 60, .3);
					inRadius(b.x, b.y, B.chain.totemRadius);
				end
			end);
		end
		for k = 1, B.chain.hops + config.IntMod("hops") do
			local best = nearest(from, 150);
			if not best then
				break;
			end
			delay = delay + .09;
			arc(from, best, delay);
			if math.random() < forkChance then
				local fork = nearest(from, 120);
				if fork then
					arc(from, fork, delay + .05);
				end
			end
			from = best;
		end
	elseif(mode == "stars")then
		-- Starfall: a shower of stars over a moment; Elune guides most of them to orange pegs.
		local eclipse = Mod("eclipse") > 0;
		local bias = eclipse and 1 or B.stars.bias;
		local splash = Mod("starSplash") > 0;
		local list = unhit();
		for k = 1, B.stars.count + config.IntMod("starCount") + (eclipse and B.stars.eclipseExtra or 0) do
			if #list == 0 then
				break;
			end
			local idx;
			if math.random() < bias then
				local oranges = {};
				for j = 1, #list do
					if list[j].id == 2 then
						oranges[#oranges + 1] = j;
					end
				end
				if #oranges > 0 then
					idx = oranges[math.random(1, #oranges)];
				end
			end
			local o = table.remove(list, idx or math.random(1, #list));
			local delay = (k - 1) * .11;
			FX.Beam(o.x + 60, e.boardHeight + 20, o.x, o.y, .6, .8, 1, 3, .3, delay);
			FX.Star(o.x, o.y, .7, .85, 1, .3, delay, function()
				FX.Flare(o.x, o.y, .85, .92, 1, 56, .32);
				FX.Burst(o.x, o.y, .8, .9, 1, 6, 55);
				hitPeg(o, crit);
				if splash then
					FX.Ring(o.x, o.y, .7, .85, 1, 10, 52, .3);
					inRadius(o.x, o.y, 25);
				end
			end);
		end
	elseif(mode == "pierce")then
		e.pierceCharges = (e.pierceCharges or 0) + 1;
		FX.Flare(n.x, n.y, 1, .85, .3, 70, .45);
		FX.Burst(n.x, n.y, 1, .85, .3, 8, 60);
		e.UpdatePowerLabel();
		d:SpawnText(n, "NEXT SHOT PIERCES!", 1, .8, .2, 0, 40, n.x, n.y + 14, .35);
	elseif(mode == "shield")then
		e.shieldCharges = (e.shieldCharges or 0) + (config.Balance.shield.charges or 1);
		FX.Ring(n.x, n.y, .9, .7, .3, 12, 80, .5);
		e.UpdatePowerLabel();
		d:SpawnText(n, "SHIELD UP!", .8, .6, .3, 0, 40, n.x, n.y + 14, .35);
	elseif(mode == "hex")then
		-- Hex: curses random pegs. Hitting any cursed peg detonates all of them (see e.HexTrigger).
		e.hexList = e.hexList or {};
		local list = unhit(function(o)
			return o.isPeg and not o.hexed;
		end);
		for k = 1, B.hex.count + config.IntMod("hexCount") do
			if #list == 0 then
				break;
			end
			local o = config.PickPeg(list, B.hex.orangeBias);
			o.hexed = true;
			e.hexList[#e.hexList + 1] = o;
			FX.Flare(o.x, o.y, .7, .3, 1, 60, .5);
		end
		d:SpawnText(n, "CURSED!", .75, .4, 1, 0, 40, n.x, n.y + 14, .35);
	else
		d:SpawnGlow(n, nil, 2);
		inRadius(n.x, n.y, baseRadius);
	end
end
-- Start of level: Mod("startRegreen") extra green pegs.
config.OnLevelStart = function()
	local v = config.Mod("startRegreen") / 100;
	local count = math.floor(v);
	if math.random() < v - count then
		count = count + 1;
	end
	if(count <= 0)then
		return;
	end
	local stack = d.animationStack;
	local blues = {};
	for k = 1, #stack do
		local o = stack[k];
		if o.isPeg and not o.hit and o.id == 1 then
			blues[#blues + 1] = o;
		end
	end
	for k = 1, count do
		if #blues == 0 then
			break;
		end
		local o = table.remove(blues, math.random(1, #blues));
		o.id = 4;
		o.texture:SetTexCoord(0 + ((o.id - 1) * .25), (o.id * .25), 0, .5);
	end
end
-- Talent effects that apply to every power: free ball, fever notch, new green peg, Shadow Barrage.
config.AfterPower = function(mode, n, crit)
	config.Stats.onPower();
	local Mod = config.Mod;
	local FX = config.FX;
	if math.random() * 100 < Mod("freeball") then
		t.ballTracker:UpdateDisplay(2);
		d:SpawnText(n, "FREE BALL!", .3, 1, .3, 0, 40, n.x, n.y + 30, .35);
	end
	if math.random() * 100 < Mod("fever") then
		t.feverTracker:UpdateDisplay(3);
	end
	if math.random() * 100 < Mod("regreen") then
		local stack = d.animationStack;
		local blues = {};
		for k = 1, #stack do
			local o = stack[k];
			if o.isPeg and not o.hit and o.id == 1 then
				blues[#blues + 1] = o;
			end
		end
		if #blues > 0 then
			local o = blues[math.random(1, #blues)];
			o.id = le;
			o.texture:SetTexCoord(0 + ((o.id - 1) * .25), (o.id * .25), 0, .5);
			FX.Flare(o.x, o.y, .4, 1, .4, 56, .4);
			d:SpawnText(n, "NEW POWER PEG!", .4, 1, .4, 0, 40, o.x, o.y + 14, .35);
		end
	end
	if(mode == "guide")then
		local arrows = (config.Balance.guide.arrows or 0) + config.IntMod("arrowCount") + ((Mod("barrage") > 0) and config.Balance.guide.barrage or 0);
		if arrows > 0 then
			config.Barrage(n, crit or 0, arrows);
		end
	end
end
config.HeroPower = function(mode, n, crit)
	crit = (crit or 0) + config.Mod("crit");
	config.HeroPowerCore(mode, n, crit);
	config.AfterPower(mode, n, crit);
	if math.random() * 100 < config.Mod("echo") then
		config.FX.After(.55, function()
			config.FX.Flare(n.x, n.y, 1, 1, 1, 64, .3);
			d:SpawnText(n, "ECHO!", 1, 1, 1, 0, 40, n.x, n.y + 14, .35);
			config.HeroPowerCore(mode, n, crit);
		end);
	end
end
local function x(e, t)
	local t, n, o, l = unpack(e.artCoords);
	if(e.horizontal)then
		t = t + (e:GetWidth() / 512) * 2;
		n = n + (e:GetWidth() / 512) * 2;
	else
		o = o + .25 * 2;
		l = l + .25 * 2;
	end
	e.down = true;
	e.tex:SetTexCoord(t, n, o, l);
end
local function Xe(e, n)
	local l, a, i, o = unpack(e.artCoords);
	if(e.hover == true)then
		local n = t.catagoryScreen;
		local r;
		for e = 1, #n.frames do
			n.frames[e]:Hide();
		end
		t.about:Hide();
		t.credits:Hide();
		t.stats:Hide();
		e.contentFrame:Show();
		if(n.lastFocus)and(n.lastFocus ~= e)then
			n.lastFocus.focus = nil;
			Xe(n.lastFocus);
		end
		n.lastFocus = e;
		e.focus = true;
		if(e.horizontal)then
			l = l + (e:GetWidth() / 512);
			a = a + (e:GetWidth() / 512);
		else
			i = i + .25;
			o = o + .25;
		end
	end
	e.down = nil;
	e.tex:SetTexCoord(l, a, i, o);
end
local function m(e)
	local o, l, n, t = unpack(e.artCoords);
	if(e.down)then
		if(e.horizontal)then
			o = o + (e:GetWidth() / 512) * 2;
			l = l + (e:GetWidth() / 512) * 2;
		else
			n = n + .25 * 2;
			t = t + .25 * 2;
		end
	else
		if(e.horizontal)then
			o = o + (e:GetWidth() / 512);
			l = l + (e:GetWidth() / 512);
		else
			n = n + .25;
			t = t + .25;
		end
	end
	e.tex:SetTexCoord(o, l, n, t);
	e.hover = true;
end
local function nt(t)
	local a, n, o, l = unpack(t.artCoords);
	if t.focus then
		if(t.horizontal)then
			a = a + (t:GetWidth() / 512);
			n = n + (t:GetWidth() / 512);
		else
			o = o + .25;
			l = l + .25;
		end
	end
	t.tex:SetTexCoord(a, n, o, l);
	t.hover = nil;
end
e.sparkleFunc = function(e, n)
	local t;
	for t = 1, #e.timer do
		e.timer[t] = e.timer[t] + n;
		if(e.timer[t] > e.speed[t] * 4)then
			e.timer[t] = 0;
		end
	end
	local i, r = e:GetWidth(), e:GetHeight();
	local l, t, a, n;
	local o = e;
	for n = 1, 4 do
		l = e.timer[n];
		t = e.speed[n];
		if(l <= t)then
			a = l / t * i;
			basePositionY = l / t * r;
			e.sparkles[0 + n]:SetPoint("CENTER", o, "TOPLEFT", a, 0);
			e.sparkles[4 + n]:SetPoint("CENTER", o, "BOTTOMRIGHT",  - a, 0);
			e.sparkles[8 + n]:SetPoint("CENTER", o, "TOPRIGHT", 0,  - basePositionY);
			e.sparkles[12 + n]:SetPoint("CENTER", o, "BOTTOMLEFT", 0, basePositionY);
		elseif(l <= t * 2)then
			a = (l - t) / t * i;
			basePositionY = (l - t) / t * r;
			e.sparkles[0 + n]:SetPoint("CENTER", o, "TOPRIGHT", 0,  - basePositionY);
			e.sparkles[4 + n]:SetPoint("CENTER", o, "BOTTOMLEFT", 0, basePositionY);
			e.sparkles[8 + n]:SetPoint("CENTER", o, "BOTTOMRIGHT",  - a, 0);
			e.sparkles[12 + n]:SetPoint("CENTER", o, "TOPLEFT", a, 0);
		elseif(l <= t * 3)then
			a = (l - t * 2) / t * i;
			basePositionY = (l - t * 2) / t * r;
			e.sparkles[0 + n]:SetPoint("CENTER", o, "BOTTOMRIGHT",  - a, 0);
			e.sparkles[4 + n]:SetPoint("CENTER", o, "TOPLEFT", a, 0);
			e.sparkles[8 + n]:SetPoint("CENTER", o, "BOTTOMLEFT", 0, basePositionY);
			e.sparkles[12 + n]:SetPoint("CENTER", o, "TOPRIGHT", 0,  - basePositionY);
		else
			a = (l - t * 3) / t * i;
			basePositionY = (l - t * 3) / t * r;
			e.sparkles[0 + n]:SetPoint("CENTER", o, "BOTTOMLEFT", 0, basePositionY);
			e.sparkles[4 + n]:SetPoint("CENTER", o, "TOPRIGHT", 0,  - basePositionY);
			e.sparkles[8 + n]:SetPoint("CENTER", o, "TOPLEFT", a, 0);
			e.sparkles[12 + n]:SetPoint("CENTER", o, "BOTTOMRIGHT",  - a, 0);
		end
	end
end
local function De(a, c, n, d, o, r, l)
	local o = e.artCut[o];
	local n = CreateFrame("Frame", "", n);
	n:SetPoint("Topleft", a, 0);
	n:SetWidth(i((o[2] - o[1]) * 512 + .5));
	n:SetHeight(i((o[4] - o[3]) * 256 + .5));
	tex = n:CreateTexture(nil, "Artwork");
	config.Skin(tex, "tabs");
	tex:SetAllPoints(n);
	tex:SetTexCoord(unpack(o));
	n.tex = tex;
	n.artCoords = o;
	n.contentFrame = d
	n.horizontal = r;
	n:EnableMouse(true);
	n:SetScript("OnMouseDown", x);
	n:SetScript("OnMouseUp", Xe);
	n:SetScript("OnEnter", m);
	n:SetScript("OnLeave", nt);
	if(l)then
		t.sparkCount = (t.sparkCount or(0)) + 1
		local t = config.emulateAutoCastShineTemplateFrame("Frame", "PeggleSparks"..t.sparkCount, n)

		t:ClearAllPoints();
		t:SetPoint("Topleft", 6,  - 6);
		t:SetWidth(n:GetWidth() - 12);
		t:SetHeight(n:GetHeight() - 12);
		t:SetScript("OnUpdate", e.sparkleFunc);
		n.sparks = t;
		n.sparks:Hide();
		if(l == 1)then
			t.speed = {2, 2, 2, 2};
			t.timer = {0, .5, 1, 1.5};
		elseif(l == 2)then
			t.speed = {2, 4, 6, 8};
			t.timer = {0, 0, 0, 0};
		else
			t.speed = {1, 2, 3, 4};
			t.timer = {0, 0, 0, 0};
		end
		local n = t:GetName();
		local e;
		for e = 1, 16 do
			t.sparkles[e]:Show();
			t.sparkles[e]:SetVertexColor(1, 1, 0);
		end
	end
	return n, (a + n:GetWidth());
end
local function Je(r, o, l, e, i, a, d, t, n)
	local e = CreateFrame("EditBox", "PeggleTextBox_"..e, i, "InputBoxTemplate");
	e:SetPoint("Topleft", r + 6,  - (o - 4))
	e:SetWidth(l);
	e:SetHeight(32);
	e:SetAutoFocus(false);
	e:SetNumeric(a);
	-- e:SetMaxLetters(d);
	e:SetHitRectInsets(0, 0, 8, 8);
	e:Show();
	if(t)then
		e:SetScript("OnEnterPressed", t);
	end
	if(n)then
		e.tooltipText = n
		e.oldOnEnter = e:GetScript("OnEnter");
		e.oldOnLeave = e:GetScript("OnLeave");
		e:SetScript("OnEnter", Tooltip_Show);
		e:SetScript("OnLeave", Tooltip_Hide);
	end
	return e, o + 24;
end
local function x(n, a, h, o, S, t, l, d, r, c, i, s)
	local t = CreateFrame("CheckButton", "PeggleCheckbox_"..o, t, "InterfaceOptionsCheckButtonTemplate");
	t:SetWidth(21);
	t:SetHeight(21);
	t:SetPoint("Topleft", n,  - a);
	local n = getglobal(t:GetName().."Text");
	if(s)then
		n:SetFont(config.fontBody, 10);
		t:SetWidth(17);
		t:SetHeight(17);
	else
		n:SetFont(STANDARD_TEXT_FONT, 14);
	end
	n:SetJustifyV("Top");
	n:SetJustifyH("Left");
	n:ClearAllPoints();
	n:SetPoint("Topleft", t, "TopRight", 0,  - 4);
	n:SetText(h);
	n:SetTextColor((d or 1), (r or 1), (c or 1));
	if(l)then
		t.key = o;
		t:SetScript("OnClick", l);
	end
	if(PeggleForeverData.settings[o] == S)then
		t:SetChecked(true);
	end
	if(i)then
		t.tooltipText = i
		t.oldOnEnter = t:GetScript("OnEnter");
		t.oldOnLeave = t:GetScript("OnLeave");
		t:SetScript("OnEnter", Tooltip_Show);
		t:SetScript("OnLeave", Tooltip_Hide);
	end
	return t, a + 20;
end
function o:CreateSlider(s, d, c, r, n, t, l, S, h, i, p, a, T, g, u, f)
	local t = CreateFrame("Slider", "PeggleSlider"..n, t, "OptionsSliderTemplate");
	t:SetWidth(c);
	getglobal(t:GetName().."Thumb"):Show();
	if(f)then
		getglobal(t:GetName().."Text"):SetFont(config.fontBody, a or 14);
	else
		getglobal(t:GetName().."Text"):SetFont(STANDARD_TEXT_FONT, a or 14);
	end
	getglobal(t:GetName().."Text"):SetShadowOffset(1,  - 1);
	getglobal(t:GetName().."Text"):SetText(r);
	getglobal(t:GetName().."Text"):SetVertexColor(T or 1, g or 1, u or 0);
	getglobal(t:GetName().."Low"):SetText("");
	getglobal(t:GetName().."Low"):SetVertexColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
	getglobal(t:GetName().."High"):SetText("");
	getglobal(t:GetName().."High"):SetVertexColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
	t.valueCaption = o:CreateCaption(0, 0, "", t, a or 14, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	t.valueCaption:ClearAllPoints();
	t.valueCaption:SetPoint("Topleft", t, "Topright");
	t:SetHitRectInsets(0, 0, 0, 0);
	t:SetMinMaxValues(l, S);
	t:SetValueStep(h);
	if(PeggleForeverData.settings[n])then
		if(i)then
			t.valueCaption:SetFormattedText(": %d%%", (PeggleForeverData.settings[n] * 100));
		else
			t.valueCaption:SetFormattedText(": %d", PeggleForeverData.settings[n]);
		end
		t:SetValue(PeggleForeverData.settings[n]);
	else
		t:SetValue(l);
		if(i)then
			t.valueCaption:SetFormattedText(": %d%%", (l * 100));
		else
			t.valueCaption:SetFormattedText(": %d", l);
		end
	end
	t:SetPoint("Topleft", s, d);
	t:SetScript("OnValueChanged", o.CreateSlider_OnValueChanged);
	t.updateFunc = p;
	t.objectSetting = n;
	t.usePercent = i;
	return t
end
function o.CreateSlider_OnValueChanged(e)
	if(PeggleForeverData.settings[e.objectSetting])then
		PeggleForeverData.settings[e.objectSetting] = e:GetValue();
	end
	if(e.usePercent)then
		e.valueCaption:SetFormattedText(": %d%%", (e:GetValue() * 100));
	else
		e.valueCaption:SetFormattedText(": %d", e:GetValue());
	end
	if(e.updateFunc)then
		e:updateFunc();
	end
end
function o:CreateCaption(i, r, s, t, n, S, d, c, l, a, o)
	local t = t:CreateFontString(nil, "Overlay");
	if(l == true)then
		t:SetFont(config.fontBody, (n or 10), (o or"Outline"));
	elseif(l == 1)then
		t:SetFont(config.fontHeading, (n or 10), (o or"Outline"));
	else
		if(a)then
			t:SetFont(STANDARD_TEXT_FONT, (n or 10));
		else
			t:SetFont(STANDARD_TEXT_FONT, (n or 10), (o or"Outline"));
		end
	end
	t:SetTextColor((S or 1), (d or 1), (c or 1));
	if(S == .05)and(d == .66)and(c == 1)then
		config.headers[#config.headers + 1] = t;
		t:SetTextColor(config.HeaderColor());
	end
	t:SetPoint("Topleft", i,  - r);
	t:SetText(s);
	t:Show();
	return t;
end
local function l(n, l)
	local o
	if(l == 1)then
		local e = UIDropDownMenu_GetCurrentDropDown();
		UIDropDownMenu_SetText(e, n:GetText(), e);
		UIDropDownMenu_SetSelectedValue(e, n.value);
		PeggleForeverData.settings.defaultPublish = n.value;
	elseif l then
		local e = t.catagoryScreen.frames[2];
		e.name2:SetText(PeggleForeverProfile.lastDuels[n.value]);
	else
		if not n.forced then
			local t = UIDropDownMenu_GetCurrentDropDown();
			UIDropDownMenu_SetText(t, n:GetText(), t);
			UIDropDownMenu_SetSelectedName(t, n:GetText());
			t.selectedValue = n.value;
			if(t.updateFunc)then
				t.updateFunc:SetTexture(e.artPath.."BG"..n.value.."_thumb");
			end
			o = n.value;
		else
			n.forced = nil;
			o = n.selectedValue or(1);
			local t = string.format(e.locale["_LEVEL_INFO"], o, LEVEL_NAMES[o]);
			UIDropDownMenu_SetText(n, t, n);
			n.selectedValue = o;
			if(n.updateFunc)then
				n.updateFunc:SetTexture(e.artPath.."BG"..o.."_thumb");
			end
		end
		local e = t.catagoryScreen.frames[1];
		e:UpdateDisplay(o);
	end
end
local function We(o)
	if(UIDROPDOWNMENU_MENU_LEVEL == 1)then
		local a
		local n;
		local n = e.dropInfo;
		if(o.names)then
			getglobal("DropDownList1").maxWidth = 240;
			table.wipe(n);
			n.text = e.locale["_DUEL_HISTORY"];
			n.isTitle = true;
			n.value = 0;
			UIDropDownMenu_AddButton(n);
			if(PeggleForeverProfile.lastDuels)and(PeggleForeverProfile.lastDuels[1])then
				for e = 1, #PeggleForeverProfile.lastDuels do
					table.wipe(n);
					n.text = PeggleForeverProfile.lastDuels[e];
					n.value = e;
					n.arg1 = true;
					n.func = l;
					UIDropDownMenu_AddButton(n);
				end
			else
				table.wipe(n);
				n.text = e.locale["_DUEL_NO_HISTORY"];
				n.notClickable = true;
				n.value = 0;
				UIDropDownMenu_AddButton(n);
			end
		elseif(o.publish)then
			table.wipe(n);
			local t = e.channels[1];
			for o = 1, 3 do
				table.wipe(n);
				n.text = e.locale["_PUBLISH_"..o];
				n.value = e.channels[o];
				if(PeggleForeverData.settings.defaultPublish == n.value)then
					t = n.value;
				end
				n.arg1 = 1;
				n.func = l;
				UIDropDownMenu_AddButton(n);
			end
			local a = string.lower(PeggleForeverData.settings.defaultPublish);
			local e = o:GetParent();
			e:refreshChannels(EnumerateServerChannels())
			for o = 1, #e.channelNames do
				table.wipe(n);
				n.text = e.channelNames[o];
				if(a == string.lower(n.text))then
					t = n.text;
				end
				n.value = n.text;
				n.arg1 = 1;
				n.func = l;
				UIDropDownMenu_AddButton(n);
			end
			PeggleForeverData.settings.defaultPublish = t;
		else
			getglobal("DropDownList1").maxWidth = 280;
			for o = 1, #LEVELS do
				table.wipe(n);
				n.text = string.format(e.locale["_LEVEL_INFO"], o, LEVEL_NAMES[o]);
				n.value = o;
				n.fontObject = t.fontObj;
				n.icon = e.artPath.."bannerMenu";
				a = levelScoreData[o + #LEVELS];
				if(a == 3)then
					n.tCoordLeft = 0;
					n.tCoordRight = .5;
					n.tCoordTop = .5;
					n.tCoordBottom = 1;
				elseif(a == 2)then
					n.tCoordLeft = .5;
					n.tCoordRight = 1;
					n.tCoordTop = 0;
					n.tCoordBottom = .5;
				else
					n.tCoordLeft = 0;
					n.tCoordRight = .5;
					n.tCoordTop = 0;
					n.tCoordBottom = .5;
				end
				n.checked = nil;
				n.func = l
				UIDropDownMenu_AddButton(n);
			end
		end
	end
end
local function m(t)
	local n = t.selectedValue;
	UIDropDownMenu_SetAnchor(t, 0, 0, "Top", t, "Bottom");
	UIDropDownMenu_Initialize(t, We);
	if(t.publish)then
		UIDropDownMenu_SetSelectedValue(t, PeggleForeverData.settings.defaultPublish)
		n = PeggleForeverData.settings.defaultPublish;
	else
		UIDropDownMenu_SetSelectedName(t, string.format(e.locale["_LEVEL_INFO"], t.selectedValue, LEVEL_NAMES[t.selectedValue]));
	end
	t.selectedValue = n;
	UIDropDownMenu_SetWidth(t, t.menuWidth);
end
local function We(i, n, d, e, l, c, a, r, c)
	local e = CreateFrame("Frame", "PeggleDropdown_"..e, a, "UIDropDownMenuTemplate");
	e:SetHitRectInsets(10, 10, 0, 0);
	if(l)then
		e.text = o:CreateCaption(i, n, l, a, 14, 1, 1, 0, nil, nil);
		e.text:SetParent(e);
		e.text:ClearAllPoints();
		e.text:SetPoint("Bottom", e, "Top", 0, 4);
		n = n + 16;
	end
	e.updateFunc = r;
	e.menuWidth = d;
	e.selectedValue = 1;
	e.peggleMenu = true;
	e.displayMode = "MENU";
	if(l)then
		getglobal(e:GetName().."Text"):SetFont(e.text:GetFont());
		getglobal(e:GetName().."Text"):SetVertexColor(1, 1, 1);
	else
		getglobal(e:GetName().."Text"):SetFontObject(t.fontObj);
		getglobal(e:GetName().."Text"):SetVertexColor(1, .82, 0);
	end
	getglobal(e:GetName().."Text"):SetJustifyH("CENTER");
	e:SetPoint("Topleft", i - 16,  - n);
	e:SetScript("OnShow", m);
	return e, n + 30;
end
local function ct(e, t)
	e.down = true;
	e.highlight:SetAlpha(.2);
end
local function dt(e, t)
	e.down = nil;
	if(e.hover == true)then
		e.highlight:SetAlpha(.1);
	end
end
local function at(e)
	if(e.down)then
		e.highlight:SetAlpha(.2);
	else
		e.highlight:SetAlpha(.1);
	end
	e.hover = true;
end
local function rt(e)
	e.highlight:SetAlpha(0);
	e.hover = nil;
end
-- Hero choices for duels and Battles: 0 = standard (nobody uses a hero, everybody gets the plain blast), 1-8 = that hero
-- for every player. Talents are always off in a match, so everyone has the same base power.
config.MatchHeroName = function(id)
	id = tonumber(id) or 0;
	if id == 0 then
		return "Standard (no hero)";
	end
	local hero = config.GetHero and config.GetHero(id);
	if not hero then
		return "Standard (no hero)";
	end
	-- "Bolvar (Human)" with the race in a darker grey, then the faction's crest
	local text = hero.short or string.match(hero.name, "^(%S+)") or hero.name;
	if hero.race then
		text = text.." |cFF9A9A9A("..hero.race..")|r";
	end
	local crest = config.crestIcons[hero.faction];
	if crest then
		text = text.." "..crest;
	end
	return text;
end
-- the PvP crests are 64x64 textures with the symbol in the top-left 39x41 pixels
config.crestIcons = {
	Alliance = "|TInterface\\TargetingFrame\\UI-PVP-Alliance:16:16:0:-2:64:64:0:39:0:41|t",
	Horde = "|TInterface\\TargetingFrame\\UI-PVP-Horde:16:16:0:-2:64:64:0:39:0:41|t",
};
config.CreateHeroPicker = function(parent, name)
	local drop = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate");
	drop.value = 0;
	UIDropDownMenu_SetWidth(drop, 165);
	local function pick(self)
		drop.value = self.value;
		UIDropDownMenu_SetSelectedValue(drop, self.value);
		UIDropDownMenu_SetText(drop, config.MatchHeroName(self.value));
	end
	UIDropDownMenu_Initialize(drop, function()
		for id = 0, (config.heroes and #config.heroes or 0) do
			local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo() or {};
			info.text = config.MatchHeroName(id);
			info.value = id;
			info.func = pick;
			info.checked = (drop.value == id);
			UIDropDownMenu_AddButton(info);
		end
	end);
	UIDropDownMenu_SetText(drop, config.MatchHeroName(0));
	drop.SetHero = function(_, id)
		drop.value = tonumber(id) or 0;
		UIDropDownMenu_SetSelectedValue(drop, drop.value);
		UIDropDownMenu_SetText(drop, config.MatchHeroName(drop.value));
	end
	return drop;
end
-- The thumb of a scroll bar (the part that shows where you are) was only drawn while the mouse was over the bar.
-- Give it an explicit texture, full opacity and a draw layer above the box behind it, and lift the bar a little.
config.FixScrollThumb = function(slider)
	if not slider then
		return;
	end
	local thumb = slider.GetThumbTexture and slider:GetThumbTexture();
	if type(thumb) ~= "table" and slider.SetThumbTexture then
		slider:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob");
		thumb = slider:GetThumbTexture();
	end
	if type(thumb) == "table" then
		thumb:SetTexture("Interface\\Buttons\\UI-ScrollBar-Knob");
		thumb:SetTexCoord(.20, .80, .125, .875);
		thumb:SetWidth(18);
		thumb:SetHeight(24);
		thumb:SetAlpha(1);
		thumb:SetDrawLayer("OVERLAY");
		thumb:Show();
	end
	local parent = slider:GetParent();
	if parent and parent.GetFrameLevel then
		slider:SetFrameLevel(parent:GetFrameLevel() + 5);
	end
	-- The thumb was not drawn until the bar was dragged: the client only lays it out when the value changes.
	-- So refresh it whenever the bar is shown or its range changes: re-enable it and nudge the value once and back.
	local busy;
	local function refresh()
		if busy or not slider.GetMinMaxValues then
			return;
		end
		busy = true;
		local thumb = slider.GetThumbTexture and slider:GetThumbTexture();
		if type(thumb) == "table" then
			thumb:SetAlpha(1);
			thumb:Show();
		end
		if slider.Enable then
			slider:Enable();
		end
		local lo, hi = slider:GetMinMaxValues();
		if lo and hi and hi > lo then
			local value = slider:GetValue() or lo;
			slider:SetValue((value + 1 <= hi) and (value + 1) or (value - 1));
			slider:SetValue(value);
		end
		busy = nil;
	end
	local setRange = slider.SetMinMaxValues;
	if setRange then
		slider.SetMinMaxValues = function(self, lo, hi)
			setRange(self, lo, hi);
			refresh();
		end
	end
	if slider.HookScript then
		slider:HookScript("OnShow", refresh);
	end
	refresh();
end
config.ArtButton = function(c, o, d, n, r, t, s, a, S, l)
	local t = CreateFrame("Button", "PeggleButton_"..t, s);
	local n = e.artCut[n];
	t:SetPoint("TopLeft", c,  - o);
	t:EnableMouse(true);
	t:RegisterForClicks("LeftButtonUp", "MiddleButtonUp", "RightButtonUp", "Button4Up", "Button5Up");
	local o = 256;
	if(l)then
		o = 512;
	end
	if(r)then
		t:SetWidth(i((n[4] - n[3]) * o + .5));
		t:SetHeight(i((n[2] - n[1]) * 256 + .5));
	else
		t:SetWidth(i((n[2] - n[1]) * 256 + .5));
		t:SetHeight(i((n[4] - n[3]) * o + .5));
	end
	local o = d / t:GetHeight();
	t:SetWidth(o * t:GetWidth());
	t:SetHeight(o * t:GetHeight());
	local o = t:CreateTexture(nil, "Background");
	o:SetAllPoints(t);
	if(l)then
		o:SetTexture(e.artPath.."board2");
	else
		config.Skin(o, "buttons");
	end
	o:Show();
	t.background = o;
	if(r)then
		o:SetTexCoord(n[2], n[3], n[1], n[3], n[2], n[4], n[1], n[4]);
	else
		o:SetTexCoord(unpack(n));
	end
	o = t:CreateTexture(nil, "Artwork");
	o:SetPoint("Center");
	o:SetWidth(t:GetWidth());
	o:SetHeight(t:GetHeight());
	o:SetTexture(e.artPath.."buttonHighlight");
	o:SetBlendMode("ADD");
	o:SetTexCoord(0, 93 / 128, 0, 1);
	o:SetAlpha(0);
	t.highlight = o;
	t:SetScript("OnMouseDown", ct);
	t:SetScript("OnMouseUp", dt);
	t:SetScript("OnClick", a);
	t:SetScript("OnEnter", at);
	t:SetScript("OnLeave", rt);
	t.clickFunc = a;
	return t;
end
config.buttonText = {
	buttonOkay = "OK", buttonGo = "PLAY!", buttonPublish = "BRAG!", buttonBack = "BACK", buttonDecline = "DECLINE",
	buttonAbandonGame = "ABANDON GAME", buttonRestartLevel = "RESTART LEVEL", buttonReturnToGame = "RETURN TO GAME",
	buttonChallenge = "CHALLENGE", buttonNewChallenge = "NEW CHALLENGE", buttonResetTalents = "RESET TALENTS",
	buttonAbout = "ABOUT", buttonCredits = "CREDITS",
};
local function m(c, o, d, n, r, t, s, a, S, l)
	local label = config.buttonText[n];
	if not label then
		return config.ArtButton(c, o, d, n, r, t, s, a, S, l);      -- icon buttons (close, sound, menu) keep their art
	end
	local cut = e.artCut[n];
	local sheet = l and 512 or 256;
	local w, h;
	if(r)then
		w, h = (cut[4] - cut[3]) * sheet, (cut[2] - cut[1]) * 256;
	else
		w, h = (cut[2] - cut[1]) * 256, (cut[4] - cut[3]) * sheet;
	end
	local scale = d / h;
	w, h = i(w * scale + .5), i(d + .5);
	local btn = CreateFrame("Button", "PeggleButton_"..t, s, "UIPanelButtonTemplate");
	btn:SetPoint("TopLeft", c,  - o);
	btn:SetWidth(w);
	btn:SetHeight(h);
	btn:EnableMouse(true);
	btn:RegisterForClicks("LeftButtonUp", "MiddleButtonUp", "RightButtonUp", "Button4Up", "Button5Up");
	btn:SetText(label);
	local size = math.max(10, math.min(i(h * .46), i((w - 16) / (#label * .62))));
	config.StyleButton(btn, size);
	btn:SetScript("OnClick", a);
	btn.clickFunc = a;
	btn.highlight = {SetAlpha = function() end};
	-- code greys buttons out with SetDesaturation(button.background, true/false)
	btn.background = {SetDesaturated = function(_, on)
		btn.dimmed = on and true or nil;
		config.StyleButton(btn);
	end};
	return btn;
end
local function pt(t, e)
	if not e.animated then
		if(e.isBall)then
			s(t.activeBallStack, e);
		else
			s(t.animationStack, e);
		end
		e.animated = true;
	end
end
local function Tt(r, o, n, a, l, e, i)
	local e = (e or t):CreateTexture(nil, "ARTWORK")
	e:SetPoint("Topleft", o,  - n);
	e:SetWidth(a);
	e:SetHeight(l);
	e:Show();
	if(i)then
		e.texture = e;
		e:SetDrawLayer("Overlay")
	else
		e.texture = e;
	end
	e.x = o;
	e.y = n;
	return e;
end
local function mt()
	local o = e.artCut["catcherGlow"];
	local n = r.foreground:CreateTexture(nil, "Artwork");
	n:SetWidth(i((o[2] - o[1]) * 512 + .5));
	n:SetHeight(i((o[4] - o[3]) * 512 + .5));
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(o));
	n:SetAlpha(0);
	n:SetVertexColor(1, 1, .5);
	t.catcherGlow = n;
	n = r.foreground:CreateTexture(nil, "Background");
	n:SetWidth(e.catcherWidth);
	n:SetHeight(e.catcherHeight);
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(e.artCut["catcherBack"]));
	t.catcherBack = n;
	n = t.artBorder:CreateTexture(nil, "Overlay");
	n:SetWidth(e.catcherWidth);
	n:SetHeight(e.catcherHeight);
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(e.artCut["catcher"]));
	t.catcher = n;
	t.catcherGlow:SetPoint("Bottom", n, "Bottom", 0, 10);
	t.catcher.elapsed = 1;
	t.catcher.isCatcher = true;
	t.catcher.startX = 60;
	t.catcher.startY = 9;
	t.catcher.value1 = e.boardWidth - 60;
	t.catcher.value2 = 9;
	t.catcher.reverser = true;
	t.catcher.rotation = 135 + 180;
	t.catcher.loopTime = e.catcherLoopTime;
	t.catcher.Update = function(e, n)
		e.elapsed = e.elapsed + n;
		if(e.elapsed > e.loopTime)then
			e.elapsed = f(e.elapsed, e.loopTime);
		end
		He(e);
		e:SetPoint("Center", r, "Bottomleft", e.x, e.y);
		t.catcherBack:SetPoint("Center", r, "Bottomleft", e.x, e.y);
		if(e.freeGlowElapsed)then
			e.freeGlowElapsed = e.freeGlowElapsed + n;
			if(e.freeGlowElapsed > 1)then
				e.freeGlowElapsed = nil;
				t.catcherGlow:SetAlpha(0);
				t.ballTracker:UpdateDisplay(1);
			else
				t.catcherGlow:SetAlpha(1 - e.freeGlowElapsed);
			end
		end
	end
end
local function n()
	local o = e.artCut["feverRay"];
	local n = r.foreground:CreateTexture(nil, "Artwork");
	n:SetWidth(i((o[2] - o[1]) * 512 + .5));
	n:SetHeight(i((o[4] - o[3]) * 512 + .5));
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(o));
	n:SetAlpha(0);
	n:SetVertexColor(1, 1, .5);
	t.catcherGlow = n;
	n = r.foreground:CreateTexture(nil, "Background");
	n:SetWidth(e.catcherWidth);
	n:SetHeight(e.catcherHeight);
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(e.artCut["catcherBack"]));
	t.catcherBack = n;
	n = t.artBorder:CreateTexture(nil, "Overlay");
	n:SetWidth(e.catcherWidth);
	n:SetHeight(e.catcherHeight);
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(e.artCut["catcher"]));
	t.catcher = n;
	t.catcherGlow:SetPoint("Bottom", n, "Bottom", 0, 10);
	t.catcher.elapsed = 1;
	t.catcher.isCatcher = true;
	t.catcher.startX = 60;
	t.catcher.startY = 9;
	t.catcher.value1 = e.boardWidth - 60;
	t.catcher.value2 = 9;
	t.catcher.reverser = true;
	t.catcher.rotation = 135 + 180;
	t.catcher.loopTime = e.catcherLoopTime;
	t.catcher.Update = function(e, n)
		e.elapsed = e.elapsed + n;
		if(e.elapsed > e.loopTime)then
			e.elapsed = f(e.elapsed, e.loopTime);
		end
		He(e);
		e:SetPoint("Center", r, "Bottomleft", e.x, e.y);
		t.catcherBack:SetPoint("Center", r, "Bottomleft", e.x, e.y);
		if(e.freeGlowElapsed)then
			e.freeGlowElapsed = e.freeGlowElapsed + n;
			if(e.freeGlowElapsed > 1)then
				e.freeGlowElapsed = nil;
				t.catcherGlow:SetAlpha(0);
				t.ballTracker:UpdateDisplay(1);
			else
				t.catcherGlow:SetAlpha(1 - e.freeGlowElapsed);
			end
		end
	end
end
local function Pt(o, p, g, h, f)
	local t = o.ballQueue[1];
	if t then
		u(o.ballQueue, 1);
	else
	t = o:CreateImage(0, 0, e.ballWidth, e.ballHeight, r.foreground);
	t.isBall = true;
	config.Skin(t.texture, "ball");
	t.texture:SetDrawLayer("Overlay")
	local l, n;
	local d = 1
	local i = 0
	local s = 0;
	local c =  - .1;
	local a = .1;
	local S = 0;
	for l = 1, 30 do
		n = o:CreateImage(0, 0, e.ballWidth, e.ballHeight, r.foreground);
		n.texture:SetTexture(e.artPath.."ballTrail");
		n.texture:SetVertexColor(d, i, s);
		n.x = -100;
		n.y = -100;
		d = d + c;
		i = i + a;
		s = s + S;
		if(l == 10)then
			c = 0;
			a = 0;
			S = .1;
		elseif(l == 20)then
			c = .1;
			a =  - .1;
			S = 0;
		end
		n:SetAlpha(xe((35 - l) / 30, 1));
		n:Hide();
		t["trail"..l] = n;
		end
	end
	t.x = p;
	t.y = g;
	t:ClearAllPoints();
	t:SetPoint("Center", r, "Bottomleft", t.x, t.y);
	t:SetAlpha(1)
	t:Show();
	local e;
	for e = 1, 30 do
		t["trail"..e].x = -1e3;
		t["trail"..e].y = -1e3;
		t["trail"..e]:Hide();
	end
	t.xVel = k(T(h)) * f;
	t.yVel = I(T(h)) * f;
	o:Add(t);
end
local function Ct(o, e, l, n, t, s, p, g, S, d, u, h, c, i)
	e.x = l;
	e.y = n;
	e.xVel = 0;
	e.yVel = 0;
	e.radius = p or 0;
	e.rotation = f((s or 0) + 135, 360);
	e.moveType = g or 0;
	e.id = t;
	if(e.isBrick)then
		o:RotateTexture(e.texture, e.rotation, .5, .5)
	end
	if(e.moveType > 0)then
		e.startX = l;
		e.startY = n;
		e.value1 = u;
		e.value2 = h;
		e.value3 = c;
		e.value4 = i;
		if(e.isPeg)then
		else
		end
		e.elapsed = S or 0;
		e.loopTime = d or(.01);
	else
		e.startX = nil;
		e.startY = nil;
		e.value1 = nil;
		e.value2 = nil;
		e.value3 = nil;
		e.value4 = nil;
		e.elapsed = nil;
		e.loopTime = nil;
	end
	e.hit = nil;
	e.pierced = nil;
	e.hexed = nil;
	e.required = nil;
	e.hitCount = 0;
	if(t == a)then
		e.required = true;
	end
	o:Add(e);
	e:ClearAllPoints();
	e:SetPoint("Center", r, "Bottomleft", e.x, e.y);
	e:SetAlpha(1)
	e:Show();
end
local function dt(n, l, a, o, i, d, c, g, s, S, h, f, p)
	local t = n.pegQueue[1];
	if t then
		u(n.pegQueue, 1);
	else
		t = n:CreateImage(0, 0, e.pegWidth, e.pegHeight, r.foreground);
		t.isPeg = true;
		t.texture:SetDrawLayer("Background");
		t.texture:SetTexCoord(0, .5, 0, .5);
	end
	if(PeggleForeverData.settings.colorBlindMode)then
		t.texture:SetTexture(e.artPath.."pegs_");
	else
		t.texture:SetTexture(e.artPath.."pegs");
	end
	t.texture:SetTexCoord(0 + ((o - 1) * .25), (o * .25), 0, .5);
	n:SetupObject(t, l, a, o, i, d, c, g, s, S, h, f, p)
	return t;
end
local function ct(l, o, i, n)
	local t = l.glowQueue[1];
	if t then
		u(l.glowQueue, 1);
	else
		t = l:CreateImage(0, 0, 32, 32, r);
		t:SetTexture(e.artPath.."hitGlow");
		t:SetDrawLayer("Overlay");
		t.texture = nil;
	end
	t:ClearAllPoints();
	t:SetPoint("Center", o, "Center");
	t:SetHeight(32);
	t:SetWidth(32);
	t:SetAlpha(.5);
	t:Show();
	t.elapsed = 0;
	if(n == 1)or(n == 2)then
		t.texture = n;
		if(n == 1)then
			t:SetVertexColor(1, 0, 1);
			t:SetTexture("Spells\\AURARUNE9.BLP");
			t:SetBlendMode("ADD");
		else
			t:SetVertexColor(1, 1, 1);
			t:SetTexture("Interface\\SpellShadow\\Spell-Shadow-Acceptable.blp");
			t:SetBlendMode("ADD");
		end
		t:SetWidth((ae * 9) * n);
		t:SetHeight((ae * 9) * n);
		t:SetAlpha(.66);
		t.startSize = (ae * 9) * n;
		t.endSize = 0;
	else
		if(t.texture)then
			t.texture = nil;
			t:SetTexture(e.artPath.."hitGlow");
		end
		t:SetBlendMode("ADD");
		if i then
			t:SetVertexColor(1, 1, 0);
			t:SetWidth(60);
			t:SetHeight(60);
			t.startSize = 60;
			t.endSize = 120;
		else
			t.startSize = 32;
			t.endSize = 64;
			if(o.id == M)then
				t:SetVertexColor(.4, .4, 1);
			elseif(o.id == a)then
				t:SetVertexColor(1, .4, .4);
			elseif(o.id == le)then
				t:SetVertexColor(.4, 1, .4);
			else
				t:SetVertexColor(1, .4, 1);
			end
		end
	end
	s(l.activeGlows, t);
	return t;
end
local function rt(n, c, a, S, l, i, h, d, o, g, f)
	local t = n.particleQueue[1];
	if t then
		u(n.particleQueue, 1);
		t:SetTexture(e.artPath..d);
	else
		t = n:CreateImage(0, 0, 32, 32, r.foreground);
		t:SetTexture(e.artPath..d);
		t:SetDrawLayer("Overlay");
		t.texture = nil;
	end
	local e = e.starColors
	t:ClearAllPoints();
	t:SetPoint("Center", r, "BottomLeft", c, a);
	t:SetAlpha(1);
	t:Show();
	t.elapsed = 0;
	t.life = S;
	t.x = c;
	t.y = a;
	t.gravity = h;
	t.xVel = i * k(T(l));
	t.yVel = i * I(T(l));
	t.angle = C(0, 359);
	if(o)then
		t:SetVertexColor(o, g, f);
		else
		local n = C(0, #e / 3 - 1);
		t:SetVertexColor(e[n * 3 + 1], e[n * 3 + 2], e[n * 3 + 3]);
	end
	s(n.activeParticles, t);
	return t;
end
local function ft(t, c, d, r, i, n, h, p, T, f, g, a, S, l, o)
	local e = t.particleGenQueue[1];
	if e then
		u(t.particleGenQueue, 1);
	else
		e = {};
	end
	e.life = r;
	e.x = c;
	e.y = d;
	e.elapsed = 0;
	e.spawnRate = n;
	e.spawnElapsed = n;
	e.startAngle = h;
	e.endAngle = p;
	e.minSpeed = T;
	e.maxSpeed = f;
	e.particleType = a;
	e.particleLife = i;
	e.r = S;
	e.g = l;
	e.b = o;
	e.gravity = g;
	s(t.activeParticleGens, e);
	return e;
end
local function st(a, i, h, f, S, o, c, g, n, l, d, p)
	local t = a.pointTextQueue[1];
	if t then
		u(a.pointTextQueue, 1);
	else
		t = r.foreground:CreateFontString(nil, "Overlay");
		t:SetFont(config.fontBody, 12, "Outline");
		t:SetTextColor(1, 1, 0);
		t.elapsed = 0;
		t.Update = a.Update_FloatingText;
	end
	n = n or i.x;
	l = l or(i.y - 15);
	t.elapsed = 0;
	t:SetText(h);
	t:SetTextColor((f or 1), (S or 1), (o or 0));
	t:SetAlpha(1);
	if t.critText then
		t:SetFont(config.fontBody, 12, "Outline");
	end
	t.critText = p;
	if t.critText then
		t:SetFont(config.fontBody, 24, "Outline");
		t:SetTextColor(1, .5, 0)
	end
	local o = t:GetStringWidth();
	if(n > 250)then
		if(n + o / 2) > e.boardWidth then
			n = e.boardWidth - o / 2 - 8;
		end
	else
		if(n - o / 2) < 0 then
			n = o / 2 + 8;
		end
	end
	t:SetPoint("Center", r, "BottomLeft", n, l);
	t.x = n;
	t.y = l;
	if(c)then
		t.xVel = c;
		t.yVel = g;
		t.xOffset = 0;
		t.yOffset = 0;
		t.parent = i;
		t.displayTime = 1;
	else
		t.xVel = nil;
		t.yVel = nil;
		t.xOffset = nil;
		t.yOffset = nil;
		t.parent = nil;
		t.displayTime = .4
	end
	s(a.activePointTextStack, t);
	t:Show();
	if(d)then
		t:SetAlpha(0);
		t.elapsed =  - d;
		t.delayed = true;
	end
	return t;
end
local function ut(n, S, s, o, d, i, c, h, f, g, p, T, C)
	local t = n.brickQueue[1];
	if t then
		u(n.brickQueue, 1);
	else
		t = n:CreateImage(0, 0, e.brickWidth, e.brickHeight, r.foreground);
		t.isBrick = true;
		t.texture:SetTexture(e.artPath.."blueBrick1");
		t.texture:SetDrawLayer("Background");
	end
	local l = "";
	if(PeggleForeverData.settings.colorBlindMode)and(o ~= a)then
		l = "_";
	end
	t.texture:SetTexture(e.artPath..e.brickTex[o].."Brick"..e.curvedBrick[i]..l);
	n:SetupObject(t, S, s, o, d, i, c, h, f, g, p, T, C)
	return t;
end
local function Lt(e, t)
	local n;
	e.elapsed = e.elapsed + t;
	if(e.elapsed >= 0)then
		if(e.delayed)then
			e:SetAlpha(1);
			e.delayed = nil;
		end
		if(e.xVel)then
			e.xOffset = e.xOffset + t * e.xVel;
			e.yOffset = e.yOffset + t * e.yVel;
			e:SetPoint("Center", r, "BottomLeft", e.x + e.xOffset, e.y + e.yOffset);
		end
		if(e.elapsed >= e.displayTime)then
			if(e.elapsed >= e.displayTime + .2)then
				e:Hide();
				e.elapsed = 0;
				s(d.pointTextQueue, e);
				n = true;
			else
				e:SetAlpha(1 - ((e.elapsed - e.displayTime) / .2));
			end
		end
	end
	return n;
end

-- Draws the preview line for the "Super Guide" powerup
-- l -> startX
-- o -> startY
-- n -> endX
-- a -> endY
local function le(l, o, n, a)
	ce = ce + 1;
	local t;
	if(ce > (Ke or(0)))then
		t = r.foreground:CreateTexture("polyLine"..ce, "OVERLAY");
		if(e.debugMode)then
			t:SetTexture(e.artPath.."editorLine");
		else
			t:SetTexture(e.artPath.."pathLine");
		end
		t:SetVertexColor(.3, .7, 1);
		t:SetAlpha(.8);
		t:SetWidth(16);
		t:SetHeight(16);
		t:ClearAllPoints();
		Ke = ce
	else
		t = getglobal("polyLine"..ce);
	end
	if(t)then
		rotation = i(atan2(a-o, n-l)or(0)) + 135;
		t:SetTexture(e.artPath.."pathLine");
		t:SetPoint("center", r, "Bottomleft", l, o);

		t:Show();
		d:RotateTexture(t, rotation, .5, .5)
	end
end

local function Ke(o, n, l, a)
	q = q + 1;
	local t;
	if(q > (qe or(0)))then
		t = r.foreground:CreateTexture("pathPiece"..q, "OVERLAY");
		t:SetWidth(16);
		t:SetHeight(16);
		t:ClearAllPoints();
		qe = q
	else
		t = getglobal("pathPiece"..q);
	end
	if(t)then
		t:SetTexture(e.artPath.."path"..a);
		t:SetPoint("center", r, "Bottomleft", o, n);
		t:Show();
		d:RotateTexture(t, l, .5, .5)
	end
end

local function He(S, u, l, h, c, o, n, t, s, g)
	local r = l + o;
	local o = (h - S) ^ 2 + (c - u) ^ 2;
	local f = r ^ 2;
	local i
	local l, p;
	if(o <= f)then
		-- Heroic Strike: the empowered ball passes straight through pegs (still scoring them)
		local pierce = (not g) and e.PierceCheck(n, t);
		if not pierce then
		local f = z(o)
		local o = atan2(c - u, h - S)
		local r = (r - f) * (101 / (0 + 100))
		local c = T(o + 180)
		n.x = n.x + r * k(c);
		n.y = n.y + r * I(c);
		local o = T(o);
		local c = k(o)
		local r = I(o)
		local o = n.xVel * c + n.yVel * r
		local o = ((1 + Ee) * o) / 2
		n.xVel = n.xVel - (o * 2 * c)
		n.yVel = n.yVel - (o * 2 * r)
		if(Se(n.xVel) < 80)and(n.yVel >= 0)and(n.yVel < 40)then
			n.yVel = 0;
		end
		end
		if not g then
			re = 0;
			if not(t.hit)then
				t.hit = true;
				if(t == d.lastPeg)then
					for e = 1, 30 do
						n["trail"..e].x = -100;
						n["trail"..e].y = -100;
						n["trail"..e]:Hide();
					end
					n.trail1:SetPoint("Center",  - 1e3,  - 1e3);
					n.trail1:Show();
				end
				Ne(t);
				if(t.isPeg)then
					t.texture:SetTexCoord(0 + ((t.id - 1) * .25), (t.id * .25), .5, 1);
				elseif(t.isBrick)then
					local n = "";
					if(PeggleForeverData.settings.colorBlindMode)and(t.id > a)then
						n = "_";
					end
					t.texture:SetTexture(e.artPath..e.brickTex[t.id].."Brick"..e.curvedBrick[t.radius].."a"..n);
				end
			end
			t.hitCount = t.hitCount + 1;
			if(t.hitCount > 90)then
				s = true;
			end
			Ce = t;
			if(s)then
				ve(t);
				t:Hide();
				i = true;
			end
		end
		l = true;
	end
	return l, i;
end
local function at(S, s, t, a, l, o, n, b)
	local L = e.polyTable;
	local o = t + o;
	local q = (t - 1) ^ 2;
	local l = (a - S) ^ 2 + (l - s) ^ 2;
	local o = o ^ 2;
	local t;
	local t = Ye;
	if(l <= o)then
		local p = Ze(b);
		local o = true;
		local d, x, g, c, h, a, r, o, l
		local u, d, T;
		local T = 100;
		local T;
		local T, C
		local E;
		local O = e.polygonCorners[e.curvedBrick[b.radius]];
		local X = 0;
		local I, H, y, N, A, B, w, k, e, P
		local D, _, v, J, K, Q, W, j, R, G, F, U, M, V, Y;
		c = L[p - 1];
		h = L[p];
		for m = 1, p, 2 do
			x = c;
			g = h;
			c = L[m];
			h = L[m + 1];
			a = c - x;
			r = h - g;
			d = ((S - x) * (a) + (s - g) * (r)) / (a ^ 2 + r ^ 2);
			if(d < 0)then
				d = 0;
			elseif(d > 1)then
				d = 1;
			end
			o = (1 - d) * x + d * c;
			l = (1 - d) * g + d * h;
			T = (S - o) ^ 2
			C = (s - l) ^ 2
			u = T + C
			if(u < (q))then
				E = i((m + 1) / 2);
				e = nil;
				if(E == O[1])or(E == O[2])or(E == O[3])or(E == O[4])then
					k = z(a * a + r * r);
					B = a / k;
					w = r / k;
					I = S - x;
					H = s - g;
					A = I * B + H * w;
					if(A < 0)then
						e = I;
						P = H;
						o = x;
						l = g;
					else
						y = S - c;
						N = s - h;
						A = y * B + N * w;
						if(A > 0)then
							e = y;
							P = N;
							o = c;
							l = h;
						else
						end
					end
				end
				if(e)then
					if(X == 0)then
						X = 1;
						D = (S - o + 1) ^ 2
						_ = (s - l + 1) ^ 2
						v = D + _
						J = b;
						local t = f(atan2(P, e) + 360, 360);
						local i = z(n.xVel * n.xVel + n.yVel * n.yVel) * (.75);
						local e = f(atan2(P, e) + 360, 360);
						K = o;
						Q = l;
						W = o;
						j = l;
						R = a;
						G = r
						F = t + 90;
						U = f(atan2(n.yVel, n.xVel) + 360, 360);
						M = v;
						V = m;
						Y = p;
					else
						T = (S - o + 1) ^ 2
						C = (s - l + 1) ^ 2
						u = T + C
						if(u <= v)then
							t.bestObj = b;
							local i = f(atan2(P, e) + 360, 360);
							local d = z(n.xVel * n.xVel + n.yVel * n.yVel) * (.75);
							local e = f(atan2(P, e) + 360, 360);
							t.bestCenterX = o;
							t.bestCenterY = l;
							t.centerX = o;
							t.centerY = l;
							t.pDistX = T
							t.pDistY = C
							t.dxSeg = a;
							t.dySeg = r
							t.hitAngle = i + 90;
							t.ballAngle = f(atan2(n.yVel, n.xVel) + 360, 360);
							t.bestDist = u;
							t.hitSeg = m;
							t.maxPoly = p;
						else
							t.bestObj = J;
							t.bestCenterX = K;
							t.bestCenterY = Q;
							t.centerX = W;
							t.centerY = j;
							t.pDistX = D
							t.pDistY = _
							t.dxSeg = R;
							t.dySeg = G
							t.hitAngle = F;
							t.ballAngle = U;
							t.bestDist = M;
							t.hitSeg = V;
							t.maxPoly = Y;
						end
						n.gravMultiplier = 0;
						break;
					end
				else
					if(u <= t.bestDist)then
						t.bestObj = b;
						t.bestDist = u;
						t.hitSeg = m;
						t.hitAngle = f(atan2(r, a) + 360, 360);
						t.ballAngle = f(atan2(n.yVel, n.xVel) + 360, 360);
						t.bestCenterX = o;
						t.bestCenterY = l;
						t.dxSeg = a;
						t.dySeg = r;
						t.pDistX = T;
						t.pDistY = C;
						t.centerX = o;
						t.centerY = l;
						t.maxPoly = p;
						-- (the original wrote `obj.gravMultiplier = 0` here: a stray global, the last ball icon made
						-- for the ball counter, so it never affected the ball; left out to keep the physics unchanged)
					end
				end
			end
		end
	end
end
local function qe(t, o, C, P)
	local i = o.bestCenterX;
	local l = o.bestCenterY;
	local n = o.bestObj;
	local h = o.pDistX;
	local c = o.pDistY;
	local r = o.dxSeg;
	local r = o.dySeg;
	local S = o.hitAngle;
	local s = o.ballAngle;
	local r = o.bestDist;
	local u = o.hitSeg;
	local u = o.maxPoly;
	local r = z(r);
	local h = h / r;
	local r = c / r;
	local c = h;
	local r = r;
	local r = S - 90 - .01;
	local c;
	local h;
	local c;
	local p = S;
	local S = p - 90;
	local u = f(S + 180 - .01, 360);
	local g = k(T(S));
	local u = I(T(S));
	local S =  - t.xVel * g;
	local m =  - t.yVel * u;
	local S = S + m;
	local g = (1 + Ee) * g * S;
	local S = (1 + Ee) * u * S;
	local u = t.xVel + g;
	local g = t.yVel + S;
	local f = f(atan2(g, u) + 360, 360);
	local S
	newAngle = f;
	r = p - 90;
	if(s > newAngle)then
		if(s > 330)then
			if(Se(newAngle + 360 - s) / 2) < 25 then
				c = true;
				S = (r - 90)
			end
		else
			if(Se(newAngle - s) / 2) < 25 then
				c = true;
				S = (r + 90)
			end
		end
	else
		if(Se(newAngle - s) / 2) < 25 then
			c = true;
			S = (r - 90)
		end
	end
	if(c == true)then
		newAngle = S;
		h = z(t.xVel * t.xVel + t.yVel * t.yVel) * .98
		t.xVel = h * k(T(newAngle));
		t.yVel = h * I(T(newAngle));
	else
		re = 0;
		t.xVel = u;
		t.yVel = g;
	end
	t.x = i + k(T(r)) * (v + .1);
	t.y = l + I(T(r)) * (v + .1);
	if not P then
		if(c == true)then
			if(re >= 2)then
				d:SpawnParticle(i + 1, l, .2, newAngle + 180, 10,  - 1, "spark")
				d:SpawnParticle(i, l - 1, .2, newAngle + 181, 8,  - 1, "spark")
				d:SpawnParticle(i - 1, l, .2, newAngle + 182, 6,  - 1, "spark")
				d:SpawnParticle(i, l + 1, .2, newAngle + 183, 9,  - 1, "spark")
				d:SpawnParticle(i, l, .2, newAngle + 184, 7,  - 1, "spark")
			end
		end
		if not(n.hit)then
			if(c == true)then
				re = re + 1;
				Oe(5, n.x, n.y);
			end
			if(n == d.lastPeg)then
				for e = 1, 30 do
					t["trail"..e].x = -100;
					t["trail"..e].y = -100;
					t["trail"..e]:Hide();
				end
				t.trail1:SetPoint("Center",  - 1e3,  - 1e3);
				t.trail1:Show();
			end
			n.hit = true;
			Ne(n);
			local t = "";
			if(PeggleForeverData.settings.colorBlindMode)and(n.id > a)then
				t = "_";
			end
			n.texture:SetTexture(e.artPath..e.brickTex[n.id].."Brick"..e.curvedBrick[n.radius].."a"..t);
		end
		n.hitCount = n.hitCount + 1;
		if(n.hitCount > 9)then
			C = true;
		end
		Ce = n;
		if(C)then
			ve(n);
			n:Hide();
		end
	end
	o.bestObj = nil;
end
local function Ne(o, n)
	o.elapsed = o.elapsed + n;
	if(o.elapsed < o.delay)then
		return;
	end
	if not t:IsVisible()then
		o.elapsed = 0;
		return;
	end
	o.elapsed = xe(o.elapsed, o.elapsed) * J;
	if(e.speedy == true)then
		o.elapsed = o.elapsed * 3;
	end
	local x = 1 / 100;
	local O = 0;
	local Be = be * x;
	local D = E;
	local Ce = o.animationStack;
	local X = o.activeBallStack;
	local S = Ye;
	local n, l, m, me, a, A, a, a, De;
	local a, g, h, H, E, L, be, xe, K;
	local j, M, V, de, Y, ie;
	local B, W, U, p
	local oe = t.catcher;
	local Z;
	local ee = 0;
	local Ae = 10 + 40;
	local c = e.stats;
	t.catcher:Update(o.elapsed);
	t.feverTracker:Update(o.elapsed);
	if(o.elapsedCount ~= re)then
		o.elapsedCount = re;
		o.elapsedCount2 = 0;
	elseif(o.elapsedCount ~= 0)then
		o.elapsedCount2 = o.elapsedCount2 + o.elapsed;
		if(o.elapsedCount2 > .05)then
			re = 0;
			o.elapsedCount = 0;
		end
	end
	for e = 1, #Ce do
		n = Ce[e];
		o:UpdateMover(n, o.elapsed);
	end
	if(o.feverUp)then
		if(o.feverUp >  - 1)then
			o.feverUp = o.feverUp + o.elapsed / J;
			if(o.feverUp >= .5)then
				o.feverUp = -1;
				t.rainbow:SetWidth(r:GetWidth());
				t.rainbow:SetTexCoord(0, 1, 0, 1);
				t.feverPegScore:Show();
				t.fever3:Show();
			else
				t.rainbow:SetWidth(r:GetWidth() * o.feverUp * 2);
				t.rainbow:SetTexCoord(1 - o.feverUp * 2, 1, 0, 1);
			end
		end
	end
	m = 1;
	for e = 1, #o.activeGlows do
		n = o.activeGlows[m];
		if(n.texture)then
			n.elapsed = n.elapsed + o.elapsed / 3;
		else
			n.elapsed = n.elapsed + o.elapsed;
		end
		if(n.elapsed > .3)then
			s(o.glowQueue, n);
			u(o.activeGlows, m);
			n:Hide();
		else
			m = m + 1;
			me = n.startSize + n.endSize * n.elapsed;
			n:SetWidth(me)
			n:SetHeight(me)
			if n.texture then
				if(n.elapsed > .2)then
					n:SetAlpha(1 - ((n.elapsed - .2) / .1))
				end
			else
				n:SetAlpha(.6 - n.elapsed * 2)
			end
		end
	end
	m = 1;
	for e = 1, #o.activeParticleGens do
		n = o.activeParticleGens[m];
		n.elapsed = n.elapsed + o.elapsed;
		n.spawnElapsed = n.spawnElapsed + o.elapsed;
		if(n.elapsed > n.life)then
			s(o.particleGenQueue, n);
			u(o.activeParticleGens, m);
		else
			m = m + 1;
			if(n.spawnElapsed > n.spawnRate)then
				n.spawnElapsed = 0;
				o:SpawnParticle(n.x, n.y, n.particleLife, C(n.startAngle, n.endAngle), C(n.minSpeed, n.maxSpeed), n.gravity, n.particleType, n.r, n.g, n.b);
			end
		end
	end
	m = 1;
	for e = 1, #o.activeParticles do
		n = o.activeParticles[m];
		n.elapsed = n.elapsed + o.elapsed;
		if(n.elapsed > n.life + .2)then
			s(o.particleQueue, n);
			u(o.activeParticles, m);
			n:Hide();
		else
			if(n.elapsed > n.life)then
				n:SetAlpha(1 - ((n.elapsed - n.life) / .2));
			end
			n.x = n.x + n.xVel * J
			n.y = n.y + n.yVel * J;
			n.yVel = n.yVel + n.gravity * J;
			m = m + 1;
			n.angle = n.angle + 10;
			if(n.angle >= 360)then
				n.angle = n.angle - 360;
			end
			o:RotateTexture(n, n.angle, .5, .5);
			n:SetPoint("Center", r, "BottomLeft", n.x, n.y);
		end
	end
	A = 1;
	local C;
	for e = 1, #o.activePointTextStack do
		n = o.activePointTextStack[A];
		C = n:Update(o.elapsed);
		if(C)then
			u(d.activePointTextStack, A);
		else
			A = A + 1;
		end
	end
	oe = oe.x
	if(t.roundPegs.elapsed)then
		n = t.roundPegs;
		n.elapsed = n.elapsed + o.elapsed;
		if(n.elapsed >= 2)then
			n:Hide();
			t.fever3:Hide();
			t.feverPegScore:Hide();
			t.roundPegScore:Hide();
			t.roundBonusScore:Hide();
			n:SetAlpha(1);
			t.roundPegScore:SetAlpha(1);
			t.roundBonusScore:SetAlpha(1);
			n.elapsed = nil;
			if(o.temp2)then
				if(o.temp1)then
					t.banner.tex:SetTexCoord(unpack(t.banner.tex["clear"..o.temp1]));
					t.banner.tex:SetAlpha(0);
					t.banner.tex:Show();
					t.banner:Show();
					D(e.SOUND_APPLAUSE);
				else
					t.summaryScreen:Show();
				end
			end
		elseif(n.elapsed > 1)and not o.feverUp then
			local e = 1 - (n.elapsed - 1);
			n:SetAlpha(e);
			t.roundPegScore:SetAlpha(e);
			t.roundBonusScore:SetAlpha(e);
		end
	end
	if(o.reclaim)then
		if(G == R)and not o.feverUp then
			o.feverUp = 0;
			t.roundPegs:SetText("");
			t.roundPegScore:SetText("");
			t.roundBonusScore:SetText("");
			t.fever1:Hide();
			t.fever2:Hide();
			t.rainbow:Show();
			t.rainbow:SetTexCoord(1, 1, 0, 1);
			t.rainbow:SetWidth(1);
		end
		if(not o.feverUp)or(o.feverUp == -1)then
			if(#o.hitPegStack > 0)then
				if not o.pegDelay then
					o.pegDelay = o.elapsed;
				else
					o.pegDelay = o.pegDelay + o.elapsed;
				end
				if(o.pegDelay >= .05)then
					o.pegDelay = nil;
					D(e.SOUND_PEG_POP);
					n = u(o.hitPegStack, 1);
					n:Hide();
					o.pegsHit = o.pegsHit + 1;
					D(e.SOUND_SCORECOUNTER);
					o:SpawnGlow(n);
					if o.feverUp then
						t.feverPegScore:SetFormattedText("%s", P(he * o.pegsHit));
						t.feverPegScore:Show();
						t.roundPegs.elapsed = 0;
					else
						t.roundPegs:SetFormattedText(e.locale["_PEGS_HIT"], o.roundValue, o.pegsHit);
						t.roundPegScore:SetFormattedText("%s", P(he * o.pegsHit));
						t.roundPegs:Show();
						t.roundPegScore:Show();
						t.roundPegs.elapsed = 0;
					end
				end
				else
					if(o.pegsHit == 0)and(not o.freeBall)then
						t.roundPegScore:SetFormattedText("%s", e.locale["_TOTAL_MISS"]);
						t.roundPegScore:Show();
						if not e[e.newInfo[13]]then
							D(e.SOUND_COIN_SPIN);
							o.coin.elapsed = 0;
							o.coin.side = 0;
							o.coin.flips = 0;
							o.coin.check = nil;
							o.spinStop = nil;
							o.coin:Show();
							Le = 0;
						end
					else
					end
					if(c[5] == 0)then
						c[4] = c[4] + (he * o.pegsHit) - (we * o.pegsHit);
					else
						c[5] = c[5] + (we * o.pegsHit);
					end
					if(pe > 0)then
						t.roundBonusScore:SetFormattedText(e.locale["_STYLE_COUNT"], P(ge));
						t.roundBonusScore:Show();
						c[6] = c[6] + pe;
					end
					t.ballTracker:UpdateDisplay(3);
					w = w + je + ge;
					if(o.feverUp)then
						c[5] = c[5] + te * (2344 + 7656);
						local n = t.ballTracker.ballStack;
						for o = 1, #n do
							d:SpawnText(nil, e.locale["_BALL_SCORE"], .4, 1, 1, 0, 40, 0, n[o].y + 40, 0);
							n[o]:Hide();
						end
						t.feverPegScore:SetFormattedText("%s", P(c[5]));
						t.feverPegScore:Show();
						t.roundBonusScore:Hide();
					end
					Ie:SetText(P(w));
					we = 0;
					he = 0;
					je = 0;
					pe = 0;
					ge = 0;
					if(not o.freeBall)and(o.pegsHit > 0)and(G < R)then
						t.ballTracker:UpdateDisplay(1);
					end
					o.freeBall = nil;
					o.reclaim = nil;
					it();
				end
			end
		end
		if(o.freeElapsed)then
			o.freeElapsed = o.freeElapsed + o.elapsed;
			if(o.freeElapsed >= .5)then
				o.freeState = o.freeState + 1;
				o.freeElapsed = 0;
				if(o.freeState == 7)then
					t.ballTracker.freeDisplay1:Hide();
					t.ballTracker.freeDisplay2:Hide();
					t.ballTracker.freeDisplayGlow:Hide();
					t.ballTracker.ballDisplay:Show();
					o.freeElapsed = nil;
					o.freeState = 0;
				elseif(o.freeState < 5)then
					if(f(o.freeState, 2) == 0)then
						t.ballTracker.freeDisplay1:Show();
						t.ballTracker.freeDisplay2:Hide();
					else
						t.ballTracker.freeDisplay1:Hide();
						t.ballTracker.freeDisplay2:Show();
					end
				end
			else
				if(o.freeState == 6)then
					t.ballTracker.freeDisplay1:SetAlpha((.5 - o.freeElapsed) / .5);
					t.ballTracker.freeDisplayGlow:SetAlpha((.5 - o.freeElapsed) / .5);
				end
			end
		end
		if(Q)then
			if(N ~= ht)then
				local t;
				for e = 1, ce do
					getglobal("polyLine"..e):Hide();
				end
				for e = 1, q do
					getglobal("pathPiece"..e):Hide();
				end
				local r = 0;
				n = St;
				n.x = e.boardWidth / 2 + 1;
				n.y = e.boardHeight - 16 - 20;
				n.xVel = k(T(N)) * se;
				n.yVel = I(T(N)) * se;
				local t, o = n.x, n.y
				S.bestDist = 100;
				local a = false;
				local a = 1e3;
				local a = false;
				local a;
				local a, a, a, a, a, a, a, a, a, a;
				local a = e.polyTable;
				local a, a;
				local a;
				local a, a;
				local a = 0;
				local a = 0;
				local a = 0;
				local a = 0;
				local a =  - .2 - (Se(270 - ue) / 110 * .15);
				if(ue < 90)then
					a =  - .2 - (Se(270 - 360 + ue) / 110 * .15);
				end
				local c
				p = 0;
				local d = 0;
				ce = 0;
				q = 0;
				while((r < 10)and(n.y > 0)and(p < Te))do
					t, o = n.x, n.y
					n.x = n.x + (n.xVel * x);
					n.y = n.y + (n.yVel * x);
					r = r + x;
					U = true
					S.bestDist = 100;
					B, W = ke(n.x, n.y);
					if(B)then
						for i = W - 1, W + 1 do
							if(i > 0)and(i <= e.boardXYSections)then
								for a = B - 1, B + 1 do
									if(a > 0)and(a <= e.boardXYSections)then
										for e = 1, #y[i][a]do
											l = y[i][a][e];
											if(l.isPeg)then
												c = He(n.x, n.y, v, l.x, l.y, ae, n, l, nil, true);
												if(c)then
													if(fe)then
														le(t, o, n.x, n.y);
													end
													p = p + 1;
												end
											elseif(l.isBrick)then
												at(n.x, n.y, v, l.x, l.y, ze, n, l);
											end
										end
									end
								end
							end
						end
						if(S.bestObj)then
							p = p + 1;
							if(S.bestDist == -1)then
								He(n.x, n.y, v, S.centerX, S.centerY, 1, n, S.bestObj, nil, true);
								S.bestObj = nil;
							else
								qe(n, S, nil, true);
							end
							if(fe)then
								le(t, o, n.x, n.y);
							end
						end
					end
					if(fe)then
						if(d == p)then
							le(t, o, n.x, n.y);
						end
					end
					a = a + x;
					if(a > .04)or(d ~= p)then
						a = 0;
						if(p ~= d)then
							Ke(n.x, n.y, i(atan2(n.yVel, n.xVel)or(0)) + 135, "Circle");
						else
							if not fe then
								if(q == 9)then
									Ke(t, o, i(atan2(n.yVel, n.xVel)or(0)) + 135, "Edge");
								else
									Ke(t, o, i(atan2(n.yVel, n.xVel)or(0)) + 135, "Square");
								end
								if(q > 9)and(Te <= 2)then
									r = 11;
								end
							end
						end
					end
					d = p;
					if(ce > 240)and(Te <= 2)then
						r = 11;
					end
					if(n.x < e.boardBoundryLeft)then
						n.x = e.boardBoundryLeft + (e.boardBoundryLeft - n.x);
						n.xVel =  - n.xVel - (O);
					elseif(n.x > e.boardBoundryRight)then
						n.x = e.boardBoundryRight - (n.x - e.boardBoundryRight);
						n.xVel =  - n.xVel - (O);
					end
					if(n.y < (e.boardBoundryBottom - 10))then
						n.y = -100;
						n.yVel = 0;
					elseif(n.y > e.boardBoundryTop)then
						n.y = e.boardBoundryTop - (n.y - e.boardBoundryTop);
						n.yVel =  - n.yVel;
					end
					if(n.y < v * 2)then
						if(n.xVel < 0)then
							n.xVel = n.xVel + O;
						else
							n.xVel = n.xVel - O;
						end
						if(Se(n.xVel) < 2)then
							n.xVel = 0;
						end
					else
						if(n.xVel < 0)then
							n.xVel = n.xVel + O;
						else
							n.xVel = n.xVel - O;
						end
					end
					n.yVel = n.yVel + Be;
				end
				if(showPoly)then
					local t;
					local t, o;
					local e = e.polyTable;
					for o = 1, #Ce do
						n = Ce[o];
						if(n.isBrick)then
							t = Ze(n);
							for t = 1, (t - 2), 2 do
								le(e[t], e[t + 1], e[t + 2], e[t + 3]);
							end
							le(e[t - 1], e[t], e[1], e[2]);
						end
					end
				end
			end
		else
		end
		while(ee <= o.elapsed)do
			A = 1;
			for T = 1, #X do
				n = X[A];
				if(n.isBall)then
					n.gravMultiplier = 1;
					if(ee == 0)then
						if(n.trail1:IsShown())then
							for e = 30, 2,  - 1 do
								n["trail"..e].x = n["trail"..(e - 1)].x
								n["trail"..e].y = n["trail"..(e - 1)].y
							end
							n.trail1.x = n.x;
							n.trail1.y = n.y;
						end
					end
					n.x = n.x + (n.xVel * x);
					n.y = n.y + (n.yVel * x);
					for e = 1, #X do
						if(A ~= e)then
							l = X[e];
							g = (l.x - n.x);
							h = (l.y - n.y);
							a = z(g ^ 2 + h ^ 2);
							if(a <= (v * 2))then
								be = n.xVel * g / a + n.yVel * h / a;
								xe = l.xVel * g / a + l.yVel * h / a;
								H = (v + v - a) / (be - xe);
								n.x = n.x - n.xVel * H;
								n.y = n.y - n.yVel * H;
								l.x = l.x - l.xVel * H;
								l.y = l.y - l.yVel * H;
								g = l.x - n.x
								h = l.y - n.y;
								a = z(g ^ 2 + h ^ 2);
								E = g / a;
								L = h / a;
								j = n.xVel * E + n.yVel * L;
								M =  - n.xVel * L + n.yVel * E;
								V = l.xVel * E + l.yVel * L;
								de =  - l.xVel * L + l.yVel * E;
								K = Ee;
								Y = j + (1 + K) * (V - j) / 2;
								ie = V + (1 + K) * (j - V) / 2;
								n.xVel = Y * E - M * L;
								n.yVel = Y * L + M * E;
								l.xVel = ie * E - de * L;
								l.yVel = ie * L + de * E;
								n.x = n.x + n.xVel * H;
								n.y = n.y + n.yVel * H;
								l.x = l.x + l.xVel * H;
								l.y = l.y + l.yVel * H;
							end
						end
					end
					S.bestDist = 100;
					S.bestObj = nil;
					U = true
					p = 0;
					while((U == true)and(p < 5))do
						if(o.lastPeg)then
							l = o.lastPeg;
							g = (l.x - n.x);
							h = (l.y - n.y);
							a = z(g ^ 2 + h ^ 2);
							if(a <= e.zoomDistance)then
								local i = ""local n = ""if(l.y < e.boardHeight / 3)then
								i = "bottom";
							elseif(l.y < (2 * e.boardHeight / 3))then
								i = "";
							else
								i = "top";
							end
							if(l.x < e.boardWidth / 3)then
								n = "left";
							elseif(l.x < (2 * e.boardWidth / 3))then
								n = "";
							else
								n = "right";
							end
							if(n == "")and(i == "")then
								n = "center";
							end
							if not Pe then
								Pe = a;
								D(e.SOUND_TIMPANI);
							end
							if(Pe < a)and not o.sigh then
								D(e.SOUND_SIGH);
								o.sigh = true;
							end
							Pe = a;
							local o = F(a, e.zoomDistance / 2)
							o = o / e.zoomDistance
							r:ClearAllPoints();
							r:SetPoint(i..n);
							r:SetScale(1.5 - (o - .5));
							J = .1
							t.catcher:SetAlpha(0);
						else
							if(J ~= 1)then
								o.sigh = nil;
								r:ClearAllPoints();
								r:SetPoint("center");
								r:SetScale(1);
								J = 1
								t.catcher:SetAlpha(1);
								Pe = nil;
							end
						end
					end
					J = DEBUG_SPEED or J;
					U = false;
					B, W = ke(n.x, n.y);
					if(B)then
						for o = W - 1, W + 1 do
							if(o > 0)and(o <= e.boardXYSections)then
								for t = B - 1, B + 1 do
									if(t > 0)and(t <= e.boardXYSections)then
										local i = false;
										local i = 1e3;
										local i = false;
										local i;
										local i, i, i, i, i, i, i, i, i, i;
										local e = e.polyTable;
										local e, e;
										local e;
										local e, e;
										local e = 0;
										local e = 0;
										local e = 0;
										local e = 0;
										for e = 1, #y[o][t]do
											l = y[o][t][e];
											g = (l.x - n.x);
											h = (l.y - n.y);
											a = z(g ^ 2 + h ^ 2);
											if(l.isPeg)then
												_, removed = He(n.x, n.y, v, l.x, l.y, ae, n, l, Z);
												if(removed)then
													break;
												end
											elseif(l.isBrick)then
												at(n.x, n.y, v, l.x, l.y, ze, n, l);
											end
										end
										if(S.bestObj)then
											if(S.bestDist == -1)then
												He(n.x, n.y, v, S.centerX, S.centerY, 1, n, S.bestObj, Z);
												S.bestObj = nil;
											else
												qe(n, S, Z);
											end
											U = true;
											p = p + 1;
										end
									end
									if(U == true)then
										break;
									end
								end
							end
						end
					end
				end
				if(n.x < e.boardBoundryLeft)then
					n.x = e.boardBoundryLeft + (e.boardBoundryLeft - n.x);
					n.xVel =  - n.xVel - (O * 10);
				elseif(n.x > e.boardBoundryRight)then
					n.x = e.boardBoundryRight - (n.x - e.boardBoundryRight);
					n.xVel =  - n.xVel - (O * 10);
				end
				if(G >= R)then
					if(n.y <= 50)then
						W = -8;
						for t = 1, 6 do
							B = o.bouncer[t];
							g = (B - n.x);
							h = (W - n.y);
							a = z(g ^ 2 + h ^ 2);
							if(a <= (v + 32))then
								D(e.SOUND_BUMPER);
								be = n.xVel * g / a + n.yVel * h / a;
								xe = 0;
								n.x = n.x - (n.xVel * x)
								n.y = n.y - (n.yVel * x)
								g = B - n.x
								h = W - n.y;
								a = z(g ^ 2 + h ^ 2);
								E = g / a;
								L = h / a;
								j = n.xVel * E + n.yVel * L;
								M =  - n.xVel * L + n.yVel * E;
								V =  - j;
								de =  - M;
								K = Ee;
								Y = j + (1 + K) * (V - j) / 2;
								ie = V + (1 + K) * (j - V) / 2;
								n.xVel = Y * E - M * L;
								n.yVel = Y * L + M * E;
								n.x = n.x + n.xVel * x
								n.y = n.y + n.yVel * x
								U = true;
								checkBricks = true;
								break;
							end
						end
					end
				else
					if(n.y < (e.boardBoundryBottom + 30))then
						local s = Ze(t.catcher, e.catcherPolygon);
						local i, l, r, a, t, d, c, o, g, T;
						local C, m, u;
						local h = e.polyTable;
						local S = false;
						local t, t;
						local t = Ye;
						t.bestDist = 1e3;
						local P = 0;
						local P = 0;
						local P = 0;
						local P = 0;
						l = h[s - 1];
						a = h[s];
						for e = 1, s, 2 do
							i = l
							r = a;
							l = h[e];
							a = h[e + 1];
							d = l - i
							c = a - r
							o = ((n.x - i) * (d) + (n.y - r) * (c)) / (d * d + c * c)
							if(o < 0)then
								o = 0;
							elseif(o > 1)then
								o = 1;
							end
							g = (1 - o) * i + o * l
							T = (1 - o) * r + o * a
							C = n.x - g
							m = n.y - T
							u = C ^ 2 + m ^ 2
							if(u) < (v * v)then
								if(u < t.bestDist)then
									if(((i - n.x) ^ 2 + (r - n.y) ^ 2) < 25)then
										t.bestDist = -1;
										t.centerX = i;
										t.centerY = r;
										S = true;
									elseif(((l - n.x) ^ 2 + (a - n.y) ^ 2) < 25)then
										t.bestDist = -1;
										t.centerX = l;
										t.centerY = a;
										S = true;
									else
										t.bestDist = u;
										t.hitSeg = e;
										t.hitAngle = f(atan2(c, d) + 360, 360);
										t.ballAngle = f(atan2(n.yVel, n.xVel) + 360, 360);
										t.bestCenterX = g;
										t.bestCenterY = T;
										t.dxSeg = d;
										t.dySeg = c;
										t.pDistX = C;
										t.pDistY = m;
										t.centerX = g;
										t.centerY = T;
										t.maxPoly = s;
										S = true;
									end
								end
							end
						end
						if(S == true)then
							D(e.SOUND_BUCKET_HIT);
							if(t.bestDist == -1)then
								He(n.x, n.y, v, t.centerX, t.centerY, 1, n, t.bestObj, Z, true);
								t.bestObj = nil;
							else
								qe(n, t, nil, true)
							end
							n.x = n.x + n.xVel * x
							n.y = n.y + n.yVel * x
							U = true;
							p = p + 1;
							break;
						end
					end
				end
				if(n.y < (e.boardBoundryBottom - 10))then
					if not e.PierceLeap(n, o)and not e.ShieldSave(n, o)then
						n.y = -100;
						n.yVel = 0;
						if(n == e.pierceBall)then
							e.pierceBall = nil;
							e.UpdatePowerLabel();
						end
					end
				elseif(n.y > e.boardBoundryTop)then
					n.y = e.boardBoundryTop - (n.y - e.boardBoundryTop);
					n.yVel =  - n.yVel;
				end
				if(n.y < v * 2)then
					if(n.xVel < 0)then
						n.xVel = n.xVel + O;
					else
						n.xVel = n.xVel - O;
					end
					if(Se(n.xVel) < 2)then
						n.xVel = 0;
					end
				else
					if(n.xVel < 0)then
						n.xVel = n.xVel + O;
					else
						n.xVel = n.xVel - O;
					end
				end
				n.yVel = n.yVel + Be * n.gravMultiplier;
				local l = ((oe - Ae) < n.x)and((oe + Ae) > n.x)
				if not(n.y <= -100)then
					if(De)then
						n.lastSame = (n.lastSame or(0)) + 1;
					else
						n.lastSame = 0;
						n.lastX = n.x;
						n.lastY = n.y;
					end
					for e = 1, 30 do
						if(n["trail"..e].x >  - 100)then
							n["trail"..e]:ClearAllPoints();
							n["trail"..e]:SetPoint("Center", r, "Bottomleft", n["trail"..e].x, n["trail"..e].y);
							n["trail"..e]:Show();
						end
					end
					n:ClearAllPoints();
					n:SetPoint("Center", r, "Bottomleft", n.x, n.y);
				else
					u(X, A);
					A = A - 1;
					if(G < R)then
						if(l)then
							D(29);
							if not e[e.newInfo[13]]then
								t.ballTracker:UpdateDisplay(2);
								t.catcher.freeGlowElapsed = 0;
								c[2] = c[2] + 1;
								o:SpawnText(t.catcher, e.locale["_FREE_BALL"], nil, nil, nil, 0, 40, t.catcher.x, t.catcher.y + 30);
								o.freeBall = true;
							else
								c[2] = c[2] + 1;
								o:SpawnText(t.catcher, string.format(e.locale["_FREE_BALL_DUEL"], P((1900 + 600) * c[2])), nil, nil, nil, 0, 40, t.catcher.x, t.catcher.y + 30);
								pe = pe + (1900 + 600) * c[2]
								ge = ge + (1900 + 600) * c[2]
							end
							ne = 1;
						end
						if not Oe(4, t.catcher.x, t.catcher.y + 14)then
							Oe(1, t.catcher.x, t.catcher.y + 14);
						end
						J = 1
					else
						for t = 1, 5 do
							if(n.x > o.bouncer[t])and(n.x < o.bouncer[t + 1])then
								D(14);
								o:SpawnParticleGen(o.bouncer[t] + ((o.bouncer[t + 1] - o.bouncer[t]) / 2), 0, 1.5, 1.2, .03, 80, 100, 30, 40,  - 2, "star");
								o:SpawnParticleGen(o.bouncer[t] + ((o.bouncer[t + 1] - o.bouncer[t]) / 2), 0, 1.5, 1.2, .015, 80, 100, 20, 40,  - 2, "spark")
								local r;
								local l
								local a = 0;
								if not e[e.newInfo[13]]then
									a = b[33 + 4] + e.Mod("bucket") / 10;
								end
								if(c[3] == c[7])then
									l = i(1e3 * 100 * (1 + (a * .1)));
									r = i(1e3 * 100);
								else
									l = i(o.bouncer[t + 6] * 1e4 * (1 + (a * .1)));
									r = i(o.bouncer[t + 6] * 1e4);
								end
								o:SpawnText(n, P(l), nil, nil, nil, 0, 80, o.bouncer[t] + ((o.bouncer[t + 1] - o.bouncer[t]) / 2), 50, 0);
								w = w + l;
								c[5] = c[5] + l;
								c[4] = c[4] + l - r;
								Ie:SetText(P(w));
								break
							end
						end
						J = .3
					end
					o.sigh = nil;
					r:ClearAllPoints();
					r:SetPoint("center");
					r:SetScale(1);
					t.catcher:SetAlpha(1);
					Pe = nil;
					s(d.ballQueue, n);
					n.animated = nil;
					n:Hide();
					for e = 1, 30 do
						n["trail"..e]:Hide();
					end
					if(#X == 0)then
						o.roundValue = P(he);
						o.pegsHit = 0;
						o.reclaim = true;
						t.feverTracker:UpdateDisplay(2);
					end
				end
			end
			A = A + 1;
		end
		ee = ee + x;
	end
	o.elapsed = 0;
end
local function Ce(l, a, e, n, t)
	if(e <= 0)then
		e = 360 + e
	end
	local o = l.tableSin[e] * .71;
	local e = l.tableCos[e] * .71;
	a:SetTexCoord(n - o, t + e, n + e, t + o, n - e, t - o, n + o, t - e);
end
local function ce(n, l)
	if not n.active then
		return;
	end
	local a = true;
	local i = true;
	local e;
	if(n.feverElapsed)then
		l = l * 2;
		local o = r:GetScale();
		if(o > 1.001)then
			o = o - .01;
			if(o < 1)then
				o = 1;
				r:ClearAllPoints();
				r:SetPoint("center");
				t.catcher:SetAlpha(1);
			end
			r:SetScale(o);
		end
		n.glowElapsed = n.glowElapsed + l
		if(n.glowElapsed > .5)then
			n.glowElapsed = 0;
		end
		local t;
		for t = 1, 25 do
			e = n.bar[t];
			e.elapsed = e.elapsed + l;
			if(e.elapsed > .8)then
				e.elapsed = e.elapsed - .8;
				e:SetTexCoord(unpack(n.highlight));
				e.on = true;
			end
			if(e.elapsed <= .1)then
				e:SetAlpha(1);
			elseif(e.elapsed <= .2)then
				e:SetAlpha(.9);
			elseif(e.elapsed <= .3)then
				e:SetAlpha(.8);
			else
				if(e.on)then
					e.on = nil;
					e:SetTexCoord(unpack(n.normal));
					e:SetAlpha(1);
				end
			end
		end
		for t = 26, 29 do
			e = n.bar[t];
			if(n.glowElapsed < .25)then
				if(t < 27)or(t > 28)then
					e:SetTexCoord(unpack(e.highlight));
				else
					e:SetTexCoord(unpack(e.normal));
				end
			else
				if(t < 27)or(t > 28)then
					e:SetTexCoord(unpack(e.normal));
				else
					e:SetTexCoord(unpack(e.highlight));
				end
			end
		end
	else
		if(n.barFlashUpdate)then
			for t = (n.lastBar + 1), X do
				e = n.bar[t];
				if(e.elapsed)then
					i = nil;
					e.elapsed = e.elapsed + l;
					if(e.elapsed > .2)then
						e.flashCount = e.flashCount + 1;
						e.elapsed = 0;
						if(f(e.flashCount, 2) == 0)then
							if(e.flashCount >= 6)then
								e.flashCount = nil;
								e.elapsed = nil;
								e:Show();
								e:SetTexCoord(unpack(n.normal));
							else
								e:Hide();
							end
						else
							e:Show();
						end
					end
				end
			end
			if(i)then
				n.lastBar = xe(F(X, 1), 25);
				n.barFlashUpdate = nil;
			else
				a = nil;
			end
		end
		for t = 26, 29 do
			e = n.bar[t];
			if(e.elapsed)then
				a = nil;
				e.elapsed = e.elapsed + l;
				if(e.elapsed >= .2)then
					e.flashCount = e.flashCount + 1;
					e.elapsed = 0;
					if(f(e.flashCount, 2) == 0)then
						if(e.flashCount == 6)then
							e.flashCount = nil;
							e.elapsed = nil;
							e:SetTexCoord(unpack(e.highlight));
						else
							e:SetTexCoord(unpack(e.normal));
						end
					else
						e:SetTexCoord(unpack(e.highlight));
					end
				end
			end
		end
		if(a)then
			n.active = nil;
		end
	end
end
local function fe(n, l, a)
	local o;
	if(l == 1)then
		X = 0;
		Re = 1;
		n.lastBar = 0;
		n.active = nil;
		n.feverElapsed = nil;
		n.glowElapsed = nil;
		for e = 1, 25 do
			n.bar[e]:Hide();
			n.bar[e].elapsed = nil;
		end
		for e = 26, 29 do
			n.bar[e]:SetTexCoord(unpack(n.bar[e].normal));
			n.bar[e].elapsed = nil;
		end
	elseif(l == 2)then
		if(G < R)then
			for e = n.lastBar + 1, X do
				n.bar[e].elapsed = (a or 0);
				n.bar[e].flashCount = (a or 0);
				n.bar[e]:Hide();
				n.barFlashUpdate = true;
			end
			n.active = true;
		end
	elseif(l == 3)then
		if(X < 25)then
			if(n.barFlashUpdate)then
				n.lastBar = xe(F(X, 1), 25);
				n.barFlashUpdate = nil;
				n.active = nil;
				for e = 1, X do
					bar = n.bar[e];
					bar.flashCount = nil;
					bar.elapsed = nil;
					bar:Show();
					bar:SetTexCoord(unpack(n.normal));
				end
			end
			X = X + 1;
			n.bar[X]:SetTexCoord(unpack(n.highlight));
			n.bar[X]:Show();
			if(n.nextValue[X])then
				o = 25 + n.nextValue[X]
				n.bar[o].elapsed = 0;
				n.bar[o].flashCount = 0;
				n.bar[o]:SetTexCoord(unpack(n.bar[o].highlight));
				Re = n.bar[o].id;
				n.active = true;
			end
		end
		if(G >= R)then
			E(e.SOUND_ODETOJOY);
			E(e.SOUND_FEVER);
			local e = e.artCut;
			t.bonusBar1:Show();
			t.bonusBar2:Show();
			t.bonusBar3:Show();
			t.bonusBar4:Show();
			t.bonusBar5:Show();
			t.catcher:Hide();
			t.catcherBack:Hide();
			if(d.lastPeg)then
				d:SpawnParticleGen(d.lastPeg.x, d.lastPeg.y, .5, .3, .005, 0, 359, 1, 3,  - .05, "spark")
				d:SpawnParticleGen(d.lastPeg.x, d.lastPeg.y, .5, .3, .005, 0, 359, 1, 3,  - .05, "spark")
			end
			t.roundPegs:SetText("");
			t.roundPegScore:SetText("");
			t.roundPegs:Show();
			t.roundPegScore:Show();
			t.fever1:Show();
			local e = 0;
			for t = 25, 1,  - 1 do
				n.bar[t].elapsed = e * .125;
				e = e + 1;
				if(e == 6)then
					e = 0;
				end
				n.bar[t]:Show();
			end
			J = .5;
			n.feverElapsed = true;
			n.glowElapsed = 0;
			n.active = true;
			d.lastPeg = nil;
		end
	end
	n.text:SetText(25 - G);
end
local function he(n, o)
	if not n.active then
		return;
	end
	if(n.ball)then
		if(n.ball.loading)then
			n.ball.y = n.ball.y + o * 900;
			n.ball:SetPoint("TopLeft", n, "BottomLeft", 22, n.ball.y);
			if(n.ball.y > (e.boardHeight - 170))then
				n.ball:Hide();
				s(n.ballQueue, n.ball);
				n.ball.loading = nil;
				n.ball = nil;
				n.active = nil;
				Q = true;
				config.Stats.onBallEnd(w);
				local e;
				for e = 1, 10 do
					r.trail[e]:Show();
				end
				t.shooter.ball:Show();
			end
		elseif(n.ball.adding)then
			if(n.fastAdd == true)then
				n.ball.y = n.ball.y - o * 2250;
			else
				n.ball.y = n.ball.y - o * 900;
			end
			n.ball:SetPoint("TopLeft", n, "BottomLeft", 22, n.ball.y);
			if(n.ball.y <= n.ball.newY)then
				E(e.SOUND_BALL_ADD);
				n.ball.y = n.ball.newY;
				n.ball:SetPoint("TopLeft", n, "BottomLeft", 22, n.ball.y);
				n.ball.adding = nil;
				n.ball = nil;
				n.active = nil;
				n.ballSpring:SetPoint("TopLeft", n, "BottomLeft", 18, 76 - (te * 3));
				local e;
				local t = #n.ballStack;
				for e = 1, t do
					n.ballStack[e].y = 74 - (t * 3) + e * 18;
					n.ballStack[e]:SetPoint("TopLeft", n, "BottomLeft", 22, n.ballStack[e].y);
				end
				if(n.actionQueue[1])then
					n:UpdateDisplay(u(n.actionQueue, 1));
				else
					n.fastAdd = nil;
				end
			end
		end
	elseif(n.springMove)then
		n.ballSpring.y = n.ballSpring.y + (n.springMove * o * 450);
		if(n.ballSpring.y < 0)then
			n.ballSpring.y = 0;
			n.springMove = 1;
		elseif(n.ballSpring.y >= n.ballSpring.newY)then
			n.springMove = nil;
			local e = u(n.ballStack, #n.ballStack);
			e.loading = true;
			n.ball = e;
			local t = #n.ballStack;
			n.ballSpring.y = 76 - (t * 3);
			local e;
			for e = 1, t do
				n.ballStack[e].y = 74 - (t * 3) + e * 18;
				n.ballStack[e]:SetPoint("TopLeft", n, "BottomLeft", 22, n.ballStack[e].y);
			end
		end
		n.ballSpring:SetPoint("TopLeft", n, "BottomLeft", 18, n.ballSpring.y);
	end
end
local function re(n, r, f)
	local c, S
	if(r <= 2)and(n.active)then
		s(n.actionQueue, r);
		return;
	end
	if(r == 1)then
		if(n.ballStack[1])then
			n.active = true;
			S = true;
			local e = #n.ballStack;
			n.ballSpring.newY = 76 - ((e - 2) * 3);
			n.ballSpring.y = 76 - ((e - 1) * 3);
			n.springMove = -1;
			if(e < 4)then
				t.roundBalls:Hide();
				t.roundBalls:Show();
			else
				t.roundBalls:Hide();
			end
		else
			if(e[e.newInfo[11]])then
				t.network:Send(e.commands[21], e[e.newInfo[11]].."+"..U(h(w, 4), p(e.name)), "WHISPER", e[e.newInfo[11].. 4]);
				if not e[e.newInfo[12]]then
					e[e.newInfo[11]] = nil;
				end
			elseif(e.extraInfo)then
				Me(w);
			end
			config.Stats.onEnd(w, false, false, e.stats);
			V["r".."ece".."nt"][ee] = w;
			if(w > levelScoreData[ee])then
				lt(w, ee, 1);
			else
				if(t.duelStatus == 3)then
					local n = t.catagoryScreen.frames[2];
					local o, a, l = _e();
					local o = h(a + ((oe * 20 + 10 + l) * 100) + 1, 2)
					o = o..h(w, 4)..h(e.stats[4], 4)..h(e.stats[5], 4)..h(e.stats[6], 4);
					local o = U(o, p(e.name));
					n.player1.value1 = e.stats[4];
					n.player1.value2 = e.stats[6];
					n.player1.value3 = e.stats[5];
					n.player1.value4 = oe + 1;
					n.player1.value5 = a;
					n.player1.value6 = l;
					n.player1.value = w;
					config.SendAddonMessage(t.network.prefix, e.commands[6].."+"..o, "WHISPER", n.name2:GetText());
					n:UpdateWinners();
					if(PeggleForeverData.settings.closeDuelChallenge == true)then
						t.duelStatus = nil;
						t:Hide();
					end
				end
			end
			de = true;
			t.summaryScreen:Show();
		end
	elseif(r == 2)then
		if(n.ballQueue[1])then
			obj = u(n.ballQueue, 1);
		else
			obj = d:CreateImage(0, 0, 18, 18, n);
			config.Skin(obj.texture, "ball");
		end
		obj:Show();
		s(n.ballStack, obj);
		te = te + 1;
		n.ballDisplay:SetText(te);
		obj.y = e.boardHeight - 170;
		obj.newY = 74 - (te * 3) + te * 18;
		obj.adding = true;
		n.ball = obj;
		n.active = true;
		obj:SetPoint("TopLeft", n, "BottomLeft", 22, obj.y);
	elseif(r == 3)then
		n.nextValue = 25e3;
		n.currentValue = 0;
		n.valueStart = 0;
		n.extraLevel = 0;
		c = true;
		t.range = nil;
		local i, o, t, l, a, e;
		i, o, t = 0, 0, 0;
		l, a, e = 0, 1, .7;
		n.leftbar2Top:SetVertexColor(i, o, t, 0);
		n.rightbar2Top:SetVertexColor(i, o, t, 0);
		n.leftbar2Middle:SetVertexColor(i, o, t, 0);
		n.rightbar2Middle:SetVertexColor(i, o, t, 0);
		n.leftbar2Bottom:SetVertexColor(i, o, t, 0);
		n.rightbar2Bottom:SetVertexColor(i, o, t, 0);
		n.leftbar1Top:SetVertexColor(l, a, e, 1);
		n.rightbar1Top:SetVertexColor(l, a, e, 1);
		n.leftbar1Middle:SetVertexColor(l, a, e, 1);
		n.rightbar1Middle:SetVertexColor(l, a, e, 1);
		n.leftbar1Bottom:SetVertexColor(l, a, e, 1);
		n.rightbar1Bottom:SetVertexColor(l, a, e, 1);
	elseif(r == 4)then
		n.currentValue = f;
		c = true;
	end
	if(S)then
		local e = #n.ballStack;
		n.ballSpring.newY = 76 - (e * 3);
		n.ballSpring.y = 76 - ((e + 1) * 3);
		n.springMove = -1;
		n.ballDisplay:SetText(te);
	end
	if(c)then
		local c = (n.currentValue - n.valueStart) / n.nextValue
		if(c >= 1)then
			if(n.extraLevel == 1)then
				E(e.SOUND_EXTRABALL1);
				t.range = 1;
			elseif(n.extraLevel == 2)then
				E(e.SOUND_EXTRABALL2);
				t.range = 2;
			else
				E(e.SOUND_EXTRABALL3);
			end
			e.stats[2] = e.stats[2] + 1;
			c = 0;
			n.freeDisplay2:SetText(P(n.nextValue));
			n.valueStart = n.nextValue;
			n.nextValue = n.nextValue + 5e4;
			d.freeState = 0;
			d.freeElapsed = 0;
			n.extraLevel = n.extraLevel + 1;
			local r, t, a, l, o, i;
			if(n.extraLevel == 1)then
				r, t, a = 0, 1, .7;
				l, o, i = 1, 0, 1;
			elseif(n.extraLevel == 2)then
				r, t, a = 1, 0, 1;
				l, o, i = 1, 1, 0;
			else
				r, t, a = 1, 1, 0;
				l, o, i = 1, 1, 0;
			end
			n.leftbar2Top:SetVertexColor(r, t, a, 1);
			n.rightbar2Top:SetVertexColor(r, t, a, 1);
			n.leftbar2Middle:SetVertexColor(r, t, a, 1);
			n.rightbar2Middle:SetVertexColor(r, t, a, 1);
			n.leftbar2Bottom:SetVertexColor(r, t, a, 1);
			n.rightbar2Bottom:SetVertexColor(r, t, a, 1);
			n.leftbar1Top:SetVertexColor(l, o, i, 1);
			n.rightbar1Top:SetVertexColor(l, o, i, 1);
			n.leftbar1Middle:SetVertexColor(l, o, i, 1);
			n.rightbar1Middle:SetVertexColor(l, o, i, 1);
			n.leftbar1Bottom:SetVertexColor(l, o, i, 1);
			n.rightbar1Bottom:SetVertexColor(l, o, i, 1);
			n.ballDisplay:Hide();
			n.freeDisplay1:SetAlpha(1);
			n.freeDisplay1:Show();
			n.freeDisplayGlow:SetAlpha(1);
			n.freeDisplayGlow:Show();
			if(e[e.newInfo[11]])then
				local t = ne;
				ne = 2;
				Oe(1, 8, e.boardHeight - 40)
				ne = t;
			else
				n:UpdateDisplay(2);
			end
		end
		local e = c * 300;
		if(e < 32)then
			n.leftbar1Bottom:Hide();
			n.rightbar1Bottom:Hide();
		else
			n.leftbar1Bottom:Show();
			n.rightbar1Bottom:Show();
		end
		n.leftbar1Top:SetPoint("TopLeft", n, "BottomLeft", 12, 12 + e);
	end
end
local function R(e)
	if(e == false)then
		if config.matchSaved then
			config.activeHero = config.matchSaved.hero;
			config.matchSaved = nil;
			config.ResyncTalents();
			if config.RefreshQuickPlayHero then
				config.RefreshQuickPlayHero();
			end
		end
		t.gameMenu:Hide();
		t.rainbow:Hide();
		r:Hide();
		t.artBorder:Hide();
		t.summaryScreen:Hide();
		t.summaryScreen.bragScreen:Hide();
		t.charPortrait:Hide();
		d:Hide();
		t.catagoryScreen:Show();
		t.fever1:Hide();
		t.fever2:Hide();
		t.fever3:Hide();
		t.feverPegScore:Hide();
		t.banner:Hide();
		t.banner.tex:Hide();
		if(V)then
			Ge();
		end
		Q = false;
		SetDesaturation(t.menuButton.background, true);
		t.menuButton:EnableMouse(false);
	else
		t.gameMenu:Hide();
		r:Show();
		t.artBorder:Show();
		d:Show();
		t.catagoryScreen:Hide();
		t.charPortrait:Show();
		Q = true;
		SetDesaturation(t.menuButton.background, false);
		t.menuButton:EnableMouse(true);
	end
end
local function J(d, l, s)
	local a = e.newInfo;
	local i, n, o;
	if not s then
		local r = l[a[2]];
		n = l[a[4]];
		o = gsub(l[a[5]], "+", "???");
		i = l[a[1]].."+1+"..n.."+"..o;
		t.network:Send(e.commands[15], i, "WHISPER", d)
		local o, c;
		local c = #r;
		n = "";
		o = 1;
		while(o <= c)do
			n = "";
			for e = o, o + 7 do
				if(e < c)then
					if(e < (o + 7))then
						n = n..r[e]..",";
					else
						n = n..r[e];
					end
				elseif(e == c)then
					n = n..r[e];
				end
			end
			i = l[a[1]].."+2+"..n;
			t.network:Send(e.commands[15], i, "WHISPER", d)
			o = o + 8;
		end
		r = l[a[3]];
		c = #r;
		n = "";
		o = 1;
		while(o <= c)do
			n = "";
			for e = o, o + 7 do
				if(e < c)then
					if(e < (o + 7))then
						n = n..r[e]..",";
					else
						n = n..r[e];
					end
				elseif(e == c)then
					n = n..r[e];
				end
			end
			i = l[a[1]].."+3+"..n;
			t.network:Send(e.commands[15], i, "WHISPER", d)
			o = o + 8;
		end
	else
		t.network:Send(e.commands[15], l[a[1]].."+4s+", "WHISPER", d);
	end
	n = l[g];
	for o = 1, #n, 200 do
		i = l[a[1]].."+4+"..c(n, o, xe(199 + o, #n));
		t.network:Send(e.commands[15], i, "WHISPER", d)
	end
	if not s then
		i = l[a[1]].."+5";
		t.network:Send(e.commands[15], i, "WHISPER", d)
	else
		t.network:Send(e.commands[15], l[a[1]].."+4e+", "WHISPER", d);
	end
end
local function pe(c, m, x, d, l, S, hero)
	local n = {};
	local t = e.newInfo;
	local r = UnitName("player");
	local i = h(time() * 100 + i((p(r) % 100)), 7);
	table.sort(l);
	e.cCount = e.cCount + 1;
	local a = {};
	local e = {};
	local f;
	for t = 1, #l do
		s(a, l[t]);
		s(e, l[t]);
	end
	o.TableRemove(e, r);
	n[t[1]] = i;
	n[t[2]] = a;
	n[t[3]] = e;
	n[t[4]] = r;
	n[t[5]] = S;
	n[t[6]] = true;
	n[t[7]] = d;
	local e, b, T, P = config.GetCompatDate()
	local f, S = GetGameTime();
	Fe(c);
	local a = #B;
	local e = {};
	local o, t;
	local o = "";
	for t = 1, a do
		s(e, t);
	end
	for n = 1, 25 do
		t = C(1, #e);
		o = o..h(u(e, t), 2);
	end
	local s = (ae * 9) ^ 2;
	local i;
	local a;
	for n = 1, 2 do
		t = C(1, #e);
		i = nil;
		while(i == nil)do
			if(a)then
				if(((B[e[t]].x - B[e[a]].x) ^ 2) + ((B[e[t]].y - B[e[a]].y) ^ 2)) < s then
					if(#e > 0)then
						t = C(1, #e);
					end
				else
					i = true;
				end
			else
				a = t;
				i = true;
			end
		end
		o = o..h(u(e, t), 2);
	end
	t = C(1, #e);
	o = o..h(u(e, t), 2);
	local e = "";
	for t = 1, #l do
		e = e..h(1e3, 2)..O(C(48, 90))..O(C(48, 90))..O(C(48, 90))..O(C(48, 90))
	end
	local e = U(""..h(c, 1)..h(m, 1)..h(x, 1)..h(hero or 0, 1)..h(d, 2)..h(f, 1)..h(S, 1)..h(T, 1)..h(b, 1)..h(P, 2)..o..e, p(r));
	n[g] = e
	collectgarbage();
	return n;
end
local function ge(n)
	local o = e.newInfo;
	local t = e.currentView;
	local e = L(n[g], p(n[o[4]]));
	if(e)then
		local i = S(O(W(e, 1)));
		local l = S(O(W(e, 2)));
		local r = S(O(W(e, 3)));
		local hero = S(c(e, 4, 4));
		local d = S(c(e, 5, 6));
		local a = S(O(W(e, 7)));
		local a = S(O(W(e, 8)));
		local a = S(O(W(e, 9)));
		local a = S(O(W(e, 10)));
		local a = S(c(e, 11, 12));
		local a = c(e, 69);
		local e, e, e, e = config.GetCompatDate()
		local e, e = GetGameTime();
		t[1] = n[o[4]];
		t[9] = hero;
		t[2] = d;
		t[3] = i;
		t[4] = l;
		t[5] = r;
		t[6] = n[o[5]];
		local l = t[7];
		local t = t[8];
		table.wipe(l);
		table.wipe(t);
		local e = n[o[2]];
		local n;
		for e = 1, #e do
			t[e] = S(c(a, (e - 1) * 6 + 1, (e - 1) * 6 + 2));
			l[e] = S(c(a, (e - 1) * 6 + 3, e * 6));
			if(t[e] == 1e3)then
				l[e] = -1;
			end
		end
	end
	return true;
end
-- Hero id a Battle was created with (0 = standard, no hero).
config.ChallengeHero = function(ch)
	local content = ch and L(ch[g], p(ch.creator));
	if content then
		return S(c(content, 4, 4)) or 0;
	end
	return 0;
end
-- Takes a Battle off this player's list (Cancel, Remove, or the creator cancelling it).
config.RemoveChallenge = function(ch)
	for i = #Y, 1, - 1 do
		if Y[i] == ch then
			table.remove(Y, i);
		end
	end
	if ch.creator == e.name and not ch.ended then
		e.cCount = math.max(0, e.cCount - 1);
	end
	local server = t.network.server;
	if server and server.tracking then
		for i = #server.tracking, 1, - 1 do
			if server.tracking[i] == ch then
				table.remove(server.tracking, i);
				table.remove(server.list, i);
			end
		end
		-- the server loop must never point at a Battle that is gone
		server.currentNode = 0;
		server.processing = nil;
		server.process = "";
		server.elapsed = 0;
		if #server.tracking == 0 then
			server.currentID = 1;
			server:Hide();
		elseif(server.currentID or 1) > #server.tracking or(server.currentID or 1) < 1 then
			server.currentID = 1;
		end
	end
	local page = t.catagoryScreen.frames[3];
	if page and page.content1 then
		page.content1.state = 0;
		page.content1.showID = nil;
		page.content1:Hide();
		if page:IsShown()then
			page.content1:Show();
		end
	end
end
-- The creator cancels a Battle: everyone invited is told, then it is removed here.
config.CancelChallenge = function(ch)
	for _, name in ipairs(ch.names or {})do
		if name ~= e.name then
			t.network:Send(e.commands[23], ch.id, "WHISPER", name);
		end
	end
	config.RemoveChallenge(ch);
end
local function X(n, n, e, ...)
	e = gsub(e, "%*", "");
	local e = {strsplit(",", e)};
	local n = t.catagoryScreen.frames[3].content2;
	local t = n.inviteList;
	local a, l;
	for n = 1, #e do
		l = strtrim(e[n]);
		o.TableInsertOnce(t, l);
	end
	table.sort(t);
	n.nameGrabber.elapsed = 0;
	return true
end
local function M(n, a, t, ...)
	local t = string.match(t, e.filterText);
	if(t)then
		if(e.onlineList[t])then
			e.onlineList[t] = nil;
			e.offlineList[t] = true;
			local o, n;
			local o = Y;
			for l = 1, #o do
				n = o[l];
				if(n.serverName == t)then
					local o;
					local o = n.names;
					local l = e.commands[12].."+"..n.id.."+";
					n.serverName = nil;
					for a = 1, #o do
						t = o[a];
						if(e.onlineList[t] == 2)then
							if not n.serverName then
								t = gsub(t, "^%l", string.upper);
								l = l..t;
								break;
							end
						end
					end
					if not n.serverName then
						for n = 1, #o do
							t = o[n];
							if(e.onlineList[t] == 2)then
								t = gsub(t, "^%l", string.upper);
								config.SendAddonMessage(e.addonName, l, "WHISPER", t);
							end
						end
					end
				end
			end
		end
		return a, true, ...
	end
end;
local function le()
	local n = e.sentList;
	local a = e.onlineList;
	local e = e.offlineList;
	table.wipe(n);
	table.wipe(e);
	table.wipe(a);
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", M)
	local i, o, i, e, l;
	local i = Y
	for t = 1, #i do
		o = i[t]
		o.serverName = nil;
		l = o.names;
		for t = 1, #l do
			e = gsub(l[t], "^%l", string.upper);
			if not n[e]then
				n[e] = true;
				a[e] = 1;
			end
		end
	end
	pinger = t.network.pinger;
	pinger.elapsed = 0;
	pinger.lastIndex = -1;
	pinger:Show();
end
local function ne(r)
	local n = t.network.pinger;
	if not r then
		local l, t, i, a, r, s, d, f, h;
		local l = Y
		t = 1;
		for p = 1, #l do
			l[t].serverName = nil;
			l[t].updating = nil;
			l[t].new = nil;
			l[t].dirty = nil;
			if(l[t].removed == true)or(l[t][g] == nil)or(l[t][g] == "")then
				u(l, t);
			else
				i = S(c(l[t][g], 3 + 5, 3 + 6));
				r = S(c(l[t][g], 3 + 7, 3 + 7));
				s = S(c(l[t][g], 3 + 8, 3 + 8));
				d = S(c(l[t][g], 3 + 9, 3 + 9));
				f = S(c(l[t][g], 3 + 10, 3 + 10));
				h = S(c(l[t][g], 3 + 11, 3 + 12));
				a = o.MinuteDifference(r, s, d, f, h);
				if(a >= i)then
					l[t].ended = true;
					a = a - i;
				end
				if(l[t].creator == e.name)and not l[t].ended then
					e.cCount = e.cCount + 1;
				end
				if(a >= i)then
					u(l, t);
				else
					l[t].elapsed = i - a;
					t = t + 1;
				end
			end
		end
		n.command = e.commands[8]
		n.data = "";
		n.state = 0;
		n.challengeIndex = 0;
		le();
	else
		local c, l, c, a, i, c, S, d;
		local h = e.sentList;
		local u = e.onlineList;
		local c = e.offlineList;
		local c = Y
		if(r == 1)then
			table.wipe(h);
			if(n.challengeIndex > 0)then
				l = c[n.challengeIndex]
				if not l.serverName then
					i = l.names;
					d = l.namesWithoutChallenge
					o.TableRemove(d, e.name);
					table.sort(i);
					for n = 1, #i do
						a = i[n];
						if(u[a] == 2)then
							S = o.TableFind(d, a);
							if not S then
								l.serverName = a
								if(a == e.name)then
									local n;
									local t = t.network.server;
									local n;
									for e = 1, #t.tracking do
										if(l == t.tracking[e])then
											n = true;
											break;
										end
									end
									if not n then
										l[e.newInfo[14]] = true;
										s(t.tracking, l);
										s(t.list, {{}, {}, {}, nil, nil});
										t:Populate(#t.list);
										if not t:IsShown()then
											t.currentID = 1;
											t.currentNode = 0;
										end
										t:Show();
									end
								end
								break;
							end
						end
					end
				end
			end
			n.challengeIndex = n.challengeIndex + 1;
			if(n.challengeIndex <= #c)then
				l = c[n.challengeIndex]
				l.serverName = nil;
				n.command = e.commands[10];
				n.data = l.id
				i = l.names;
				d = l.namesWithoutChallenge
				table.sort(i);
				for e = 1, #i do
					a = gsub(i[e], "^%l", string.upper);
					if(u[a] == 2)then
						S = o.TableFind(d, a);
						if not S then
							h[a] = true;
						end
					end
				end
				n.elapsed = 0;
				n.lastIndex = -1;
				n:Show();
				return;
			else
				n.state = 2;
				n.challengeIndex = 0;
				r = 2;
			end
		end
		if(r == 2)then
			table.wipe(h);
			n.challengeIndex = n.challengeIndex + 1;
			if(n.challengeIndex <= #c)then
				l = c[n.challengeIndex]
				if not l.ended then
					n.command = e.commands[16];
					n.data = l.id;
					i = l.namesWithoutChallenge
					for e = 1, #i do
						a = gsub(i[e], "^%l", string.upper);
						if(u[a] == 2)then
							h[a] = true;
						end
					end
					n.elapsed = 0;
					n.lastIndex = -1;
					n:Show();
					return;
				end
			else
				n.state = 3;
				n.challengeIndex = 0;
				r = 3;
			end
		end
	end
end
local function le()
	local c = t.artBorder;
	local s = e.artCut;
	local d = CreateFrame("ScrollFrame", "", c);
	d:SetWidth(64);
	d:SetHeight(300);
	d:SetPoint("BottomLeft", t.leftBorder, "BottomLeft",  - 8, 56);
	local a = CreateFrame("Frame", "", t);
	a:SetWidth(64);
	a:SetHeight(300);
	a:SetPoint("BottomLeft");
	d:SetScrollChild(a);
	d:SetVerticalScroll(0);
	local r = o:CreateCaption(0, 0, "9", c, 25, 0, 1, 0, true)
	r:ClearAllPoints();
	r:SetPoint("Center", t.leftBorder, "TopLeft", 36,  - 36);
	a.ballDisplay = r;
	local n = c:CreateTexture(nil, "OVERLAY");
	n:SetPoint("Center", c, "TopLeft", 43,  - 62);
	n:SetWidth(128);
	n:SetHeight(128);
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(s["glow"]));
	n:SetAlpha(1);
	n:SetVertexColor(0, 1, 0);
	n:Hide();
	a.freeDisplayGlow = n;
	local l = s["extraBallBottomCover"];
	n = a:CreateTexture(nil, "OVERLAY");
	n:SetPoint("BottomLeft");
	n:SetWidth(i((l[2] - l[1]) * 512 + .5));
	n:SetHeight(i((l[4] - l[3]) * 512 + .5));
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(l));
	l = s["extraBallTopCover"];
	n = a:CreateTexture(nil, "OVERLAY");
	n:SetPoint("BottomLeft", 16, 346 - 56);
	n:SetWidth(i((l[2] - l[1]) * 512 + .5));
	n:SetHeight(i((l[4] - l[3]) * 512 + .5));
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(l));
	l = s["extraBallBarTop"];
	n = d:CreateTexture(nil, "ARTWORK");
	n:SetPoint("TopLeft", a, "BottomLeft", 12, 12);
	n:SetWidth(i((l[2] - l[1]) * 512 + .5));
	n:SetHeight(i((l[4] - l[3]) * 512 + .5));
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(l));
	n:SetVertexColor(0, 1, .7, 0);
	a.leftbar2Top = n;
	n = d:CreateTexture(nil, "ARTWORK");
	n:SetPoint("Top", a.leftbar2Top, "Top");
	n:SetPoint("Left", a, "Left", 38, 0);
	n:SetWidth(i((l[2] - l[1]) * 512 + .5));
	n:SetHeight(i((l[4] - l[3]) * 512 + .5));
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(l[2], l[1], l[3], l[4]);
	n:SetVertexColor(0, 1, .7, 0);
	a.rightbar2Top = n;
	n = a:CreateTexture(nil, "BACKGROUND");
	n:SetPoint("TopLeft", a, "BottomLeft", 12, 12);
	n:SetWidth(i((l[2] - l[1]) * 512 + .5));
	n:SetHeight(i((l[4] - l[3]) * 512 + .5));
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(l));
	n:SetVertexColor(0, 1, .7);
	a.leftbar1Top = n;
	n = a:CreateTexture(nil, "BACKGROUND");
	n:SetPoint("Top", a.leftbar1Top, "Top");
	n:SetPoint("Left", a, "Left", 38, 0);
	n:SetWidth(i((l[2] - l[1]) * 512 + .5));
	n:SetHeight(i((l[4] - l[3]) * 512 + .5));
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(l[2], l[1], l[3], l[4]);
	n:SetVertexColor(0, 1, .7);
	a.rightbar1Top = n;
	l = s["extraBallBar"];
	n = d:CreateTexture(nil, "ARTWORK");
	n:SetPoint("TopRight", a.leftbar2Top, "BottomRight");
	n:SetPoint("BottomLeft", a, "BottomLeft", 12, 12);
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(l));
	n:SetVertexColor(0, 1, .7, 0);
	a.leftbar2Middle = n;
	n = d:CreateTexture(nil, "ARTWORK");
	n:SetPoint("TopRight", a.rightbar2Top, "BottomRight");
	n:SetPoint("BottomLeft", a, "BottomLeft", 38, 12);
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(l[2], l[1], l[3], l[4]);
	n:SetVertexColor(0, 1, .7, 0);
	a.rightbar2Middle = n;
	n = a:CreateTexture(nil, "BACKGROUND");
	n:SetPoint("TopRight", a.leftbar1Top, "BottomRight");
	n:SetPoint("BottomLeft", a, "BottomLeft", 12, 12);
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(l));
	n:SetVertexColor(0, 1, .7);
	a.leftbar1Middle = n;
	n = a:CreateTexture(nil, "BACKGROUND");
	n:SetPoint("Top", a.leftbar1Top, "Bottom");
	n:SetPoint("Right", a.rightbar1Top, "Right");
	n:SetPoint("BottomLeft", a, "BottomLeft", 38, 12);
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(l[2], l[1], l[3], l[4]);
	n:SetVertexColor(0, 1, .7);
	a.rightbar1Middle = n;
	l = s["extraBallBarBot"];
	n = d:CreateTexture(nil, "ARTWORK");
	n:SetPoint("BottomLeft", a, "BottomLeft", 12, 12);
	n:SetWidth(i((l[2] - l[1]) * 512 + .5));
	n:SetHeight(i((l[4] - l[3]) * 512 + .5));
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(l));
	n:SetVertexColor(0, 1, .7, 0);
	a.leftbar2Bottom = n;
	n = d:CreateTexture(nil, "ARTWORK");
	n:SetPoint("BottomLeft", a, "BottomLeft", 38, 12);
	n:SetWidth(i((l[2] - l[1]) * 512 + .5));
	n:SetHeight(i((l[4] - l[3]) * 512 + .5));
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(l[2], l[1], l[3], l[4]);
	n:SetVertexColor(0, 1, .7, 0);
	a.rightbar2Bottom = n;
	n = a:CreateTexture(nil, "ARTWORK");
	n:SetPoint("BottomLeft", a, "BottomLeft", 12, 12);
	n:SetWidth(i((l[2] - l[1]) * 512 + .5));
	n:SetHeight(i((l[4] - l[3]) * 512 + .5));
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(l));
	n:SetVertexColor(0, 1, .7);
	a.leftbar1Bottom = n;
	n = a:CreateTexture(nil, "ARTWORK");
	n:SetPoint("BottomLeft", a, "BottomLeft", 38, 12);
	n:SetWidth(i((l[2] - l[1]) * 512 + .5));
	n:SetHeight(i((l[4] - l[3]) * 512 + .5));
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(l[2], l[1], l[3], l[4]);
	n:SetVertexColor(0, 1, .7);
	a.rightbar1Bottom = n;
	a.leftbar1Top:SetPoint("TopLeft", a, "BottomLeft", 12, 297);
	a.leftbar2Top:SetPoint("TopLeft", a, "BottomLeft", 12, 297);
	r = o:CreateCaption(0, 0, e.locale["FREE_BALL2"], c, 18, 0, 1, 0, true)
	r:ClearAllPoints();
	r:SetPoint("Center", c, "TopLeft", 46,  - 62);
	a.freeDisplay1 = r;
	r:Hide();
	r = o:CreateCaption(0, 0, "25,000", c, 12, 0, 1, 0, true)
	r:ClearAllPoints();
	r:SetPoint("Center", c, "TopLeft", 46,  - 62);
	a.freeDisplay2 = r;
	r:Hide();
	t.ballTracker = a;
	a.extraLevel = 0;
	a.UpdateDisplay = re;
	a.ballQueue = {};
	a.ballStack = {};
	a.actionQueue = {};
	a:SetScript("OnUpdate", he);
	l = s["ballLoader"];
	n = a:CreateTexture(nil, "BACKGROUND");
	n:SetPoint("TopLeft", a, "BottomLeft", 17, 76);
	n:SetWidth(i((l[2] - l[1]) * 512 + .5));
	n:SetHeight(i((l[4] - l[3]) * 512 + .5));
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(l));
	a.ballSpring = n;
end
local function re()
	local d = t.artBorder;
	local r = e.artCut;
	local a = CreateFrame("Frame", "", d);
	a:SetWidth(48);
	a:SetHeight(300);
	a:SetPoint("BottomRight", t.rightBorder3, "BottomRight",  - 8, 54);
	local l = r["feverBottomCover"];
	local n = a:CreateTexture(nil, "OVERLAY");
	n:SetPoint("BottomLeft", 2, 0);
	n:SetWidth(i((l[2] - l[1]) * 512 + .5));
	n:SetHeight(i((l[4] - l[3]) * 512 + .5));
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(l));
	l = r["feverTopCover"];
	n = a:CreateTexture(nil, "OVERLAY");
	n:SetPoint("BottomLeft", 2, 293);
	n:SetWidth(i((l[2] - l[1]) * 512 + .5));
	n:SetHeight(i((l[4] - l[3]) * 512 + .5));
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(l));
	local o = o:CreateCaption(0, 0, "25", d, 25, 1, .69, 0, true)
	o:ClearAllPoints();
	o:SetPoint("Center", t.rightBorder1, "TopRight",  - 48,  - 36);
	a.text = o;
	a.bar = {};
	l = r["feverBar"];
	local o = i((l[4] - l[3]) * 512 + .5)
	local d;
	for t = 0, 24 do
		n = a:CreateTexture(nil, "ARTWORK");
		n:SetPoint("BottomLeft", 3, t * o + 5);
		n:SetWidth(i((l[2] - l[1]) * 512 + .5));
		n:SetHeight(i((l[4] - l[3]) * 512 + .5));
		n:SetTexture(e.artPath.."board1");
		n:SetTexCoord(unpack(l));
		s(a.bar, n);
	end
	a.normal = e.artCut["feverBar"];
	a.highlight = e.artCut["feverBarHighlight"];
	l = r["fever2x"];
	n = a:CreateTexture(nil, "OVERLAY");
	n:SetPoint("BottomLeft",  - 5, 512 - 336 - 62);
	n:SetWidth(i((l[2] - l[1]) * 512 + .5));
	n:SetHeight(i((l[4] - l[3]) * 512 + .5));
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(l));
	n.normal = r["fever2x"];
	n.highlight = r["fever2xHighlight"];
	s(a.bar, n);
	n.id = 2;
	l = r["fever3x"];
	n = a:CreateTexture(nil, "OVERLAY");
	n:SetPoint("BottomLeft",  - 5, 512 - 277 - 61);
	n:SetWidth(i((l[2] - l[1]) * 512 + .5));
	n:SetHeight(i((l[4] - l[3]) * 512 + .5));
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(l));
	n.normal = r["fever3x"];
	n.highlight = r["fever3xHighlight"];
	s(a.bar, n);
	n.id = 3;
	l = r["fever5x"];
	n = a:CreateTexture(nil, "OVERLAY");
	n:SetPoint("BottomLeft",  - 5, 512 - 229 - 60);
	n:SetWidth(i((l[2] - l[1]) * 512 + .5));
	n:SetHeight(i((l[4] - l[3]) * 512 + .5));
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(l));
	n.normal = r["fever5x"];
	n.highlight = r["fever5xHighlight"];
	s(a.bar, n);
	n.id = 5;
	l = r["fever10x"];
	n = a:CreateTexture(nil, "OVERLAY");
	n:SetPoint("BottomLeft",  - 5, 512 - 194 - 59);
	n:SetWidth(i((l[2] - l[1]) * 512 + .5));
	n:SetHeight(i((l[4] - l[3]) * 512 + .5));
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(l));
	n.normal = r["fever10x"];
	n.highlight = r["fever10xHighlight"];
	s(a.bar, n);
	n.id = 10;
	a.nextValue = {[10] = 1, [15] = 2, [19] = 3, [22] = 4, };
	a.UpdateDisplay = fe;
	a.Update = ce;
	t.feverTracker = a;
end
local function he()
	local n = CreateFrame("Frame", "", t.artBorder, config.backdroptmpl);
	n:SetPoint("Center", r, "Center", 0,  - 20)
	n:SetWidth(380);
	n:SetHeight(260);
	n:EnableMouse(true);
	n:SetFrameLevel(n:GetFrameLevel() + 3);
	n.noPublishHeight = 260;
	n.publishHeight = 260 + 40 + 4;
	n:SetMovable(true);
	n:RegisterForDrag("LeftButton");
	n:SetScript("OnDragStart", t:GetScript("OnDragStart"));
	n:SetScript("OnDragStop", t:GetScript("OnDragStop"));
	local c = e.GetBackdrop();
	c.edgeFile = e.artPath.."windowBorder";
	c.bgFile = e.artPath.."windowBackground";
	c.edgeSize = 32;
	c.tileSize = 64;
	c.tile = false;
	c.insets.right = 8;
	c.insets.left = 8;
	c.insets.top = 8;
	c.insets.bottom = 8;
	n:SetBackdrop(c);
	n:SetBackdropColor(.7, .7, .7, 1);
	local S = n;
	n:Hide();
	t.summaryScreen = n;
	n:SetScript("OnShow", function(n)
		t.fever1:Hide();
		t.fever2:Hide();
		t.fever3:Hide();
		t.feverPegScore:Hide();
		n:SetPoint("Center", r, "Center", 0,  - 20)
		d.temp1 = nil;
		d.temp2 = nil;
		t.rainbow:Hide();
		local o = 0;
		if(#d.animationStack == 0)then
			o = 2;
		elseif(G == (20 + 5))then
			o = 1;
		end
		if(t.duelStatus)then
			o = 3
			n.publish:Hide();
			n:SetHeight(n.noPublishHeight);
		elseif(e.extraInfo)then
			o = 4
			n.publish:Show();
			n:SetHeight(n.publishHeight);
		elseif(e[e.newInfo[13]])then
			o = 5
			n.publish:Show();
			n:SetHeight(n.publishHeight);
		else
			n.publish:Show();
			n:SetHeight(n.publishHeight);
		end
		local t = i(e.stats[3] / e.stats[7] * 100)
		n.title:SetText(e.locale["_SUMMARY_TITLE"..o]);
		n.best:SetFormattedText(n.best.caption1, P(levelScoreData[ee]))
		n.current:SetFormattedText(n.current.caption1, P(w))
		n.stat1:SetText(e.stats[1]);
		n.stat2:SetText(e.stats[2]);
		n.stat3:SetFormattedText("%d%%", t);
		n.stat4:SetText(P(e.stats[4]));
		n.stat5:SetText(P(e.stats[5]));
		n.stat6:SetText(P(e.stats[6]));
		n.publishInfo = P(w);
	end);
	local l = o:CreateCaption(0, 0, "", n, 25, 1, .82, 0, 1, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", 0,  - 36);
	n.title = l;
	local r = 20;
	local a = 74;
	l = o:CreateCaption(r, a + 24, e.locale["SUMMARY_SCORE_YOURS"], n, 23, 1, .82, 0, 1, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", n, "Top", 0,  - a + 2);
	l.caption1 = l:GetText();
	n.current = l;
	a = a + 32 - 2;
	local i = 17;
	l = o:CreateCaption(r, a, e.locale["SUMMARY_STAT1"], n, i, 1, .82, 0, nil, nil)
	l = o:CreateCaption(r, a, "", n, i, 1, 1, 1, nil, nil)
	l:ClearAllPoints();
	l:SetPoint("Topright", n, "Topleft", r + 144,  - a);
	n.stat1 = l;
	l = o:CreateCaption(r, a + ((i + 1) * 1), e.locale["SUMMARY_STAT2"], n, i, 1, .82, 0, nil, nil)
	l = o:CreateCaption(r, a, "", n, i, 1, 1, 1, nil, nil)
	l:ClearAllPoints();
	l:SetPoint("Topright", n, "Topleft", r + 144,  - a - ((i + 1) * 1));
	n.stat2 = l;
	l = o:CreateCaption(r, a + ((i + 1) * 2), e.locale["SUMMARY_STAT3"], n, i, 1, .82, 0, nil, nil)
	l = o:CreateCaption(r, a, "", n, i, 1, 1, 1, nil, nil)
	l:ClearAllPoints();
	l:SetPoint("Topright", n, "Topleft", r + 144,  - a - ((i + 1) * 2));
	n.stat3 = l;
	r = 170
	l = o:CreateCaption(r, a, e.locale["SUMMARY_STAT5"], n, i, 1, .82, 0, nil, nil)
	l = o:CreateCaption(r, a, "", n, i, 1, 1, 1, nil, nil)
	l:ClearAllPoints();
	l:SetPoint("Topright", n, "Topleft", r + 190,  - a);
	n.stat5 = l;
	l = o:CreateCaption(r, a + ((i + 1) * 1), e.locale["SUMMARY_STAT6"], n, i, 1, .82, 0, nil, nil)
	l = o:CreateCaption(r, a, "", n, i, 1, 1, 1, nil, nil)
	l:ClearAllPoints();
	l:SetPoint("Topright", n, "Topleft", r + 190,  - a - ((i + 1) * 1));
	n.stat6 = l;
	l = o:CreateCaption(r, a + ((i + 1) * 2), e.locale["SUMMARY_STAT4"], n, i, 1, .82, 0, nil, nil)
	l = o:CreateCaption(r, a, "", n, i, 1, 1, 1, nil, nil)
	l:ClearAllPoints();
	l:SetPoint("Topright", n, "Topleft", r + 190,  - a - ((i + 1) * 2));
	n.stat4 = l;
	l = o:CreateCaption(r, a, e.locale["SUMMARY_SCORE_BEST"], n, i, 1, .82, 0, nil, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", n, "Top", 0,  - a - 66);
	l.caption1 = l:GetText();
	n.best = l;
	n = m(0, 0, 40, "buttonPublish", true, "sumPublish", S, function(e)
		t.summaryScreen.publishDuel = nil;
		t.summaryScreen.bragScreen:SetParent(t.summaryScreen);
		t.summaryScreen.bragScreen:SetFrameLevel(t.summaryScreen:GetFrameLevel() + 10);
		t.summaryScreen.bragScreen:Show();
	end, nil, true)
	n:ClearAllPoints();
	n:SetPoint("Bottom",  - 1, 16 + 44);
	S.publish = n;
	n = m(0, 0, 40, "buttonOkay", nil, "sumOkay", S, function(e)
		e.publishInfo = nil;
		R(false);
		if(PeggleForeverData.settings.closePeggleLoot == true)then
			t:Hide();
		end
	end)
	n:ClearAllPoints();
	n:SetPoint("Bottom", 0, 16);
	n:Show();
	n = CreateFrame("Frame", "", S, config.backdroptmpl);
	n:SetPoint("Bottom", 0, 10)
	n:SetWidth(340);
	n:SetHeight(200);
	n:EnableMouse(true);
	n:SetFrameLevel(n:GetFrameLevel() + 3);
	S.bragScreen = n;
	n:Hide();
	n:SetScript("OnHide", function(e)
		t.summaryScreen.publishDuel = nil;
		e:SetParent(t.summaryScreen);
		e:SetFrameLevel(e:GetParent():GetFrameLevel() + 10);
	end);
	n:SetBackdrop(c);
	n:SetBackdropColor(.7, .7, .7, 1);
	n.serverChannels = {};
	n.channelNames = {};
	n.refreshChannels = function(t, ...)
		table.wipe(t.serverChannels);
		local e;
		for e = 1, #(...)do
			s(t.serverChannels, (select(e, ...)));
		end
		table.wipe(t.channelNames);
		local e, n
		for n = 1, 15 do
			_, e = GetChannelName(n);
			if(e)then
				for n = 1, #t.serverChannels do
					if(string.find(e, t.serverChannels[n]))then
						e = nil;
						break;
					end
				end
				if(e)then
					s(t.channelNames, e)
				end
			end
		end
	end
	l = o:CreateCaption(0, 0, e.locale["BRAG"], n, i, 1, .82, 0, nil, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", 0,  - 36);
	l:SetWidth(290);
	local o = We(40, 72, 240, "defaultPublish", "", nil, n, nil);
	o.publish = true;
	local e = m(0, 0, 40, "buttonPublish", true, "bragPublish", n, function(n)
		local n = t.summaryScreen;
		local l = GetChannelName(PeggleForeverData.settings.defaultPublish);
		local o;
		if not n.publishDuel then
			n:SetHeight(n.noPublishHeight);
			o = string.format(e.locale["_PUBLISH_SCORE"], UnitName("player"), n.publishInfo, LEVEL_NAMES[ee]);
		else
			o = n.publishInfo
		end
		if(l > 0)then
			SendChatMessage(o, "CHANNEL", nil, l);
		else
			SendChatMessage(o, PeggleForeverData.settings.defaultPublish);
		end
		n.bragScreen:Hide();
		if not n.publishDuel then
			n:Show();
		end
		n.publish:Hide();
		t.catagoryScreen.frames[2].publish:Hide();
		n.publishDuel = nil;
		n.publishInfo = nil;
	end, nil, true)
	e:ClearAllPoints();
	e:SetPoint("Bottomleft", 16, 16);
	e = m(0, 0, 40, "buttonBack", nil, "bragBack", n, function(e)
		e:GetParent():Hide();
		t.summaryScreen:Show();
	end, nil, true)
	e:ClearAllPoints();
	e:SetPoint("Bottomright",  - 16, 16);
end
local function ce()
	local n = CreateFrame("Frame", "", t.artBorder, config.backdroptmpl);
	n:SetPoint("Center", r, "Center", 0,  - 20)
	n:SetWidth(240);
	n:SetHeight(214);
	n:EnableMouse(true);
	n:SetFrameLevel(n:GetFrameLevel() + 4);
	local l = e.GetBackdrop();
	l.tileSize = 128;
	l.tile = false;
	l.edgeFile = "Interface\\Glues\\Common\\TextPanel-Border"l.edgeSize = 32;
	l.bgFile = e.artPath.."windowBackground";
	n:SetBackdrop(l);
	n:SetBackdropColor(.7, .7, .7, 1);
	n:SetBackdropBorderColor(1, .8, .45);
	local l = n;
	n:Hide();
	t.gameMenu = n;
	n:SetScript("OnShow", function(n)
		d:Hide();
		if(e[e.newInfo[13]])or(e.extraInfo)or((t.duelStatus == 3)and t.catagoryScreen.frames[2].player1.value == -1)then
			SetDesaturation(n.restart.background, true);
			n.restart:EnableMouse(false);
		else
			SetDesaturation(n.restart.background, false);
			n.restart:EnableMouse(true);
		end
	end);
	n:SetScript("OnHide", function(e)
		d:Show();
	end);
	local o = o:CreateCaption(0, 0, e.locale["MENU"], n, 25, 1, .82, 0, 1, nil)
	o:ClearAllPoints();
	o:SetPoint("Top", 0,  - 20);
	n = m(0, 0, 40, "buttonAbandonGame", true, "menuAbandon", l, function(o)
		if(t.duelStatus == 3)then
			local n = t.catagoryScreen.frames[2];
			config.SendAddonMessage(t.network.prefix, e.commands[6], "WHISPER", n.name2:GetText());
			n.player1.value = -2;
			n:UpdateWinners();
			if(PeggleForeverData.settings.closeDuelChallenge == true)then
				t.duelStatus = nil;
				t:Hide();
			end
		end
		de = true;
		R(false);
		o:GetParent():Hide();
	end)
	n:ClearAllPoints();
	n:SetPoint("Top", 0,  - 56);
	n = m(0, 0, 40, "buttonRestartLevel", nil, "menuRestart", l, function(t)
		Ae(Qe, e.extraInfo);
		t:GetParent():Hide();
	end)
	n:ClearAllPoints();
	n:SetPoint("Top", 0,  - 106);
	l.restart = n;
	n = m(0, 0, 40, "buttonReturnToGame", nil, "menuReturn", l, function(e)
		e:GetParent():Hide();
	end)
	n:ClearAllPoints();
	n:SetPoint("Top", 0,  - 156);
	return l;
end
-- Applies the active hero: engine power family, power name, shooter portrait and
-- that hero's talent ranks.
-- Clips a texture to a circle (for round frames) with a mask texture; skipped if the client lacks masks.
config.RoundMask = function(tex, size)
	if tex.roundMask then
		tex.roundMask:SetWidth(size);
		tex.roundMask:SetHeight(size);
		return;
	end
	if not tex.GetParent then
		return;
	end
	local parent = tex:GetParent();
	if parent and parent.CreateMaskTexture then
		local mask = parent:CreateMaskTexture();
		mask:SetTexture(e.artPath.."fx_circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE");
		mask:SetPoint("Center", tex, "Center");
		mask:SetWidth(size);
		mask:SetHeight(size);
		tex:AddMaskTexture(mask);
		tex.roundMask = mask;
	end
end
config.ApplyHero = function(skipUI)
	local hero = config.GetHero(config.activeHero);
	if not hero then
		return;
	end
	K = 0;
	if(hero.power == "guide")then
		oe = me;
	else
		oe = tt;
	end
	ye = hero.powerName;
	config.heroMode = hero.power;
	e.ResetPowerState();
	if t.shooter and t.shooter.face then
		config.SetPortrait(t.shooter.face, hero, nil, nil, 52, true);
		t.shooter.face:SetWidth(76);
		t.shooter.face:SetHeight(76);
		config.RoundMask(t.shooter.face, 76);
	end
	et();
	if not skipUI then
		Ve();
	end
	if config.RefreshHeroHeader then
		config.RefreshHeroHeader();
	end
	if config.RefreshQuickPlayHero then
		config.RefreshQuickPlayHero();
	end
end
-- Re-reads the active hero's talent ranks into the game and refreshes the Talents tab.
config.ResyncTalents = function()
	et();
	Ve();
	if config.RefreshHeroHeader then
		config.RefreshHeroHeader();
	end
end
-- Simple yes/no confirmation dialog: config.Confirm("Are you sure?", function() ... end)
config.Confirm = function(text, onAccept)
	local box = config.confirmBox;
	if not box then
		box = CreateFrame("Frame", "", t, config.backdroptmpl);
		box:SetFrameStrata("FULLSCREEN_DIALOG");
		box:SetWidth(340);
		box:SetHeight(150);
		box:SetPoint("Center", t, "Center", 0, 0);
		box:EnableMouse(true);
		local bd = e.GetBackdrop();
		bd.tileSize = 64;
		bd.tile = false;
		bd.edgeFile = e.artPath.."windowBorder";
		bd.edgeSize = 32;
		bd.insets.right = 3;
		bd.bgFile = e.artPath.."windowBackground";
		box:SetBackdrop(bd);
		box:SetBackdropColor(.5, .5, .5, 1);
		box:SetBackdropBorderColor(1, 1, 1);
		box.text = box:CreateFontString(nil, "OVERLAY", "GameFontNormal");
		box.text:SetPoint("Top", 0,  - 28);
		box.text:SetWidth(290);
		box.yes = CreateFrame("Button", nil, box, "UIPanelButtonTemplate");
		config.StyleButton(box.yes);
		box.yes:SetWidth(100);
		box.yes:SetHeight(26);
		box.yes:SetPoint("BottomLeft", 50, 22);
		box.yes:SetText("Yes");
		box.yes:SetScript("OnClick", function()
			box:Hide();
			if box.onAccept then
				box.onAccept();
			end
		end);
		box.no = CreateFrame("Button", nil, box, "UIPanelButtonTemplate");
		config.StyleButton(box.no);
		box.no:SetWidth(100);
		box.no:SetHeight(26);
		box.no:SetPoint("BottomRight",  - 50, 22);
		box.no:SetText("No");
		box.no:SetScript("OnClick", function()
			box:Hide();
		end);
		box:Hide();
		config.confirmBox = box;
	end
	box.text:SetText(text);
	box.onAccept = onAccept;
	box:SetFrameLevel(t:GetFrameLevel() + 220);
	box:Show();
end
local function fe()
	local owner = o;
	local heroes = config.heroes;
	-- parented to the main window (not the board) so it stays visible while the menu screens are up
	local n = CreateFrame("Frame", "", t, config.backdroptmpl);
	n:SetPoint("Center", t, "Center", 0, 0)
	n:SetWidth(520);
	n:SetHeight(480);
	n:SetFrameStrata("DIALOG");
	n:EnableMouse(true);
	-- same border art as the main Peggle window so the screen has a proper frame
	local l = e.GetBackdrop();
	l.tileSize = 64;
	l.tile = false;
	l.edgeFile = e.artPath.."windowBorder";
	l.edgeSize = 32;
	l.insets.right = 3;
	l.bgFile = e.artPath.."windowBackground";
	n:SetBackdrop(l);
	n:SetBackdropColor(.7, .7, .7, 1);
	n:SetBackdropBorderColor(1, 1, 1);
	n:Hide();
	t.charScreen = n;
	-- the Quick Play level list never shows through the hero select screen
	n:HookScript("OnShow", function()
		if t.levelList then
			t.levelList:Hide();
		end
	end);
	n:HookScript("OnHide", function()
		local quickPlay = t.catagoryScreen and t.catagoryScreen.frames[1];
		if t.levelList and quickPlay and quickPlay:IsShown() then
			t.levelList:SetParent(quickPlay);
			t.levelList:Show();
		end
	end);
	local a = n;

	local title = n:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	title:SetPoint("Top", 0,  - 36);
	title:SetText("CHOOSE YOUR HERO");

	local close = CreateFrame("Button", nil, n, "UIPanelCloseButton");
	close:SetPoint("TopRight", -4, -4);

	local border = e.GetBackdrop();
	border.tileSize = 128;
	border.tile = false;
	border.edgeFile = e.artPath.."CharSelectBorder";

	local buttons = {};
	local selected;
	local info = {};

	info.name = n:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	info.name:SetPoint("Top", 0,  - 318);
	info.sub = n:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	info.sub:SetPoint("Top", info.name, "Bottom", 0,  - 4);
	info.icon = n:CreateTexture(nil, "ARTWORK");
	info.icon:SetWidth(22);
	info.icon:SetHeight(22);
	info.power = n:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	info.power:SetPoint("Top", info.sub, "Bottom", 0,  - 10);
	info.power:SetTextColor(.5, 1, .5);
	info.icon:SetPoint("Right", info.power, "Left",  - 6, 0);
	info.desc = n:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	info.desc:SetPoint("Top", info.power, "Bottom", 0,  - 4);
	info.desc:SetWidth(440);

	local function select(id)
		selected = id;
		for i = 1, #buttons do
			local b = buttons[i];
			if(i == id)then
				b:SetBackdropBorderColor(1, .9, .4);
				b.icon:SetVertexColor(1, 1, 1);
			else
				b:SetBackdropBorderColor(.62, .46, .2);
				b.icon:SetVertexColor(.55, .55, .55);
			end
		end
		local hero = heroes[id];
		if hero then
			info.name:SetText(hero.name);
			info.sub:SetText(hero.title.." - "..hero.race);
			info.power:SetText(hero.powerName);
			info.desc:SetText(hero.powerDesc);
			info.icon:SetTexture(hero.icon);
			info.icon:SetTexCoord(0, 1, 0, 1);
			info.icon:Show();
		else
			info.icon:Hide();
			info.name:SetText("");
			info.sub:SetText("Pick a leader to play as. Each hero keeps their own talents.");
			info.power:SetText("");
			info.desc:SetText("");
		end
	end

	local rowY = {Alliance =  - 84, Horde =  - 210};
	local rowCount = {Alliance = 0, Horde = 0};
	for faction, y in pairs(rowY) do
		local header = n:CreateFontString(nil, "OVERLAY", "GameFontNormal");
		header:SetPoint("Top", 0, y + 24);
		header:SetText(string.upper(faction));
		if(faction == "Alliance")then
			header:SetTextColor(.3, .55, 1);
		else
			header:SetTextColor(1, .25, .25);
		end
	end
	for i = 1, #heroes do
		local hero = heroes[i];
		local b = CreateFrame("Button", nil, n, config.backdroptmpl);
		b:SetWidth(88);
		b:SetHeight(88);
		local col = rowCount[hero.faction];
		rowCount[hero.faction] = col + 1;
		b:SetPoint("TopLeft", 39 + col * 118, rowY[hero.faction]);
		b:SetBackdrop(border);
		b:SetBackdropColor(0, 0, 0, 0);
		b:SetBackdropBorderColor(.62, .46, .2);
		local icon = b:CreateTexture(nil, "Background");
		icon:SetWidth(64);
		icon:SetHeight(64);
		icon:SetPoint("Center", 0, 6);
		config.SetPortrait(icon, hero);
		icon:ClearAllPoints();
		icon:SetPoint("TopLeft", b, "TopLeft", 5,  - 5);
		icon:SetPoint("BottomRight", b, "BottomRight",  - 5, 5);
		if icon.model then
			icon.model:ClearAllPoints();
			icon.model:SetPoint("TopLeft", b, "TopLeft", 5,  - 5);
			icon.model:SetPoint("BottomRight", b, "BottomRight",  - 5, 5);
		end
		b.icon = icon;
		-- small ability icon in the corner, and the hero's level (talent points) on the portrait;
		-- they live on a frame above the 3D head model
		local top = CreateFrame("Frame", nil, b);
		top:SetAllPoints(b);
		top:SetFrameLevel(b:GetFrameLevel() + 10);
		local badge = top:CreateTexture(nil, "Overlay");
		badge:SetWidth(24);
		badge:SetHeight(24);
		badge:SetPoint("TopRight",  - 6,  - 6);
		badge:SetTexture(hero.icon);
		badge:SetTexCoord(0, 1, 0, 1);
		local level = top:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
		level:SetPoint("TopLeft", 8,  - 8);
		level:SetTextColor(1, 1, .4);
		b.level = level;
		local label = top:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
		label:SetPoint("Bottom", 0, 6);
		label:SetWidth(84);
		label:SetText(hero.short or string.match(hero.name, "^(%S+)") or hero.name);
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:ClearLines();
			GameTooltip:AddLine(hero.name, 1, .82, 0);
			GameTooltip:AddLine(hero.title.." - "..hero.race, 1, 1, 1);
			GameTooltip:AddLine(" ");
			GameTooltip:AddLine("|T"..hero.icon..":28|t "..hero.powerName, .5, 1, .5);
			GameTooltip:AddLine(hero.powerDesc, 1, 1, 1, true);
			GameTooltip:AddLine(" ");
			GameTooltip:AddLine("Level "..config.HeroPoints(i), 1, 1, .4);
			GameTooltip:Show();
		end);
		b:SetScript("OnLeave", function()
			GameTooltip:Hide();
		end);
		b:SetScript("OnClick", function()
			select(i);
		end);
		buttons[i] = b;
	end

	n:SetScript("OnShow", function(self)
		-- sit above the category/talent screens, which are drawn over the board
		self:SetFrameLevel(t:GetFrameLevel() + 150);
		for i = 1, #buttons do
			buttons[i].level:SetText("Lv "..config.HeroPoints(i));
		end
		select(config.activeHero);
	end);

	local ok = m(0, 0, 40, "buttonOkay", nil, "charOkay", a, function(self)
		if not selected then
			return;
		end
		config.SetHero(selected);
		config.ApplyHero();
		config.PlayHeroVoice(true);
		self:GetParent():Hide();
	end)
	ok:ClearAllPoints();
	ok:SetPoint("Bottom", 0, 16);
	return a;
end
local function me()
	local n = CreateFrame("Frame", "", t.catagoryScreen, config.backdroptmpl);
	n:SetPoint("TopLeft", 5,  - 9)
	n:SetPoint("BottomRight",  - 4, 4);
	local d = e.GetBackdrop();
	d.tileSize = 128;
	d.edgeFile = "Interface\\Glues\\Common\\TextPanel-Border"d.edgeSize = 32;
	n:SetBackdrop(d);
	n:SetBackdropColor(0, 0, 0, .5);
	n:SetBackdropBorderColor(1, 1, 1);
	n:SetFrameLevel(t.catagoryScreen:GetFrameLevel() + 1);
	s(t.catagoryScreen.frames, n);
	local a = n;
	n:Hide();
	n.showID = 1;
	-- who is playing: portrait, name and level (talent points) of the active hero
	local heroPortrait = n:CreateTexture(nil, "ARTWORK");
	heroPortrait:SetWidth(46);
	heroPortrait:SetHeight(46);
	heroPortrait:SetPoint("TopLeft", 22,  - 20);
	local heroFrame = e.GetBackdrop();
	heroFrame.tileSize = 128;
	heroFrame.tile = false;
	heroFrame.edgeFile = e.artPath.."CharSelectBorder";
	heroFrame.edgeSize = 16;
	heroFrame.bgFile = nil;
	local heroBorder = CreateFrame("Frame", nil, n, config.backdroptmpl);
	heroBorder:SetPoint("TopLeft", heroPortrait, "TopLeft",  - 5, 5);
	heroBorder:SetPoint("BottomRight", heroPortrait, "BottomRight", 5,  - 5);
	heroBorder:SetFrameLevel(n:GetFrameLevel() + 6);
	heroBorder:SetBackdrop(heroFrame);
	heroBorder:SetBackdropColor(0, 0, 0, 0);
	heroBorder:SetBackdropBorderColor(1, .82, .35);
	-- hovering the portrait shows the hero's ability with its icon
	local heroHover = CreateFrame("Button", nil, n);
	heroHover:SetPoint("TopLeft", heroPortrait, "TopLeft",  - 5, 5);
	heroHover:SetPoint("BottomRight", heroPortrait, "BottomRight", 5,  - 5);
	heroHover:SetScript("OnEnter", function(self)
		local hero = config.GetHero(config.activeHero);
		if not hero then
			return;
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:ClearLines();
		GameTooltip:AddLine(hero.name, 1, .82, 0);
		GameTooltip:AddLine(hero.title.." - "..hero.race, 1, 1, 1);
		GameTooltip:AddLine(" ");
		GameTooltip:AddLine("|T"..hero.icon..":28|t "..hero.powerName, .5, 1, .5);
		GameTooltip:AddLine(hero.powerDesc, 1, 1, 1, true);
		GameTooltip:Show();
	end);
	heroHover:SetScript("OnLeave", function()
		GameTooltip:Hide();
	end);
	config.heroHover = heroHover;
	local heroName = n:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	heroName:SetPoint("TopLeft", heroPortrait, "TopRight", 14,  - 4);
	local heroLevel = n:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	heroLevel:SetPoint("TopLeft", heroName, "BottomLeft", 0,  - 4);
	local heroChange = CreateFrame("Button", nil, n, "UIPanelButtonTemplate");
	config.StyleButton(heroChange);
	heroChange:SetWidth(90);
	heroChange:SetHeight(22);
	heroChange:SetPoint("TopRight",  - 14,  - 14);
	heroChange:SetText("Choose Hero");
	heroChange:SetScript("OnClick", function()
		t.charScreen:Show();
	end);
	local heroStats = CreateFrame("Button", nil, n, "UIPanelButtonTemplate");
	config.StyleButton(heroStats);
	heroStats:SetWidth(90);
	heroStats:SetHeight(22);
	heroStats:SetPoint("TopRight",  - 14,  - 40);
	heroStats:SetText("Stats");
	heroStats:SetScript("OnClick", function()
		config.ShowStats();
	end);
	config.RefreshQuickPlayHero = function()
		local hero = config.GetHero(config.activeHero);
		if hero then
			config.SetPortrait(heroPortrait, hero);
			heroPortrait:Show();
			heroBorder:Show();
			heroName:SetText("|cFFFFFFFF"..hero.name.."|r");
			heroLevel:SetText("Level "..config.HeroPoints(config.activeHero).."  |cFF999999"..hero.race.."|r");
		else
			heroPortrait:Hide();
			heroBorder:Hide();
			heroName:SetText("No hero chosen");
			heroLevel:SetText("|cFF999999Click Choose Hero|r");
		end
	end
	t.fontObj = CreateFont("PeggleDropdownFont");
	t.fontObj:SetFont(config.fontBody, 16, "");
	t.fontObj.oldSetFont = t.fontObj.SetFont;
	t.fontObj.oldGetFont = t.fontObj.GetFont;
	t.fontObj.oldGetFontObject = t.fontObj.GetFontObject;
	t.fontObj.blankFunc = function()end;
	t.fontObj.SetFont = t.fontObj.blankFunc
	t.fontObj.GetFontObject = t.fontObj.blankFunc
	t.fontObj.GetFont = t.fontObj.blankFunc
	n:SetScript("OnShow", function(e)
		config.RefreshQuickPlayHero();
		config.ApplyQuickPlayLayout();
		e:UpdateDisplay(e.showID);
		t.levelList:SetParent(e);
		t.levelList:UpdateList();
		t.levelList:Show();
	end);
	n.UpdateDisplay = function(n, t)
		local o = levelScoreData[t];
		if n.levelTitle then
			n.levelTitle:SetText(LEVEL_NAMES[t] or "");
		end
		if(o == 0)then
			n.beatLevel:Show();
			n.best:Hide();
			n.points:Hide();
			n.mostRecentFrame:Hide();
		else
			n.beatLevel:Hide();
			n.best:Show();
			n.points:Show();
			n.points:SetText(P(o));
			n.mostRecentFrame:Show();
			n.mostRecentPoints:SetText(P(PeggleForeverData.recent[t] or o));
		end
		local o = levelScoreData[t + #LEVELS];
		local t;
		t = n.talent2;
		if(o == 3)then
			t:SetText(t.caption2)
			t.tex:SetTexCoord(unpack(t.tex.on));
			t:SetVertexColor(0, 1, 0);
		else
			t:SetText(t.caption1)
			t.tex:SetTexCoord(unpack(t.tex.off));
			t:SetVertexColor(1, 1, 0);
		end
		t = n.talent1;
		if(o >= 2)then
			t:SetText(t.caption2)
			t.tex:SetTexCoord(unpack(t.tex.on));
			t:SetVertexColor(0, 1, 0);
		else
			t:SetText(t.caption1)
			t.tex:SetTexCoord(unpack(t.tex.off));
			t:SetVertexColor(1, 1, 0);
		end
		n.levelImage:SetTexture(e.artPath.."bg"..n.showID.."_thumb");
	end
	local l = o:CreateCaption(0, 0, e.locale["QUICK_PLAY"], n, 25, .05, .66, 1, 1, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", 0,  - 22);
	local c = CreateFrame("Frame", "", a);
	c:SetPoint("TopLeft")
	c:SetPoint("BottomRight");
	t.levelList = c;
	c.UpdateList = function(e)
		local t, n;
		for t = 1, #LEVELS do
			n = levelScoreData[t + #LEVELS];
			if(n == 3)then
				e["flag"..t.."a"]:Show();
				e["flag"..t.."b"]:Show();
			elseif(n == 2)then
				e["flag"..t.."a"]:Show();
				e["flag"..t.."b"]:Hide();
			else
				e["flag"..t.."a"]:Hide();
				e["flag"..t.."b"]:Hide();
			end
			e["highlight"..t].tex:SetAlpha(0);
		end
		e["highlight"..e:GetParent().showID].tex:SetAlpha(1);
	end
	l = o:CreateCaption(0, 0, e.locale["SELECT_LEVEL"], c, 20, 1, .82, 0, 1, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", c, "Topleft", 170,  -84);
	local r = CreateFrame("Frame", "", c, config.backdroptmpl);
	r:SetPoint("Topleft", 20,  -104)
	r:SetPoint("Bottomleft", 20, 70);
	r:SetWidth(300);
	d.bgFile = e.artPath.."windowBackground";
	d.tileSize = 128;
	d.tile = false;
	r:SetBackdrop(d);
	r:SetBackdropColor(0, 0, 0, .5);
	r:SetBackdropBorderColor(1, .8, .45);
	-- the level rows live in a scroll frame inside the box, so nothing is ever drawn outside it
	local scroller = CreateFrame("ScrollFrame", nil, r);
	-- inset past the border art, so rows slide behind the frame instead of over it
	scroller:SetPoint("TopLeft", r, "TopLeft", 6,  - 6);
	scroller:SetPoint("BottomRight", r, "BottomRight",  - 6, 6);
	local holder = CreateFrame("Frame", nil, scroller);
	holder:SetPoint("TopLeft", scroller, "TopLeft", 0, 0);
	holder:SetWidth(288);
	holder:SetHeight(14 * #LEVELS + 20);
	scroller:SetScrollChild(holder);
	c.rowHolder = holder;
	c.scroll = 0;
	local function rowVisible(id)
		local first = c.scroll;
		local rows = math.floor((r:GetHeight() - 12) / 14);
		return id > first and id <= first + rows;
	end
	local s = function(e)
		if not rowVisible(e:GetID()) then
			return;
		end
		a = e:GetParent():GetParent():GetParent():GetParent():GetParent();
		if(a.showID ~= e:GetID())then
			e.tex:SetAlpha(.5);
		end
	end
	local S = function(e)
		a = e:GetParent():GetParent():GetParent():GetParent():GetParent();
		if(a.showID ~= e:GetID())then
			e.tex:SetAlpha(0);
		end
	end
	local h = function(e)
		if not rowVisible(e:GetID()) then
			return;
		end
		local t = e:GetParent():GetParent():GetParent():GetParent():GetParent();
		if(t.showID ~= e:GetID())then
			e:GetParent():GetParent():GetParent():GetParent()["highlight"..t.showID].tex:SetAlpha(0);
			t.showID = e:GetID();
			t:UpdateDisplay(e:GetID());
			e.tex:SetAlpha(1);
		end
	end
	local u, t, u;
	for a = 1, #LEVELS do
		l = o:CreateCaption(4, 4 + (a - 1) * 14, a, holder, 14, 1, 1, 1, 1, nil)
		l:SetWidth(32);
		l:SetHeight(14);
		l:SetJustifyH("LEFT")
		l = o:CreateCaption(36, 4 + (a - 1) * 14, LEVEL_NAMES[a], holder, 12, 1, 1, 1, 1, nil)
		l:SetWidth(300 - 42 - 42);
		l:SetHeight(14);
		t = holder:CreateTexture(nil, "Overlay");
		t:SetWidth(14);
		t:SetHeight(14);
		t:SetPoint("Topright",  - 4 - 16,  - 3 - (a - 1) * 14);
		t:SetTexture(e.artPath.."bannerSmallRed");
		c["flag"..a.."a"] = t;
		t = holder:CreateTexture(nil, "Overlay");
		t:SetWidth(14);
		t:SetHeight(14);
		t:SetPoint("Topright",  - 4,  - 3 - (a - 1) * 14);
		t:SetTexture(e.artPath.."bannerSmallBlue");
		c["flag"..a.."b"] = t;
		n = CreateFrame("Frame", "", holder);
		n:SetWidth(280);
		n:SetHeight(16);
		n:SetPoint("Topleft", 4, -2 - (a - 1) * 14);
		n:SetScript("OnEnter", s);
		n:SetScript("OnLeave", S);
		n:SetScript("OnMouseUp", h);
		n.tex = holder:CreateTexture(nil, "Artwork");
		n.tex:SetAllPoints(n);
		n.tex:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight");
		config.ListHighlight(n.tex);
		n.tex:SetAlpha(0);
		n.tex:SetBlendMode("ADD");
		n:EnableMouse(true);
		n:SetID(a);
		c["highlight"..a] = n;
	end
	do
		local slider = CreateFrame("Slider", "Peggle_levelListSlider", c, "UIPanelScrollBarTemplate");
		config.FixScrollThumb(slider);
		slider:SetPoint("TopLeft", r, "TopRight", 2, -34);
		slider:SetPoint("BottomLeft", r, "BottomRight", 2, 34);
		slider:SetValueStep(1);
		local function setScroll(value)
			c.scroll = value;
			scroller:SetVerticalScroll(value * 14);
		end
		slider:SetScript("OnValueChanged", function(self, value)
			setScroll(math.floor((value or 0) + .5));
		end);
		local function resize()
			local visible = math.floor((r:GetHeight() - 12) / 14);
			local extra = math.max(0, #LEVELS - visible);
			slider:SetMinMaxValues(0, extra);
			if slider:GetValue() > extra then
				slider:SetValue(extra);
			end
			if extra == 0 then
				slider:Hide();
			else
				slider:Show();
			end
		end
		c.UpdateScroll = resize;
		slider:SetValue(0);
		getglobal(slider:GetName().."ScrollUpButton"):SetScript("OnClick", function()
			slider:SetValue(slider:GetValue() - 1);
		end);
		getglobal(slider:GetName().."ScrollDownButton"):SetScript("OnClick", function()
			slider:SetValue(slider:GetValue() + 1);
		end);
		local function wheel(_, delta)
			slider:SetValue(slider:GetValue() - delta * 3);
		end
		r:EnableMouseWheel(true);
		r:SetScript("OnMouseWheel", wheel);
		scroller:EnableMouseWheel(true);
		scroller:SetScript("OnMouseWheel", wheel);
		c:HookScript("OnShow", resize);
		resize();
		c.slider = slider;
	end
	n = CreateFrame("Frame", "", a, config.backdroptmpl);
	n:SetPoint("Topright",  - 96 + 32 - 10 - 6,  - 64)
	n:SetWidth(192 - 20 - 4);
	n:SetHeight(192 - 20 - 4);
	n:SetBackdrop(d);
	n:SetBackdropColor(0, 0, 0, 0);
	n:SetBackdropBorderColor(1, 1, 1);
	t = n:CreateTexture(nil, "Background");
	t:SetTexture(e.artPath.."bg1_thumb");
	t:SetPoint("Center");
	t:SetWidth(192 - 14 - 20 - 4);
	t:SetHeight(192 - 14 - 20 - 4);
	a.levelImage = t;
	a.thumbFrame = n;
	do
		-- the level's name, centred above the level viewer
		local title = o:CreateCaption(0, 0, "", a, 17, 1, 1, 1, 1, nil);
		title:ClearAllPoints();
		title:SetPoint("Bottom", n, "Top", 0, 6);
		title:SetWidth(260);
		a.levelTitle = title;
	end
	n = CreateFrame("Frame", "", a, config.backdroptmpl);
	n:SetPoint("Topright",  - 34,  - 236)
	n:SetWidth(256);
	n:SetHeight(60);
	n:SetBackdrop(d);
	n:SetBackdropColor(0, 0, 0, .5);
	n:SetBackdropBorderColor(1, 1, 1);
	a.bestFrame = n;
	l = o:CreateCaption(0, 0, e.locale["PERSONAL_BEST"], n, 20, 1, .82, 0, 1, nil)
	l:ClearAllPoints();
	l:SetPoint("Center", 0, 12);
	l:Hide();
	a.best = l;
	l = o:CreateCaption(0, 0, "", n, 20, 1, 1, 1, 1, nil)
	l:ClearAllPoints();
	l:SetPoint("Center", 0,  - 10);
	l:Hide();
	a.points = l;
	l = o:CreateCaption(0, 0, e.locale["NO_SCORE"], n, 20, 0, 1, 0, 1, nil)
	l:ClearAllPoints();
	l:SetPoint("Center");
	l:SetWidth(220);
	a.beatLevel = l;
	n = CreateFrame("Frame", "", a, config.backdroptmpl);
	n:SetPoint("Topright", a.bestFrame, "Bottomright", 0,  - 4)
	n:SetWidth(256);
	n:SetHeight(60);
	n:SetBackdrop(d);
	n:SetBackdropColor(0, 0, 0, .5);
	n:SetBackdropBorderColor(1, 1, 1);
	a.mostRecentFrame = n;
	l = o:CreateCaption(0, 0, e.locale["MOST_RECENT"], n, 20, 1, .82, 0, 1, nil)
	l:ClearAllPoints();
	l:SetPoint("Center", 0, 12);
	l:Show();
	a.mostRecent = l;
	l = o:CreateCaption(0, 0, "", n, 20, 1, 1, 1, 1, nil)
	l:ClearAllPoints();
	l:SetPoint("Center", 0,  - 10);
	l:Show();
	a.mostRecentPoints = l;
	local r = e.artCut["bannerSmall1"];
	t = a:CreateTexture(nil, "Artwork");
	t:SetWidth(i((r[2] - r[1]) * 320 + .5));
	t:SetHeight(i((r[4] - r[3]) * 320 + .5));
	t:SetPoint("Bottomleft", a, "BottomLeft", 55, 40);
	t:SetTexture(e.artPath.."banner2");
	t:SetTexCoord(unpack(r));
	t.on = r;
	t.off = e.artCut["bannerSmall3"];
	l = o:CreateCaption(0, 0, e.locale["BEAT_THIS_LEVEL1"], a.bestFrame, 11, 0, 1, 0, nil, nil)
	l:ClearAllPoints();
	l:SetPoint("Topleft", t, "Topright", 0, -5);
	l:SetWidth(220);
	l.caption1 = e.locale["BEAT_THIS_LEVEL1"]
	l.caption2 = e.locale["BEAT_THIS_LEVEL3"]
	a.talent1 = l;
	l.tex = t;
	r = e.artCut["bannerSmall2"];
	t = a:CreateTexture(nil, "Artwork");
	t:SetWidth(i((r[2] - r[1]) * 320 + .5));
	t:SetHeight(i((r[4] - r[3]) * 320 + .5));
	t:SetPoint("Bottomleft", a, "BottomLeft", 55, 10);
	t:SetTexture(e.artPath.."banner2");
	t:SetTexCoord(unpack(r));
	t.on = r;
	t.off = e.artCut["bannerSmall3"];
	l = o:CreateCaption(0, 0, e.locale["BEAT_THIS_LEVEL2"], a.bestFrame, 11, 0, 1, 0, nil, nil)
	l:ClearAllPoints();
	l:SetPoint("Topleft", t, "Topright", 0,  -5);
	l:SetWidth(220);
	l.caption1 = e.locale["BEAT_THIS_LEVEL2"]
	l.caption2 = e.locale["BEAT_THIS_LEVEL4"]
	a.talent2 = l;
	l.tex = t;
	n = m(0, 0, 64, "buttonGo", nil, "quickPlayGo", a, function(t)
		e.extraInfo = nil;
		Ae(t:GetParent().showID);
		R(true);
		Q = false;
		PeggleGameWindow.delay = PeggleForeverData.settings.highFPS and 1/144 or 1/60
	end)
	n:ClearAllPoints();
	n:SetPoint("Top", a.bestFrame, "Bottom", 0,  - 71);
	-- Layout of the Quick Play page. "new" (default): Stats and Change Hero share one row at the top right, the
	-- level's name sits above the viewer, and the viewer and score boxes move down a little to make room.
	-- "old" restores the original positions (/peggle qplayout old | new).
	local page = a;
	local bestRef, recentRef, thumbRef = a.bestFrame, a.mostRecentFrame, a.thumbFrame;
	config.ApplyQuickPlayLayout = function()
		local old = PeggleForeverData and PeggleForeverData.settings and PeggleForeverData.settings.qpLayout == "old";
		heroChange:ClearAllPoints();
		heroChange:SetPoint("TopRight", page, "TopRight",  - 14,  - 14);
		heroStats:ClearAllPoints();
		thumbRef:ClearAllPoints();
		bestRef:ClearAllPoints();
		if old then
			heroStats:SetWidth(90);
			heroStats:SetPoint("TopRight", page, "TopRight",  - 14,  - 40);
			thumbRef:SetPoint("Topright", page, "Topright",  - 80,  - 64);
			bestRef:SetPoint("Topright", page, "Topright",  - 34,  - 236);
			bestRef:SetHeight(60);
			recentRef:SetHeight(60);
			page.levelTitle:Hide();
		else
			heroStats:SetWidth(64);
			heroStats:SetPoint("TopRight", page, "TopRight",  - 14,  - 14);
			heroChange:ClearAllPoints();
			heroChange:SetPoint("TopRight", heroStats, "TopLeft",  - 4, 0);
			thumbRef:SetPoint("Topright", page, "Topright",  - 80,  - 74);
			bestRef:SetPoint("Topright", page, "Topright",  - 34,  - 246);
			bestRef:SetHeight(54);
			recentRef:SetHeight(54);
			page.levelTitle:Show();
		end
	end
	a.bestFrame = nil;
	return a;
end
local function oe()
	local n = CreateFrame("Frame", "", t.catagoryScreen, config.backdroptmpl);
	n:SetPoint("TopLeft", 5,  - 9)
	n:SetPoint("BottomRight",  - 4, 4);
	local r = e.GetBackdrop();
	r.tileSize = 128;
	r.edgeFile = "Interface\\Glues\\Common\\TextPanel-Border"r.edgeSize = 32;
	n:SetBackdrop(r);
	n:SetBackdropColor(0, 0, 0, .5);
	n:SetBackdropBorderColor(1, 1, 1);
	n:SetFrameLevel(t.catagoryScreen:GetFrameLevel() + 1);
	s(t.catagoryScreen.frames, n);
	local a = n;
	n.showID = 1;
	n:Hide();
	n:SetScript("OnShow", function(e)
		t.levelList:SetParent(e);
		t.levelList:UpdateList();
		t.levelList:Hide();
		if not t.duelStatus then
			if a.go:IsVisible()then
				e.finished = nil;
				t.levelList:Show();
			end
		end
		e:UpdateDisplay(e.showID);
	end);
	n.UpdateDisplay = function(n, o)
		n.showID = o or n.showID;
		n.levelImage:SetTexture(e.artPath.."bg"..n.showID.."_thumb");
		n.levelImage2:SetTexture(e.artPath.."bg"..n.showID.."_thumb");
		local e, l = 0, 0;
		if PeggleForeverProfile.levelTracking[o]then
			e, l = strsplit(",", PeggleForeverProfile.levelTracking[n.showID]);
		end
		t.catagoryScreen.frames[2].winLossCount:SetFormattedText("%d - %d", e, l);
	end
	a.playing = e.locale["PLAYING"];
	a.forfeit = e.locale["FORFEIT"];
	a.UpdateWinners = function(s)
		if(s.finished)then
			return;
		end
		local r = 0;
		local o = s;
		local a = o.player1.value;
		local i = o.player2.value;
		o.timeRemaining:ClearAllPoints();
		o.timeRemaining:SetPoint("Center", o.player2, "Center", 0,  - 22);
		o.timeRemaining:SetParent(o.player2);
		if not((a < 0)or(i < 0))then
			if(a > i)then
				r = 1;
			else
				r = 2;
			end
		elseif((a == i)and(a == -2))then
		r = 3;
		elseif(a == -2)and(i >= 0)then
		r = 2;
		elseif(i == -2)and(a >= 0)then
		r = 1;
		end
		o.player1.results:Hide();
		o.player1.forfeit:Hide();
		o.player1.waiting:Hide();
		o.player2.results:Hide();
		o.player2.forfeit:Hide();
		o.player2.waiting:Hide();
		local l = o.player1.results;
		if(a == -1)then
			o.player1.waiting:Show();
		elseif(a >= 0)then
			l:Show();
			l.score:SetFormattedText(l.score.caption1, P(a));
			l.talent:SetFormattedText(l.talent.caption1, P(o.player1.value1));
			l.style:SetFormattedText(l.style.caption1, P(o.player1.value2));
			l.fever:SetFormattedText(l.fever.caption1, P(o.player1.value3));
			l.charImage:SetTexture(e.artPath.."char"..o.player1.value4);
			l.redCount:SetText(o.player1.value5);
			l.blueCount:SetText(o.player1.value6);
		else
			o.player1.forfeit:Show();
		end
		l = o.player2.results;
		if(i == -1)then
			o.player2.waiting:Show();
		elseif(i >= 0)then
			l:Show();
			l.score:SetFormattedText(l.score.caption1, P(i));
			l.talent:SetFormattedText(l.talent.caption1, P(o.player2.value1));
			l.style:SetFormattedText(l.style.caption1, P(o.player2.value2));
			l.fever:SetFormattedText(l.fever.caption1, P(o.player2.value3));
			l.charImage:SetTexture(e.artPath.."char"..o.player2.value4);
			l.redCount:SetText(o.player2.value5);
			l.blueCount:SetText(o.player2.value6);
		else
			o.player2.forfeit:Show();
		end
		local l = o.name2:GetText();
		if(l)then
			l = gsub(l, "^%l", string.upper);
		end
		local a, i = 0, 0;
		local c, d = 0, 0;
		if(r > 0)then
			t.duelTimer:Hide()
			if(PeggleForeverProfile.duelTracking[l])then
				a, i = strsplit(",", PeggleForeverProfile.duelTracking[l]);
			end
			if(PeggleForeverProfile.levelTracking[ee])then
				c, d = strsplit(",", PeggleForeverProfile.levelTracking[ee]);
			end
			s.finished = true;
			o.publish:Hide();
			if(r == 1)then
				E(e.SOUND_APPLAUSE);
				a = a + 1;
				c = c + 1;
				o.resultStatus:SetFormattedText(o.resultStatus.caption2, l);
				o.player1.results.score:SetTextColor(0, 1, 0);
				o.player2.results.score:SetTextColor(1, 0, 0);
				o.publishInfo = string.format(e.locale["_PUBLISH_DUEL_W"], UnitName("player"), l);
				o.publish:Show();
			elseif(r == 2)then
				E(e.SOUND_SIGH);
				i = i + 1;
				d = d + 1;
				o.resultStatus:SetFormattedText(o.resultStatus.caption3, l);
				o.player1.results.score:SetTextColor(1, 0, 0);
				o.player2.results.score:SetTextColor(0, 1, 0);
				o.publishInfo = string.format(e.locale["_PUBLISH_DUEL_L"], UnitName("player"), l);
				o.publish:Show();
			else
				o.resultStatus:SetFormattedText(o.resultStatus.caption4);
			end
			PeggleForeverProfile.duelTracking[l] = D(a)..","..D(i);
			PeggleForeverProfile.levelTracking[ee] = D(c)..","..D(d);
			o:UpdateDisplay(o.showID);
			o.name2:SetText("");
			o.name2:SetText(l);
			if(PeggleForeverData.settings.closeDuelComplete)then
				t:Hide();
			end
		else
			o.resultStatus:SetFormattedText(o.resultStatus.caption1, l);
		end
		a, i = 0, 0
		if PeggleForeverProfile.duelTracking[l]then
			a, i = strsplit(",", PeggleForeverProfile.duelTracking[l]);
		end
		o.winLossDuelsVs:SetFormattedText(o.winLossDuelsVs.caption1, l, a, i);
		a, i = 0, 0
		local l, e;
		local t;
		for t = 1, #LEVELS do
			if PeggleForeverProfile.levelTracking[t]then
				l, e = strsplit(",", PeggleForeverProfile.levelTracking[t]);
				a = a + A(l);
				i = i + A(e);
			end
		end
		o.winLossDuels:SetFormattedText(o.winLossDuels.caption1, a, i);
	end
	n = CreateFrame("Frame", "", a);
	n:SetPoint("Topright",  - 35,  - 200)
	n:SetWidth(256);
	n:SetHeight(128);
	a.duelInfo1 = n;
	local l = o:CreateCaption(0, 0, e.locale["DUEL"], n, 25, .05, .66, 1, 1, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", a, "Top", 0,  - 22);
	l:SetParent(n);
	n = CreateFrame("Frame", "", a.duelInfo1, config.backdroptmpl);
	n:SetPoint("Topright", a, "Topright",  - 98,  - 60)
	n:SetWidth(128);
	n:SetHeight(128);
	n:SetBackdrop(r);
	n:SetBackdropColor(0, 0, 0, 0);
	n:SetBackdropBorderColor(1, 1, 1);
	tex = n:CreateTexture(nil, "Background");
	tex:SetTexture(e.artPath.."bg1_thumb");
	tex:SetPoint("Center");
	tex:SetWidth(128 - 14);
	tex:SetHeight(128 - 14);
	a.levelImage = tex;
	l = o:CreateCaption(0, 0, e.locale["OPPONENT"], a.duelInfo1, 20, 1, .82, 0, 1, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", n, "Bottom", 2,  - 10);
	l.caption1 = l:GetText();
	l.caption2 = e.locale["DUEL_CHALLENGE"];
	a.name1 = l;
	l = Je(0, 0, 256, "opponentName", a.duelInfo1, nil, nil, nil, tooltipText)
	l:ClearAllPoints();
	l:SetPoint("Top", n, "Bottom", 0,  - 36);
	a.name2 = l;
	l:SetScript("OnTextChanged", function(e)
		local t = e:GetParent():GetParent();
		local e = e:GetText();
		if(e)then
			e = gsub(e, "^%l", string.upper);
			t.winLossPlayer:Show();
			local o, n = 0, 0
			if PeggleForeverProfile.duelTracking[e]then
				o, n = strsplit(",", PeggleForeverProfile.duelTracking[e]);
			end
			t.winLossPlayer:SetFormattedText(t.winLossPlayer.caption1, o, n);
		else
			t.winLossPlayer:Hide();
		end
	end);
	local i = We(0, 0, 256, "duelNames", nil, nil, l, nil, nil)
	i.names = true;
	i:DisableDrawLayer("ARTWORK");
	i:ClearAllPoints();
	i:SetPoint("Topright", l, "Topright", 18,  -3);
	a.nameDrop = i;
	l = o:CreateCaption(0, 0, e.locale["WIN_LOSS_PLAYER"], a.duelInfo1, 14, 1, .82, 0, nil, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", n, "Bottom", 0,  -70);
	l.caption1 = l:GetText();
	a.winLossPlayer = l;
	l:Hide();
	l = o:CreateCaption(0, 0, e.locale["OPPONENT_NOTE"].." "..e.locale["OPTIONAL"], a.duelInfo1, 14, 1, .82, 0, 1, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", n, "Bottom", 0,  -96);
	l.caption1 = l:GetText();
	l.caption2 = e.locale["OPPONENT_NOTE"];
	l.caption3 = e.locale["OPPONENT_NOTE2"];
	a.note1 = l;
	l = Je(0, 0, 256, "opponentNote", a.duelInfo1, nil, nil, nil, tooltipText)
	l:ClearAllPoints();
	l:SetPoint("Top", n, "Bottom", 0,  -116);
	l:SetMaxBytes(48);
	a.note2 = l;
	-- the hero everyone plays as in this duel ("Standard" = no hero); the picker is only shown while setting up an invite
	-- one row under the note: "HERO" label on the left, the drop-down on the right
	l = o:CreateCaption(0, 0, "HERO", a.duelInfo1, 14, 1, .82, 0, 1, nil)
	l:ClearAllPoints();
	l:SetPoint("Left", n, "Bottom",  - 124,  - 168);
	a.heroLabel = l;
	l = config.CreateHeroPicker(a.duelInfo1, "PeggleDuelHeroPicker");
	l:SetPoint("Left", n, "Bottom",  - 82,  - 168);
	a.heroPicker = l;
	l = o:CreateCaption(0, 0, "", a.duelInfo1, 14, .5, .85, 1, 1, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", n, "Bottom", 0,  - 168);
	l:SetWidth(256);
	l:Hide();
	a.heroLine = l;
	a.duelHero = 0;
	local duelPage = a;
	-- two swords from the Credits page, crossed in the top-left corner (flat side by side if the client cannot rotate textures)
	do
		local cut = e.artCut["peggleBringer"];
		local scale = .5;
		local sw = math.floor((cut[4] - cut[3]) * (512 - 128) * scale + .5);
		local sh = math.floor((cut[2] - cut[1]) * (512 - 128) * scale + .5);
		local function sword(mirrored, angle, flatX)
			local tex = duelPage:CreateTexture(nil, "Artwork");
			tex:SetWidth(sw);
			tex:SetHeight(sh);
			tex:SetTexture(e.artPath.."board1");
			if mirrored then
				tex:SetTexCoord(cut[2], cut[4], cut[1], cut[4], cut[2], cut[3], cut[1], cut[3]);
			else
				tex:SetTexCoord(cut[2], cut[3], cut[1], cut[3], cut[2], cut[4], cut[1], cut[4]);
			end
			if tex.SetRotation then
				tex:SetPoint("Center", duelPage, "TopLeft", 84,  - 48);
				tex:SetRotation(angle);
			else
				tex:SetPoint("TopLeft", duelPage, "TopLeft", flatX,  - 60);
			end
			return tex;
		end
		duelPage.swordA = sword(false, math.rad(34), 20);
		duelPage.swordB = sword(true, - math.rad(34), 20 + sw + 6);
	end
	config.DuelHero = function()
		return duelPage.duelHero or 0;
	end
	a:HookScript("OnUpdate", function(self)
		local idle = self.go and self.go:IsVisible();
		if idle then
			self.heroLabel:Show();
			self.heroPicker:Show();
			self.heroLine:Hide();
		else
			self.heroLabel:Hide();
			self.heroPicker:Hide();
			self.heroLine:SetText("Hero: "..config.MatchHeroName(self.duelHero));
			self.heroLine:Show();
		end
	end);
	l = o:CreateCaption(0, 0, "", a.duelInfo1, 12, 1, 1, 1, nil, "")
	l:ClearAllPoints();
	l:SetPoint("Top", n, "Bottom", 0,  -122);
	l:SetWidth(256);
	l:SetHeight(14 * 2);
	l:SetJustifyV("TOP");
	l:SetFontObject(t.fontObj);
	l:Hide();
	a.note2a = l;
	l = o:CreateCaption(0, 0, e.locale["DUEL_STATUS"], a.duelInfo1, 14, 1, .82, 0, 1, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", a, "Topleft", 170,  -120);
	l:SetWidth(256);
	a.note3Title = l;
	l:Hide();
	l = o:CreateCaption(0, 0, "", a.duelInfo1, 14, 1, 1, 1, 1, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", a, "Topleft", 170,  -180);
	l:SetWidth(256);
	l.status1 = e.locale["DUEL_STATUS1"];
	l.status2 = e.locale["DUEL_STATUS2"];
	l.status3 = e.locale["DUEL_STATUS3"];
	l.status4 = e.locale["DUEL_STATUS4"];
	l.status5 = e.locale["DUEL_STATUS5"];
	l.status6 = e.locale["DUEL_STATUS6"];
	a.note3 = l;
	l = o:CreateCaption(0, 0, e.locale["WIN_LOSS"], n, 12, 0, 1, 0, nil, nil)
	l:ClearAllPoints();
	l:SetPoint("Topleft", a, "Bottomleft", 20, 60);
	l:SetWidth(300);
	a.winLoss = l;
	l = o:CreateCaption(0, 0, e.locale["WIN_LOSS_LEVEL"], n, 12, 0, 1, 0, nil, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", a.winLoss, "Bottom", 0,  -4);
	l:SetWidth(300);
	a.winLossLevel = l;
	l = o:CreateCaption(0, 0, "0 - 0", n, 14, 0, 1, 0, nil, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", a.winLossLevel, "Bottom", 0,  -6);
	l:SetWidth(300);
	a.winLossCount = l;
	l = o:CreateCaption(0, 0, e.locale["DUEL_TIME"], a, 12, 1, .82, 0, nil, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", a.winLossCount, "Bottom", 0,  -6);
	l:SetWidth(300);
	l.caption1 = l:GetText();
	l:Hide();
	a.timeRemaining = l;
	n = m(0, 0, 54, "buttonGo", nil, "8", a.duelInfo1, function(o)
		local n = o:GetParent():GetParent();
		local d = n.name2:GetText()or"";
		if(d ~= "")then
			o:Hide();
			ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", M)
			t.levelList:Hide();
			n.winLoss:ClearAllPoints();
			n.winLoss:SetPoint("Topleft", n, "Bottomleft", 14, 190);
			n.nameDrop:Hide();
			n.name2:DisableDrawLayer("BACKGROUND");
			n.name2:SetJustifyH("CENTER")
			n.name2:EnableMouse(false);
			n.name2:ClearFocus();
			n.note1:SetText(n.note1.caption2);
			n.note2a:SetText(n.note2:GetText()or NONE);
			n.note2a:Show();
			n.note2:Hide();
			n.note3:Show();
			n.note3:SetText(n.note3.status1);
			n.note3Title:Show();
			n.decline1:Show();
			Fe(n.showID);
			local i = #B;
			local o = {};
			local a, l;
			local a = "";
			for e = 1, i do
				s(o, e);
			end
			for e = 1, 25 do
				l = C(1, #o);
				a = a..h(u(o, l), 2);
			end
			local c = (ae * 9) ^ 2;
			local r;
			local i;
			for e = 1, 2 do
				l = C(1, #o);
				r = nil;
				while(r == nil)do
					if(i)then
						if(((B[o[l]].x - B[o[i]].x) ^ 2) + ((B[o[l]].y - B[o[i]].y) ^ 2)) < c then
							if(#o > 0)then
								l = C(1, #o);
							end
						else
							r = true;
						end
					else
						i = l;
						r = true;
					end
				end
				a = a..h(u(o, l), 2);
			end
			l = C(1, #o);
			a = a..h(u(o, l), 2);
			n.levelInfo = a;
			a = U(a, p(e.name));
			collectgarbage();
			t.duelTimer.elapsed = 0;
			t.duelTimer.remaining = 300;
			t.duelTimer:Show()
			t.duelStatus = 1;
			t.network.inviteTimer = 0;
			t.network.watchError = d;
			n.duelHero = n.heroPicker.value or 0;
			local o = n.note2:GetText()or"";
			if(o == "")then
				o = NONE;
			end
			config.SendAddonMessage(t.network.prefix, e.commands[1].."+"..n.showID.."+"..o.."+"..a.."+"..(n.heroPicker.value or 0), "WHISPER", d);
		end
	end)
	n:ClearAllPoints();
	n:SetPoint("Top", a.duelInfo1, "Bottom", 0,  - 46);
	a.go = n;
	n = m(0, 0, 64, "buttonDecline", true, "duelDecline1", a.duelInfo1, function(n)
		n:Hide();
		t.duelTimer:Hide()
		local n = n:GetParent():GetParent();
		t.duelStatus = nil;
		n.nameDrop:Show();
		t.levelList:Show();
		n.winLoss:ClearAllPoints();
		n.winLoss:SetPoint("Topleft", n, "Bottomleft", 20, 90);
		n.go:Show();
		n.name2:EnableDrawLayer("BACKGROUND");
		n.name2:SetJustifyH("LEFT");
		n.name2:EnableMouse(true);
		n.note1:SetText(n.note1.caption1);
		n.note2:Show();
		n.note2a:Hide();
		n.note3:Hide();
		n.note3Title:Hide();
		config.SendAddonMessage(t.network.prefix, e.commands[7].."+", "WHISPER", n.name2:GetText());
	end, nil, true)
	n:ClearAllPoints();
	n:SetPoint("Bottom", a, "Bottom", 0, 16);
	n:Hide();
	a.decline1 = n;
	n = m(0, 0, 64, "buttonOkay", nil, "duelOkay1", a.duelInfo1, function(e)
		e:Hide();
		local e = e:GetParent():GetParent();
		t.levelList:Show();
		e.winLoss:ClearAllPoints();
		e.winLoss:SetPoint("Topleft", e, "Bottomleft", 20, 70);
		e.winLoss:Show();
		e.winLossLevel:Show();
		e.winLossCount:Show();
		e.go:Show();
		e.nameDrop:Show();
		e.name2:EnableDrawLayer("BACKGROUND");
		e.name2:SetJustifyH("LEFT");
		e.name2:EnableMouse(true);
		e.note1:SetText(e.note1.caption1);
		e.note2:Show();
		e.note2a:Hide();
		e.note3:Hide();
		e.note3Title:Hide();
		t.duelStatus = nil
		t.network.inviteTimer = nil;
		t.network.watchError = nil;
	end)
	n:ClearAllPoints();
	n:SetPoint("Bottom", a, "Bottom", 0, 16);
	n:Hide();
	a.okay1 = n;
	n = m(0, 0, 64, "buttonGo", nil, "duelOkay2", a.duelInfo1, function(n)
		n:Hide();
		local n = n:GetParent():GetParent();
		n.decline2:Hide();
		config.SendAddonMessage(t.network.prefix, e.commands[4].."+", "WHISPER", n.name2:GetText());
		t.minimap.notice = nil;
		t.levelList:Hide();
		n.winLoss:Hide();
		n.winLossLevel:Hide();
		n.winLossCount:Hide();
		n.nameDrop:Hide();
		n.duelInfo1:Hide();
		n.duelInfo2:Show();
		n.go:Show();
		n.okay1:Hide();
		n.okay2:Hide();
		n.decline1:Hide();
		n.decline2:Hide();
		n.name2:EnableDrawLayer("BACKGROUND");
		n.name2:SetJustifyH("LEFT");
		n.name2:EnableMouse(true);
		n.note1:SetText(n.note1.caption1);
		n.note2:Show();
		n.note2a:Hide();
		n.note3:Hide();
		n.note3Title:Hide();
		local e
		for e = 1, 6 do
			n.player1["value"..e] = 0;
			n.player2["value"..e] = 0;
		end
		n.player1.value = -1;
		n.player2.value = -1;
		t.duelTab.sparks:Hide();
		Ae(n.showID, nil, n.levelInfo);
		R(true);
		Q = false;
		t.duelStatus = 3;
	end)
	n:ClearAllPoints();
	n:SetPoint("Bottom", a, "Bottom",  - 150, 16);
	n:Hide();
	a.okay2 = n;
	n = m(0, 0, 64, "buttonDecline", true, "duelDecline2", a.duelInfo1, function(n)
		n:Hide();
		t.duelTimer:Hide()
		local n = n:GetParent():GetParent();
		n.okay2:Hide();
		t.minimap.notice = nil;
		t.duelTab.sparks:Hide();
		n.nameDrop:Show();
		t.levelList:Show();
		n.winLoss:ClearAllPoints();
		n.winLoss:SetPoint("Topleft", n, "Bottomleft", 20, 90);
		n.name2:EnableDrawLayer("BACKGROUND");
		n.name2:SetJustifyH("LEFT");
		n.name2:EnableMouse(true);
		n.note1:SetText(n.note1.caption1);
		n.note2:Show();
		n.note2a:Hide();
		n.note2:SetText("");
		n.note3:Hide();
		n.note3Title:Hide();
		n.go:Show();
		config.SendAddonMessage(t.network.prefix, e.commands[3].."+", "WHISPER", n.name2:GetText());
		t.duelStatus = nil;
	end, nil, true)
	n:ClearAllPoints();
	n:SetPoint("Bottom", a, "Bottom", 150, 16);
	n:Hide();
	a.decline2 = n;
	n = CreateFrame("Frame", "", a);
	n:SetPoint("Topright",  - 35,  - 160)
	n:SetWidth(256);
	n:SetHeight(128);
	n:Hide();
	a.duelInfo2 = n;
	l = o:CreateCaption(0, 0, e.locale["DUEL_RESULTS"], a.duelInfo2, 40, .05, .66, 1, 1, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", a, "Top", 0,  - 22);
	l:SetParent(n);
	n = CreateFrame("Frame", "", a.duelInfo2, config.backdroptmpl);
	n:SetPoint("Topleft", a, "Topleft", 98,  - 60)
	n:SetWidth(128);
	n:SetHeight(128);
	n:SetBackdrop(r);
	n:SetBackdropColor(0, 0, 0, 0);
	n:SetBackdropBorderColor(1, 1, 1);
	tex = n:CreateTexture(nil, "Background");
	tex:SetTexture(e.artPath.."bg1_thumb");
	tex:SetPoint("Center");
	tex:SetWidth(128 - 14);
	tex:SetHeight(128 - 14);
	a.levelImage2 = tex;
	l = o:CreateCaption(0, 0, e.locale["DUEL_RESULT1"], a.duelInfo2, 25, 1, .82, 0, 1, nil)
	l:ClearAllPoints();
	l:SetPoint("Topleft", n, "Topright", 10,  - 10);
	l:SetPoint("Bottomright", a, "Topright",  - 10,  - 60 - 55 - 10);
	l:SetJustifyV("TOP")
	l.caption1 = e.locale["DUEL_RESULT1"];
	l.caption2 = e.locale["DUEL_RESULT2"];
	l.caption3 = e.locale["DUEL_RESULT3"];
	l.caption4 = e.locale["DUEL_RESULT4"];
	a.resultStatus = l;
	l = o:CreateCaption(0, 0, e.locale["DUEL_TOTAL_WL"], a.duelInfo2, 16, 1, .82, 0, 1, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", a.resultStatus, "Bottom", 0,  - 10);
	l:SetWidth(400);
	l.caption1 = e.locale["DUEL_TOTAL_WL"]
	a.winLossDuels = l;
	l = o:CreateCaption(0, 0, e.locale["DUEL_OPP_WL"], a.duelInfo2, 16, 1, .82, 0, 1, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", a.winLossDuels, "Bottom", 0,  - 6);
	l:SetWidth(400);
	l.caption1 = e.locale["DUEL_OPP_WL"]
	a.winLossDuelsVs = l;
	n = CreateFrame("Frame", "", a.duelInfo2, config.backdroptmpl);
	n:SetPoint("Topleft", a, "Topleft", 10,  - 190)
	n:SetPoint("Topright", a, "Topright",  - 10,  - 190)
	n:SetHeight(88);
	n:SetBackdrop(r);
	n:SetBackdropColor(0, 0, 0, .5);
	n:SetBackdropBorderColor(1, 1, 1);
	n.value = -1;
	n.value1 = 0;
	n.value2 = 0;
	n.value3 = 0;
	n.value4 = 1;
	n.value5 = 0;
	n.value6 = 0;
	a.player1 = n;
	l = o:CreateCaption(0, 0, e.locale["DUEL_WAITING"], n, 25, 1, .82, 0, 1, nil)
	l:SetAllPoints(n);
	l:SetJustifyV("MIDDLE")
	a.player1.waiting = l;
	l = o:CreateCaption(0, 0, e.locale["DUEL_FORFEIT1"], n, 25, 1, .82, 0, 1, nil)
	l:SetAllPoints(n);
	l:SetJustifyV("MIDDLE")
	a.player1.forfeit = l;
	n = CreateFrame("Frame", "", n);
	n:SetAllPoints(a.player1);
	a.player1.results = n;
	n:Hide();
	tex = n:CreateTexture(nil, "Artwork");
	tex:SetTexture(e.artPath.."char1");
	tex:SetPoint("Topleft", 16,  - 12);
	tex:SetWidth(64);
	tex:SetHeight(64);
	n.charImage = tex;
	tex = n:CreateTexture(nil, "Artwork");
	tex:SetTexture(e.artPath.."bannerSmallRed");
	tex:SetPoint("Topleft", 64 + 32,  - 12 - 32 - 4);
	tex:SetWidth(24);
	tex:SetHeight(24);
	l = o:CreateCaption(64 + 32 + 2, 12 + 4 + 32 + 6, "11", n, 12, 1, 1, 1, 1, nil)
	l:SetWidth(24);
	n.redCount = l;
	tex = n:CreateTexture(nil, "Artwork");
	tex:SetTexture(e.artPath.."bannerSmallBlue");
	tex:SetPoint("Topleft", 64 + 32 + 32 - 8,  - 12 - 32 - 4);
	tex:SetWidth(24);
	tex:SetHeight(24);
	l = o:CreateCaption(64 + 32 + 32 + 2 - 8, 12 + 4 + 32 + 6, "8", n, 12, 1, 1, 1, 1, nil)
	l:SetWidth(24);
	n.blueCount = l;
	l = o:CreateCaption(8, 12 + 4, "", n, 25, 1, .82, 0, 1, nil)
	l:SetWidth(n:GetWidth() - 16);
	l.caption1 = e.locale["DUEL_BREAKDOWN1"]
	n.score = l;
	l = o:CreateCaption(64 + 32 + 8 + 64 - 2 - 7, 12 + 32 + 8, "", n, 18, .05, .66, 1, 1, nil)
	l.caption1 = e.locale["DUEL_BREAKDOWN2"]
	n.talent = l;
	l = o:CreateCaption(64 + 32 + 8 + 64 + 150 - 2, 12 + 32 + 8, "", n, 18, .05, .66, 1, 1, nil)
	l.caption1 = e.locale["DUEL_BREAKDOWN3"]
	n.style = l;
	l = o:CreateCaption(64 + 32 + 8 + 64 + 300, 12 + 32 + 8, "", n, 18, .05, .66, 1, 1, nil)
	l.caption1 = e.locale["DUEL_BREAKDOWN4"]
	n.fever = l;
	n = CreateFrame("Frame", "", a.duelInfo2, config.backdroptmpl);
	n:SetPoint("Topleft", a, "Topleft", 10,  - 190 - 86)
	n:SetPoint("Topright", a, "Topright",  - 10,  - 190 - 86)
	n:SetHeight(88);
	n:SetBackdrop(r);
	n:SetBackdropColor(0, 0, 0, .5);
	n:SetBackdropBorderColor(1, 1, 1);
	n.value = -1;
	n.value1 = 0;
	n.value2 = 0;
	n.value3 = 0;
	n.value4 = 1;
	n.value5 = 0;
	n.value6 = 0;
	a.player2 = n;
	l = o:CreateCaption(0, 0, e.locale["DUEL_WAITING"], n, 25, 1, .82, 0, 1, nil)
	l:SetAllPoints(n);
	l:SetJustifyV("MIDDLE")
	a.player2.waiting = l;
	l = o:CreateCaption(0, 0, e.locale["DUEL_FORFEIT2"], n, 25, 1, .82, 0, 1, nil)
	l:SetAllPoints(n);
	l:SetJustifyV("MIDDLE")
	a.player2.forfeit = l;
	n = CreateFrame("Frame", "", n);
	n:SetAllPoints(a.player2);
	a.player2.results = n;
	n:Hide();
	tex = n:CreateTexture(nil, "Artwork");
	tex:SetTexture(e.artPath.."char1");
	tex:SetPoint("Topleft", 15,  - 11);
	tex:SetWidth(64);
	tex:SetHeight(64);
	n.charImage = tex;
	tex = n:CreateTexture(nil, "Artwork");
	tex:SetTexture(e.artPath.."bannerSmallRed");
	tex:SetPoint("Topleft", 64 + 32,  - 12 - 32 - 4);
	tex:SetWidth(24);
	tex:SetHeight(24);
	l = o:CreateCaption(64 + 32 + 2, 12 + 4 + 32 + 6, "11", n, 12, 1, 1, 1, 1, nil)
	l:SetWidth(24);
	n.redCount = l;
	tex = n:CreateTexture(nil, "Artwork");
	tex:SetTexture(e.artPath.."bannerSmallBlue");
	tex:SetPoint("Topleft", 64 + 32 + 32 - 8,  - 12 - 32 - 4);
	tex:SetWidth(24);
	tex:SetHeight(24);
	l = o:CreateCaption(64 + 32 + 32 + 2 - 8, 12 + 4 + 32 + 6, "8", n, 12, 1, 1, 1, 1, nil)
	l:SetWidth(24);
	n.blueCount = l;
	l = o:CreateCaption(8, 12 + 4, "", n, 25, 1, .82, 0, 1, nil)
	l:SetWidth(n:GetWidth() - 16);
	l.caption1 = e.locale["DUEL_BREAKDOWN1a"]
	n.score = l;
	l = o:CreateCaption(64 + 32 + 8 + 64 - 2 - 7, 12 + 32 + 8, "", n, 18, .05, .66, 1, 1, nil)
	l.caption1 = e.locale["DUEL_BREAKDOWN2"]
	n.talent = l;
	l = o:CreateCaption(64 + 32 + 8 + 64 + 150 - 2, 12 + 32 + 8, "", n, 18, .05, .66, 1, 1, nil)
	l.caption1 = e.locale["DUEL_BREAKDOWN3"]
	n.style = l;
	l = o:CreateCaption(64 + 32 + 8 + 64 + 300, 12 + 32 + 8, "", n, 18, .05, .66, 1, 1, nil)
	l.caption1 = e.locale["DUEL_BREAKDOWN4"]
	n.fever = l;
	n = m(0, 0, 64, "buttonOkay", nil, "duelOkay", a.duelInfo2, function(e)
		local e = e:GetParent():GetParent();
		e.nameDrop:Show();
		t.levelList:Show();
		e.winLoss:ClearAllPoints();
		e.winLoss:SetPoint("Topleft", e, "Bottomleft", 20, 90);
		e.winLoss:Show();
		e.winLossLevel:Show();
		e.winLossCount:Show();
		e.note3Title:Hide();
		t.duelStatus = nil;
		e.finished = nil;
		e.duelInfo1:Show();
		e.duelInfo2:Hide();
	end)
	n:ClearAllPoints();
	n:SetPoint("Bottom", a, "Bottom", 0, 16);
	a.okay3 = n;
	n = m(0, 0, 64, "buttonPublish", true, "duelPublish", a.duelInfo2, function(e)
		t.summaryScreen.publishInfo = e:GetParent():GetParent().publishInfo;
		t.summaryScreen.publishDuel = true;
		t.summaryScreen.bragScreen:SetParent(t.catagoryScreen.frames[2]);
		t.summaryScreen.bragScreen:SetFrameLevel(t.catagoryScreen.frames[2]:GetFrameLevel() + 10);
		t.summaryScreen.bragScreen:Show();
	end, nil, true)
	n:ClearAllPoints();
	n:SetPoint("Bottomright", a, "Bottomright",  -16, 16);
	n:Hide();
	a.publish = n;
	n = CreateFrame("Frame", "", UIParent);
	n:SetWidth(10);
	n:SetHeight(10);
	n:SetPoint("Right");
	n:Hide();
	n.elapsed = 0;
	n.remaining = 300;
	n:SetScript("OnShow", function(e)
		local t = t.catagoryScreen.frames[2];
		local e = t.timeRemaining;
		e:ClearAllPoints();
		e:SetPoint("Top", t.winLossCount, "Bottom", 0,  0);
		e:SetFormattedText(e.caption1, "5m 0s");
		e:Show()
		e:SetParent(t);
	end);
	n:SetScript("OnHide", function(e)
		t.catagoryScreen.frames[2].timeRemaining:Hide()
	end);
	n:SetScript("OnUpdate", function(e, n)
		e.elapsed = e.elapsed + n;
		if(e.elapsed >= 1)then
			e.elapsed = 0;
			e.remaining = e.remaining - 1;
			if(e.remaining <= 0)then
				e.remaining = 0;
				e:Hide();
				if(t.duelStatus == 3)then
					if(de == false)and not t.catagoryScreen:IsShown()then
						local e = getglobal("PeggleButton_menuAbandon");
						e:GetScript("OnClick")(e);
					end
				end
				if(t.duelStatus == 2)then
					local e = getglobal("PeggleButton_duelDecline2");
					if(e:IsVisible())then
						e:GetScript("OnClick")(e);
					else
						e = getglobal("PeggleButton_duelDecline1");
						if(e:IsVisible())then
							e:GetScript("OnClick")(e);
						end
					end
				end
			else
				local e, n = o.TimeBreakdown(ceil(e.remaining));
				if(e > 0)then
					e = e.."m "else
					e = "";
				end
				if(n > 0)then
					n = n.."s";
				else
					n = ""
				end
				if(t.duelStatus == 3)and(t.catagoryScreen.frames[2].player1.value == -1)then
					t.bestScoreCaption:SetFormattedText(t.bestScoreCaption.caption2, e..n);
				end
				local t = t.catagoryScreen.frames[2];
				t.timeRemaining:SetFormattedText(t.timeRemaining.caption1, e..n);
			end
		end
	end);
	t.duelTimer = n;
	return a;
end
local function ee()
	local l = CreateFrame("Frame", "", t.catagoryScreen, config.backdroptmpl);
	l:SetPoint("TopLeft", 5,  - 9)
	l:SetPoint("BottomRight",  - 4, 4);
	local d = e.GetBackdrop();
	d.tileSize = 128;
	d.edgeFile = "Interface\\Glues\\Common\\TextPanel-Border"d.edgeSize = 32;
	l:SetBackdrop(d);
	l:SetBackdropColor(0, 0, 0, .5);
	l:SetBackdropBorderColor(1, 1, 1);
	l:SetFrameLevel(t.catagoryScreen:GetFrameLevel() + 1);
	s(t.catagoryScreen.frames, l);
	local p = l;
	l:Hide();
	l:SetScript("OnShow", function(e)
		e.content1.state = 0;
		e.content2:Hide();
		e.content1:Hide();
		e.content1:Show();
	end);
	local a = CreateFrame("Frame", "", p);
	a:SetPoint("TopLeft")
	a:SetPoint("BottomRight");
	p.content1 = a;
	a.state = 0;
	a:SetScript("OnShow", function(e)
		t.catagoryScreen.frames[3].content2.active = nil;
		if(e.state == 0)then
			local n;
			for t = 1, 13 do
				e["highlight"..t].tex:SetAlpha(0);
			end
			e.showID = nil;
			t.challengeTabSparks:Hide();
			e.title:SetText(e.title.caption1);
			e.catagory1:SetText(e.catagory1.caption1);
			e.newChallenge:Show();
			e.details:Hide();
			e.startChallenge1:Hide();
			e.backChallenge:Hide();
			e.cancelChallenge:Hide();
			e.noneSelected:Show();
			for t = 1, 6 do
				e["stageDetails"..t]:Hide();
				e["stageDetails"..t.."a"]:Hide();
			end
			e.levelImage1:Hide();
			e.nameList:Hide();
		elseif(e.state == 1)then
		else
			t.challengeTabSparks:Hide();
			e.details:Show();
			e.startChallenge1:Show();
			e.backChallenge:Show();
			e.noneSelected:Hide();
			for t = 1, 6 do
				e["stageDetails"..t]:Show();
				e["stageDetails"..t.."a"]:Show();
			end
			e.levelImage1:Show();
			e.nameList:Show();
		end
		e:UpdateScreen(true);
	end);
	a.UpdateScreen = function(r, p)
		local n = r;
		local i = Y;
		local a, l;
		local a = e.newInfo;
		local u;
		if(r.state == 0)or(r.state == 2)then
			r.extraInfo = nil;
			n.listSlider:SetMinMaxValues(0, F(0, #i - 13));
			if(n.listSlider:GetValue() > (F(0, (#i - 13))))then
				n.listSlider:SetValue(F(0, #i - 13));
			end
			if(e.cCount >= e.maxBattles)then
				SetDesaturation(n.newChallenge.background, true);
				n.newChallenge:EnableMouse(false);
			else
				SetDesaturation(n.newChallenge.background, false);
				n.newChallenge:EnableMouse(true);
			end
			local d = n.listSlider:GetValue();
			local r, c
			for t = 1, 13 do
				n["highlight"..t].tex:SetAlpha(0);
				if(n.showID == t + d)then
					n["highlight"..t].tex:SetAlpha(1);
				end
				l = i[t + d];
				n["info"..t.."1"]:SetTextColor(1, 1, 1)
				n["info"..t.."2"]:SetTextColor(1, 1, 1);
				if(l)and(l[g])then
					u = l[a[4]];
					if(l[a[6]])then
						n["info"..t.."New"]:Show();
					else
						n["info"..t.."New"]:Hide();
					end
					if(l[a[10]])then
						l[a[6]] = nil;
						n["info"..t.."New"]:Hide();
						n["info"..t.."Played"]:Show();
					end
					n["info"..t.."1"]:SetText(u);
					if(l.removed == true)then
						n["info"..t.."2"]:SetText(e.locale["_EXPIRED"]);
						n["info"..t.."2"]:SetTextColor(.5, .5, .5);
					elseif(l.ended == true)then
						n["info"..t.."2"]:SetFormattedText("%dh %dm", o.TimeBreakdown(l.elapsed));
						n["info"..t.."2"]:SetTextColor(.5, .5, .5);
					else
						r, c = o.TimeBreakdown(l.elapsed);
						n["info"..t.."2"]:SetFormattedText("%dh %dm", r, c);
						if(r < 2)then
							n["info"..t.."2"]:SetTextColor(1, 0, 0);
						elseif(r < 8)then
							n["info"..t.."2"]:SetTextColor(1, 1, 0);
						else
							n["info"..t.."2"]:SetTextColor(0, 1, 0);
						end
					end
				else
					n["info"..t.."1"]:SetText("");
					n["info"..t.."2"]:SetText("");
				end
			end
		elseif(r.state == 1)then
		end
		if(r.state == 2)then
			l = i[r.showID];
			r.extraInfo = l;
			local c = l[a[2]];
			ge(l);
			r.cancelChallenge:SetText(((l.creator == e.name) and not l.ended) and "Cancel Battle" or "Remove");
			r.cancelChallenge:Show();
			local a = e.currentView;
			local T = n.nameListSlider:GetValue();
			local i, g, s, S, d;
			r.tempNames = r.tempNames or{};
			local h = r.tempNames;
			r.nameListSlider:SetMinMaxValues(0, F(#c - 13, 0));
			if(p)then
				table.wipe(h);
				local n, n, e
				e = 1;
				for e = 1, #c do
					h[e] = {c[e], a[7][e], e, a[8][e]};
				end
				table.sort(h, t.peggleLootTimer.compare);
			end
			local r = 1;
			for t = 1, 13 do
				i = t + T
				r = i;
				if(h[i])then
					i = h[i][3];
					u = c[i];
					n["infoName"..t.."1"]:SetText(u);
					if(a[8][i]and a[8][i] > 1e3)then
						d = a[8][i] - 1;
						s = f(d, 100);
						d = (d - s) / 100;
						if(d >= 30)then
							S = d - 30;
							g = 2;
						else
							S = d - 10;
							g = 1;
						end
						if(s == 0)then
							s = "";
						end
						if(S == 0)then
							S = "";
						end
						n["infoName"..t.."2"]:SetText(P(a[7][i]));
						n["infoRank"..t]:SetText(r);
						n["infoName"..t.."1"]:SetTextColor(1, 1, 1);
						n["infoName"..t.."2"]:SetTextColor(1, 1, 1);
						n["infoName"..t.."a"]:SetTexture(e.artPath.."char"..g.."Power");
						n["infoName"..t.."b1"]:SetText(s);
						n["infoName"..t.."c1"]:SetText(S);
						n["infoName"..t.."a"]:Show();
						n["infoName"..t.."b"]:Show();
						n["infoName"..t.."c"]:Show();
						n["infoName"..t.."b1"]:Show();
						n["infoName"..t.."c1"]:Show();
					else
						n["infoName"..t.."2"]:SetText(0);
						n["infoRank"..t]:SetText("");
						n["infoName"..t.."1"]:SetTextColor(.5, .5, .5);
						n["infoName"..t.."2"]:SetTextColor(.5, .5, .5);
						n["infoName"..t.."a"]:Hide();
						n["infoName"..t.."b"]:Hide();
						n["infoName"..t.."c"]:Hide();
						n["infoName"..t.."b1"]:Hide();
						n["infoName"..t.."c1"]:Hide();
					end
				else
					n["infoName"..t.."1"]:SetText("");
					n["infoName"..t.."2"]:SetText("");
					n["infoRank"..t]:SetText("");
					n["infoName"..t.."a"]:Hide();
					n["infoName"..t.."b"]:Hide();
					n["infoName"..t.."c"]:Hide();
					n["infoName"..t.."b1"]:Hide();
					n["infoName"..t.."c1"]:Hide();
				end
			end
			n.stageDetails1a:SetText(a[1]);
			if(l.removed == true)then
				n.stageDetails2a:SetText(e.locale["_EXPIRED"]);
				n.stageDetails2a:SetTextColor(.5, .5, .5);
				SetDesaturation(n.startChallenge1.background, true);
				n.startChallenge1:EnableMouse(false);
			elseif(l.ended == true)then
				n.stageDetails2a:SetFormattedText("%dh %dm", o.TimeBreakdown(l.elapsed));
				n.stageDetails2a:SetTextColor(.5, .5, .5);
				SetDesaturation(n.startChallenge1.background, true);
				n.startChallenge1:EnableMouse(false);
			else
				hours, minutes = o.TimeBreakdown(l.elapsed);
				n.stageDetails2a:SetFormattedText("%dh %dm", hours, minutes);
				if(hours < 2)then
					n.stageDetails2a:SetTextColor(1, 0, 0);
				elseif(hours < 8)then
					n.stageDetails2a:SetTextColor(1, 1, 0);
				else
					n.stageDetails2a:SetTextColor(0, 1, 0);
				end
				SetDesaturation(n.startChallenge1.background, false);
				n.startChallenge1:EnableMouse(true);
			end
			n.stageDetails3a:SetText(a[4])
			n.stageDetails4a:SetText("|cFF7FD9FFHero: "..config.MatchHeroName(a[9]).."|r"..string.char(10)..(a[6] or ""));
			n.levelImage1.tex:SetTexture(e.artPath.."bg"..a[3].."_thumb");
			local t = 0;
			local l = 0;
			local d = 0;
			local s = NONE;
			local r = 0;
			i = o.TableFind(c, e.name);
			r = a[7][i];
			if(r >  - 1)then
				for e = 1, #c do
					if(a[7][e] >  - 1)then
						l = l + 1;
						if(e ~= i)then
							if(a[7][e] < r)then
								t = t + 1;
							end
						end
					end
					if(a[7][e] > d)then
						d = a[7][e];
						s = e;
					end
				end
			end
			t = l - t;
			if(r == -1)then
				n.stageDetails6a:SetText(n.stageDetails6a.caption1);
				SetDesaturation(n.startChallenge1.background, false);
				n.startChallenge1:EnableMouse(true);
			else
				n.stageDetails6a:SetFormattedText(n.stageDetails6a.caption2, t, l);
				SetDesaturation(n.startChallenge1.background, true);
				n.startChallenge1:EnableMouse(false);
			end
		end
	end
	local n = o:CreateCaption(0, 0, e.locale["CHALLENGE"], a, 40, .05, .66, 1, 1, nil)
	n:ClearAllPoints();
	n:SetPoint("Top", 0,  - 22);
	n.caption1 = n:GetText();
	n.caption2 = e.locale["CHALLENGE_DETAILS"];
	a.title = n;
	-- the two swords from the Credits page, either side of the title
	do
		local cut = e.artCut["peggleBringer"];
		local sword = a:CreateTexture(nil, "Artwork");
		sword:SetPoint("Top", a, "Top",  - 205,  - 18);
		sword:SetWidth(math.floor((cut[4] - cut[3]) * (512 - 128) + .5));
		sword:SetHeight(math.floor((cut[2] - cut[1]) * (512 - 128) + .5));
		sword:SetTexture(e.artPath.."board1");
		sword:SetTexCoord(cut[2], cut[3], cut[1], cut[3], cut[2], cut[4], cut[1], cut[4]);
		a.sword = sword;
		sword = a:CreateTexture(nil, "Artwork");
		sword:SetPoint("Top", a, "Top", 205,  - 18);
		sword:SetWidth(math.floor((cut[4] - cut[3]) * (512 - 128) + .5));
		sword:SetHeight(math.floor((cut[2] - cut[1]) * (512 - 128) + .5));
		sword:SetTexture(e.artPath.."board1");
		sword:SetTexCoord(cut[2], cut[4], cut[1], cut[4], cut[2], cut[3], cut[1], cut[3]);
		a.swordRight = sword;
	end
	local i = CreateFrame("Frame", "", a, config.backdroptmpl);
	i:SetPoint("Topleft", 10,  - 58)
	i:SetPoint("Bottomleft", 10, 10);
	i:SetWidth(200);
	d.bgFile = e.artPath.."windowBackground";
	d.tileSize = 128;
	d.tile = false;
	i:SetBackdrop(d);
	i:SetBackdropColor(.4, .4, .4, 1);
	i:SetBackdropBorderColor(1, 1, 1);
	i = CreateFrame("Frame", "", i, config.backdroptmpl);
	i:SetPoint("Topleft", 6,  - 30)
	i:SetPoint("Bottomright",  - 6, 6 + 66);
	d.bgFile = e.artPath.."windowBackground";
	d.tileSize = 128;
	d.tile = false;
	i:SetBackdrop(d);
	i:SetBackdropColor(.2, .2, .2, 1);
	i:SetBackdropBorderColor(1, 1, 1);
	local r = CreateFrame("Slider", "Peggle_challengeListSlider", i, "UIPanelScrollBarTemplate");
	config.FixScrollThumb(r);
	r:SetPoint("TopRight", i, "TopRight",  - 6,  - 21);
	r:SetPoint("BottomRight", i, "BottomRight",  - 6, 23);
	r:SetValueStep(1);
	r:SetMinMaxValues(0, 0);
	r:SetScript("OnValueChanged", function()end);
	r:SetValue(0);
	r:SetScript("OnValueChanged", function(e)
		t.catagoryScreen.frames[3].content1:UpdateScreen()
	end);
	r.background = r:CreateTexture(nil, "background");
	r.background:SetPoint("TopLeft")
	r.background:SetPoint("BottomRight",  - 1, 0)
	r.background:SetTexture(0, 0, 0, .35);
	getglobal(r:GetName().."ScrollUpButton"):SetScript("OnClick", function(e)
		e:GetParent():SetValue(e:GetParent():GetValue() - 1);
	end);
	getglobal(r:GetName().."ScrollDownButton"):SetScript("OnClick", function(e)
		e:GetParent():SetValue(e:GetParent():GetValue() + 1);
	end);
	a.listSlider = r;
	n = o:CreateCaption(20, 138, e.locale["CHALLENGE_LIST"], i, 16, 1, 1, 0, 1, nil)
	n:ClearAllPoints();
	n:SetPoint("Top", i:GetParent(), "Top", 0,  - 10);
	n:SetWidth(180);
	n.caption1 = n:GetText();
	n.caption2 = e.locale["CHALLENGE_PLAYER"]
	a.catagory1 = n;
	local C = function(e)
		local t = t.catagoryScreen.frames[3].content1
		local n = t["info"..e:GetID().."1"]:GetText();
		local o = e:GetID() + t.listSlider:GetValue();
		if n and(n ~= "")then
			if(t.showID ~= o)then
				e.tex:SetAlpha(.5);
			end
		end
	end
	local T = function(n)
		local e = t.catagoryScreen.frames[3].content1
		local t = n:GetID() + e.listSlider:GetValue();
		if(e.showID ~= t)then
			n.tex:SetAlpha(0);
		end
	end
	local f = function(e, n)
		local e = t.catagoryScreen.frames[3].content1;
		e.listSlider:SetValue(e.listSlider:GetValue() - (n * 3));
	end
	local r = function(n)
		local e = t.catagoryScreen.frames[3].content1;
		local o = e["info"..n:GetID().."1"]:GetText();
		local t = n:GetID() + e.listSlider:GetValue();
		if o and(o ~= "")then
			if(e.showID ~= t)then
				local o;
				for t = 1, 13 do
					e["highlight"..t].tex:SetAlpha(0);
				end
				n.tex:SetAlpha(1);
				e.showID = t;
				e.state = 2;
				Y[e.showID].new = nil;
				e:Hide();
				e:Show();
			end
		end
	end
	local P, h;
	for t = 1, 13 do
		n = o:CreateCaption(10, 10 + (t - 1) * 20, "nameGoesHere", i, 11, 1, 1, 1, nil, nil)
		n:ClearAllPoints();
		n:SetPoint("Topleft", 10,  - 10 - (t - 1) * 20);
		n:SetWidth(100);
		n:SetHeight(14);
		n:SetJustifyH("LEFT");
		a["info"..t.."1"] = n;
		n = o:CreateCaption(170, 10 + (t - 1) * 20, "48h 44m", i, 11, 1, 1, 1, nil, nil)
		n:ClearAllPoints();
		n:SetPoint("Topright",  - 22,  - 10 - (t - 1) * 20);
		n:SetWidth(90);
		n:SetHeight(14);
		n:SetJustifyH("RIGHT");
		a["info"..t.."2"] = n;
		h = i:CreateTexture(nil, "Artwork");
		h:SetWidth(32);
		h:SetHeight(16);
		h:SetPoint("Topleft",  - 14,  - 9 - (t - 1) * 20);
		h:SetTexture(e.artPath.."new");
		a["info"..t.."New"] = h;
		h:Hide();
		h = i:CreateTexture(nil, "Artwork");
		h:SetWidth(16);
		h:SetHeight(16);
		h:SetPoint("Topleft",  - 8,  - 9 - (t - 1) * 20);
		h:SetTexture(e.artPath.."checkmark");
		a["info"..t.."Played"] = h;
		h:Hide();
		l = CreateFrame("Frame", "", i);
		l:SetWidth(156);
		l:SetHeight(20);
		l:SetPoint("Topleft", 10,  - 8 - (t - 1) * 20);
		l:SetScript("OnEnter", C);
		l:SetScript("OnLeave", T);
		l:SetScript("OnMouseUp", r);
		l:SetScript("OnMouseWheel", f);
		l.tex = i:CreateTexture(nil, "Artwork");
		l.tex:SetAllPoints(l);
		l.tex:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight");
		config.ListHighlight(l.tex);
		l.tex:SetAlpha(0);
		l.tex:SetBlendMode("ADD");
		l:EnableMouse(true);
		l:EnableMouseWheel(true);
		l:SetID(t);
		a["highlight"..t] = l;
	end
	l = m(0, 0, 36, "buttonNewChallenge", nil, "newChallengeButton", i:GetParent(), function(n)
		local t = t.catagoryScreen.frames[3];
		t.content1:Hide();
		table.wipe(t.content2.inviteList);
		s(t.content2.inviteList, e.name);
		t.content2.active = true;
		t.content2.nameSlider:SetValue(0);
		t.content2.setSrc = 0;
		t.content2.inviteBox:GetScript("OnClick")(t.content2.inviteBox);
		t.content2.invitedCount:SetFormattedText(t.content2.invitedCount.caption, 1);
		t.content2.inviteSlider:SetValue(0);
		t.content2.inviteSlider:SetMinMaxValues(0, 0);
		t.content2.inviteSlider:GetScript("OnValueChanged")(t.content2.inviteSlider);
		t.content2:Show();
	end)
	l:ClearAllPoints();
	l:SetPoint("Bottom", 0, 34);
	a.newChallenge = l;
	n = o:CreateCaption(20, 138, e.locale["CHALLENGE_LIMIT"], i:GetParent(), 10, 1, 1, 1, nil, nil)
	n:ClearAllPoints();
	n:SetPoint("Bottom", i:GetParent(), "Bottom", 0, 10);
	n:SetWidth(180);
	i = CreateFrame("Frame", "", a, config.backdroptmpl);
	i:SetPoint("Topleft", 10 + 200,  - 58)
	i:SetPoint("Bottomright",  - 10, 10);
	i:SetWidth(200);
	d.bgFile = e.artPath.."windowBackground";
	d.tileSize = 128;
	d.tile = false;
	i:SetBackdrop(d);
	i:SetBackdropColor(.4, .4, .4, 1);
	i:SetBackdropBorderColor(1, 1, 1);
	n = o:CreateCaption(190, 138, e.locale["CHALLENGE_DETAILS"], i, 16, 1, 1, 0, 1, nil)
	n:ClearAllPoints();
	n:SetPoint("Top", i, "Top", 0,  - 10);
	n:SetWidth(180);
	a.details = n;
	n = o:CreateCaption(0, 0, e.locale["CHALLENGE_DESC"], i, 18, 1, .55, 0, 1, nil)
	n:ClearAllPoints();
	n:SetPoint("Center");
	a.noneSelected = n;
	local r = 30;
	n = o:CreateCaption(12, r, e.locale["CHALLENGE_CAT1"], i, 12, 1, 1, 0, nil, nil)
	a.stageDetails1 = n;
	n = o:CreateCaption(62, r, "nameGoesHere", i, 12, 1, 1, 1, nil, nil)
	n:ClearAllPoints();
	n:SetPoint("Topright", i, "Topleft", 10 + 128,  - r);
	n:SetJustifyH("RIGHT");
	a.stageDetails1a = n;
	r = r + 16;
	n = o:CreateCaption(12, r, e.locale["CHALLENGE_CAT5"], i, 12, 1, 1, 0, nil, nil)
	a.stageDetails2 = n;
	n = o:CreateCaption(82, r, "47h 59m", i, 12, 1, 1, 1, nil, nil)
	n:ClearAllPoints();
	n:SetPoint("Topright", i, "Topleft", 10 + 128,  - r);
	n:SetJustifyH("RIGHT");
	a.stageDetails2a = n;
	r = r + 16;
	n = o:CreateCaption(12, r, e.locale["CHALLENGE_CAT3"], i, 12, 1, 1, 0, nil, nil)
	a.stageDetails3 = n;
	n = o:CreateCaption(82, r, "0", i, 12, 1, 1, 1, nil, nil)
	n:ClearAllPoints();
	n:SetPoint("Topright", i, "Topleft", 10 + 128,  - r);
	n:SetJustifyH("RIGHT");
	a.stageDetails3a = n;
	r = r + 16;
	n = o:CreateCaption(12, r, e.locale["CHALLENGE_CAT2"], i, 12, 1, 1, 0, nil, nil)
	a.stageDetails5 = n;
	n:SetText("");
	n = o:CreateCaption(12, r, "", i, 12, 1, 1, 1, nil, nil)
	a.stageDetails5a = n;
	l = CreateFrame("Frame", "", i, config.backdroptmpl);
	l:SetPoint("Topleft", 10,  - r)
	l:SetWidth(128)
	l:SetHeight(128)
	l:SetBackdrop(d);
	l:SetBackdropColor(0, 0, 0, 0);
	l:SetBackdropBorderColor(1, 1, 1);
	a.levelImage1 = l;
	h = l:CreateTexture(nil, "Background");
	h:SetTexture(e.artPath.."bg1_thumb");
	h:SetPoint("Center");
	h:SetWidth(128 - 14)
	h:SetHeight(128 - 14)
	l.tex = h;
	r = r + l:GetHeight();
	n = o:CreateCaption(12, r, e.locale["CHALLENGE_CAT6"], i, 12, 1, 1, 0, nil, nil)
	a.stageDetails4 = n;
	r = r + 16;
	n = o:CreateCaption(12, r, "", i, 12, 1, 1, 1, nil, nil)
	n:SetWidth(128);
	n:SetHeight(13 * 4);
	n:SetJustifyH("LEFT");
	n:SetJustifyV("TOP");
	a.stageDetails4a = n;
	r = r + 13 * 4 + 4;
	n = o:CreateCaption(12, r, e.locale["CHALLENGE_CAT4"], i, 12, 1, 1, 0, nil, nil)
	a.stageDetails6 = n;
	r = r + 16;
	n = o:CreateCaption(12, r, e.locale["NOT_PLAYED"], i, 12, 1, 1, 1, nil, nil)
	n.caption1 = n:GetText();
	n.caption2 = e.locale["CHALLENGE_RANK"];
	a.stageDetails6a = n;
	l = m(0, 0, 40, "buttonGo", nil, "startChallengeButton1", i, function(n)
		local t = t.catagoryScreen.frames[3];
		local n = e.currentView[3];
		local e = t.content1.extraInfo
		t.content1.state = 2;
		t.content1:Hide();
		t.content1:Show();
		Ae(n, e);
		R(true);
		Q = false;
	end)
	l:ClearAllPoints();
	l:SetPoint("Bottom",  - 75, 21);
	a.startChallenge1 = l;
	l = m(0, 0, 40, "buttonBack", nil, "backChallengeButton", i, function(e)
		local e = t.catagoryScreen.frames[3];
		e.content1.state = 0;
		e.content1:Hide();
		e.content1:Show();
	end, nil, true)
	l:ClearAllPoints();
	l:SetPoint("Bottom", 75, 21);
	a.backChallenge = l;
	l = CreateFrame("Button", "PeggleButton_cancelChallenge", i, "UIPanelButtonTemplate");
	config.StyleButton(l);
	l:SetWidth(104);
	l:SetHeight(22);
	l:SetPoint("TopRight", i, "TopRight",  - 10,  - 5);
	l:SetText("Cancel Battle");
	l:SetScript("OnClick", function(btn)
		local page = t.catagoryScreen.frames[3].content1;
		local ch = page.showID and Y[page.showID];
		if not ch then
			return;
		end
		local mine = (ch.creator == e.name) and not ch.ended;
		config.Confirm(mine and "Cancel this Battle for everyone? The other players are told it has ended." or "Remove this Battle from your list?", function()
			if mine then
				config.CancelChallenge(ch);
			else
				config.RemoveChallenge(ch);
			end
		end);
	end);
	l:Hide();
	a.cancelChallenge = l;
	i = CreateFrame("Frame", "", i, config.backdroptmpl);
	i:SetPoint("Topright",  - 6,  - 30)
	i:SetPoint("Bottomright",  - 6, 6 + 66);
	i:SetWidth(270);
	d.bgFile = e.artPath.."windowBackground";
	d.tileSize = 128;
	d.tile = false;
	i:SetBackdrop(d);
	i:SetBackdropColor(.2, .2, .2, 1);
	i:SetBackdropBorderColor(1, 1, 1);
	a.nameList = i;
	i:EnableMouseWheel(true)
	i:SetScript("OnMouseWheel", function(n, e)
		a = t.catagoryScreen.frames[3].content1;
		a.nameListSlider:SetValue(a.nameListSlider:GetValue() - (e * 3));
	end);
	local r = CreateFrame("Slider", "Peggle_challengeNameListSlider", i, "UIPanelScrollBarTemplate");
	config.FixScrollThumb(r);
	r:SetPoint("TopRight", i, "TopRight",  - 6,  - 21);
	r:SetPoint("BottomRight", i, "BottomRight",  - 6, 23);
	r:SetValueStep(1);
	r:SetMinMaxValues(0, 0);
	r:SetScript("OnValueChanged", function()end);
	r:SetValue(0);
	r:SetScript("OnValueChanged", function(e)
		t.catagoryScreen.frames[3].content1:UpdateScreen()
	end);
	r.background = r:CreateTexture(nil, "background");
	r.background:SetPoint("TopLeft")
	r.background:SetPoint("BottomRight",  - 1, 0)
	r.background:SetTexture(0, 0, 0, .35);
	getglobal(r:GetName().."ScrollUpButton"):SetScript("OnClick", function(e)
		e:GetParent():SetValue(e:GetParent():GetValue() - 1);
	end);
	getglobal(r:GetName().."ScrollDownButton"):SetScript("OnClick", function(e)
		e:GetParent():SetValue(e:GetParent():GetValue() + 1);
	end);
	a.nameListSlider = r;
	local f, h;
	for t = 1, 13 do
		n = o:CreateCaption(10, 66 + (t - 1) * 20, t, i, 11, 1, 1, 1, nil, nil)
		n:ClearAllPoints();
		n:SetPoint("Topleft", 12,  - 10 - (t - 1) * 20);
		n:SetWidth(24);
		n:SetHeight(14);
		n:SetJustifyH("LEFT");
		a["infoRank"..t] = n;
		n = o:CreateCaption(10, 66 + (t - 1) * 20, "nameGoesHereSomeMore", i, 11, 1, 1, 1, nil, nil)
		n:ClearAllPoints();
		n:SetPoint("Topleft", 32,  - 10 - (t - 1) * 20);
		n:SetWidth(100);
		n:SetHeight(14);
		n:SetJustifyH("LEFT");
		a["infoName"..t.."1"] = n;
		n = o:CreateCaption(170, 10 + (t - 1) * 20, "9,999,999", i, 11, 1, 1, 1, nil, nil)
		n:ClearAllPoints();
		n:SetPoint("Topright",  - 24,  - 10 - (t - 1) * 20);
		n:SetWidth(80);
		n:SetHeight(14);
		n:SetJustifyH("RIGHT");
		a["infoName"..t.."2"] = n;
		h = i:CreateTexture(nil, "Artwork");
		h:SetWidth(16);
		h:SetHeight(16);
		h:SetPoint("Topleft", 122 + 14,  - 9 - (t - 1) * 20);
		h:SetTexture(e.artPath.."char1Power");
		a["infoName"..t.."a"] = h;
		h = i:CreateTexture(nil, "Artwork");
		h:SetWidth(16);
		h:SetHeight(16);
		h:SetPoint("Topleft", 122 + 30,  - 9 - (t - 1) * 20);
		h:SetTexture(e.artPath.."bannerSmallRed");
		a["infoName"..t.."b"] = h;
		n = o:CreateCaption(122 + 30, 10 + (t - 1) * 20, "12", i, 9, 1, 1, 1, 1, nil)
		n:SetWidth(18);
		n:SetHeight(14);
		a["infoName"..t.."b1"] = n;
		h = i:CreateTexture(nil, "Artwork");
		h:SetWidth(16);
		h:SetHeight(16);
		h:SetPoint("Topleft", 122 + 46,  - 9 - (t - 1) * 20);
		h:SetTexture(e.artPath.."bannerSmallBlue");
		a["infoName"..t.."c"] = h;
		n = o:CreateCaption(122 + 46, 10 + (t - 1) * 20, "8", i, 9, 1, 1, 1, 1, nil)
		n:SetWidth(18);
		n:SetHeight(14);
		a["infoName"..t.."c1"] = n;
	end
	a:Show();
	a = CreateFrame("Frame", "", p);
	a:SetPoint("TopLeft")
	a:SetPoint("BottomRight");
	a:Hide();
	p.content2 = a;
	-- back to the list of Battles without making one (and without switching tabs)
	do
		local backList = CreateFrame("Button", "PeggleButton_newBattleBack", a, "UIPanelButtonTemplate");
		config.StyleButton(backList);
		backList:SetWidth(112);
		backList:SetHeight(22);
		backList:SetPoint("BottomLeft", 12, 44); -- just above the "Note: Offline users..." line
		backList:SetText("Back to Battles");
		backList:SetScript("OnClick", function()
			local page = t.catagoryScreen.frames[3];
			page.content2.active = nil;
			page.content2:Hide();
			page.content1.state = 0;
			page.content1:Hide();
			page.content1:Show();
		end);
		a.backToList = backList;
	end
	a.setSrc = 1;
	a.setDur = 1;
	a.serverChannels = {EnumerateServerChannels()}
	a.channelNames = {};
	a.inviteList = {};
	a.grabNames = {};
	a.getChannels = function(e)
		return("|cFF4CB2FF"..t.catagoryScreen.frames[3].content2.channelNames[e]);
	end
	n = o:CreateCaption(10, 26, e.locale["CHALLENGE_NEW"], a, 30, .05, .66, 1, 1, nil)
	n.caption1 = n:GetText();
	n.caption2 = e.locale["CHALLENGE"];
	n:SetWidth(330);
	n = o:CreateCaption(10, 60, e.locale["INVITEES"], a, 25, 1, 1, 0, 1, nil)
	n:SetWidth(330);
	n = o:CreateCaption(10, 90, e.locale["CHALLENGE_DESC1"], a, 11, 1, 1, 0, 1, nil)
	n:SetWidth(330);
	n = o:CreateCaption(10, 90, e.locale["CHALLENGE_DESC2"], a, 11, 1, 1, 0, nil, nil)
	n:ClearAllPoints();
	n:SetPoint("Bottomleft", 10, 40);
	n:SetWidth(350);
	n:Hide();
	a.customText = n;
	n = o:CreateCaption(10, 90, e.locale["CHALLENGE_DESC3"], a, 10, 1, 1, 1, nil, "")
	n:ClearAllPoints();
	n:SetPoint("Bottomleft", 10, 10);
	n:SetWidth(350);
	l = x(14, 342, e.locale["CHALLENGE_VIEW_OFFLINE"], "guildViewOnline", true, a, function(e)
		if(e:GetChecked())then
			SetGuildRosterShowOffline(true);
		else
			SetGuildRosterShowOffline(false);
		end
		a.nameSlider:SetMinMaxValues(0, F(0, GetNumGuildMembers() - 15));
		local e = t.catagoryScreen.frames[3].content2;
		if(e.nameSlider:GetValue() == 0)then
			e.nameSlider:GetScript("OnValueChanged")(e.nameSlider);
		else
			e.nameSlider:SetValue(0);
		end
	end, 1, .82, 0, tooltipText, true)
	-- only gets set on init so might no necessarily reflect the current guildmember offline option
	l:SetChecked(GetGuildRosterShowOffline())
	l:SetHitRectInsets(0,  - 120, 0, 0);
	l:Hide();
	a.guildOption1 = l;
	l = x(14, 362, e.locale["CHALLENGE_SORT_ONLINE"], "guildSortOnline", true, a, function(e)
		if(e:GetChecked())then
			SortGuildRoster("online");
		else
			SortGuildRoster("name");
		end
		a.nameSlider:SetMinMaxValues(0, F(0, GetNumGuildMembers() - 15));
		local e = t.catagoryScreen.frames[3].content2;
		if(e.nameSlider:GetValue() == 0)then
			e.nameSlider:GetScript("OnValueChanged")(e.nameSlider);
		else
			e.nameSlider:SetValue(0);
		end
	end, 1, .82, 0, tooltipText, true)
	l:SetHitRectInsets(0,  - 120, 0, 0);
	l:Hide();
	a.guildOption2 = l;
	local f = function(n)
		local e = t.catagoryScreen.frames[3].content2;
		if(e.setSrc ~= n:GetID())then
			e.setSrc = n:GetID();
			getglobal("PeggleCheckbox_inviteSrc1"):SetChecked(false);
			getglobal("PeggleCheckbox_inviteSrc2"):SetChecked(false);
			getglobal("PeggleCheckbox_inviteSrc3"):SetChecked(false);
			e.customText:Hide();
			e.guildOption1:Hide();
			e.guildOption2:Hide();
			if(e.setSrc == 1)then
				e.nameSlider:SetMinMaxValues(0, F(0, C_FriendList.GetNumFriends() - 15));
			elseif(e.setSrc == 2)then
				local t = GetNumGuildMembers();
				e.nameSlider:SetMinMaxValues(0, F(0, t - 15));
				if(t > 0)then
					if((GetGuildRosterInfo(1)) > (GetGuildRosterInfo(t)))then
						SortGuildRoster("name");
					end
				end
				e.guildOption1:Show();
				--e.guildOption2:Show(); -- seems unneeded
			else
				local n, n, o, t
				e.serverChannels = {EnumerateServerChannels()}
				table.wipe(e.channelNames);
				for n = 1, 15 do
					o, t = GetChannelName(n);
					if(t)then
						for n = 1, #e.serverChannels do
							if(string.find(t, e.serverChannels[n]))then
								t = nil;
								break;
							end
						end
						if(t)then
							s(e.channelNames, t)
						end
					end
				end
				e.nameSlider:SetMinMaxValues(0, 0);
				e.customText:Show();
			end
			if(e.nameSlider:GetValue() == 0)then
				e.nameSlider:GetScript("OnValueChanged")(e.nameSlider);
			else
				e.nameSlider:SetValue(0);
			end
		end
		n:SetChecked(true);
	end
	local T = function(l)
		local e = t.catagoryScreen.frames[3].content2;
		local o, n;
		if(e.setSrc == 1)then
			o = C_FriendList.GetFriendInfoByIndex;
			n = C_FriendList.GetNumFriends();
		elseif(e.setSrc == 2)then
			o = GetGuildRosterInfo;
			n = GetNumGuildMembers();
		else
			o = e.getChannels;
			n = #e.channelNames;
		end
		local t;
		local a = l:GetValue();
		local i, d, r, t;
		for l = 1, 15 do
			t = e["listItemA"..l];
			if(l + a) <= n then
				if o == C_FriendList.GetFriendInfoByIndex then
					local info = o(l + a);
					i = info.name
					d = info.connected
					r = info.guid
				else
					i, _, _, _, d, _, _, _, r = o(l + a);
				end
				t:SetText(i);
				if(e.setSrc == 1)and not d then
					t:SetTextColor(.5, .5, .5);
				elseif(e.setSrc == 2)and not r then
					t:SetTextColor(.5, .5, .5);
				else
					t:SetTextColor(1, 1, 1);
				end
			else
				t:SetText("");
			end
		end
	end
	local A = function(n)
		local t = t.catagoryScreen.frames[3].content2;
		local a = #t.inviteList;
		local o, e;
		local o = n:GetValue();
		for n = 1, 15 do
			e = t["listItemB"..n];
			if(n + o) <= a then
				e:SetText(t.inviteList[n + o]);
				e:SetTextColor(1, 1, 1);
			else
				e:SetText("");
			end
		end
	end
	l = x(13, 115, e.locale["CHALLENGE_INVITE1"], "inviteSrc1", true, a, f, 1, .82, 0, tooltipText, true)
	l:SetHitRectInsets(0,  - 40, 0, 0);
	l:SetID(1);
	l:SetChecked(true);
	a.inviteBox = l;
	l = x(75, 115, e.locale["CHALLENGE_INVITE2"], "inviteSrc2", true, a, f, 1, .82, 0, tooltipText, true)
	l:SetHitRectInsets(0,  - 25, 0, 0);
	l:SetID(2);
	l = x(123, 115, e.locale["CHALLENGE_INVITE3"], "inviteSrc3", true, a, f, 1, .82, 0, tooltipText, true)
	l:SetHitRectInsets(0,  - 50, 0, 0);
	l:SetID(3);
	n = o:CreateCaption(320, 115, e.locale["INVITED"], a, 12, 1, 1, 0, 1, nil)
	n:ClearAllPoints();
	n:SetPoint("Bottom", a, "Topleft", 280,  - 130);
	n:SetWidth(150);
	n.caption = e.locale["INVITED"];
	a.invitedCount = n;
	i = CreateFrame("Frame", "", a, config.backdroptmpl);
	i:SetPoint("Topleft", 10,  - 135)
	i:SetWidth(160);
	i:SetHeight(204);
	i:SetBackdrop(d);
	i:SetBackdropColor(0, 0, 0, 0);
	i:SetBackdropBorderColor(1, 1, 1);
	r = CreateFrame("Slider", "Peggle_challengeNameSlider", i, "UIPanelScrollBarTemplate");
	config.FixScrollThumb(r);
	r:SetPoint("TopRight", i, "TopRight",  - 6,  - 21);
	r:SetPoint("BottomRight", i, "BottomRight",  - 6, 23);
	r:SetValueStep(1);
	r:SetMinMaxValues(0, 0);
	r:SetScript("OnValueChanged", T);
	r.background = r:CreateTexture(nil, "background");
	r.background:SetPoint("TopLeft")
	r.background:SetPoint("BottomRight",  - 1, 0)
	r.background:SetTexture(0, 0, 0, .35);
	getglobal(r:GetName().."ScrollUpButton"):SetScript("OnClick", getglobal("Peggle_challengeNameListSliderScrollUpButton"):GetScript("OnClick"));
	getglobal(r:GetName().."ScrollDownButton"):SetScript("OnClick", getglobal("Peggle_challengeNameListSliderScrollDownButton"):GetScript("OnClick"));
	a.nameSlider = r;
	local E = function(e)
		local t = t.catagoryScreen.frames[3].content2["listItemA"..e:GetID()]:GetText();
		if t and(t ~= "")then
			e.tex:SetAlpha(.25);
		end
	end
	local L = function(e)
	local t = t.catagoryScreen.frames[3].content2["listItemB"..e:GetID()]:GetText();
		if t and(t ~= "")then
			e.tex:SetAlpha(.25);
		end
	end
	local f = function(e)
		e.tex:SetAlpha(0);
	end
	local b = function(n, e)
		a = t.catagoryScreen.frames[3].content2;
		a.nameSlider:SetValue(a.nameSlider:GetValue() - (e * 3));
	end
	local T = function(n, e)
		a = t.catagoryScreen.frames[3].content2;
		a.inviteSlider:SetValue(a.inviteSlider:GetValue() - (e * 3));
	end
	local C = function(e)
		a = t.catagoryScreen.frames[3].content2;
		name = a["listItemA"..e:GetID()]:GetText();
		if name and((name ~= "")and(name ~= "Feature Incomplete!"))then
			if o.TableInsertOnce(a.inviteList, name, true)then
				a.invitedCount:SetFormattedText(a.invitedCount.caption, #a.inviteList);
				a.inviteSlider:GetScript("OnValueChanged")(a.inviteSlider);
				r:SetMinMaxValues(0, F(0, #a.inviteList - 15));
			end
		end
	end
	local P = function(n)
		a = t.catagoryScreen.frames[3].content2;
		offset = a.inviteSlider:GetValue();
		name = a["listItemB"..n:GetID()]:GetText();
		if name and(name ~= "")and(name ~= e.name)then
			u(a.inviteList, n:GetID() + offset);
			a.invitedCount:SetFormattedText(a.invitedCount.caption, #a.inviteList);
			r:SetMinMaxValues(0, F(0, #a.inviteList - 15));
			if(a.inviteSlider:GetValue() > (F(0, (#a.inviteList - 15))))then
				a.inviteSlider:SetValue(F(0, #a.inviteList - 15));
			else
				a.inviteSlider:GetScript("OnValueChanged")(a.inviteSlider);
			end
		end
	end
	for e = 1, 15 do
		n = o:CreateCaption(14, 10 + (e - 1) * 12, "NameGoesHere", i, 10, 1, 1, 1, nil, "")
		n:SetWidth(128);
		n:SetHeight(12);
		n:SetJustifyH("LEFT");
		a["listItemA"..e] = n;
		l = CreateFrame("Frame", "", i);
		l:SetWidth(126);
		l:SetHeight(12);
		l:SetPoint("Topleft", 10,  - 11 - (e - 1) * 12);
		l:SetScript("OnEnter", E);
		l:SetScript("OnLeave", f);
		l:SetScript("OnMouseUp", C);
		l:SetScript("OnMouseWheel", b);
		l.tex = i:CreateTexture(nil, "Artwork");
		l.tex:SetAllPoints(l);
		l.tex:SetTexture(1, 1, 0);
		l.tex:SetAlpha(0);
		l:EnableMouse(true);
		l:EnableMouseWheel(true);
		l:SetID(e);
	end
	i = CreateFrame("Frame", "", a, config.backdroptmpl);
	i:SetPoint("Topleft", 200,  - 135)
	i:SetWidth(160);
	i:SetHeight(204);
	i:SetBackdrop(d);
	i:SetBackdropColor(0, 0, 0, 0);
	i:SetBackdropBorderColor(1, 1, 1);
	r = CreateFrame("Slider", "Peggle_invitedNameSlider", i, "UIPanelScrollBarTemplate");
	config.FixScrollThumb(r);
	r:SetPoint("TopRight", i, "TopRight",  - 6,  - 21);
	r:SetPoint("BottomRight", i, "BottomRight",  - 6, 23);
	r:SetValueStep(1);
	r:SetMinMaxValues(0, 0);
	r:SetScript("OnValueChanged", A);
	r.background = r:CreateTexture(nil, "background");
	r.background:SetPoint("TopLeft")
	r.background:SetPoint("BottomRight",  - 1, 0)
	r.background:SetTexture(0, 0, 0, .35);
	getglobal(r:GetName().."ScrollUpButton"):SetScript("OnClick", getglobal("Peggle_challengeNameListSliderScrollUpButton"):GetScript("OnClick"));
	getglobal(r:GetName().."ScrollDownButton"):SetScript("OnClick", getglobal("Peggle_challengeNameListSliderScrollDownButton"):GetScript("OnClick"));
	a.inviteSlider = r;
	for e = 1, 15 do
		n = o:CreateCaption(14, 10 + (e - 1) * 12, "NameGoesHere", i, 10, 1, 1, 1, nil, "")
		n:SetWidth(128);
		n:SetHeight(12);
		n:SetJustifyH("LEFT");
		a["listItemB"..e] = n;
		l = CreateFrame("Frame", "", i);
		l:SetWidth(126);
		l:SetHeight(12);
		l:SetPoint("Topleft", 10,  - 11 - (e - 1) * 12);
		l:SetScript("OnEnter", L);
		l:SetScript("OnLeave", f);
		l:SetScript("OnMouseUp", P);
		l:SetScript("OnMouseWheel", T);
		l.tex = i:CreateTexture(nil, "Artwork");
		l.tex:SetAllPoints(l);
		l.tex:SetTexture(1, 1, 0);
		l.tex:SetAlpha(0);
		l:EnableMouse(true);
		l:EnableMouseWheel(true);
		l:SetID(e);
	end
	l = CreateFrame("Frame", "", a, config.backdroptmpl);
	l:SetPoint("Topleft", 340 + 16 + 32 - 32 + 16,  - 46)
	l:SetWidth(176)
	l:SetHeight(176)
	l:SetBackdrop(d);
	l:SetBackdropColor(0, 0, 0, 0);
	l:SetBackdropBorderColor(1, 1, 1);
	h = l:CreateTexture(nil, "Background");
	h:SetTexture(e.artPath.."bg1_thumb");
	h:SetPoint("Center");
	h:SetWidth(176 - 14)
	h:SetHeight(176 - 14)
	a.levelImage = h;
	l = We(357, 16, 256 - 16, "challengeLevels", nil, nil, a, a.levelImage, nil)
	getglobal(l:GetName().."Text"):ClearAllPoints();
	getglobal(l:GetName().."Text"):SetPoint("Center", a, "Topleft", 360 + (256 - 16) / 2,  - 16 - 13);
	a.info = l;
	l = o:CreateSlider(383,  - 240, 200, e.locale["CHALLENGE_SHOTS"], "challengeNumShots", a, 1, 10, 1, nil, nil, nil, nil, nil, nil, true);
	a.shots = l;
	local i = function(e)
		local t = e:GetParent();
		if(t.setDur ~= e:GetID())then
			t.setDur = e:GetID();
			getglobal("PeggleCheckbox_duration1"):SetChecked(false);
			getglobal("PeggleCheckbox_duration2"):SetChecked(false);
			getglobal("PeggleCheckbox_duration3"):SetChecked(false);
		end
		e:SetChecked(true);
	end
	n = o:CreateCaption(383, 240 + 20, e.locale["CHALLENGE_DUR"], a, 14, 1, 1, 0, 1, nil)
	n:SetWidth(200);
	l = x(383 + 0, 240 + 36, "12h", "duration1", true, a, i, 1, 1, 1, tooltipText)
	l:SetHitRectInsets(0,  - 50, 0, 0);
	l:SetID(1);
	l:SetChecked(true);
	l = x(453 + 0, 240 + 36, "24h", "duration2", true, a, i, 1, 1, 1, tooltipText)
	l:SetHitRectInsets(0,  - 50, 0, 0);
	l:SetID(2);
	l = x(523 + 0, 240 + 36, "48h", "duration3", true, a, i, 1, 1, 1, tooltipText)
	l:SetHitRectInsets(0,  - 50, 0, 0);
	l:SetID(3);
	n = o:CreateCaption(373, 240 + 60, e.locale["INVITE_NOTE"].." "..e.locale["OPTIONAL"], a, 14, 1, .82, 0, 1, nil)
	n:SetWidth(220);
	n.caption1 = n:GetText();
	n.caption2 = e.locale["INVITE_NOTE"];
	a.note1 = n;
	n = Je(383, 240 + 74, 194, "inviteNote", a, nil, nil, nil, tooltipText)
	n:SetMaxLetters(64);
	a.note2 = n;
	-- one row under the note: "HERO" label, then the drop-down
	n = o:CreateCaption(373, 240 + 114, "HERO", a, 14, 1, .82, 0, 1, nil)
	l = config.CreateHeroPicker(a, "PeggleBattleHeroPicker");
	l:SetPoint("Topleft", 410, - (240 + 106));
	a.heroPicker = l;
	l = m(0, 0, 40, "buttonChallenge", nil, "challengeButton", a, function(n)
		local n = n:GetParent();
		local l = n.inviteList;
		local a, o
		o = 1;
		table.wipe(n.grabNames);
		for e = 1, #l do
			if(W(l[o], 1) == W("|"))then
				s(n.grabNames, c(l[o], 11));
				u(l, o);
			else
				o = o + 1;
			end
		end
		if(#n.grabNames > 0)then
			ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_LIST", X);
			n.nameGrabber.elapsed = -1;
			n.nameGrabber:Show();
			return;
		end
		local a = n.info.selectedValue;
		local d = n.shots:GetValue();
		local i = 1;
		local r = 2 ^ (n.setDur - 1) * 12 * 60
		local o = n.note2:GetText();
		local l = n.inviteList;
		if(o == "")or(o == nil)then
			o = NONE;
		end
		local a = pe(a, d, i, r, l, o, n.heroPicker.value)
		s(Y, a);
		ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", M)
		a.serverName = e.name;
		local o = t.network.server;
		a[e.newInfo[14]] = true;
		s(o.tracking, a);
		s(o.list, {{}, {}, {}, nil, nil});
		o:Populate(#o.list);
		if not o:IsShown()then
			o.currentID = #o.tracking;
			o.currentNode = 0;
		end
		o:Show();
		for n = 1, #l do
			e.onlineList[l[n]] = e.onlineList[l[n]]or 2;
			t.network:Send(e.commands[16], a.id, "WHISPER", l[n]);
		end
		t.challengeTabSparks:Show();
		n.active = nil;
		local e = t.catagoryScreen.frames[3];
		e.content1.state = 2;
		e.content1.showID = #Y;
		e.content2:Hide();
		e.content1:Hide();
		e.content1:Show();
		getglobal("PeggleButton_startChallengeButton1"):GetScript("OnClick")();
	end)
	l:ClearAllPoints();
	l:SetPoint("Center", 166,  - 188);
	a.newChallenge = l;
	l = CreateFrame("Frame", "", t);
	l:SetAllPoints(t);
	l:EnableMouse(true);
	l:SetFrameLevel(l:GetFrameLevel() + 70);
	l.elapsed = -1;
	l.content = a;
	l:Hide();
	l:SetScript("OnUpdate", function(e, t)
		if(e.elapsed == -1)then
			ListChannelByName(u(e.content.grabNames));
			e.elapsed = 0;
		end
		e.elapsed = e.elapsed + t;
		if(e.elapsed > 1)then
			if(#e.content.grabNames > 0)then
				e.elapsed = -1;
			else
				e:Hide();
				ChatFrame_RemoveMessageEventFilter("CHAT_MSG_CHANNEL_LIST", X);
				e.content.newChallenge:GetScript("OnClick")(e.content.newChallenge);
			end
		end
	end);
	a.nameGrabber = l;
	l = CreateFrame("Frame", "", a.nameGrabber, config.backdroptmpl);
	l:SetPoint("Center")
	l:SetWidth(560);
	l:SetHeight(64);
	d.tileSize = 128;
	d.edgeFile = "Interface\\Glues\\Common\\TextPanel-Border"d.edgeSize = 32;
	d.bgFile = e.artPath.."windowBackground";
	l:SetBackdrop(d);
	l:SetBackdropColor(.7, .7, .7, 1);
	l:SetBackdropBorderColor(1, .8, .45);
	n = o:CreateCaption(0, 0, e.locale["GENERATING_NAMES"], l, 25, 1, .82, 0, 1, nil)
	n:ClearAllPoints();
	n:SetPoint("Center");
	l = CreateFrame("Frame", "", UIParent);
	l:SetWidth(1);
	l:SetHeight(1);
	l:SetPoint("top");
	l.elapsed = 0;
	l.sElapsed = 0;
	l:Hide();
	l:SetScript("OnUpdate", function(o, n)
		if(Y[1])then
			o.elapsed = o.elapsed + n;
			o.sElapsed = o.sElapsed + n;
			if(o.elapsed >= e.seconds)then
				o.elapsed = 0;
				local n;
				local n = Y;
				for t = 1, #n do
					n[t].elapsed = n[t].elapsed - 1;
					if(n[t].elapsed <= 0)then
						local o = S(c(n[t][g], 3 + 5, 3 + 6));
						if(n[t].ended)then
							n[t].removed = true;
							n[t].elapsed = o;
						else
							n[t].ended = true
							n[t].elapsed = o;
							if(n[t].creator == e.name)then
								e.cCount = e.cCount - 1;
							end
						end
					end
				end
				local e = t.catagoryScreen;
				local t = e.frames[3].content1;
				if(e.frames[3]:IsShown())then
					if not(e.frames[3].content2.active)then
						if(t:IsVisible())then
							t:Hide();
							t:Show();
						end
					end
				end
			end
			if(o.sElapsed >= 180)then
				local i = t.network.server;
				local d, r, n, d, l, a
				if(i.tracking[1])then
					a = e.commands[16];
					for e = 1, #i.tracking do
						r = i.tracking[e].id;
						n = i.tracking[e].namesWithoutChallenge;
						if not i.tracking[e].ended then
							for e = 1, #n do
								l = gsub(n[e], "^%l", string.upper);
								t.network:Send(a, r, "WHISPER", l);
							end
						end
					end
				end
				local d = Y
				local i;
				for c = 1, #d do
					i = d[c];
					n = i.names;
					a = e.commands[8]
					for o = 1, #n do
						l = gsub(n[o], "^%l", string.upper);
						if(l ~= e.name)then
							t.network:Send(a, "", "WHISPER", l);
						end
					end
					if(o.sChallPing)then
						o.sChallPing = nil
						a = e.commands[16];
						r = i.id;
						n = i.namesWithoutChallenge;
						for e = 1, #n do
							l = gsub(n[e], "^%l", string.upper);
							t.network:Send(a, r, "WHISPER", l);
						end
					end
				end
				o.sElapsed = 0;
			end
		end
	end);
	t.challengeTimer = l;
	return p;
end
local function G()
	local l = CreateFrame("Frame", "", t.catagoryScreen, config.backdroptmpl);
	l:SetPoint("TopLeft", 297,  - 9)
	l:SetPoint("BottomRight",  - 4, 4);
	local d = e.GetBackdrop();
	d.tileSize = 128;
	d.edgeFile = "Interface\\Glues\\Common\\TextPanel-Border"d.edgeSize = 32;
	l:SetBackdrop(d);
	l:SetBackdropColor(0, 0, 0, .5);
	l:SetBackdropBorderColor(1, 1, 1);
	l:SetFrameLevel(t.catagoryScreen:GetFrameLevel() + 1);
	s(t.catagoryScreen.frames, l);
	local r = l;
	l:Hide();
	l:SetScript("OnShow", Ve);
	local n = o:CreateCaption(0, 0, e.locale["TALENTS"], l, 40, .05, .66, 1, 1, nil)
	n:ClearAllPoints();
	n:SetPoint("Top", 0,  - 20);
	n = o:CreateCaption(0, 0, e.locale["TALENTS_DESC"], l, 18, 1, .55, 0, nil)
	n:ClearAllPoints();
	n:SetPoint("Top", 0,  - 62);
	n:SetWidth(l:GetWidth() - 20);
	local descText = n;
	descText:SetText("");
	local portrait = l:CreateTexture(nil, "ARTWORK");
	portrait:SetWidth(46);
	portrait:SetHeight(46);
	portrait:SetPoint("TopLeft", 22,  - 16);
	local portraitFrame = e.GetBackdrop();
	portraitFrame.tileSize = 128;
	portraitFrame.tile = false;
	portraitFrame.edgeFile = e.artPath.."CharSelectBorder";
	portraitFrame.edgeSize = 16;
	portraitFrame.bgFile = nil;
	local portraitBorder = CreateFrame("Frame", nil, l, config.backdroptmpl);
	portraitBorder:SetPoint("TopLeft", portrait, "TopLeft",  - 5, 5);
	portraitBorder:SetPoint("BottomRight", portrait, "BottomRight", 5,  - 5);
	portraitBorder:SetFrameLevel(l:GetFrameLevel() + 6);
	portraitBorder:SetBackdrop(portraitFrame);
	portraitBorder:SetBackdropColor(0, 0, 0, 0);
	portraitBorder:SetBackdropBorderColor(1, .82, .35);
	local abilityLabel = l:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	abilityLabel:SetPoint("TopLeft", 14,  - 90);
	abilityLabel:SetTextColor(.7, .7, .7);
	local powerIcon = l:CreateTexture(nil, "ARTWORK");
	powerIcon:SetWidth(24);
	powerIcon:SetHeight(24);
	powerIcon:SetPoint("TopLeft", 104,  - 84);
	local powerText = l:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	powerText:SetPoint("Left", powerIcon, "Right", 6, 0);
	powerText:SetTextColor(.5, 1, .5);
	local infoKind, infoTitle, infoRank, infoDesc, infoIcon;
	local abilityHover = CreateFrame("Button", nil, l);
	abilityHover:SetPoint("TopLeft", 8,  - 82);
	abilityHover:SetWidth(l:GetWidth() - 20);
	abilityHover:SetHeight(28);
	config.abilityHover = abilityHover;
	abilityHover:SetScript("OnEnter", function()
		if infoTitle then
			r.mouseOver:Hide();
			r.name:SetText(infoTitle);
			r.rank:SetText(infoRank);
			r.icon:SetTexture(infoIcon);
			r.icon:SetTexCoord(0, 1, 0, 1);
			r.icon:Show();
			r.desc:SetText(infoDesc);
			config.LayoutInfo(r);
			r.name:Show();
			r.rank:Show();
			r.desc:Show();
			r.learn:Hide();
		end
	end);
	abilityHover:SetScript("OnLeave", function()
		r.mouseOver:Show();
		r.name:Hide();
		r.rank:Hide();
		r.desc:Hide();
		r.learn:Hide();
		r.icon:Hide();
	end);
	local heroButton = CreateFrame("Button", nil, l, "UIPanelButtonTemplate");
	config.StyleButton(heroButton);
	heroButton:SetWidth(90);
	heroButton:SetHeight(24);
	heroButton:SetPoint("BottomLeft", 12, 22);
	heroButton:SetText("Choose Hero");
	heroButton:SetScript("OnClick", function()
		t.charScreen:Show();
	end);
	local resetAll = CreateFrame("Button", nil, l, "UIPanelButtonTemplate");
	config.StyleButton(resetAll);
	resetAll:SetWidth(90);
	resetAll:SetHeight(24);
	resetAll:SetPoint("BottomRight",  - 12, 22);
	resetAll:SetText("Reset All");
	resetAll:SetScript("OnClick", function()
		config.Confirm("Reset EVERYTHING?\nAll heroes, levels and talents go back to brand new. This cannot be undone.", function()
			config.FullReset();
			t.charScreen:Show();
		end);
	end);
	local function wrapText(text, width)
		local lines, line = {}, "";
		for word in string.gmatch(text, "%S+") do
			if(#line > 0)and(#line + #word + 1 > width)then
				lines[#lines + 1] = line;
				line = word;
			else
				line = (#line > 0 and (line.." ") or "")..word;
			end
		end
		lines[#lines + 1] = line;
		return table.concat(lines, "\n");
	end
	-- background of the talent tree: the hero's home city (level backgrounds: 1 Ironforge, 2 Orgrimmar, 3 Stormwind,
	-- 4 Undercity, 5 Darnassus, 6 Thunder Bluff), and the Dark Portal (7) for the Legacy tree
	config.heroCityBg = {[1] = 3, [2] = 1, [3] = 5, [4] = 1, [5] = 2, [6] = 4, [7] = 6, [8] = 2};
	config.RefreshHeroHeader = function()
		local hero = config.GetHero(config.activeHero);
		local legacy = (config.treeKind == "legacy");
		if r.tree and r.tree.background then
			r.tree.background:SetTexture(e.artPath.."bg"..((not legacy and hero and config.heroCityBg[hero.id]) or 7));
		end
		if hero then
			config.SetPortrait(portrait, hero);
			portrait:Show();
			portraitBorder:Show();
		else
			portrait:Hide();
			portraitBorder:Hide();
		end
		if r.mouseOver then
			r.mouseOver:SetText("|cFF999999Mouse over a talent for details|r");
		end
		if legacy then
			local earned = config.TreePoints("legacy");
			descText:SetText("|cFFFFFFFFLegacy Talents|r");
			abilityLabel:SetText("Legacy Points:");
			powerIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_09");
			powerIcon:SetTexCoord(0, 1, 0, 1);
			powerIcon:Show();
			powerText:SetText(earned.." earned");
			infoTitle, infoRank, infoIcon = "Legacy Points", earned.." of "..(2 * #LEVELS).." earned", "Interface\\Icons\\INV_Misc_Book_09";
			infoDesc = "Shared by every hero. Earn 1 point for each level where any hero beats both challenges, plus 1 more when every hero has done it.";
		elseif hero then
			descText:SetText("|cFFFFFFFF"..hero.name.."|r");
			abilityLabel:SetText("Hero Ability:");
			powerIcon:SetTexture(hero.icon);
			powerIcon:SetTexCoord(0, 1, 0, 1);
			powerIcon:Show();
			powerText:SetText(hero.powerName);
			infoTitle, infoRank, infoIcon, infoDesc = hero.powerName, "Hero Ability", hero.icon, hero.powerDesc;
		else
			descText:SetText("No hero chosen");
			abilityLabel:SetText("");
			powerIcon:Hide();
			powerText:SetText("Click Choose Hero");
			infoTitle = nil;
		end
	end
	config.RefreshHeroHeader();
	local a = CreateFrame("Frame", "", l, config.backdroptmpl);
	a:SetPoint("Top", 0,  - 114)
	a:SetWidth(l:GetWidth() - 40);
	a:SetHeight(230);
	a:SetBackdrop(d);
	a:SetBackdropColor(0, 0, 0, .5);
	a:SetBackdropBorderColor(1, 1, 1);
	local i = a:CreateTexture(nil, "Artwork");
	i:SetWidth(44);
	i:SetHeight(44);
	i:SetPoint("Topleft", 16,  - 14);
	i:SetTexture(e.artPath..e.talentTex[1]);
	l.icon = i;
	i:Hide();
	n = o:CreateCaption(0, 0, "", a, 22, 1, 1, 1, 1)
	n:ClearAllPoints();
	n:SetPoint("Top", 34,  - 12);
	n:SetWidth(a:GetWidth() - 90);
	n:Hide();
	l.name = n;
	n = o:CreateCaption(0, 0, "", a, 16, 1, 1, 1, nil, true)
	n:ClearAllPoints();
	n:SetPoint("Top", 34,  - 32);
	n:SetWidth(a:GetWidth() - 90);
	n:Hide();
	l.rank = n;
	n = o:CreateCaption(0, 0, "", a, 14, 1, .82, 0, nil, true)
	n:ClearAllPoints();
	n:SetPoint("Top", 0,  - 66);
	n:SetJustifyH("LEFT");
	n:SetWidth(a:GetWidth() - 40);
	n:Hide();
	l.desc = n;
	-- long names wrap onto two lines: keep the rank under the name and the text under both
	config.LayoutInfo = function(frame)
		local nameH = frame.name.GetStringHeight and frame.name:GetStringHeight() or 22;
		local rankH = frame.rank.GetStringHeight and frame.rank:GetStringHeight() or 16;
		frame.rank:ClearAllPoints();
		frame.rank:SetPoint("Top", frame.name, "Bottom", 0,  - 3);
		frame.desc:ClearAllPoints();
		frame.desc:SetPoint("Top", 0,  - math.max(66, 12 + nameH + 3 + rankH + 10));
	end
	n = o:CreateCaption(0, 0, TOOLTIP_TALENT_LEARN, a, 14, 0, 1, 0, nil, true)
	n:ClearAllPoints();
	n:SetPoint("Bottom", 0, 16);
	n:SetJustifyH("LEFT");
	n:SetWidth(a:GetWidth() - 40);
	n:Hide();
	l.learn = n;
	n = o:CreateCaption(0, 0, e.locale["MOUSE_OVER"], a, 14, 0, 1, 0, nil, true)
	n:ClearAllPoints();
	n:SetPoint("Center", 0, 0);
	n:SetWidth(a:GetWidth() - 40);
	l.mouseOver = n;
	if config.RefreshHeroHeader then
		config.RefreshHeroHeader();
	end
	n = o:CreateCaption(0, 0, "", l, 18, 1, .82, 0, nil)
	n:ClearAllPoints();
	n:SetPoint("Top", 0,  - 350);
	n:SetWidth(l:GetWidth() - 20);
	l.pointsLeft = n;
	l = m(0, 0, 34, "buttonResetTalents", true, "talentReset", r, function(e)
		local kind = config.treeKind or "hero";
		local hero = config.GetHero(config.activeHero);
		local who = (kind == "legacy") and "your Legacy talents" or ("all talent points for "..(hero and hero.name or "this hero"));
		config.Confirm("Reset "..who.."?", function()
			local ranks = (kind == "legacy") and config.LegacyTalents() or config.ActiveTalents();
			local slots = (kind == "legacy") and config.LEGACY_SLOTS or config.TALENT_SLOTS;
			for i = 1, slots do
				ranks[i] = 0;
			end
			config.ResyncTalents();
		end);
	end)
	l:ClearAllPoints();
	-- Reset Talents sits in the exact middle; the two side buttons have the same width, so the gaps are equal
	l:SetPoint("Bottom", heroButton:GetParent(), "Bottom", 0, 17);
	local n = CreateFrame("Frame", "", r, config.backdroptmpl);
	n:SetPoint("Topright", r, "Topleft", 8, 0)
	n:SetPoint("Bottomright", r, "Bottomleft", 8, 0)
	n:SetWidth(300);
	r.tree = n;
	n:SetBackdrop(d);
	n:SetBackdropColor(.43, .43, .43, 0);
	n:SetBackdropBorderColor(1, 1, 1);
	local i = n:CreateTexture(nil, "Background");
	i:SetTexture(e.artPath.."bg7");
	i:SetPoint("Topleft", 4,  - 4);
	i:SetWidth(294);
	i:SetHeight(r:GetHeight() - 12);
	i:SetTexCoord(.3, .8, .2, .9);
	i:SetVertexColor(.3, .3, .3);
	n.background = i;
	local col1 = 26 + 40 + 25;
	local col2 = 26 + 40 + 80 + 25;
	local colA = 26 + 25;
	local colB = 26 + (80 * 1) + 25;
	local colC = 26 + (80 * 2) + 25;
	n.node = {};
	n.legacyNode = {};
	local hover = function(button)
		local slot = button:GetID();
		local kind = button.kind or "hero";
		local frame = t.catagoryScreen.frames[4];
		local rank, max, tier, prereq = Ue(kind, slot);
		local left, spent = Ge(kind);
		local canLearn = true;
		local name, descFmt, iconPath, base, step = config.TalentInfo(kind, slot);
		frame.mouseOver:Hide();
		frame.name:SetText(name);
		frame.rank:SetFormattedText(e.locale["_RANK"], rank, max);
		local cost = config.TierCost(tier);
		if(cost > 1)then
			frame.rank:SetText(frame.rank:GetText().."  |cFFFFD100"..cost.." points per rank|r");
		end
		frame.icon:SetTexture(iconPath);
		frame.icon:Show();
		local req = "";
		if(prereq > 0)then
			local prank, pmax = Ue(kind, prereq);
			if(prank < pmax)then
				req = req..string.format(e.locale["_REQUIRES_5"], (config.TalentInfo(kind, prereq)));
				canLearn = nil;
			end
		end
		if(spent < tier * 5)then
			req = req..string.format(e.locale["_REQUIRES_X"], tier * 5);
			canLearn = nil;
		end
		if(rank == max)then
			canLearn = nil;
		end
		-- fractional values (e.g. 0.6 stars per rank) are shown with one decimal
		local function fmtDesc(value)
			if(value == math.floor(value))then
				return string.format(descFmt, value);
			end
			return string.format((string.gsub(descFmt, "%%d", "%%s")), string.format("%.1f", value));
		end
		local nextText = " ";
		if(rank > 0)and(rank < max)then
			nextText = "|cFFFFFFFF"..TOOLTIP_TALENT_NEXT_RANK.."|r\n"..fmtDesc(base + (rank + 1) * step);
		end
		local shown = (rank == 0) and 1 or rank;
		frame.desc:SetText(req.."|r"..fmtDesc(base + shown * step).."\n\n"..nextText);
		config.LayoutInfo(frame);
		frame.name:Show();
		frame.rank:Show();
		frame.desc:Show();
		if(left >= cost)and(canLearn)then
			frame.learn:Show();
		else
			frame.learn:Hide();
		end
	end
	local leave = function()
		local frame = t.catagoryScreen.frames[4];
		frame.mouseOver:Show();
		frame.name:Hide();
		frame.rank:Hide();
		frame.desc:Hide();
		frame.learn:Hide();
		frame.icon:Hide();
	end
	local texNames = e.talentTex;
	-- (Ketho's version loaded Blizzard_TalentUI here on Classic Era; the arrow and branch texture
	-- tables it needed are now defined at the top of this file, so nothing from it is used.)
	local make = function(x, y, slot, kind, hasDown, hasTop)
		local btn = CreateFrame("Button", "PeggleTalent"..kind..slot, n, "ActionButtonTemplate");
		btn:SetPoint("Topleft", x, y);
		btn:SetID(slot);
		btn.kind = kind;
		btn:GetNormalTexture():SetTexture(0, 0, 0, 0);
		btn.rank = _G[btn:GetName().."Count"];
		btn.border = _G[btn:GetName().."Border"];
		btn.icon = _G[btn:GetName().."Icon"];
		btn.icon:SetTexture(e.artPath..(texNames[slot] or "t_coin"));
		btn:SetScript("OnClick", xt);
		btn:SetScript("OnEnter", hover);
		btn:SetScript("OnLeave", leave);
		if(hasDown)then
			btn.arrowDown = btn:CreateTexture(nil, "Background", "TalentBranchTemplate");
			btn.arrowDown:SetTexCoord(unpack(TALENT_BRANCH_TEXTURECOORDS.down[ - 1]));
			btn.arrowDown:SetPoint("Topleft", btn, "Bottomleft", 2,  - 1);
		end
		if(hasTop)then
			btn.arrowTop = btn:CreateTexture(nil, "Overlay", "TalentArrowTemplate");
			btn.arrowTop:SetTexCoord(unpack(TALENT_ARROW_TEXTURECOORDS.top[ - 1]));
			btn.arrowTop:SetPoint("Topleft", 2, 17);
		end
		return btn;
	end
	local rows = {{1, 2}, {3, 4, 5}, {6, 7}, {8, 9}, {10, 11}, {12, 13}, {14, 15}};
	local build = function(kind, store, maxSlot)
		local y = -21 - 45;
		for _, row in ipairs(rows) do
			if(row[1] <= maxSlot)then
				local xs = (#row == 3) and {colA, colB, colC} or {col1, col2};
				for idx, slot in ipairs(row) do
					local hasDown = false;
					for other = 1, maxSlot do
						if(config.TREE_DEFS[other][3] == slot)then
							hasDown = true;
						end
					end
					s(store, make(xs[idx], y, slot, kind, hasDown, config.TREE_DEFS[slot][3] > 0));
				end
				y = y - 54;
			end
		end
	end
	build("hero", n.node, config.TALENT_SLOTS);
	build("legacy", n.legacyNode, config.LEGACY_SLOTS);
	-- sub-tabs: hero tree (per hero) and legacy tree (shared by every hero)
	local heroTab = CreateFrame("Button", nil, n, "UIPanelButtonTemplate");
	config.StyleButton(heroTab);
	heroTab:SetWidth(138);
	heroTab:SetHeight(22);
	heroTab:SetPoint("TopLeft", 8,  - 8);
	local legacyTab = CreateFrame("Button", nil, n, "UIPanelButtonTemplate");
	config.StyleButton(legacyTab);
	legacyTab:SetWidth(138);
	legacyTab:SetHeight(22);
	legacyTab:SetPoint("TopRight",  - 8,  - 8);
	config.SetTreeKind = function(kind, quiet)
		config.treeKind = kind;
		for _, node in ipairs(n.node) do
			node:SetShown(kind == "hero");
		end
		for _, node in ipairs(n.legacyNode) do
			node:SetShown(kind == "legacy");
		end
		heroTab:SetText((kind == "hero") and "|cFFFFD200Hero Talents|r" or "Hero Talents");
		legacyTab:SetText((kind == "legacy") and "|cFFFFD200Legacy Talents|r" or "Legacy Talents");
		if not quiet then
			Ve();
			if config.RefreshHeroHeader then
				config.RefreshHeroHeader();
			end
		end
	end
	heroTab:SetScript("OnClick", function()
		config.SetTreeKind("hero");
	end);
	legacyTab:SetScript("OnClick", function()
		config.SetTreeKind("legacy");
	end);
	config.SetTreeKind(config.treeKind or "hero", true);
	return r;
end
local function w()
	local n = CreateFrame("Frame", "", t.catagoryScreen, config.backdroptmpl);
	n:SetPoint("TopLeft", 5,  - 9)
	n:SetPoint("BottomRight",  - 4, 4);
	local l = e.GetBackdrop();
	l.tileSize = 128;
	l.edgeFile = "Interface\\Glues\\Common\\TextPanel-Border"l.edgeSize = 32;
	n:SetBackdrop(l);
	n:SetBackdropColor(0, 0, 0, .5);
	n:SetBackdropBorderColor(1, 1, 1);
	n:SetFrameLevel(t.catagoryScreen:GetFrameLevel() + 1);
	s(t.catagoryScreen.frames, n);
	local a = n;
	n.showID = 1;
	n:Hide();
	n:SetScript("OnShow", function(e)
		e.showID = 1;
		e:UpdateDisplay(e.showID);
	end);
	n.UpdateDisplay = function(e, t)
		local t
		for t = 1, 8 do
			e["highlight"..t].tex:SetAlpha(0);
			e["content"..t]:Hide();
			if(e.showID == t)then
				e["highlight"..t].tex:SetAlpha(1);
				e["content"..t]:Show();
			end
		end
	end
	local r = CreateFrame("Frame", "", a, config.backdroptmpl);
	r:SetPoint("Topleft", 10,  - 10)
	r:SetPoint("Bottomleft", 10, 10);
	r:SetWidth(180);
	l.bgFile = e.artPath.."windowBackground";
	l.tileSize = 128;
	r:SetBackdrop(l);
	r:SetBackdropColor(0, 0, 0, .5);
	r:SetBackdropBorderColor(1, .8, .45);
	local c = function(e)
		a = e:GetParent():GetParent();
		if(a.showID ~= e:GetID())then
			e.tex:SetAlpha(.5);
		end
	end
	local d = function(e)
		a = e:GetParent():GetParent();
		if(a.showID ~= e:GetID())then
			e.tex:SetAlpha(0);
		end
	end
	local l = function(e)
		local t = e:GetParent():GetParent();
		if(t.showID ~= e:GetID())then
			t.showID = e:GetID();
			t:UpdateDisplay(e:GetID());
		end
	end
	local t, t, t;
	-- menu order: the hero topics (5-7) come right after Basic Gameplay
	local order = {1, 5, 6, 7, 8, 2, 3, 4};
	for row = 1, 8 do
		local t = order[row];
		text = o:CreateCaption(10, 10 + (row - 1) * 20, e.locale["HOW_TO_PLAY"..t], r, 19, 1, 1, 1, 1, nil)
		text:SetWidth(180 - 16);
		text:SetHeight(14);
		text:SetJustifyH("LEFT")
		n = CreateFrame("Frame", "", r);
		n:SetWidth(180 - 16);
		n:SetHeight(20);
		n:SetPoint("Topleft", 10,  - 6 - (row - 1) * 20);
		n:SetScript("OnEnter", c);
		n:SetScript("OnLeave", d);
		n:SetScript("OnMouseUp", l);
		n.tex = r:CreateTexture(nil, "Artwork");
		n.tex:SetAllPoints(n);
		n.tex:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight");
		config.ListHighlight(n.tex);
		n.tex:SetAlpha(0);
		n.tex:SetBlendMode("ADD");
		n:EnableMouse(true);
		n:SetID(t);
		a["highlight"..t] = n;
	end
	local t = CreateFrame("Frame", "", a);
	t:SetPoint("Topleft", r, "Topright");
	t:SetPoint("Bottomright",  - 10, 10);
	t:Hide();
	a.content1 = t;
	text = o:CreateCaption(0, 0, e.locale["HOW_TO_PLAY1"], t, 40, .05, .66, 1, 1, nil)
	text:ClearAllPoints();
	text:SetPoint("Top", t, "Top", 0,  - 22);
	local l = e.artCut["howToPlay1"];
	local n = t:CreateTexture(nil, "Artwork");
	n:SetWidth(i((l[2] - l[1]) * 520 + .5));
	n:SetHeight(i((l[4] - l[3]) * 520 + .5));
	n:SetPoint("Topleft", 10,  - 70);
	n:SetTexture(e.artPath.."howtoplay");
	n:SetTexCoord(unpack(l));
	l = e.artCut["howToPlay2"];
	n = t:CreateTexture(nil, "Artwork");
	n:SetWidth(i((l[2] - l[1]) * 520 + .5));
	n:SetHeight(i((l[4] - l[3]) * 520 + .5));
	n:SetPoint("Topright",  - 10,  - 70);
	n:SetTexture(e.artPath.."howtoplay");
	n:SetTexCoord(unpack(l));
	l = e.artCut["howToPlay3"];
	n = t:CreateTexture(nil, "Artwork");
	n:SetWidth(i((l[2] - l[1]) * 520 + .5));
	n:SetHeight(i((l[4] - l[3]) * 520 + .5));
	n:SetPoint("Bottomleft", 10, 20);
	n:SetTexture(e.artPath.."howtoplay");
	n:SetTexCoord(unpack(l));
	l = e.artCut["howToPlay4"];
	n = t:CreateTexture(nil, "Artwork");
	n:SetWidth(i((l[2] - l[1]) * 520 + .5));
	n:SetHeight(i((l[4] - l[3]) * 520 + .5));
	n:SetPoint("Bottomright",  - 10, 20);
	n:SetTexture(e.artPath.."howtoplay");
	n:SetTexCoord(unpack(l));
	t = CreateFrame("Frame", "", a);
	t:SetPoint("Topleft", r, "Topright");
	t:SetPoint("Bottomright",  - 10, 10);
	t:Hide();
	a.content2 = t;
	text = o:CreateCaption(0, 0, e.locale["HOW_TO_PLAY2"], t, 40, .05, .66, 1, 1, nil)
	text:ClearAllPoints();
	text:SetPoint("Top", t, "Top", 0,  - 22);
	text = o:CreateCaption(0, 0, e.locale["HOW_TO_PLAY2a"], t, 11, 1, 1, 1, nil, nil)
	text:SetWidth(t:GetWidth() - 20);
	text:ClearAllPoints();
	text:SetPoint("Top", t, "Top", 0,  - 64);
	l = e.artCut["howToPlay5"];
	n = t:CreateTexture(nil, "Artwork");
	n:SetWidth(i((l[2] - l[1]) * 500 + .5));
	n:SetHeight(i((l[4] - l[3]) * 500 + .5));
	n:SetPoint("Top", text, "Bottom", 0,  - 10);
	n:SetTexture(e.artPath.."howtoplay");
	n:SetTexCoord(unpack(l));
	text = o:CreateCaption(0, 0, e.locale["HOW_TO_PLAY2b"], t, 11, 1, 1, 1, nil, nil)
	text:SetWidth(t:GetWidth() - 20);
	text:ClearAllPoints();
	text:SetPoint("Top", n, "Bottom", 0,  - 10);
	l = e.artCut["howToPlay6"];
	n = t:CreateTexture(nil, "Artwork");
	n:SetWidth(i((l[2] - l[1]) * 500 + .5));
	n:SetHeight(i((l[4] - l[3]) * 500 + .5));
	n:SetPoint("Top", text, "Bottom", 0,  - 10);
	n:SetTexture(e.artPath.."howtoplay");
	n:SetTexCoord(unpack(l));
	t = CreateFrame("Frame", "", a);
	t:SetPoint("Topleft", r, "Topright");
	t:SetPoint("Bottomright",  - 10, 10);
	t:Hide();
	a.content3 = t;
	text = o:CreateCaption(0, 0, e.locale["HOW_TO_PLAY3"], t, 40, .05, .66, 1, 1, nil)
	text:ClearAllPoints();
	text:SetPoint("Top", t, "Top", 0,  - 22);
	text = o:CreateCaption(0, 0, e.locale["HOW_TO_PLAY3a"], t, 11, 1, 1, 1, nil, nil)
	text:SetWidth(t:GetWidth() - 20);
	text:ClearAllPoints();
	text:SetPoint("Top", t, "Top", 0,  - 64);
	l = e.artCut["howToPlay7"];
	n = t:CreateTexture(nil, "Artwork");
	n:SetWidth(i((l[2] - l[1]) * 500 + .5));
	n:SetHeight(i((l[4] - l[3]) * 500 + .5));
	n:SetPoint("Top", text, "Bottom", 0,  - 10);
	n:SetTexture(e.artPath.."howtoplay");
	n:SetTexCoord(unpack(l));
	text = o:CreateCaption(0, 0, e.locale["HOW_TO_PLAY3b"], t, 11, 1, 1, 1, nil, nil)
	text:SetWidth(t:GetWidth() - 20);
	text:ClearAllPoints();
	text:SetPoint("Top", n, "Bottom", 0,  - 10);
	t = CreateFrame("Frame", "", a);
	t:SetPoint("Topleft", r, "Topright");
	t:SetPoint("Bottomright",  - 10, 10);
	t:Hide();
	a.content4 = t;
	text = o:CreateCaption(0, 0, e.locale["HOW_TO_PLAY4"], t, 40, .05, .66, 1, 1, nil)
	text:ClearAllPoints();
	text:SetPoint("Top", t, "Top", 0,  - 22);
	text = o:CreateCaption(0, 0, e.locale["HOW_TO_PLAY4a"], t, 11, 1, 1, 1, nil, nil)
	text:SetWidth(t:GetWidth() - 20);
	text:ClearAllPoints();
	text:SetPoint("Top", t, "Top", 0,  - 64);
	l = e.artCut["howToPlay8"];
	n = t:CreateTexture(nil, "Artwork");
	n:SetWidth(i((l[2] - l[1]) * 500 + .5));
	n:SetHeight(i((l[4] - l[3]) * 500 + .5));
	n:SetPoint("Top", text, "Bottom", 0,  - 10);
	n:SetTexture(e.artPath.."howtoplay");
	n:SetTexCoord(unpack(l));
	text = o:CreateCaption(0, 0, e.locale["HOW_TO_PLAY4b"], t, 11, 1, 1, 1, nil, nil)
	text:SetWidth(t:GetWidth() - 20);
	text:ClearAllPoints();
	text:SetPoint("Top", n, "Bottom", 0,  - 10);
	-- topics 5-7: heroes, hero talents, legacy talents and how points are earned
	local function page(id, paragraphs, size, decorate)
		local frame = CreateFrame("Frame", "", a);
		frame:SetPoint("Topleft", r, "Topright");
		frame:SetPoint("Bottomright",  - 10, 10);
		frame:Hide();
		a["content"..id] = frame;
		local title = o:CreateCaption(0, 0, e.locale["HOW_TO_PLAY"..id], frame, 40, .05, .66, 1, 1, nil)
		title:ClearAllPoints();
		title:SetPoint("Top", frame, "Top", 0,  - 22);
		local previous;
		local used = decorate and decorate(frame) or 0;
		for _, para in ipairs(paragraphs) do
			local line = o:CreateCaption(0, 0, para, frame, size or 11, 1, 1, 1, nil, nil)
			line:SetWidth(420);
			line:SetJustifyH("LEFT");
			line:ClearAllPoints();
			if previous then
				line:SetPoint("Top", previous, "Bottom", 0,  - 9);
			else
				line:SetPoint("Top", frame, "Top", 0,  - 64 - used);
			end
			previous = line;
		end
	end
	local abilities = {};
	for _, hero in ipairs(config.heroes) do
		abilities[#abilities + 1] = "|cFFFFD100"..hero.name.."|r  |cFF8CD9FF"..hero.powerName.."|r: "..hero.powerDesc;
	end
	-- pictures for the new pages
	local function iconRow(frame, icons, size, gap, y)
		local total = #icons * size + (#icons - 1) * gap;
		for k, spec in ipairs(icons) do
			local tex = frame:CreateTexture(nil, "ARTWORK");
			tex:SetWidth(size);
			tex:SetHeight(size);
			tex:SetPoint("TopLeft", frame, "Top",  - total / 2 + (k - 1) * (size + gap), y);
			spec(tex);
		end
	end
	local function heroIcon(hero)
		return function(tex)
			config.SetPortrait(tex, hero, nil, true);
		end
	end
	local function pathIcon(path)
		return function(tex)
			tex:SetTexture(path);
			tex:SetTexCoord(.07, .93, .07, .93);
		end
	end
	local function bannerIcon(name)
		return function(tex)
			tex:SetTexture(e.artPath..name);
		end
	end
	local function heroesPictures(frame)
		local icons = {};
		for _, hero in ipairs(config.heroes) do
			icons[#icons + 1] = heroIcon(hero);
		end
		iconRow(frame, icons, 38, 6,  - 64);
		return 46;
	end
	local function talentPictures(frame)
		local first = config.HERO_TALENTS[1];
		local icons = {};
		for _, slot in ipairs({1, 3, 4, 9, 10, 12, 14, 15}) do
			if first and first[slot] then
				icons[#icons + 1] = pathIcon(first[slot].icon);
			end
		end
		iconRow(frame, icons, 34, 8,  - 64);
		return 42;
	end
	local function legacyPictures(frame)
		local icons = {pathIcon("Interface\\Icons\\INV_Misc_Book_09")};
		for slot = 1, 7 do
			icons[#icons + 1] = function(tex)
				tex:SetTexture(e.artPath..e.talentTex[slot]);
			end
		end
		iconRow(frame, icons, 34, 8,  - 64);
		return 42;
	end
	page(5, {
		"Pick a leader on the Hero Select screen (it opens on your first play, and from Choose Hero). Your hero is your shooter, and has a unique |cFFFFD100Hero Ability|r that triggers when the ball hits a green peg:",
		table.concat(abilities, "\n"),
		"|cFFFFD100Duels, Battles and Peggle Loot.|r Talents never count in a match: everyone plays with the same base ability, either the match's chosen hero or the plain blast (Standard, no hero).",
		"Every hero keeps their own progress, talent points and talent tree. |cFFFFD100Reset Talents|r refunds the tree you are viewing; |cFFFFD100Reset All|r wipes every hero.",
	}, 10, heroesPictures);
	page(6, {
		"|cFFFFD100How hero points are earned.|r Every level can give your hero 2 talent points: |cFF00FF00+1|r for beating the level (clear every orange peg) and |cFF00FF00+1|r for a 100% clear (clear every peg). With "..#LEVELS.." levels a hero can earn up to "..(2 * #LEVELS).." points. Progress is tracked separately for each hero.",
		"|cFFFFD100The tree.|r Open the Talents tab and choose |cFFFFD100Hero Talents|r. It has 15 talents themed on your hero: the first eight are passive bonuses to scoring and luck, the rest strengthen your Hero Ability, with two capstones at the bottom.",
		"|cFFFFD100The rules.|r Each row unlocks once you have spent 5 more points than the row before it, and a talent needs the talent in front of it to be fully ranked. Ranks cost more the deeper they sit: 1 point per rank in the top two rows, 2 in the middle two and 3 in the bottom two.",
		"|cFFFFD100Choose a build.|r Your points will not buy everything. A hero that has beaten every level can fund one capstone path, but not both, so decide which branches matter to you. Use Reset Talents to refund the points and try a different build.",
	}, nil, talentPictures);
	page(7, {
		"|cFFFFD100Legacy Talents|r are shared by all of your heroes: the original Peggle talents, kept for everyone. Whoever you play, your Legacy talents come with you.",
		"|cFFFFD100How Legacy points are earned.|r Each level gives |cFF00FF001 point|r the first time any hero gets both the Beat Level and 100% Clear banners on it, and |cFF00FF001 more|r once all eight heroes have done so. That is up to "..(2 * #LEVELS).." points, so keep playing different heroes!",
		"On the Quick Play list a |cFFFF4040red banner|r means a level is beaten and a |cFF40A0FFblue banner|r means it has a 100% clear.",
		"Spend Legacy points from Talents, then |cFFFFD100Legacy Talents|r. The same rules and costs apply as for hero talents, and Reset Talents only refunds the tree you are viewing.",
	}, nil, legacyPictures);
	page(8, {
		"|cFFFFD100Stats.|r Click |cFFFFD100Stats|r on the Quick Play screen for your lifetime numbers: games, wins, pegs, scores and records, for your account and for each hero.",
		"|cFFFFD100Quick Play.|r Pick a level on the list (scroll for the rest). The level's name shows above its picture, with your personal best and most recent score below. |cFFFFD100Choose Hero|r changes who you play.",
		"|cFFFFD100Appearance.|r In Options, choose Original, Horde (red) or Alliance (blue); until you do, it matches your character's faction. It changes the buttons, headings, balls, highlights and the faction crest in the corner.",
		"|cFFFFD100Sounds.|r Normal plays everything, Quiet turns the hero sounds down, Off mutes them. Heroes speak when you choose them and when a level starts.",
		"|cFFFFD100Windows.|r Drag the corner to resize the window, and use the two transparency sliders to fade it while you play.",
	}, nil);
	return a;
end
local function _()
	local n = CreateFrame("Frame", "", t.catagoryScreen, config.backdroptmpl);
	n:SetPoint("TopLeft", 5,  - 9)
	n:SetPoint("BottomRight",  - 4, 4);
	local S = e.GetBackdrop();
	S.tileSize = 128;
	S.edgeFile = "Interface\\Glues\\Common\\TextPanel-Border"S.edgeSize = 32;
	n:SetBackdrop(S);
	n:SetBackdropColor(0, 0, 0, .5);
	n:SetBackdropBorderColor(1, 1, 1);
	n:SetFrameLevel(t.catagoryScreen:GetFrameLevel() + 1);
	s(t.catagoryScreen.frames, n);
	local d = n;
	n:Hide();
	-- Options page layout: heading, two sliders, then a grid of three columns x two rows of settings, and the
	-- About / Credits buttons centred at the bottom. Columns start at X1..X3, rows at ROW_A and ROW_B.
	local X1, X2, X3 = 18, 248, 435;
	local ROW_A, ROW_B = 148, 262;
	n = o:CreateCaption(0, 0, "OPTIONS", d, 25, .05, .66, 1, 1, nil);
	n:ClearAllPoints();
	n:SetPoint("Top", 0,  - 22);
	n = o:CreateSlider(230, 100, 300, e.locale["OPT_TRANS_DEFAULT"], "mouseOnTrans", d, .1, 1, .01, true, function(e)
		t:SetAlpha(PeggleForeverData.settings.mouseOnTrans);
	end);
	n:ClearAllPoints();
	n:SetPoint("Top", 0,  - 64);
	n = o:CreateSlider(230, 100, 300, e.locale["OPT_TRANS_MOUSE"], "mouseOffTrans", d, 0, 1, .01, true, nil)
	n:ClearAllPoints();
	n:SetPoint("Top", 0,  - 102);
	local r = function(e)
		PeggleForeverData.settings[e.key] = (e:GetChecked());
	end;
	-- column 1, row A: display
	n = o:CreateCaption(X1, ROW_A, "Display:", d, 14, 1, 1, 0)
	n = x(X1, ROW_A + 20, e.locale["OPT_MINIMAP"], "showMinimapIcon", true, d, function(e)
		PeggleForeverData.settings[e.key] = (e:GetChecked());
		local ldbicon = LibStub("LibDBIcon-1.0")
		PeggleForeverData.minimap = PeggleForeverData.minimap or {};
		if(e:GetChecked())then
			PeggleForeverData.minimap.hide = false
			ldbicon:Show("PeggleForeverIcon")
		else
			PeggleForeverData.minimap.hide = true
			ldbicon:Hide("PeggleForeverIcon")
		end
	end, 1, .82, 0);
	n = x(X1, ROW_A + 40, e.locale["OPT_COLORBLIND"], "colorBlindMode", true, d, r, 1, .82, 0);
	n = x(X1, ROW_A + 60, e.locale["OPT_HIDEOUTDATED"], "hideOutdated", true, d, r, 1, .82, 0);
	n = x(X1, ROW_A + 80, e.locale["OPT_HIGHFPS"], "highFPS", true, d, r, 1, .82, 0);
	-- column 2, row A: auto-open
	n = o:CreateCaption(X1, ROW_B, e.locale["OPT_AUTO_OPEN"], d, 14, 1, 1, 0)
	n = x(X1, ROW_B + 20, e.locale["OPT_AUTO_OPEN1"], "openFlightStart", true, d, r, 1, .82, 0);
	n = x(X1, ROW_B + 40, e.locale["OPT_AUTO_OPEN2"], "openDeath", true, d, r, 1, .82, 0);
	n = x(X1, ROW_B + 60, e.locale["OPT_AUTO_OPEN3"], "openLogIn", true, d, r, 1, .82, 0);
	n = x(X1, ROW_B + 80, e.locale["OPT_AUTO_OPEN4"], "openDuel", true, d, r, 1, .82, 0);
	-- column 3, row A: auto-close
	n = o:CreateCaption(X2, ROW_B, e.locale["OPT_AUTO_CLOSE"], d, 14, 1, 1, 0)
	n = x(X2, ROW_B + 20, e.locale["OPT_AUTO_CLOSE1"], "closeFlightEnd", true, d, r, 1, .82, 0);
	n = x(X2, ROW_B + 40, e.locale["OPT_AUTO_CLOSE2"], "closeReadyCheck", true, d, r, 1, .82, 0);
	n = x(X2, ROW_B + 60, e.locale["OPT_AUTO_CLOSE3"], "closeCombat", true, d, r, 1, .82, 0);
	n = x(X2, ROW_B + 80, e.locale["OPT_AUTO_CLOSE4"], "closeDuelComplete", true, d, r, 1, .82, 0);
	n = x(X2, ROW_B + 100, e.locale["OPT_AUTO_CLOSE5"], "closePeggleLoot", true, d, r, 1, .82, 0);
	local c = function(t)
		local n = PeggleForeverData.settings.soundVolume;
		PeggleForeverData.settings.soundVolume = t:GetID();
		getglobal("PeggleCheckbox_soundVolume1"):SetChecked(false);
		getglobal("PeggleCheckbox_soundVolume2"):SetChecked(false);
		getglobal("PeggleCheckbox_soundVolume3"):SetChecked(false);
		t:SetChecked(true);
		t.updating = true;
		local e = getglobal("PeggleButton_soundButton");
		if not e.updating then
			if(e.off == 1)and(t:GetID() ~= 2)then
				e.hover = true;
				e.prev = t:GetID();
				e:GetScript("OnClick")(e);
				e.hover = nil;
			elseif((e.off == 0)or(e.off == nil))and(t:GetID() == 2)then
				e.hover = true;
				e.prev = n;
				e:GetScript("OnClick")(e);
				e.hover = nil;
			end
		end
		t.updating = nil;
	end
	-- column 1, row B: sounds
	n = o:CreateCaption(X2, ROW_A, e.locale["OPT_SOUNDS"], d, 14, 1, 1, 0)
	n = x(X2, ROW_A + 20, e.locale["OPT_SOUNDS_NORMAL"], "soundVolume1", true, d, c, 1, .82, 0);
	n:SetID(0);
	if(PeggleForeverData.settings.soundVolume == 0)then
		n:SetChecked(true);
	end
	n = x(X2, ROW_A + 40, e.locale["OPT_SOUNDS_QUIET"], "soundVolume2", true, d, c, 1, .82, 0);
	n:SetID(1);
	if(PeggleForeverData.settings.soundVolume == 1)then
		n:SetChecked(true);
	end
	n = x(X2, ROW_A + 60, e.locale["OPT_SOUNDS_OFF"], "soundVolume3", true, d, c, 1, .82, 0);
	n:SetID(2);
	if(PeggleForeverData.settings.soundVolume == 2)then
		n:SetChecked(true);
	end
	if(PeggleForeverData.settings.soundVolume == 2)then
		local e = getglobal("PeggleButton_soundButton");
		e.hover = true;
		e:GetScript("OnClick")(e);
	end
	-- column 3, row A: appearance (colour scheme)
	n = o:CreateCaption(X3, ROW_A, "Appearance:", d, 14, 1, 1, 0)
	local skinDrop = CreateFrame("Frame", "PeggleColorSchemeDropdown", d, "UIDropDownMenuTemplate");
	skinDrop:SetPoint("Topleft", X3 - 16,  - (ROW_A + 16));
	local function pickSkin(self)
		PeggleForeverData.settings.colorScheme = self.value;
		UIDropDownMenu_SetSelectedValue(skinDrop, self.value);
		UIDropDownMenu_SetText(skinDrop, self.value);
		config.ApplySkin();
	end
	UIDropDownMenu_Initialize(skinDrop, function()
		for _, v in ipairs(config.skins) do
			local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo() or {};
			info.text = v[1];
			info.value = v[1];
			info.func = pickSkin;
			info.checked = (PeggleForeverData.settings.colorScheme or config.DefaultScheme()) == v[1];
			UIDropDownMenu_AddButton(info);
		end
	end);
	UIDropDownMenu_SetWidth(skinDrop, 110);
	UIDropDownMenu_SetText(skinDrop, PeggleForeverData.settings.colorScheme or config.DefaultScheme());
	config.ApplySkin();
	-- column 3, row B: duel / battle invites
	n = o:CreateCaption(X3, ROW_B, e.locale["OPT_DUEL_INVITES"], d, 14, 1, 1, 0)
	n = x(X3, ROW_B + 20, e.locale["OPT_DUEL_INVITES1"], "inviteChat", true, d, r, 1, .82, 0);
	n = x(X3, ROW_B + 40, e.locale["OPT_DUEL_INVITES2"], "inviteRaid", true, d, r, 1, .82, 0);
	n = x(X3, ROW_B + 60, e.locale["OPT_DUEL_INVITES3"], "inviteMinimap", true, d, r, 1, .82, 0);
	n = x(X3, ROW_B + 80, e.locale["OPT_DUEL_INVITES4"], "inviteDecline", true, d, r, 1, .82, 0);
	-- bottom row: About and Credits side by side, centred (the art buttons are about 158 x 44)
	n = m(153, 388, 44, "buttonAbout", true, "about", d, function(e)
		t.catagoryScreen.frames[6]:Hide();
		t.about:Show();
	end, nil, true);
	n = m(340, 388, 44, "buttonCredits", true, "credits", d, function(e)
		t.catagoryScreen.frames[6]:Hide();
		t.credits:Show();
	end, nil, true);
	local l = CreateFrame("Frame", "", t.catagoryScreen, config.backdroptmpl);
	l:SetPoint("TopLeft", 5,  - 9)
	l:SetPoint("BottomRight",  - 4, 4);
	l:SetBackdrop(S);
	l:SetBackdropColor(0, 0, 0, .5);
	l:SetBackdropBorderColor(1, 1, 1);
	l:SetFrameLevel(t.catagoryScreen:GetFrameLevel() + 2);
	l:Hide();
	t.about = l;
	local a = o:CreateCaption(0, 0, e.locale["ABOUT"], l, 40, .05, .66, 1, 1, nil)
	a:ClearAllPoints();
	a:SetPoint("Top", 0,  - 20);
	local r, c;
	a = o:CreateCaption(0, 0, e.locale["ABOUT_TEXT1"], l, 14, 1, .85, .1, nil, nil)
	a:ClearAllPoints();
	a:SetPoint("Top", 0,  - 60);
	a:SetWidth(l:GetWidth() - 60);
	a = o:CreateCaption(0, 0, e.locale["ABOUT_TEXT4"]..e.versionString, l, 14, 1, 1, 1, nil, nil)
	a:ClearAllPoints();
	a:SetPoint("Topright",  - 20,  - 20);
	a = o:CreateCaption(0, 0, e.locale["ABOUT_FAN"], l, 11, .75, .75, .75, nil, nil)
	a:ClearAllPoints();
	a:SetPoint("Top", 0,  - 230);
	a:SetWidth(l:GetWidth() - 120);
	n = m(0, 0, 40, "buttonOkay", nil, "aboutOkay", l, function(e)
		t.catagoryScreen.frames[6]:Show();
		e:GetParent():Hide();
	end)

	--Start Credits Screen
	n:ClearAllPoints();
	n:SetPoint("Bottom", 0, 30);
	l = CreateFrame("Frame", "", t.catagoryScreen, config.backdroptmpl);
	l:SetPoint("TopLeft", 5,  - 9)
	l:SetPoint("BottomRight",  - 4, 4);
	l:SetBackdrop(S);
	l:SetBackdropColor(0, 0, 0, .5);
	l:SetBackdropBorderColor(1, 1, 1);
	l:SetFrameLevel(t.catagoryScreen:GetFrameLevel() + 2);
	l:Hide();
	t.credits = l;

	--Create Top Banner
	a = o:CreateCaption(0, 0, e.locale["CREDITS"], l, 40, .05, .66, 1, 1, nil)
	a:ClearAllPoints();
	a:SetPoint("Top", 0,  - 20);
	r = e.artCut["peggleBringer"];
	c = l:CreateTexture(nil, "Artwork")
	c:SetPoint("Top",  - (l:GetWidth() / 4) - 20,  - 10);
	c:SetWidth(i((r[4] - r[3]) * (512 - 128) + .5));
	c:SetHeight(i((r[2] - r[1]) * (512 - 128) + .5));
	c:SetTexture(e.artPath.."board1");
	c:SetTexCoord(r[2], r[3], r[1], r[3], r[2], r[4], r[1], r[4]);
	c = l:CreateTexture(nil, "Artwork")
	c:SetPoint("Top", (l:GetWidth() / 4) + 20,  - 10);
	c:SetWidth(i((r[4] - r[3]) * (512 - 128) + .5));
	c:SetHeight(i((r[2] - r[1]) * (512 - 128) + .5));
	c:SetTexture(e.artPath.."board1");
	c:SetTexCoord(r[2], r[4], r[1], r[4], r[2], r[3], r[1], r[3]);

	--Two columns of credit sections (header, body, estimated wrapped line count)
	local function creditSection(x, y, head, body, width, lines)
		o:CreateCaption(x, y, head, l, 16, 1, 1, 0, nil, nil);
		local b = o:CreateCaption(x + 14, y + 22, body, l, 13, 1, .85, .1, nil, nil);
		b:SetJustifyH("LEFT");
		b:SetWidth(width);
		return y + 22 + lines * 17 + 16;
	end
	local colW = l:GetWidth() / 2 - 50;
	local leftY, rightY = 70, 70;
	leftY = creditSection(24, leftY, e.locale["CR_H1"], e.locale["CR_B1"], colW, 5);
	leftY = creditSection(24, leftY, e.locale["CR_H2"], e.locale["CR_B2"], colW, 2);
	leftY = creditSection(24, leftY, e.locale["CR_H3"], e.locale["CR_B3"], colW, 2);
	local rx = l:GetWidth() / 2 + 10;
	rightY = creditSection(rx, rightY, e.locale["CR_H4"], e.locale["CR_B4"], colW, 3);
	rightY = creditSection(rx, rightY, e.locale["CR_H5"], e.locale["CR_B5"], colW, 3);
	rightY = creditSection(rx, rightY, e.locale["CR_H6"], e.locale["CR_B6"], colW, 3);
	a = o:CreateCaption(0, 0, e.locale["CR_NOTE"], l, 10, .75, .75, .75, nil, nil);
	a:ClearAllPoints();
	a:SetPoint("Bottom", 0, 62);
	a:SetWidth(l:GetWidth() - 120);

	n = m(0, 0, 40, "buttonOkay", nil, "aboutOkay", l, function(e)
		t.catagoryScreen.frames[6]:Show();
		e:GetParent():Hide();
	end)
	n:ClearAllPoints();
	n:SetPoint("Bottom", 0, 14);
	-- Stats page (opened from the Quick Play hero panel or /peggle stats)
	t.stats = config.Stats.BuildPage(t.catagoryScreen, S, t.catagoryScreen:GetFrameLevel() + 2);
	n = m(0, 0, 40, "buttonOkay", nil, "statsOkay", t.stats, function(e)
		e:GetParent():Hide();
		local back = t.catagoryScreen.lastFocus;
		if back and back.contentFrame then
			back.contentFrame:Show();
		else
			t.catagoryScreen.frames[1]:Show();
		end
	end)
	n:ClearAllPoints();
	n:SetPoint("Bottom", 0, 14);
	config.ShowStats = function()
		t:Show();
		for i = 1, #t.catagoryScreen.frames do
			t.catagoryScreen.frames[i]:Hide();
		end
		t.about:Hide();
		t.credits:Hide();
		t.stats:Show();
	end
	return d;
end
local function K()
	local n = CreateFrame("Frame", "", t, config.backdroptmpl);
	n:SetPoint("TopLeft", 8,  - 80)
	n:SetWidth(t:GetWidth() - 16 - 2);
	n:SetHeight(t:GetHeight() - 80 - 6 - 2);
	local l = CreateFrame("Frame", "", n);
	l:SetFrameLevel(l:GetFrameLevel() + 4);
	l:SetWidth(20);
	l:SetHeight(20);
	l:SetPoint("Bottom");
	e.outdatedText = o:CreateCaption(0, 0, e.locale["OUT_OF_DATE"], l, 11, 1, 1, 1, nil, nil)
	e.outdatedText:ClearAllPoints();
	e.outdatedText:SetPoint("Bottom", 0, 0);
	e.outdatedText:Hide();
	e.outdatedText:SetAlpha(1);

	local l = e.GetBackdrop();
	l.bgFile = e.artPath.."windowBackground";
	l.tileSize = 128;
	l.tile = false;
	l.edgeFile = "Interface\\Glues\\Common\\TextPanel-Border"l.edgeSize = 32;
	n:SetBackdrop(l);
	n:SetBackdropColor(.43, .43, .43, 1);
	n:SetBackdropBorderColor(1, .8, .45);
	n:SetFrameLevel(t:GetFrameLevel() + 1);

	t.catagoryScreen = n;
	n.frames = {};
	n:Hide();
	-- Escape closes the window while the menu is showing, never during a level (the menu screen is hidden
	-- while a level is played). UISpecialFrames is the standard list of windows Escape closes.
	config.SetEscapeCloses = function(on)
		for i = #UISpecialFrames, 1, - 1 do
			if UISpecialFrames[i] == "PeggleWindow" then
				table.remove(UISpecialFrames, i);
			end
		end
		if on then
			table.insert(UISpecialFrames, "PeggleWindow");
		end
	end
	n:HookScript("OnShow", function()
		config.SetEscapeCloses(true);
	end);
	n:HookScript("OnHide", function()
		C_Timer.After(0, function() -- not while Escape is still walking the list
			config.SetEscapeCloses(t.catagoryScreen:IsVisible());
		end);
	end);
	n = CreateFrame("Frame", "", t.catagoryScreen);
	n:SetWidth(653)
	n:SetHeight(64);
	n:SetPoint("Topleft",  - 4, 54);
	n:SetFrameLevel(t:GetFrameLevel() + 2);
	t.catagoryScreen.tabFrame = n;
	local a = 0;
	local l;
	l, a = De(a, 0, n, me(), "tabQuickPlay", nil);
	l.focus = true;
	l.contentFrame:Show();
	t.catagoryScreen.lastFocus = l;
	nt(l);
	l, a = De(a, 0, n, oe(), "tabDuel", nil, 3);
	t.duelTab = l;
	l, a = De(a, 0, n, ee(), "tabChallenge", nil, 3);
	t.challengeTabSparks = l.sparks;
	l, a = De(a, 0, n, G(), "tabTalents", nil, 3);
	t.sparks = l.sparks;
	l, a = De(a, 0, n, w(), "tabHowToPlay", true);
	t.catagoryScreen.tabFrame.currentX = a;
	n = CreateFrame("Frame", "", t.catagoryScreen);
	n:SetPoint("TopLeft", 5,  - 9)
	n:SetPoint("BottomRight",  - 4, 4);
	n:SetFrameLevel(n:GetFrameLevel() + 10);
	n:EnableMouse(true);
	n:Hide();
	n:SetScript("OnShow", function(n)
		local n;
		for n = 1, 6 do
			t.catagoryScreen.frames[n]:SetAlpha(0);
		end
		e.outdatedText:SetAlpha(0);
	end);
	n:SetScript("OnHide", function(n)
		local n;
		for n = 1, 6 do
			t.catagoryScreen.frames[n]:SetAlpha(1);
		end
		e.outdatedText:SetAlpha(1);
	end);
	n:SetScript("OnUpdate", function(n, o)
		if not n.elapsed then
			return;
		end
		if not e.name then
			e.name = UnitName("player");
		end
		n.elapsed = n.elapsed + xe(o, .2);
		if(n.elapsed >= 3)then
			n:Hide();
			n.elapsed = nil;
			n.showScreen = nil;
			n.background = nil;
			n.foreground = nil;
			n.legal = nil;
			t.splash = nil;
			return;
		end
		if(n.elapsed > 2)then
			if not n.showScreen then
				n.showScreen = true
				local e;
				for e = 1, 6 do
					t.catagoryScreen.frames[e]:SetAlpha(1);
				end
			end
			n:SetAlpha(F(1 - (n.elapsed - 2), 0));
		end
	end);
	t.splash = n;
	local t = n:CreateTexture(nil, "Artwork");
	t:SetWidth(640)
	t:SetHeight(640);
	t:SetPoint("Center", 1, 0);
	t:SetTexture(e.artPath.."splashBackground");
	n.background = t;
	local o = e.artCut["splashBringer"];
	t = n:CreateTexture(nil, "Overlay");
	-- banner2_2.tga is banner2 extended to 512x550 with FOREVER under the title
	t:SetWidth(i((o[2] - o[1]) * 520 + .5));
	t:SetHeight(i(182 / 512 * 520 + .5));
	t:SetPoint("Center");
	t:SetTexture(e.artPath.."banner2_2");
	t:SetTexCoord(o[1], o[2], 368 / 550, 1);
	n.foreground = t;
end
local function w(n, l, ...)
	w = nil;
	-- Saves used to be called PeggleData / PeggleProfile, the same names as the original Peggle add-on.
	-- Copy ours across once (only data with hero talents is ours); the TOC lists the old names only in
	-- development copies, devtools/package.py leaves them out of the release.
	if PeggleForeverData.fresh and type(PeggleData) == "table" and PeggleData.newData and PeggleData.newData.heroTalents then
		local icon = PeggleForeverData.minimap; -- the minimap icon already holds this table (Icon.lua)
		PeggleForeverData = PeggleData;
		PeggleForeverData.minimap = icon or PeggleForeverData.minimap;
		print("|cFFFFDD00Peggle Forever:|r your saved progress was moved to its new save name.");
	end
	if PeggleForeverProfile.fresh and type(PeggleProfile) == "table" and PeggleProfile.version then
		PeggleForeverProfile = PeggleProfile;
	end
	PeggleForeverData.fresh = nil;
	PeggleForeverProfile.fresh = nil;
	if(PeggleForeverData.version and(PeggleForeverData.version < 2.0))then
		PeggleForeverData.version = nil;
	end
	if not PeggleForeverData.version then
		PeggleForeverData = {};
		PeggleForeverData.newData = {};
		PeggleForeverData.newData = {["levelScores"] = {}, ["heroTalents"] = {}}
		PeggleForeverData.settings = {
			mouseOnTrans = 1,
			mouseOffTrans = .6,
			showMinimapIcon = true,
			openFlightStart = false,
			openDeath = false,
			openLogIn = false,
			openDuel = true,
			closeFlightEnd = false,
			closeReadyCheck = true,
			closeCombat = true,
			closeDuelComplete = false,
			closePeggleLoot = false,
			highFPS = false,
			inviteChat = true,
			inviteRaid = false,
			inviteMinimap = true,
			inviteDecline = false,
			hideOutdated = false;
			soundVolume = 0,
			defaultPublish = "GUILD",
		};
		PeggleForeverData.version = e.versionID;
		PeggleForeverData.recent = {};
		PeggleForeverProfile = {};
		PeggleForeverProfile.challenges = {};
		PeggleForeverProfile.lastDuels = {};
		PeggleForeverProfile.duelTracking = {};
		PeggleForeverProfile.levelTracking = {};
		PeggleForeverProfile.version = e.versionID;
	end
	if not PeggleForeverProfile.challenges then
		PeggleForeverProfile.challenges = {};
	end
	if not H then
		H = UnitName("player");
		e.name = H;
	end
	if not PeggleForeverData.loggedIn then
		PeggleForeverData.loggedIn = H;
	else
		H = PeggleForeverData.loggedIn;
	end
	if(PeggleForeverData.version < 1.02)then
		PeggleForeverData.version = 1.02;
		PeggleForeverData.settings.defaultPublish = e.channels[PeggleForeverData.settings.defaultPublish];
		PeggleForeverData.settings.hideOutdated = false;
	end
	if(PeggleForeverProfile.version < 1.02)then
		PeggleForeverProfile.challenges = {};
		PeggleForeverProfile.version = 1.02;
	end
	V = PeggleForeverData
	Y = PeggleForeverProfile.challenges;
	H = PeggleForeverData.loggedIn;
	De(t.catagoryScreen.tabFrame.currentX, 0, t.catagoryScreen.tabFrame, _(), "tabOptions", nil);
	config.MigrateTalents();
	if not config.isForever then -- only when forced on with "Load out of date AddOns"
		print("|cFFFFDD00Peggle Forever:|r this add-on is made for WoW Forever. This client (interface "..config.interfaceVersion..") is not supported, so some parts may not work.");
	end
	if PeggleForeverProfile.hero and config.GetHero(PeggleForeverProfile.hero) then
		config.activeHero = PeggleForeverProfile.hero;
		config.UseHeroLevels(config.activeHero);
	elseif config.RaceHero() then
		-- not chosen yet: start as this character's race (not saved; choosing a hero saves it)
		config.activeHero = config.RaceHero();
		config.UseHeroLevels(config.activeHero);
	end
	config.ApplyHero(true);
	if not t.heroPrompt then
		t.heroPrompt = true;
		t:HookScript("OnShow", function()
			if not config.activeHero then
				t.charScreen:Show();
			end
		end);
	end
	-- window already open at login (Open on login setting) and no hero yet: ask for one
	C_Timer.After(.5, function()
		if t:IsVisible() and not config.activeHero then
			t.charScreen:Show();
		end
	end);
	et();
	local a = V.recent;

	--fill config with initial score data
	for e = 1, #LEVELS do
		if not PeggleForeverData.newData.levelScores[e] then
			PeggleForeverData.newData.levelScores[e] = {['score'] =  0, ['progress'] =  0}
		end
	end

	local l;
	for e = 1, #LEVELS do
		l = PeggleForeverData.newData.levelScores[e]['progress'];
		if(l == 0)then
			levelScoreData[e] = 0;
		else
			levelScoreData[e] = PeggleForeverData.newData.levelScores[e]['score'];

			if not a[e]then
				a[e] = levelScoreData[e];
			end
		end
		levelScoreData[e + #LEVELS] = l
	end
	local l = t.catagoryScreen.frames[1];
	l:UpdateDisplay(1);
	t.levelList:UpdateList();
	if(PeggleForeverData.settings.showMinimapIcon ~= true)then
		t.minimap:Hide();
	end
	-- if(PeggleForeverData.settings.minimapDetached == nil)then
	-- 	t.minimap:SetPoint("Center", Minimap, "Center",  - (76 * k(T(PeggleForeverData.settings.minimapAngle or 270))), (76 * I(T(PeggleForeverData.settings.minimapAngle or 270))))
	-- else
	-- 	t.minimap:SetPoint("Center", UIParent, "bottomleft", PeggleForeverData.settings.minimapX, PeggleForeverData.settings.minimapY);
	-- end
	R(false);
	if(PeggleForeverData.settings.openLogIn ~= true)then
		n:Hide();
	end
	if UnitOnTaxi("player")then
		if(PeggleForeverData.settings.openFlightStart == true)then
			n:Show();
		end
	end
	n:SetScript("OnEvent", function(n, e, o)
		if(e == "PLAYER_DEAD")then
			if(PeggleForeverData.settings.openDeath == true)then -- (the original read openOnDeath, so the option never worked)
				n:Show();
			end
		elseif(e == "READY_CHECK")then
			if(PeggleForeverData.settings.closeReadyCheck == true)then
				n:Hide();
			end
		elseif(e == "PLAYER_REGEN_DISABLED")then
			if(PeggleForeverData.settings.closeCombat == true)then
				n:Hide();
			end
		elseif(e == "PLAYER_CONTROL_GAINED")then
			if(t.flying == true)then
				if(PeggleForeverData.settings.closeFlightEnd == true)then
				t:Hide();
				end
			end
			t.flying = nil;
		end
	end);
	n:UnregisterAllEvents();
	n:RegisterEvent("PLAYER_DEAD");
	n:RegisterEvent("PLAYER_REGEN_DISABLED");
	n:RegisterEvent("READY_CHECK");
	n:RegisterEvent("PLAYER_CONTROL_GAINED");
	hooksecurefunc("TakeTaxiNode", function()
		t.flying = true;
		if(PeggleForeverData.settings.openFlightStart == true)then
			t:Show();
		end
	end);
	t.challengeTimer:Show();
	if(Y[1])then
	ne();
	end
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", M)
	if not PeggleForeverData.legalDisplayed then
		local l = CreateFrame("Frame", "", t, config.backdroptmpl);
		l:SetWidth(160 * 2);
		l:SetHeight(216 + 32);
		l:SetToplevel(true);
		l:SetFrameStrata("High")
		l:SetPoint("Center");
		l:EnableMouse(true);
		t.legal = l;
		local n = e.GetBackdrop();
		n.edgeFile = e.artPath.."windowBorder";
		n.bgFile = e.artPath.."windowBackground";
		n.edgeSize = 32;
		n.tileSize = 64;
		n.tile = false;
		n.insets.right = 3;
		l:SetBackdrop(n);
		l:SetBackdropColor(.43, .43, .43, 1);
		l:SetBackdropBorderColor(1, .8, .45);
		l:SetBackdropBorderColor(1, 1, 1);
		local n = o:CreateCaption(0, 0, "Peggle", l, 25, 1, .4, 0, true, nil, "")
		n:ClearAllPoints();
		n:SetShadowColor(0, 0, 0);
		n:SetShadowOffset(1,  - 1);
		n:SetPoint("Top", 0,  - 38);
		n:SetWidth(160 * 1.8);
		n:Show();
		n = l:CreateFontString(nil, "Overlay");
		n:SetFont(STANDARD_TEXT_FONT, 12);
		n:SetShadowColor(0, 0, 0);
		n:SetShadowOffset(1,  - 1);
		n:SetTextColor(1, 1, 1);
		n:SetPoint("Top", 0,  - 78);
		n:SetWidth(160 * 1.8);
		n:SetText(e.locale["LEGAL2"])
		n:Show();
		l.text = n;
		local e = m(0, 0, 40, "buttonOkay", nil, "legalOkay", l, function(e)
			t.legal:Hide();
			t.legal.text:SetText("");
			t.legal.text = nil;
			t.legal = nil;
			t.splash.elapsed = 0;
			PeggleForeverData.legalDisplayed = true;
		end)
		e:ClearAllPoints();
		e:SetPoint("Top", n, "Bottom", 0,  - 16);
		l:SetHeight(n:GetHeight() + e:GetHeight() + 120);
	end
	local n = CreateFrame("Frame", "", t, config.backdroptmpl);
	n:SetWidth(290);
	n:SetHeight(90 + 32);
	n:SetToplevel(true);
	n:SetFrameStrata("High")
	n:SetPoint("Center");
	n:EnableMouse(true);
	e.outdatedPop = n;
	n:Hide();
	local o = e.GetBackdrop();
	o.edgeFile = e.artPath.."windowBorder";
	o.bgFile = e.artPath.."windowBackground";
	o.edgeSize = 32;
	o.tileSize = 64;
	o.tile = false;
	o.insets.right = 3;
	n:SetBackdrop(o);
	n:SetBackdropColor(.43, .43, .43, 1);
	n:SetBackdropBorderColor(1, .8, .45);
	n:SetBackdropBorderColor(1, 1, 1);
	text = n:CreateFontString(nil, "Overlay");
	text:SetFont(STANDARD_TEXT_FONT, 12);
	text:SetShadowColor(0, 0, 0);
	text:SetShadowOffset(1,  - 1);
	text:SetTextColor(1, 1, 1);
	text:SetPoint("Top", 0,  - 32);
	text:SetWidth(270);
	text:SetText(e.locale["OUT_OF_DATE"])
	text:Show();
	local o = m(0, 0, 40, "buttonOkay", nil, "outOfDateOkay", n, function(t)
		e.outdatedPop:Hide();
	end)
	o:ClearAllPoints();
	o:SetPoint("Top", text, "Bottom", 0,  - 12);
	n:SetHeight(text:GetHeight() + o:GetHeight() + 64);
	if(PeggleForeverData.outdated)and(PeggleForeverData.outdated <= e.ping)then
		PeggleForeverData.outdated = nil;
	elseif(PeggleForeverData.outdated)then
		e.outdatedText:Show();
	end
	local o = p(e.addonName);
	local n;
	local a;
	if not disableSplashScreen then
		t.splash:Show();
	end
	if not t.legal then
		t.splash.elapsed = 0;
		t.splash.background:SetAlpha(1);
		t.splash.foreground:SetAlpha(1);
	end
	if(not AchievementFrame)then
		--AchievementFrame_LoadUI();
	end
	-- [[ Achievement Shield ]] --
	if not AchievementShield_OnLoad then
		function AchievementShield_Desaturate (self)
			self.icon:SetTexCoord(.5, 1, 0, 0.5);
		end

		function AchievementShield_Saturate (self)
			self.icon:SetTexCoord(0, .5, 0, 0.5);
		end

		function AchievementShield_OnLoad (self)
			self.Desaturate = AchievementShield_Desaturate;
			self.Saturate = AchievementShield_Saturate;
		end
	end
	local n = CreateFrame("Button", "exhibitA", UIParent, "AchievementAlertFrameTemplate");
	n:Hide();
	n:ClearAllPoints();
	n:SetPoint("BOTTOM", 0, 128);
	n:SetWidth(526);
	n:SetHeight(160);
	n.glow:SetWidth(680);
	n.glow:SetHeight(270);
	n:EnableMouse(false)
	n.shine:SetTexCoord(0, .001, 0, .001);
	n.holdDuration = 5;
	t.achieve = n;
	n:RegisterEvent("DUEL_FINISHED");
	n:SetScript("OnEvent", function(e)
		if(t.duelStatus == 3)and not PeggleForeverData.exhibitA then
			PeggleForeverData.exhibitA = true;
			if(not AchievementFrame)then
				--AchievementFrame_LoadUI();
			end
			e.elapsed = 0;
			e.state = nil;
			e:SetAlpha(0);
			e.id = 0;
			--e:SetScript("OnUpdate", AchievementAlertFrame_OnUpdate);
			e:UnregisterAllEvents();
			e:Show();
		end
	end);
	local o = e.artCut["exhibitA"];
	local l = n:CreateTexture(nil, "Artwork");
	l:SetWidth(i((o[4] - o[3]) * 512 + .5));
	l:SetHeight(i((o[2] - o[1]) * 512 + .5));
	l:SetTexture(e.artPath.."howtoplay");
	l:SetPoint("Top", 0,  - 50);
	l:SetTexCoord(o[2], o[3], o[1], o[3], o[2], o[4], o[1], o[4]);
	n.tex = l;
	o = e.artCut["exhibitA2"];
	--getglobal(n:GetName().."IconTexture"):SetTexture(e.artPath.."howtoplay");
	--getglobal(n:GetName().."IconTexture"):SetTexCoord(unpack(o));
	--getglobal(n:GetName().."Name"):SetText("");
	--local l = getglobal(n:GetName().."Shield");
	if(l.points)then
		--AchievementShield_SetPoints(10, l.points, GameFontNormal, GameFontNormalSmall);
	end
	if(l.icon)then
		l.icon:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Shields");
	end
	--getglobal(n:GetName().."Unlocked"):ClearAllPoints();
	--getglobal(n:GetName().."Unlocked"):SetPoint("Top", 0,  - 39)o = e.artCut["exhibitA2"];
	--getglobal(n:GetName().."IconTexture"):SetTexture(e.artPath.."howtoplay");
	--getglobal(n:GetName().."IconTexture"):SetTexCoord(unpack(o));
	e.artCut = nil;
	if(a)then
		message(e.locale["PEGGLE_ISSUE2"])
		t:Hide();
		t.minimap:Hide();
		if(t.legal)then
			t.legal:Hide();
		end
		SlashCmdList["PEGGLE"] = function()end;
		SlashCmdList["PEGGLELOOT"] = function()end;
		e.addonName = "PEGGLE_BROKE";
		t.network.prefix = e.addonName;
	end
	local t, t;
	for t, n in pairs(e.locale)do
		if not(string.sub(t, 1, 1) == "_")then
			e.locale[t] = nil;
		end
	end
	collectgarbage();
end
local function W()
	local d = e.artCut;
	t = CreateFrame("Frame", "PeggleWindow", UIParent, config.backdroptmpl);
	t:SetWidth(e.windowWidth);
	t:SetHeight(e.windowHeight);
	t:SetPoint("Center");
	t:EnableMouse(true);
	t:SetToplevel(true);
	t:Show();
	t:SetHitRectInsets(0, 0,  - 14, 0);
	t:RegisterEvent("VARIABLES_LOADED");
	t:SetScript("OnEvent", w);
	t.mouseBounds = CreateFrame("Frame", "", t);
	t.mouseBounds:SetPoint("Topleft",  - 20, 20);
	t.mouseBounds:SetPoint("Bottomright", 20,  - 20);
	t.mouseBounds:Show();
	local u = h(9888, 3);
	local s = h(634, 2);
	local h = ":rYb<wrcwcre80;j";
	local g = t:GetFrameLevel();
	local n = e.GetBackdrop();
	n.edgeFile = e.artPath.."windowBorder";
	n.bgFile = e.artPath.."windowBackground";
	n.edgeSize = 32;
	n.tileSize = 64;
	n.tile = false;
	n.insets.right = 3;
	t:SetBackdrop(n);
	t:SetBackdropColor(.7, .7, .7, 1);
	t:SetMovable(true);
	t:SetClampedToScreen(true); -- cannot be dragged off the screen
	t:RegisterForDrag("LeftButton");
	t:SetScript("OnDragStart", function(e)
		e:StartMoving();
	end);
	t:SetScript("OnDragStop", function(e)
		e:StopMovingOrSizing();
	end);
	t:SetScript("OnHide", function(e)end);
	t:SetScript("OnShow", function(e)end);
	local n = t:CreateTexture(nil, "Artwork");
	n:ClearAllPoints();
	n:SetPoint("Topleft", 2, 0);
	n:SetPoint("Topright",  - 8, 0);
	n:SetHeight(26);
	n:SetTexture(0, 0, 0);
	t.coverUp = n;
	local l = CreateFrame("Frame", "", t);
	l:SetHeight(128);
	l:SetPoint("Topleft", t, "Topleft", 32, 32);
	l:SetPoint("Topright", t, "Topright", 0, 32);
	n = l:CreateTexture(nil, "OVERLAY");
	n:ClearAllPoints();
	n:SetPoint("Topright", l, "Topleft", 16, 0);
	n:SetWidth(64);
	n:SetHeight(64);
	config.Skin(n, "windowCoverLeft");
	n = l:CreateTexture(nil, "OVERLAY");
	n:SetPoint("Topleft", l, "Topright",  - 44, 0);
	n:SetWidth(64);
	n:SetHeight(64);
	config.Skin(n, "windowCoverRight");
	n = l:CreateTexture(nil, "ARTWORK");
	n:SetPoint("Topleft", 16, 0);
	n:SetWidth(t:GetWidth() - 92);
	n:SetHeight(64);
	local a = n:GetWidth();
	a = f(a, 128) / 128 + i(a / 128);
	n:SetTexCoord(0, a, 0, 1);
	config.Skin(n, "windowCoverCenter");
	t.topCover = n;
	local r = m(0, 0, 20, "buttonClose", nil, "closeButton", l, function(e)
		t:Hide();
	end)
	r:ClearAllPoints();
	r:SetPoint("Topright", t, "Topright", 2, 9)
	r.highlight:SetWidth(12);
	r.highlight:SetHeight(12);
	local a = m(0, 0, 20, "buttonSound", nil, "soundButton", l, function(e)
		if(e.hover)then
			if(e.off == 1)then
				e.off = 0;
				PeggleForeverData.settings.soundVolume = e.prev or 0;
			else
				e.off = 1;
				e.prev = e.prev or PeggleForeverData.settings.soundVolume;
				if(e.prev == 2)then
					e.prev = 0;
				end
				PeggleForeverData.settings.soundVolume = 2;
			end
			local t = getglobal("PeggleCheckbox_soundVolume"..PeggleForeverData.settings.soundVolume + 1);
			if not t.updating then
				e.updating = true;
				t:GetScript("OnClick")(t);
				e.updating = nil;
			end
			local t = e.iconCoord;
			e.background:SetTexCoord(t[1] + (e.off * 20 / 256), t[2] + (e.off * 20 / 256), t[3], t[4]);
		end
	end)
	a:ClearAllPoints();
	a:SetPoint("Topright", r, "Topleft", 0, 0)
	a.highlight:SetWidth(12);
	a.highlight:SetHeight(12);
	a.iconCoord = e.artCut["buttonSound"];
	t.soundButton = a;
	local r = m(0, 0, 20, "buttonMenu", nil, "menuButton", l, function(e, e)
		if(t.catagoryScreen:IsShown()and de == false)then
			R(true);
		else
			if(de == false)then
				if(t.gameMenu:IsShown())then
					t.gameMenu:Hide();
				else
					t.gameMenu:Show();
				end
			else
				R(false);
			end
		end
	end)
	r:ClearAllPoints();
	r:SetPoint("Topright", a, "Topleft", 0, 0)
	r.highlight:SetWidth(r:GetWidth() - 6);
	r.highlight:SetHeight(r:GetHeight() - 8);
	t.menuButton = r;
	local a = CreateFrame("Frame", "", t);
	a:SetWidth(1);
	a:SetHeight(1);
	a:SetAllPoints(t);
	a:SetFrameLevel(a:GetFrameLevel() + 3);
	t.artBorder = a;
	n = a:CreateTexture(nil, "ARTWORK");
	n:SetPoint("Topleft", 9,  - 27);
	n:SetWidth(60);
	n:SetHeight(512);
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(d["leftBorder"]));
	t.leftBorder = n;
	n = a:CreateTexture(nil, "ARTWORK");
	n:SetPoint("Topleft", t.leftBorder, "Topright", 0, 0);
	n:SetWidth(446);
	n:SetHeight(140);
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(d["topBorder"]));
	t.topBorder = n;
	n = a:CreateTexture(nil, "ARTWORK");
	n:SetPoint("Bottomleft", t.leftBorder, "Bottomright", 0, 0);
	n:SetWidth(446);
	n:SetHeight(24);
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(d["bottomBorder"]));
	t.bottomBorder = n;
	n = a:CreateTexture(nil, "ARTWORK");
	n:SetPoint("Topleft", t.topBorder, "Topright", 0, 0);
	n:SetWidth(152);
	n:SetHeight(140);
	n:SetTexture(e.artPath.."board2");
	n:SetTexCoord(unpack(d["rightBorder1"]));
	t.rightBorder1 = n;
	n = a:CreateTexture(nil, "ARTWORK");
	n:SetPoint("Topleft", t.topBorder, "Topright", 85,  - 140);
	n:SetWidth(152 - 85);
	n:SetHeight(512 - 140 - 24);
	n:SetTexture(e.artPath.."board2");
	n:SetTexCoord(unpack(d["rightBorder2"]));
	t.rightBorder2 = n;
	n = a:CreateTexture(nil, "ARTWORK");
	n:SetPoint("Topleft", t.topBorder, "Topright", 0,  - 488);
	n:SetWidth(152);
	n:SetHeight(24);
	n:SetTexture(e.artPath.."board2");
	n:SetTexCoord(unpack(d["rightBorder3"]));
	t.rightBorder3 = n;
	local r = o:CreateCaption(0, 0, "0", a, 15, .55, .85, 1, true)
	r:ClearAllPoints();
	r:SetPoint("TopRight", a, "TopLeft", 234,  - 47);
	Ie = r;
	r = o:CreateCaption(0, 0, e.locale["SCORE"], a, 15, .55, .85, 1, true)
	r:ClearAllPoints();
	r:SetPoint("TopLeft", a, "TopLeft", 112,  - 47);
	r = o:CreateCaption(0, 0, "300,000", a, 15, .55, .85, 1, true)
	r:ClearAllPoints();
	r:SetPoint("TopRight", a, "TopLeft", 546,  - 47);
	t.bestScore = r;
	r = o:CreateCaption(0, 0, e.locale["SCORE_BEST"], a, 15, .55, .85, 1, true)
	r:ClearAllPoints();
	r.caption1 = r:GetText();
	r.caption2 = e.locale["SCORE_TIME_LEFT"];
	r.caption3 = e.locale["SCORE_TIME_LEFT"].." sec";
	r:SetPoint("TopLeft", a, "TopLeft", 546 - 124,  - 47);
	t.bestScoreCaption = r;
	le();
	re();
	local r = t.feverTracker;
	l = CreateFrame("Frame", "", t);
	l:SetFrameLevel(t:GetFrameLevel() + 4);
	l:SetPoint("Topleft",  - 12, 4);
	l:SetWidth(64);
	l:SetHeight(64);
	seg = d["logoArt"];
	local o = CreateFrame("Frame", "", t);
	o:SetPoint("Top", 12, 12);
	o:SetWidth(i((seg[4] - seg[3]) * 512 + .5));
	o:SetHeight(i((seg[2] - seg[1]) * 512 + .5));
	o:SetFrameLevel(t:GetFrameLevel() + 4);
	t.logoFrame = o;
	local a = o:CreateTexture(nil, "Artwork")
	a:SetPoint("Top",  - 14, 52);
	a:SetWidth(i((seg[4] - seg[3]) * 512 * .85 + .5));
	a:SetHeight(i((seg[2] - seg[1]) * 512 * .85 + .5));
	a:SetTexture(e.artPath.."board1");
	a:SetTexCoord(seg[2], seg[3], seg[1], seg[3], seg[2], seg[4], seg[1], seg[4]);
	t.logo = a;
	local forever = o:CreateTexture(nil, "Artwork");
	forever:SetTexture(e.artPath.."titleForever");
	forever:SetWidth(152);
	forever:SetHeight(38);
	forever:SetPoint("Top", a, "Bottom", 0, 6);
	t.foreverLogo = forever;
	local o = CreateFrame("Frame", "", t);
	o:SetPoint("Bottomright", 0, 0);
	o:SetWidth(32);
	o:SetHeight(32);
	o:Show();
	o:SetFrameLevel(g + 7);
	o:EnableMouse(true);
	o:SetScript("OnMouseDown", function(o, n)
		if(n == "RightButton")then
			t:SetWidth(e.windowWidth);
			t:SetHeight(e.windowHeight);
		else
			t.resizing = true;
			t:StartSizing("Right");
		end
	end);
	o:SetScript("OnMouseUp", function(e)
		t.resizing = nil;
		t:StopMovingOrSizing();
	end);
	n = o:CreateTexture(nil, "Artwork")
	n:SetPoint("Topleft", 0, 0);
	n:SetWidth(32);
	n:SetHeight(32);
	config.Skin(n, "resize");
	t.logo = a;
	if t.SetResizeBounds then
		t:SetResizeBounds(e.windowWidth / 2, e.windowHeight / 2, e.windowWidth * 1.5, e.windowHeight * 1.5)
	else
		t:SetMaxResize(e.windowWidth * 1.5, e.windowHeight * 1.5);
		t:SetMinResize(e.windowWidth / 2, e.windowHeight / 2);
	end
	t:SetResizable(true);
	t:SetScript("OnSizeChanged", function(o)
		local n = o:GetWidth();
		local n = n / e.windowWidth;
		t.gameBoardContainer:SetScale(n);
		t.artBorder:SetScale(n);
		t.catagoryScreen:SetScale(n);
		t.logoFrame:SetScale(n);
		t.charPortrait:SetScale(n);
		local e = e.windowHeight * n;
		o:SetHeight(e);
		t.coverUp:SetHeight(26.5 * n);
		local n = t.topCover;
		n:SetWidth(t:GetWidth() - 92);
		local e = n:GetWidth();
		e = f(e, 128) / 128 + i(e / 128);
		n:SetTexCoord(0, e, 0, 1);
	end);
	l = CreateFrame("Frame", "PeggleShowHideButton", UIParent);
	l:SetWidth(1);
	l:SetHeight(1);
	l:SetPoint("Bottomright");
	l:SetScript("OnMouseDown", function()
		if(t:IsShown())then
			t:Hide();
		else
			t:Show();
		end
	end);
	t.showHideButton = l;
	l = CreateFrame("Frame", "PeggleMouseOverSentry", t);
	l:SetPoint("Topleft", 0, 30);
	l:SetPoint("Bottomright");
	l:EnableMouse(false);
	l.elapsed = 0;
	l.mouseOver = true;
	l:SetScript("OnUpdate", function(e, n)
		if not e.mouseOver and not e.fading then
			return;
		end
		e.elapsed = e.elapsed + n;
		if(e.fading)and(e.elapsed < .5)then
			local n = PeggleForeverData.settings.mouseOnTrans;
			local o = PeggleForeverData.settings.mouseOffTrans;
			local e = n - ((n - o) * (e.elapsed / .5))
			t:SetAlpha(e);
		end
		if(e.elapsed > .5)then
			e.elapsed = 0;
			if(e.fading)then
				t:SetAlpha(PeggleForeverData.settings.mouseOffTrans);
				e.fading = nil;
			else
				if not MouseIsOver(t)then
					if not t.resizing then
						e:EnableMouse(true);
						e.mouseOver = nil;
						e.fading = true;
					end
				end
			end
		end
	end);
	l:SetScript("OnEnter", function(e)
		t:SetAlpha(PeggleForeverData.settings.mouseOnTrans);
		e.mouseOver = true;
		e.fading = nil;
		e.elapsed = 0;
		e:EnableMouse(false);
	end);
	r[u][1][s] = S(L(c(h, 1, 4), 128)or"`");
	r[u][2][s] = S(L(c(h, 5, 8), 128)or"`");
	r[u][3][s] = S(L(c(h, 9, 12), 128)or"`");
	r[u][4][s] = S(L(c(h, 13, 16), 128)or"`");
	l:SetFrameLevel(t:GetFrameLevel() + 80);
	t.mouseOverScreen = l;
end
local function w()
	local e = CreateFrame("Frame", "", UIParent);
	-- Make the variable global so we can set framerate outside of it
	PeggleGameWindow = e
	e:SetWidth(1);
	e:SetHeight(1);
	e:EnableMouse(false);
	e:SetAlpha(0);
	e.elapsed = 0;
	e.delay = 1/60;
	e:SetScript("OnUpdate", Ne);
	e.tableCos = {}
	e.tableSin = {}
	for t = 0, 360 do
		j = T(t);
		e.tableSin[t] = I(j);
		e.tableCos[t] = k(j);
	end
	e:Show();
	e.animationStack = {};
	e.activeBallStack = {};
	e.activePointTextStack = {};
	e.hitPegStack = {};
	e.glowQueue = {};
	e.activeGlows = {};
	e.activeParticles = {};
	e.activeParticleGens = {};
	e.ballQueue = {};
	e.pegQueue = {};
	e.brickQueue = {};
	e.pointTextQueue = {};
	e.particleGenQueue = {};
	e.particleQueue = {};
	e.bouncer = {0, 114, 224, 330, 438, 550, 1, 5, 10, 5, 1}
	e.Add = pt;
	e.SpawnBall = Pt;
	e.SpawnPeg = dt;
	e.SpawnBrick = ut;
	e.SpawnGlow = ct;
	e.SpawnParticle = rt;
	e.SpawnParticleGen = ft;
	e.CreateImage = Tt;
	e.SpawnText = st;
	e.RotateTexture = Ce;
	e.UpdateMover = bt;
	e.SetupObject = Ct;
	e.Update_FloatingText = Lt;
	d = e;
end
local function _()
	local o = CreateFrame("Frame", "PeggleCoinFlipper", r.foreground);
	o:SetWidth(196);
	o:SetHeight(196);
	o:SetPoint("Center", r, "Center", 0,  - 30);
	o:Hide();
	o:SetScript("OnUpdate", function(n, o)
		if(o > .05)then
			o = .05;
		end
		n.elapsed = n.elapsed + o;
		if(n.spinStop)then
			if(n.elapsed > 1.5)then
				n.elapsed = nil;
				n.spinStop = nil;
				n.side = 0;
				n:Hide();
				t.ballTracker:UpdateDisplay(1);
			end
		else
			if(n.elapsed > .2)then
				n.side = n.side + 1
				n.flips = n.flips + 1;
				n.check = nil;
				if(n.side > 1)then
					n.side = 0;
				end
				n.elapsed = 0;
				n.tex:SetTexCoord(n.side * .5, (n.side + 1) * .5, 0, 1);
			end
			if(n.elapsed < .1)then
				n.tex:SetWidth(196 * ((n.elapsed) / .1 + .001));
			else
				n.tex:SetWidth(196 * (.2 - n.elapsed) / .1);
			end
			if(not n.check)and(n.flips == 6)and(n.elapsed > .1)then
				n.check = true;
				freeChance = C(1, 100);
				local o = 0;
				if not e[e.newInfo[13]]then
					o = b[33 + 1] * 10 + config.Mod("coin")
				end
				if(freeChance > 50 - o)then
					n.tex:SetWidth(196);
					n.elapsed = 0;
					n.spinStop = true;
					t.roundPegs.elapsed = 0;
					t.ballTracker:UpdateDisplay(2);
				else
					E(e.SOUND_COIN_DENIED);
				end
			end
			if(n.flips == 7)and(n.elapsed > .1)then
				n.tex:SetWidth(196);
				n.elapsed = 0;
				n.spinStop = true;
				t.roundPegs.elapsed = 0;
				E(e.SOUND_COIN_DENIED);
			end
		end
	end);
	tex = o:CreateTexture(nil, "OVERLAY");
	tex:SetWidth(0);
	tex:SetHeight(196);
	tex:SetTexture(e.artPath.."coin");
	tex:SetTexCoord(0, .5, 0, 1);
	tex:SetPoint("Center");
	tex:Show();
	o.tex = tex;
	d.coin = o;
end
local function b()
	local o = e.artCut["feverBonus10"];
	local n = r:CreateTexture(nil, "Artwork");
	n:SetWidth(i((o[2] - o[1]) * 512 + .5));
	n:SetHeight(i((o[4] - o[3]) * 512 + .5));
	n:SetPoint("BottomLeft", 0, 0);
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(o));
	n:Hide();
	t.bonusBar1 = n;
	n.coord = o;
	local l = n:GetWidth();
	o = e.artCut["feverBonus50"];
	n = r:CreateTexture(nil, "Artwork");
	n:SetWidth(i((o[2] - o[1]) * 512 + .5));
	n:SetHeight(i((o[4] - o[3]) * 512 + .5));
	n:SetPoint("BottomLeft", 0 + l, 0);
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(o));
	n:Hide();
	t.bonusBar2 = n;
	n.coord = o;
	l = l + n:GetWidth();
	o = e.artCut["feverBonus100"];
	n = r:CreateTexture(nil, "Artwork");
	n:SetWidth(i((o[2] - o[1]) * 512 + .5));
	n:SetHeight(i((o[4] - o[3]) * 512 + .5));
	n:SetPoint("BottomLeft", 0 + l, 0);
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(o));
	n:Hide();
	t.bonusBar3 = n;
	n.coord = o;
	l = l + n:GetWidth();
	o = e.artCut["feverBonus50"];
	n = r:CreateTexture(nil, "Artwork");
	n:SetWidth(i((o[2] - o[1]) * 512 + .5));
	n:SetHeight(i((o[4] - o[3]) * 512 + .5));
	n:SetPoint("BottomLeft", 0 + l, 0);
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(o));
	n:Hide();
	t.bonusBar4 = n;
	l = l + n:GetWidth();
	o = e.artCut["feverBonus10"];
	n = r:CreateTexture(nil, "Artwork");
	n:SetWidth(i((o[2] - o[1]) * 512 + .5));
	n:SetHeight(i((o[4] - o[3]) * 512 + .5));
	n:SetPoint("BottomLeft", 0 + l, 0);
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(o));
	n:Hide();
	t.bonusBar5 = n;
end
local function E()
	local n = CreateFrame("Frame", "", r.foreground);
	n:SetWidth(20);
	n:SetHeight(20);
	n:SetPoint("Center", r, "Center");
	n:Show();
	n:SetFrameLevel(n:GetFrameLevel() + 2);
	local a = o:CreateCaption(0, 0, "", n, 16, 1, 1, 0, true)
	a:ClearAllPoints();
	a:SetPoint("Center", r, "Center", 0, e.boardHeight / 4);
	t.roundPegs = a;
	a = o:CreateCaption(0, 0, "", n, 24, 1, 1, 0, true)
	a:ClearAllPoints();
	a:SetPoint("Center", r, "Center", 0, e.boardHeight / 4 - 20);
	t.roundPegScore = a;
	a = o:CreateCaption(0, 0, "", n, 20, .4, 1, 1, true)
	a:ClearAllPoints();
	a:SetPoint("Center", r, "Center", 0, e.boardHeight / 4 - 44);
	t.roundBonusScore = a;
	n = CreateFrame("Frame", "", r.foreground);
	n:SetWidth(200);
	n:SetHeight(24);
	n:SetPoint("Center", r, "Center", 0, e.boardHeight / 4 - 44 - 24);
	n:Hide();
	n.elapsed = 0;
	n:SetFrameLevel(n:GetFrameLevel() + 3);
	t.roundBalls = n;
	n:SetScript("OnShow", function(e)
		e.elapsed = 0;
		e:SetAlpha(1);
		local t = #t.ballTracker.ballStack;
		if(t == 1)then
			e.text:SetText(e.text.caption2);
		else
			e.text:SetFormattedText(e.text.caption1, t);
		end
	end);
	n:SetScript("OnUpdate", function(e, t)
		e.elapsed = e.elapsed + t;
		if(e.elapsed < .25)then
			e.text:SetTextHeight(50 - 100 * e.elapsed)
		else
			e.text:SetTextHeight(25);
		end
		if(e.elapsed > 4)then
			e.elapsed = 0;
			e:Hide();
			return;
		end
		if(e.elapsed > 3)then
			e:SetAlpha(F(4 - e.elapsed, 0));
		end
	end);
	a = o:CreateCaption(0, 0, "", n, 25, 1, 0, 0, true)
	a:ClearAllPoints();
	a:SetPoint("Center");
	a.caption1 = e.locale["BALLS_LEFT1"];
	a.caption2 = e.locale["BALLS_LEFT2"];
	n.text = a;
	local r = CreateFrame("Frame", "", t.artBorder)
	r:SetPoint("Center");
	r:SetWidth(20);
	r:SetHeight(20);
	local n = e.artCut["fever1"];
	local l = r:CreateTexture(nil, "Overlay");
	l:SetWidth(i((n[2] - n[1]) * 512 + .5));
	l:SetHeight(i((n[4] - n[3]) * 256 + .5));
	l:SetPoint("Center");
	l:SetTexture(e.artPath.."extremeFever");
	l:SetTexCoord(unpack(n));
	l:Hide();
	t.fever1 = l;
	n = e.artCut["fever2"];
	l = r:CreateTexture(nil, "Overlay");
	l:SetWidth(i((n[2] - n[1]) * 512 + .5));
	l:SetHeight(i((n[4] - n[3]) * 256 + .5));
	l:SetPoint("Bottom", t.fever1, "Top");
	l:SetTexture(e.artPath.."extremeFever");
	l:SetTexCoord(unpack(n));
	l:Hide();
	t.fever2 = l;
	n = e.artCut["feverScore"];
	l = t.artBorder:CreateTexture(nil, "Overlay");
	l:SetPoint("Center", t, "Center", 0, 42);
	l:SetWidth(i((n[4] - n[3]) * (512 * 1.4) + .5));
	l:SetHeight(i((n[2] - n[1]) * (256 * 1.3) + .5));
	l:SetTexture(e.artPath.."board2");
	l:SetTexCoord(n[2], n[3], n[1], n[3], n[2], n[4], n[1], n[4]);
	l:Hide();
	t.fever3 = l
	a = o:CreateCaption(0, 0, "", t.roundBonusScore:GetParent(), 40, .4, 1, 1, true)
	a:ClearAllPoints();
	a:SetPoint("Top", l, "Bottom", 0, 20);
	t.feverPegScore = a;
end
local function n()
	physicsWindow = CreateFrame("Frame", "PhysicsEditingWindow", t);
	physicsWindow:SetPoint("TopLeft", t, "BottomLeft", 0,  - 20);
	physicsWindow:SetPoint("TopRight", t, "BottomRight", 0,  - 20);
	physicsWindow:SetHeight(60);
	physicsWindow.background = physicsWindow:CreateTexture(nil, background);
	physicsWindow.background:SetAllPoints(physicsWindow);
	physicsWindow.background:SetTexture(0, 0, 0, .5);
	physicsWindow:Hide();
	local e = o:CreateCaption(10, 15, "Gravity                       pixels/sec", physicsWindow, 12)
	e:ClearAllPoints()
	e:SetPoint("Bottomleft", t, "Bottomleft", 16,  - 45 - 25)
	e = CreateFrame("EditBox", "PeggleEditBox1", physicsWindow, "InputBoxTemplate");
	e:SetPoint("Bottomleft", t, "Bottomleft", 70,  - 50 - 25)
	e:SetWidth(64);
	e:SetHeight(20);
	e:Show();
	e:IsNumeric(true);
	e:SetText(be);
	e:SetScript("OnTextChanged", function(e)
		local e = A(e:GetText());
		if(e)then
			be = e;
		end
	end);
	e:ClearFocus();
	e = o:CreateCaption(200, 15, "Max glide hits                        hits", physicsWindow, 12)
	e:ClearAllPoints()
	e:SetPoint("Bottomleft", t, "Bottomleft", 280,  - 45 - 25)
	e = CreateFrame("EditBox", "PeggleEditBox2", physicsWindow, "InputBoxTemplate");
	e:SetPoint("Bottomleft", t, "Bottomleft", 380,  - 50 - 25)
	e:SetWidth(64);
	e:SetHeight(20);
	e:Show();
	e:IsNumeric(true);
	e:SetText(Te);
	e:SetScript("OnTextChanged", function(e)
		local e = A(e:GetText());
		if(e)then
			Te = e;
		end
	end);
	e:ClearFocus();
	e = o:CreateCaption(10,  - 15, "Shot Force                          pixels/sec", physicsWindow, 12)
	e:ClearAllPoints()
	e:SetPoint("Bottomleft", t, "Bottomleft", 16,  - 20 - 25)
	e = CreateFrame("EditBox", "PeggleEditBox3", physicsWindow, "InputBoxTemplate");
	e:SetPoint("Bottomleft", t, "Bottomleft", 100,  - 25 - 25)
	e:SetWidth(64);
	e:SetHeight(20);
	e:Show();
	e:IsNumeric(true);
	e:SetText(se);
	e:SetScript("OnTextChanged", function(e)
		local e = A(e:GetText());
		if(e)then
			se = e;
		end
	end);
	e:ClearFocus();
	e = o:CreateCaption(200,  - 15, "Elasticity (0.00 to 1.00 pls)", physicsWindow, 12)
	e:ClearAllPoints()
	e:SetPoint("Bottomleft", t, "Bottomleft", 300,  - 20 - 25)
	e = CreateFrame("EditBox", "PeggleEditBox4", physicsWindow, "InputBoxTemplate");
	e:SetPoint("Bottomleft", t, "Bottomleft", 476,  - 25 - 25)
	e:SetWidth(64);
	e:SetHeight(20);
	e:Show();
	e:IsNumeric(true);
	e:SetText(Ee);
	e:SetScript("OnTextChanged", function(e)
		local e = A(e:GetText());
		if(e)then
			Ee = e;
		end
	end);
	e:ClearFocus();
	x(490, 30, "Show block polys", "showPolys", true, physicsWindow, function(e)
		showPoly = e:GetChecked();
	end)
	e = CreateFrame("Button", nil, physicsWindow, "OptionsButtonTemplate")
	e:SetText("Add Ball");
	e:ClearAllPoints()
	e:SetPoint("BottomRight", physicsWindow, "BottomRight",  - 10, 10)
	e:SetScript("OnClick", function(e)
		if(te < 15)then
			t.ballTracker:UpdateDisplay(2);
		end
	end);
end
local function G()
	local n, n
	for t = 1, e.boardXYSections do
		y[t] = {};
		for e = 1, e.boardXYSections do
			y[t][e] = {};
		end
	end
	local n = CreateFrame("ScrollFrame", nil, t, config.backdroptmpl);
	n:SetWidth(e.boardWidth);
	n:SetHeight(e.boardHeight);
	n:SetPoint("Topleft", 53,  - 70);
	n:Show();
	r = CreateFrame("Frame", nil, t, config.backdroptmpl);
	r:SetWidth(e.boardWidth);
	r:SetHeight(e.boardHeight);
	r:ClearAllPoints();
	r:Show();
	r:EnableMouse(true);
	r:EnableMouseWheel(true);
	r:SetPoint("Center");
	local l = e.GetBackdrop();
	r:SetBackdrop(l);
	r:SetBackdropColor(0, 0, 0, 0);
	r:SetBackdropBorderColor(1, 0, 0, 0);
	n:SetScrollChild(r);
	t.gameBoardContainer = n;
	r:SetScript("OnUpdate", function(n, o)
		if(t.gameMenu:IsShown()or t.charScreen:IsShown())then
			return;
		end
		local s, a = GetCursorPosition();
		local g, h, S, u = n:GetRect()
		local c = n:GetEffectiveScale();
		if n.fineX then
			if(Se(n.fineX - s) < 5)and(Se(n.fineY - a) < 5)then
				return;
			end
			n.fineX = nil;
			n.fineY = nil;
		end
		local l, o;
		l = s / c - g;
		if((l >= 0)and(l <= S))then
			o = a / c - h;
			if((o >= 0)and(o <= u))then
				if(n.lastX ~= l)or(n.lastY ~= o)or(n.updateShooter)then
					local c = e.boardWidth / 2;
					local s = e.boardHeight - 16 - 20;
					local a, h = l, o;
					local S = a - c;
					local a =  - (h - s);
					local h = se ^ 4;
					local u = (be * S ^ 2);
					local a = 2 * a * (se ^ 2);
					local u = h - be * (u + a);
					local h, a;
					if(u > 0)then
						local e = z(u);
						a =  - atan(((se ^ 2) - e) / (be * S));
						if(S < 0)then
							a = a - 180;
						end
						h = f(a + 360, 360);
					end
					n.lastX = l;
					n.lastY = o;
					if(n.updateShooter)then
						h = N;
						n.updateShooter = nil;
					end
					N = h or(N);
					if(N > 25)and(N < 155)then
						if(N < 90)then
							N = 25;
						else
							N = 155;
						end
					end
					local h = (se * k(T(N)));
					local S = (se * I(T(N)));
					local a = (e.boardWidth / 2)
					local u = (e.boardHeight - 16) - 20
					local g, o, l, n;
					for e = 1, 4 do
						n = ((e - 1) / 10 * 1 / 1.85);
						o = a + h * n;
						l = u + S * n + .5 * be * (n ^ 2);
						if(e == 4)then
							ue = f(atan2(s - l + 4, c - o) + 180, 360);
						end
					end
					c = (e.boardWidth / 2) + 1 + 65 * k(T(ue));
					s = (e.boardHeight - 12) - 20 + 65 * I(T(ue));
					t.shooter.ball:SetPoint("Center", r, "BottomLeft", 1 + c, s);
					d:RotateTexture(t.shooter, i(ue) - 135, .5, .5);
				end
			end
		end
	end);
	r:SetScript("OnMouseDown", Et);
	r:SetScript("OnMouseUp", function()
		e.speedy = nil
	end);
	r:SetScript("OnMouseWheel", function(e, t)
		N = N + t * .1;
		e.updateShooter = true;
		e.fineX, e.fineY = GetCursorPosition();
	end);
	r.foreground = CreateFrame("Frame", nil, r);
	r.foreground:SetWidth(e.boardWidth);
	r.foreground:SetHeight(e.boardHeight);
	r.foreground:SetPoint("Topleft", 74,  - 70);
	r.foreground:Show();
	r.foreground:SetFrameLevel(r:GetFrameLevel() + 1);
	local n = r:CreateTexture(nil, "Background");
	n:SetWidth(e.boardWidth);
	n:SetHeight(e.boardWidth);
	n:SetTexture(e.artPath.."bg1");
	n:SetPoint("Center", r, "Center", 0,  - 2);
	r.background = n;
	r.trail = {};
	for t = 1, 10 do
		n = r:CreateTexture(nil, "Overlay");
		n:SetWidth(e.ballWidth);
		n:SetHeight(e.ballHeight);
		config.Skin(n, "ball");
		n:SetVertexColor(.4, .8, 1);
		n:SetAlpha(.6);
		r.trail[t] = n;
		n:Hide();
	end
	local n = t.artBorder:CreateTexture(nil, "Overlay");
	n:SetPoint("Center", t, "Top", 1,  - 101);
	n:SetWidth(256);
	n:SetHeight(256);
	n:SetTexture(e.artPath.."shooter");
	t.shooter = n;
	n = t.artBorder:CreateTexture(nil, "Overlay");
	n:SetWidth(e.ballWidth);
	n:SetHeight(e.ballHeight);
	config.Skin(n, "ball");
	n:Hide();
	t.shooter.ball = n;
	local l = CreateFrame("Frame", "", t);
	l:SetFrameLevel(t:GetFrameLevel() + 2);
	l:SetWidth(10);
	l:SetHeight(10);
	l:SetPoint("Top", r, "Top");
	t.charPortrait = l;
	n = l:CreateTexture(nil, "Background");
	n:SetPoint("Center", t, "Top", 3,  - 101);
	n:SetWidth(72);
	n:SetHeight(50);
	n:SetTexture(0, 0, 0);
	t.shooter.faceBG1 = n;
	n = l:CreateTexture(nil, "Background");
	n:SetPoint("Center", t, "Top", 2,  - 98);
	n:SetWidth(50);
	n:SetHeight(74);
	n:SetTexture(0, 0, 0);
	t.shooter.faceBG2 = n;
	n = l:CreateTexture(nil, "Artwork");
	n:SetPoint("Center", t, "Top", 0,  - 101);
	n:SetWidth(64);
	n:SetHeight(72);
	n:SetTexture(e.artPath.."char1Face");
	n:SetTexCoord(0, 1, 0 / 256, 72 / 256);
	t.shooter.face = n;
	l = CreateFrame("Frame", "", t.artBorder);
	l:SetPoint("Top", t, "Top", 0,  - 30);
	l:SetWidth(64);
	l:SetHeight(64);
	t.powerLabel = l;
	n = r.foreground:CreateTexture(nil, "Overlay");
	n:SetPoint("Topright", r, "Topright", 0, 40);
	n:SetWidth(r:GetWidth());
	n:SetHeight(r:GetWidth());
	n:SetTexture(e.artPath.."rainbow2");
	n:SetAlpha(.8);
	t.rainbow = n;
	n:Hide();
	local a = e.artCut["powerLabel"];
	n = l:CreateTexture(nil, "ARTWORK");
	n:SetPoint("Top");
	n:SetWidth(i((a[2] - a[1]) * 512 + .5));
	n:SetHeight(i((a[4] - a[3]) * 512 + .5));
	n:SetTexture(e.artPath.."board1");
	n:SetTexCoord(unpack(a));
	local o = o:CreateCaption(0, 0, e.locale["_SPECIAL_NAME1"], l, 15, .55, .85, 1, true)
	o:ClearAllPoints();
	o:SetPoint("Top", 0,  - 5);
	t.powerLabel.text = o;
	l = CreateFrame("Frame", "", t.artBorder);
	l:SetWidth(1);
	l:SetHeight(1);
	l:SetPoint("Center", r, "Center");
	l:SetScript("OnUpdate", function(e, n)
		e.elapsed = e.elapsed + n;
		if(e.elapsed < .5)then
			e.tex:SetAlpha(e.elapsed * 2);
		else
			e.tex:SetAlpha(1);
		end
		if(e.elapsed > 3.5)then
			e.elapsed = 0;
			e:Hide();
			t.summaryScreen:Show();
		end
	end);
	l.elapsed = 0;
	l:Hide();
	t.banner = l;
	a = e.artCut["bannerBig1"];
	n = t.artBorder:CreateTexture(nil, "Overlay");
	n:SetWidth(i((a[2] - a[1]) * 512 + .5));
	n:SetHeight(i((a[4] - a[3]) * 512 + .5));
	n:SetPoint("Center", r, "Center", 2,  - 52);
	n:SetTexture(e.artPath.."banner2");
	n:SetTexCoord(unpack(a));
	n.clear1 = a;
	n.clear2 = e.artCut["bannerBig2"];
	t.banner.tex = n;
	n:Hide();
end
local function y()
	local n = CreateFrame("Frame", "PeggledMinimapIcon", Minimap);
	n:SetWidth(33);
	n:SetHeight(33);
	n:SetFrameStrata("LOW");
	n:EnableMouse(true);
	n:SetClampedToScreen(true);
	n.icon = n:CreateTexture(nil, "Background");
	n.icon:SetWidth(26);
	n.icon:SetHeight(26);
	n.icon:SetPoint("Center",  - 1, 1);
	n.icon:SetTexture(e.artPath.."minimap");
	n.icon:Show();
	n.icon2 = n:CreateTexture(nil, "Background");
	n.icon2:SetWidth(26);
	n.icon2:SetHeight(26);
	n.icon2:SetPoint("Center",  - 1, 1);
	n.icon2:SetTexture(e.artPath.."minimapNotice");
	n.icon2:Hide();
	n.border = n:CreateTexture(nil, "Artwork");
	n.border:SetWidth(52);
	n.border:SetHeight(52);
	n.border:SetPoint("Topleft");
	n.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder");
	n.highlight = n:CreateTexture(nil, "Overlay");
	n.highlight:SetWidth(32);
	n.highlight:SetHeight(32);
	n.highlight:SetPoint("Center");
	n.highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight");
	n.highlight:SetBlendMode("ADD");
	n.highlight:Hide();
	n:SetPoint("Center",  - (76 * k(T(0))), (76 * I(T(0))))
	n:Show();
	n.elapsed = 0;
	n:SetScript("OnMouseDown", function(e, t)
		e.icon:SetPoint("Center", 0, 0)
		if(t == "RightButton")then
			e.moving = true
		end
	end);
	n:SetScript("OnMouseUp", function(e, n)
		e.icon:SetPoint("Center",  - 1, 1)
		e.moving = nil;
		if(n == "LeftButton")then
			if(t:IsVisible())then
				t:Hide()
			else
				if not MouseIsOver(t)then
					t:SetAlpha(PeggleForeverData.settings.mouseOnTrans);
					t.mouseOverScreen:EnableMouse(true);
					t.mouseOverScreen.mouseOver = nil;
					t.mouseOverScreen.fading = nil;
					if not((t.catagoryScreen:IsShown()and de == false))then
						if(de == false)then
							if not(t.gameMenu:IsShown())then
								t.gameMenu:Show();
							end
						else
							R(false);
						end
					end
				else
					t:SetAlpha(PeggleForeverData.settings.mouseOnTrans);
					t.mouseOverScreen:EnableMouse(false);
					t.mouseOverScreen.mouseOver = true;
					t.mouseOverScreen.fading = nil;
				end
				t:Show()
			end
		end
	end);
	-- n:SetScript("OnEnter", function(t)
	-- 	t.highlight:Show();
	-- 	GameTooltip_SetDefaultAnchor(GameTooltip, UIParent);
	-- 	GameTooltip:SetText("|cFFFFFFFFPeggle");
	-- 	GameTooltip:AddLine(e.locale["_TOOLTIP_MINIMAP"]);
	-- 	GameTooltip:Show();
	-- end);
	-- n:SetScript("OnLeave", function(e)
	-- 	e.highlight:Hide();
	-- 	GameTooltip:Hide();
	-- end);
	-- n:SetScript("OnUpdate", function(e, r)
	-- 	if(e.moving)then
	-- 		local t, t = GetCursorPosition()
	-- 		local t = Minimap:GetLeft() + Minimap:GetWidth() / 2
	-- 		local t = Minimap:GetBottom() + Minimap:GetHeight() / 2
	-- 		PeggleForeverData.settings.minimapAngle = angle
	-- 		local o, l = GetCursorPosition()
	-- 		local i = Minimap:GetLeft() + Minimap:GetWidth() / 2
	-- 		local a = Minimap:GetBottom() + Minimap:GetHeight() / 2
	-- 		local n = (o / UIParent:GetScale()) - i;
	-- 		local t = (l / UIParent:GetScale()) - a;
	-- 		if((n ^ 2 + t ^ 2) > Minimap:GetWidth() ^ 2)then
	-- 			PeggleForeverData.settings.minimapDetached = true;
	-- 			n = o / UIParent:GetScale();
	-- 			t = l / UIParent:GetScale();
	-- 			PeggleForeverData.settings.minimapX = n;
	-- 			PeggleForeverData.settings.minimapY = t;
	-- 			e:SetPoint("Center", UIParent, "bottomleft", n, t);
	-- 		else
	-- 			local t = gt(math.atan2((l / UIParent:GetScale()) - a, i - (o / UIParent:GetScale())));
	-- 			PeggleForeverData.settings.minimapAngle = t;
	-- 			PeggleForeverData.settings.minimapDetached = nil;
	-- 			e:SetPoint("Center", Minimap, "Center",  - (76 * k(T(t))), (76 * I(T(t))))
	-- 		end
	-- 	end
	-- 	if(e.notice)then
	-- 		e.elapsed = e.elapsed + r;
	-- 		if(e.elapsed >= .5)then
	-- 			e.elapsed = 0;
	-- 			if(e.icon:IsShown())then
	-- 				e.icon:Hide();
	-- 				e.icon2:Show();
	-- 				e.on = true
	-- 			else
	-- 				e.icon:Show();
	-- 				e.icon2:Hide();
	-- 				e.on = nil;
	-- 			end
	-- 		end
	-- 	elseif(e.on)then
	-- 		e.icon:Show();
	-- 		e.icon2:Hide();
	-- 		e.on = nil;
	-- 	end
	-- end);
	n:Hide()
	t.minimap = n;
end
local function N()
	local n = CreateFrame("Frame", "PeggleLootTimer", UIParent);
	n:SetWidth(1);
	n:SetHeight(1);
	n:SetPoint("Top");
	n:Hide();
	n.remaining = nil;
	n.serverRemaining = nil;
	n.serverStage = 0;
	n.temp = {};
	n.compare = function(t, e)
		if t[2] > e[2]then
			return true
		end
	end;
	n:SetScript("OnUpdate", function(n, o)
		if(n.remaining)then
			n.remaining = n.remaining - o;
			if(n.remaining >  - 100)then
				if(n.remaining <= 0)then
					n.remaining = -100;
					t.peggleLootDialog:Hide();
					-- time is up while the loot shot is still being played (the original tested Q == false here,
					-- which is never the case on the loot board, so a late ball was never stopped)
					if(e[e.newInfo[11]])and(e[e.newInfo[13]])and(de == false)then
						local ball = d.activeBallStack[1];
						if(ball)then
							ball.y = -100;
							ball.x = 0;
							ball.xVel = 0;
							ball.yVel = 0;
						elseif(de == false)then
							-- clicked Go but never shot: counts as declined (so the leader lists them) and back to the menu
							t.network:Send(e.commands[21], e[e.newInfo[11]].."+", "WHISPER", e[e.newInfo[11].. 4]);
							if not e[e.newInfo[12]]then
								e[e.newInfo[11]] = nil;
							end
							de = true;
							R(false);
						end
					else
						if not n.serverRemaining then
							e[e.newInfo[11]] = nil;
							n:Hide();
						end
					end
				else
					t.peggleLootDialog.remaining:SetFormattedText(t.peggleLootDialog.remaining.caption1, ceil(n.remaining))
					if(e[e.newInfo[11]])and not(t.peggleLootDialog:IsShown())then
						t.bestScoreCaption:SetFormattedText(t.bestScoreCaption.caption3, ceil(n.remaining))
					end
				end
			end
		end
		if(n.serverRemaining)then
			n.serverRemaining = n.serverRemaining - o;
			if(n.serverStage == 0)and(n.serverRemaining < 30)then
				n.serverStage = 1;
				print("|CFFFFDD00"..string.format(e.locale["_PEGGLELOOT_CHAT_REMAINING"], 30));
			elseif(n.serverStage == 1)and(n.serverRemaining < 20)then
				n.serverStage = 2;
				print("|CFFFFDD00"..string.format(e.locale["_PEGGLELOOT_CHAT_REMAINING"], 20));
			elseif(n.serverStage == 2)and(n.serverRemaining < 10)then
				n.serverStage = 3;
				print("|CFFFFDD00"..string.format(e.locale["_PEGGLELOOT_CHAT_REMAINING"], 10));
			end
			if(n.serverRemaining <= 0)then
				-- stop first: if anything below failed, the results would otherwise be posted to chat every frame
				n.serverRemaining = nil;
				n.serverStage = 0;
				n:Hide();
				local o = n.temp;
				table.wipe(o);
				local a, a, l
				l = 1;
				for e, t in pairs(e[e.newInfo[12]])do
					o[l] = {e, t};
					l = l + 1;
				end
				table.sort(o, n.compare);
				local l = "PARTY";
				if IsInRaid() then
					l = "RAID";
				end
				t.network:Chat(e.locale["_PEGGLELOOT_RESULTS"], l);
				for e = 1, #o do
					if(o[e][2] >  - 1)then
						t.network:Chat(e.." - "..o[e][1].." - "..P(o[e][2]).." pts", l);
					else
						t.network:Chat(e.." - "..o[e][1].." - "..(DECLINE or "Decline"), l);
					end
				end
				if(#o > 0)and(o[1][2] >  - 1)then
					t.network:Chat(string.format(e.locale["_PEGGLELOOT_WINNER"], o[1][1]), l);
				else
					t.network:Chat(e.locale["_PEGGLELOOT_NOWINNER"], l);
				end
				e[e.newInfo[11]] = nil;
				e[e.newInfo[12]] = nil;
				n:Hide();
			end
		end
	end);
	t.peggleLootTimer = n;
	n = CreateFrame("Frame", "", UIParent, config.backdroptmpl);
	n:SetPoint("Center")
	n:SetWidth(310);
	n:SetHeight(230);
	n:EnableMouse(true);
	n:SetFrameStrata("DIALOG");
	local l = e.GetBackdrop();
	l.tileSize = 128;
	l.tile = false;
	l.edgeFile = "Interface\\Glues\\Common\\TextPanel-Border"l.edgeSize = 32;
	l.bgFile = e.artPath.."windowBackground";
	n:SetBackdrop(l);
	n:SetBackdropColor(.7, .7, .7, 1);
	n:SetBackdropBorderColor(1, .8, .45);
	n:SetScript("OnShow", function(t)
		local n = e[e.newInfo[11].. 1]or(e.locale["_THE_ITEM"]);
		if(n ~= e.locale["_THE_ITEM"])then
			t.desc:SetText(n)
		else
			t.desc:SetText("")
		end
	end);
	local a = n;
	n:Hide();
	t.peggleLootDialog = n;
	local l = o:CreateCaption(0, 0, e.locale["PEGGLELOOT_TITLE"], a, 25, 1, .82, 0, 1, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", 0,  - 20);
	l = o:CreateCaption(0, 0, e.locale["PEGGLELOOT_DESC"], a, 17, 1, 1, 1, true, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", 0,  - 50);
	l:SetWidth(a:GetWidth() - 30);
	l:SetJustifyV("TOP");
	a.desc = l;
	l = o:CreateCaption(0, 0, e.locale["PEGGLELOOT_DESC"], a, 18, 1, 1, 1, nil, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", a.desc, "Bottom", 0,  - 10);
	l:SetWidth(a:GetWidth() - 30);
	l:SetJustifyV("TOP");
	a.desc = l;
	l = o:CreateCaption(0, 0, "", a, 18, 1, 1, 1, nil, nil)
	l:ClearAllPoints();
	l:SetPoint("Top", 0,  - 50 - 18 * 5);
	l:SetWidth(a:GetWidth() - 30);
	l.caption1 = e.locale["PEGGLELOOT_REMAINING"];
	a.remaining = l;
	n = m(0, 0, 45, "buttonGo", nil, "lootGo", a, function(n)
		local o = e[e.newInfo[11].. 2];
		local l = e[e.newInfo[11].. 3];
		n:GetParent():Hide();
		t:Show();
		t:SetAlpha(PeggleForeverData.settings.mouseOnTrans);
		t.mouseOverScreen:EnableMouse(false);
		t.mouseOverScreen.mouseOver = true;
		t.mouseOverScreen.fading = nil;
		if(t.duelStatus == 3)then
			local n = t.catagoryScreen.frames[2];
			config.SendAddonMessage(t.network.prefix, e.commands[6], "WHISPER", n.name2:GetText());
			n.player1.value = -2;
			n:UpdateWinners();
			t.duelStatus = nil;
		end
		Ae(o, nil, l, true);
		R(true);
		Q = false;
	end)
	n:ClearAllPoints();
	n:SetPoint("Bottomleft", 14, 14);
	n = m(0, 0, 45, "buttonDecline", true, "lootDecline", a, function(n)
		local l = e[e.newInfo[11]];
		local o = e[e.newInfo[11].. 4];
		t.network:Send(e.commands[21], l.."+", "WHISPER", o);
		if not e[e.newInfo[12]]then
		e[e.newInfo[11]] = nil;
		end
		n:GetParent():Hide();
	end, nil, true)
	n:ClearAllPoints();
	n:SetPoint("Bottomright",  - 14, 14);
end
local function k()
	local i = CreateFrame("Frame", "PeggleNet", UIParent);
	i:SetWidth(1);
	i:SetHeight(1);
	i:SetPoint("Top");
	i:Show();
	i:RegisterEvent("CHAT_MSG_ADDON");
	i:RegisterEvent("CHAT_MSG_SYSTEM");
	i.prefix = e.addonName;
	i.queue = {};
	i.Send = function(o, n, e, t, l)
		s(o.queue, n.."+"..(e or(""))..O(174)..t..O(174)..(l or("")));
	end;
	i.Chat = function(o, t, n, e)
		s(o.queue, "[Peggle Forever]: "..t..O(174)..n..O(174)..(e or("")));
	end
	i.throttleCount = 0;
	i.elapsed = 0;
	i:SetScript("OnUpdate", function(e, n)
		if(e.inviteTimer)then
			e.inviteTimer = e.inviteTimer + n;
			if(e.inviteTimer >= 5)then
				e.inviteTimer = nil;
				if(t.duelStatus)then
					local e = t.catagoryScreen.frames[2];
					e.note3:SetText(e.note3.status4);
					e.decline1:Hide();
					e.okay1:Show();
				end
			end
		end
		e.elapsed = e.elapsed + n;
		if(e.elapsed < 1)then
			return;
		end
		local l = e.prefix;
		e.elapsed = 0;
		e.throttleCount = 0;
		if(#e.queue > 0)then
			if(e.throttleCount < 10)then
				local t, t, t, t;
				local a, o, t, n;
				while(e.throttleCount < 10)do
					o, t, n = strsplit(O(174), u(e.queue, 1));
					if((t == "GUILD")and IsInGuild())then
						config.SendAddonMessage(l, o, t, n);
						e.throttleCount = e.throttleCount + 1;
					elseif(t == "WHISPER")and(n ~= "")then
						config.SendAddonMessage(l, o, t, n);
						e.throttleCount = e.throttleCount + 1;
					elseif(t == "RAID")or(t == "PARTY")then
						SendChatMessage(o, t);
						e.throttleCount = e.throttleCount + 1;
					end
					if(#e.queue == 0)then
						break;
					end
				end
			end
		end
	end);
	i:SetScript("OnEvent", function(m, n, C, i, l, a)
		a = string.match(a, "(.*)%-(.*)") or a
		if(n == "CHAT_MSG_SYSTEM")and(m.watchError)then
			if(string.find(C, m.watchError))then
				m.watchError = nil;
				m.inviteTimer = nil;
				t.duelStatus = nil;
				local e = t.catagoryScreen.frames[2];
				e.note3:SetText(C);
				e.okay1:Show();
				e.decline1:Hide();
				return;
			end
		end
		if(C == m.prefix)then
			local h, l, d, P, x, n, r;
			h, l, i, d, P, x, n = strsplit("+", i);
			local n = (D(A(l or(""))or(0)) == l);
			if(n ~= true)then
				if e.oldUsers[a]then
					return;
				else
					if h and(#h == 4)then
						return;
					else
						if(PeggleForeverData.settings.hideOutdated ~= true)then
							if(c(h, 1, 1) == "c")then
								print("|CFFFFDD00Peggle Forever: "..string.format(e.locale["_OUTDATED"], a, "Battle"));
							elseif(c(h, 1, 1) == "d")then
								print("|CFFFFDD00Peggle Forever: "..string.format(e.locale["_OUTDATED"], a, "Duel"));
							elseif(c(h, 1, 2) == "pl")then
								print("|CFFFFDD00Peggle Forever: "..string.format(e.locale["_OUTDATED"], a, "Peggle Loot"));
							end
						end
						e.oldUsers[a] = true;
						return;
					end
				end
			end
			local T = e.newInfo;
			local r = e.commands;
			local n = t.catagoryScreen.frames[2];
			local u;
			if l and(A(l)or 0) ~= e.ping then
				-- another protocol number cannot be read; a newer one in a ping/pong still means an update is out
				-- (the notice below this return could never be reached before)
				if((h == "ping")or(h == "pong"))and((A(l)or 0) > e.ping)then
					if not e.outdated then
						PeggleForeverData.outdated = A(l);
						e.outdated = true;
						e.outdatedPop:Show();
					end
					e.outdatedText:Show();
				end
				return;
			end
			h = h.."+"..l;
			if(h == r[8])then
				if l and((A(l)or(0)) > e.ping)then
					if not e.outdated then
						PeggleForeverData.outdated = A(l);
						e.outdated = true;
						e.outdatedPop:Show();
					end
					e.outdatedText:Show();
				end
				config.SendAddonMessage(C, r[9], "WHISPER", a);
				if(e.offlineList[a])then
					e.offlineList[a] = nil;
				end
				if(e.onlineList[a] ~= 2)then
					e.onlineList[a] = 2;
				end
				return;
			end
			if(h == r[9])then
				if i and((A(i)or(0)) > e.ping)then
					if not e.outdated then
						PeggleForeverData.outdated = A(i);
						e.outdated = true;
						e.outdatedPop:Show();
					end
					e.outdatedText:Show();
				end
				if(e.offlineList[a])then
					e.offlineList[a] = nil;
				end
				if(e.onlineList[a] ~= 2)then
					e.onlineList[a] = 2;
				end
				return;
			end
			local u = Y;
			local l, b;
			if(h == r[10])then
				for e = 1, #u do
					l = u[e];
					if(l.id == i)then
						if(l.serverName)then
							config.SendAddonMessage(C, r[12].."+"..i.."+"..l.serverName, "WHISPER", a);
							break;
						end
					end
				end
				return;
			end
			if(h == r[11])then
				for e = 1, #u do
					l = u[e];
					if(l.id == i)then
						l[T[14]] = true;
						break;
					end
				end
				return;
			end
			if(h == r[12])then
				for n = 1, #u do
					l = u[n];
					if(l.id == i)then
						l.serverName = d;
						if(d == e.name)then
							local e = t.network.server;
							local t;
							for n = 1, #e.tracking do
								if(l == e.tracking[n])then
									t = true;
									break;
								end
							end
							if not t then
								l[T[14]] = true;
								s(e.tracking, l);
								s(e.list, {{}, {}, {}, nil, nil});
								e:Populate(#e.list);
								if not e:IsShown()then
									e.currentID = #e.tracking;
									e.currentNode = 0;
								end
								e:Show();
							end
						else
							Me(nil, l);
							config.SendAddonMessage(C, r[11].."+"..i, "WHISPER", d);
						end
						break;
					end
				end
				return;
			end
			if(h == r[13])then
				for n = 1, #u do
					l = u[n];
					if(l.id == i)then
						d = l[g];
						for n = 1, #d, 200 do
							P = l[T[1]].."+d+"..c(d, n, xe(199 + n, #d));
							t.network:Send(e.commands[14], P, "WHISPER", a)
						end
						t.network:Send(e.commands[14], l[T[1]].."+e+", "WHISPER", a)
						break;
					end
				end
				return;
			end
			if(h == r[14])then
				local e = t.network.server;
				for t = 1, #u do
					l = u[t];
					if(l.id == i)and(e.list[e.currentID][4] == a)then
						if(d == "d")then
							e.list[e.currentID][5] = e.list[e.currentID][5]..P;
						elseif(d == "e")then
							local t = L(e.list[e.currentID][5], p(l[T[4]]));
							if t then
								e.list[e.currentID][5] = t;
								e.processing = 1;
								e.currentIndex = 0;
							end
						end
						break;
					end
				end
				return;
			end
			if(h == r[15])then
				for n = 1, #u do
					l = u[n];
					if(l.id == i)then
						local n = e.newInfo;
						if(d == "1")then
							l[n[4]] = P;
							l[n[5]] = gsub(x, "???", "+");
							l[n[2]] = {};
							l[n[3]] = {};
							l[g] = "";
						elseif((d == "2")or(d == "3"))then
							local e = e.temp;
							table.wipe(e);
							o.TablePack(e, strsplit(",", P));
							local t;
							local o = A(d);
							for t = 1, #e do
								s(l[n[o]], e[t]);
							end
						elseif(d == "4s")then
							l[g] = "";
							l.updating = true;
						elseif(d == "4e")then
							l.updating = nil;
						elseif(d == "4")then
							l[g] = l[g]..P;
							l.updating = true;
						elseif(d == "5")then
							l.updating = nil;
							l[n[6]] = true;
							table.sort(l[n[2]]);
							table.sort(l[n[3]]);
							l[n[7]] = S(c(l[g], 3 + 5, 3 + 6));
							config.SendAddonMessage(C, r[17].."+"..i, "WHISPER", a);
							config.SendAddonMessage(C, r[10].."+"..i, "WHISPER", a);
							t.challengeTimer.sElapsed = 180;
							t.challengeTimer.sChallPing = true;
							local e = t.catagoryScreen.frames[3];
							if(e:IsShown())then
								if(e.content1:IsShown())then
									if(e.content1.state ~= 1)then
										e.content1:Hide();
										e.content1:Show();
									else
										t.challengeTabSparks:Show();
									end
								else
									t.challengeTabSparks:Show();
								end
							else
								t.challengeTabSparks:Show();
							end
						end
						break;
					end
				end
				return;
			end
			if(h == r[16])then
				local e;
				for t = 1, #u do
					l = u[t];
					if(l.id == i)then
						e = true;
						config.SendAddonMessage(C, r[17].."+"..i, "WHISPER", a);
						break;
					end
				end
				if not e then
					s(u, {["id"] = i, ["elapsed"] = 60});
					config.SendAddonMessage(C, r[18].."+"..i, "WHISPER", a);
				end
				return;
			end
			if(h == r[17])then
				local e;
				for e = 1, #u do
					l = u[e];
					if(l.id == i)then
						o.TableRemove(l.namesWithoutChallenge, a);
						break;
					end
				end
				return;
			end
			if(h == r[18])then
				local e;
				for e = 1, #u do
					l = u[e];
					if(l.id == i)then
						J(a, l);
						break;
					end
				end
				return;
			end
			if(h == r[23])then
				for n = 1, #u do
					l = u[n];
					if(l.id == i)then
						if(string.lower(l.creator or "") == string.lower(a))then
							config.RemoveChallenge(l);
							print("|CFFFFDD00Peggle Forever: "..a.." cancelled a Battle you were invited to; it has been removed from your list.");
						end
						break;
					end
				end
				return;
			end
			if(h == r[19])then
				local n;
				for n = 1, #u do
					l = u[n];
					if(l.id == i)and(l.serverName == e.name)then
						local n = o.TableFind(l[T[2]], a);
						if(n)then
							d = L(d, p(a));
							if(d)then
								local r, s = ot(d, true);
								local o;
								local t = t.network.server;
								for o = 1, #t.list do
									if(t.tracking[o].id == i)then
										if(s > t.list[o][1][n])or(a == e.name)then
											t.list[o][1][n] = s;
											t.list[o][2][n] = r;
											local t = L(l[g], p(l.creator));
											t = U((c(t, 1, 68 + (n - 1) * 6)..d..c(t, 69 + n * 6)), p(l.creator));
											l[g] = t;
											if not l[T[14]]then
												for t = 1, #l[T[2]]do
													r = l[T[2]][t];
													if(e.onlineList[r] == 2)then
														J(r, l, true)
													end
												end
											end
										end
										break;
									end
								end
							end
							break;
						end
					end
				end
				return;
			end
			if(h == r[20])then
				x = L(x, p(a));
				if not e[T[11]]and(x)then
					e[T[11]] = i
					e[T[11].. 1] = d;
					e[T[11].. 2] = A(P);
					e[T[11].. 3] = x;
					e[T[11].. 4] = a;
					t.peggleLootTimer.remaining = 30;
					t.peggleLootTimer:Show();
					t.peggleLootDialog:Hide();
					t.peggleLootDialog:Show();
				end
			end
			if(h == r[21])then
				if e[T[11]]and(e[T[11]] == i)then
					local e = e[T[12]];
					if(e)then
						if not e[a]then
							if d and(d ~= "")then
								d = L(d, p(a))
								e[a] = S(d);
							else
								e[a] = -1;
							end
						end
					end
				end
			end
			local e = string.lower(a);
			local l = string.lower(n.name2:GetText());
			if(h == r[1])then
				if(PeggleForeverData.settings.inviteDecline == true)then
					config.SendAddonMessage(C, r[3], "WHISPER", a);
				else
					if(t.duelStatus)then
						config.SendAddonMessage(C, r[5], "WHISPER", a);
					else
						t.duelTab.sparks:Show();
						t.duelTimer.elapsed = 0;
						t.duelTimer.remaining = 300;
						t.duelTimer:Show()
						if(PeggleForeverData.settings.inviteMinimap == true)then
							t.minimap.notice = true;
						end
						if(PeggleForeverData.settings.inviteChat == true)then
							print("|CFFFFDD00Peggle Forever: "..string.format(n.name1.caption2, a));
							print("|CFFFFDD00Peggle Forever: Duel hero: "..config.MatchHeroName(x));
						end
						if(PeggleForeverData.settings.inviteRaid == true)then
							RaidNotice_AddMessage(RaidBossEmoteFrame, "Peggle Forever: "..string.format(n.name1.caption2, a), ChatTypeInfo["RAID_BOSS_EMOTE"])
						end
						config.SendAddonMessage(C, r[2], "WHISPER", a);
						n.name2:SetText(a);
						n.name2:DisableDrawLayer("BACKGROUND");
						n.name2:SetJustifyH("CENTER")
						n.name2:EnableMouse(false);
						n.name2:ClearFocus();
						n.nameDrop:Hide();
						local e = o.TableFind(PeggleForeverProfile.lastDuels, a)
						if not e then
							s(PeggleForeverProfile.lastDuels, 1, a);
							if(#PeggleForeverProfile.lastDuels > 10)then
								PeggleForeverProfile.lastDuels[11] = nil;
							end
						end
						n.note1:SetText(n.note1.caption3);
						n.note2a:SetText(d);
						n.note2a:Show();
						n.note2:Hide();
						n.note3:Show();
						n.note3:SetText(string.format(n.name1.caption2, a));
						n.note3Title:Show();
						n.winLoss:ClearAllPoints();
						n.winLoss:SetPoint("Topleft", n, "Bottomleft", 20, 190);
						n:UpdateDisplay(A(i));
						n.go:Hide();
						n.okay1:Hide();
						n.decline1:Hide();
						n.okay2:Show();
						n.decline2:Show();
						t.duelStatus = 2;
						n.levelInfo = L(P, p(a));
						n.duelHero = tonumber(x) or 0;
						if not n.levelInfo then
						end
						if(PeggleForeverData.settings.openDuel)then
							if not t:IsVisible()then
								t.minimap:GetScript("OnMouseUp")(t.minimap, "LeftButton");
							end
						end
						local e = t.catagoryScreen;
						if(e:IsShown())then
							t.duelTab.hover = true;
							Xe(t.duelTab)
							t.duelTab.hover = nil;
							t.levelList:Hide();
						end
					end
				end
			elseif(e == l)then
				if(t.duelStatus)then
					if(h == r[2])then
						m.inviteTimer = nil;
						m.watchError = nil;
						n.note3:SetText(n.note3.status2);
						t.duelStatus = 2;
						local e = o.TableFind(PeggleForeverProfile.lastDuels, a)
						if not e then
							s(PeggleForeverProfile.lastDuels, 1, a);
							if(#PeggleForeverProfile.lastDuels > 10)then
								PeggleForeverProfile.lastDuels[11] = nil;
							end
						end
					elseif(h == r[3])then
						if(t.duelStatus ~= 3)then
							m.inviteTimer = nil;
							m.watchError = nil;
							n.note1:SetText(n.note1.caption2);
							n.note3:SetText(n.note3.status3);
							t.duelStatus = nil;
							n.decline1:Hide();
							n.okay1:Show();
							t.duelTimer:Hide()
						end
					elseif(h == r[4])then
						n.duelInfo1:Hide();
						n.duelInfo2:Show();
						n.go:Show();
						n.okay1:Hide();
						n.okay2:Hide();
						n.decline1:Hide();
						n.decline2:Hide();
						n.name2:EnableDrawLayer("BACKGROUND");
						n.name2:SetJustifyH("LEFT");
						n.name2:EnableMouse(true);
						n.note1:SetText(n.note1.caption1);
						n.note2:Show();
						n.note2a:Hide();
						n.note3:Hide();
						n.note3Title:Hide();
						local e
						for e = 1, 6 do
							n.player1["value"..e] = 0;
							n.player2["value"..e] = 0;
						end
						n.player1.value = -1;
						n.player2.value = -1;
						Ae(n.showID, nil, n.levelInfo);
						R(true);
						Q = false;
						t.duelStatus = 3;
						n.decline2:Hide();
						n.okay2:Hide();
					elseif(h == r[5])then
						m.inviteTimer = nil;
						m.watchError = nil;
						n.note3:SetText(n.note3.status5);
						t.duelStatus = nil;
						n.decline1:Hide();
						n.okay1:Show();
						t.duelTimer:Hide()
					elseif(h == r[7])then
						if(t.duelStatus ~= 3)then
							m.inviteTimer = nil;
							m.watchError = nil;
							n.note1:SetText(n.note1.caption2);
							n.note3:SetText(n.note3.status6);
							t.duelStatus = nil;
							t.minimap.notice = nil;
							t.duelTab.sparks:Hide();
							n.decline1:Hide();
							n.decline2:Hide();
							n.okay1:Show();
							n.okay2:Hide();
							t.duelTimer:Hide()
						end
					end
				end
				if(h == r[6])then
					if(i == nil)then
						n.player2.value = -2;
					else
						i = L(i, p(a));
						if(i)then
							local e = S(c(i, 1, 2)) - 1;
							local t = f(e, 100);
							e = (e - t) / 100;
							if(e >= 30)then
								stageFullClears = e - 30;
								e = 2;
							else
								stageFullClears = e - 10;
								e = 1;
							end
							n.player2.value1 = S(c(i, 7, 10));
							n.player2.value2 = S(c(i, 11, 14));
							n.player2.value3 = S(c(i, 15, 18));
							n.player2.value4 = e;
							n.player2.value5 = t;
							n.player2.value6 = stageFullClears;
							n.player2.value = S(c(i, 3, 6));
						else
							n.player2.value = 0;
						end
					end
					n:UpdateWinners();
				end
			end
		end
	end);
	t.network = i;
	i = CreateFrame("Frame", "PeggleNetPing", UIParent);
	i:SetWidth(1);
	i:SetHeight(1);
	i:SetPoint("Top");
	i:Hide();
	i.tempList = {};
	i.prefix = e.addonName;
	i.elapsed = 0;
	i:SetScript("OnUpdate", function(t, n)
		local e = e.sentList;
		if t.lastIndex then
			if(t.lastIndex == -1)then
				t.lastIndex = next(e);
			else
				t.lastIndex = next(e, t.lastIndex);
			end
			if(t.lastIndex)then
				config.SendAddonMessage(t.prefix, t.command.."+"..t.data, "WHISPER", t.lastIndex);
				t.elapsed = 0;
			end
		end
		if(n > 1)then
			n = 1;
		end
		t.elapsed = t.elapsed + n;
		if(t.elapsed > 5)then
			t.elapsed = 0;
			t:Hide();
			if(t.state)then
				if(t.state == 0)then
					t.state = 1;
				elseif(t.state == 1)then
				end
				ne(t.state);
			end
		end
	end);
	t.network.pinger = i;
	i = CreateFrame("Frame", "PeggleNetServer", UIParent);
	i:SetWidth(1);
	i:SetHeight(1);
	i:SetPoint("Top");
	i:Hide();
	i.prefix = e.addonName;
	i.elapsed = 0;
	i.currentID = 1;
	i.currentNode = 0;
	i.currentIndex = 0;
	i.tracking = {};
	i.processing = nil;
	i.process = "";
	i.updated = nil;
	i.list = {}
	i:SetScript("OnUpdate", function(t, n)
		if not t.processing then
			if(n > 1)then
				n = 1;
			end
			t.elapsed = t.elapsed + n;
		end
		if(t.elapsed > 4)or(t.processing)then
			local n;
			local n = t.tracking[t.currentID];
			local a;
			local o = e.newInfo;
			local l = n[o[2]];
			local i = e.onlineList;
			local r = e.commands;
			local e = n[o[4]];
			if not t.processing then
				if(not n[o[14]])and(t.currentNode == 0)then
					t.currentID = t.currentID + 1;
					if(t.currentID > #t.tracking)then
						t.currentID = 1;
					end
					t.elapsed = 0;
					return;
				end
				if(t.currentNode == 0)and(n[o[14]])then
					n[o[14]] = nil;
				end
			end
			if(t.elapsed > 4)then
				t.elapsed = 0;
				for e = t.currentNode + 1, #l do
					if(i[l[e]] == 2)then
						t.currentNode = e;
						a = l[e];
						break;
					end
				end
				if(a)then
					t.list[t.currentID][4] = a;
					t.list[t.currentID][5] = "";
					config.SendAddonMessage(t.prefix, r[13].."+"..n[o[1]], "WHISPER", a);
				else
					t.processing = 2;
					t.currentIndex = 0;
					t.elapsed = 0;
				end
			elseif(t.processing == 1)then
				if(t.currentIndex < #l)then
					t.currentIndex = t.currentIndex + 1;
					local e, l, e, n;
					local o = t.list[t.currentID][5];
					local e = S(c(o, 68 + (t.currentIndex - 1) * 6 + 1, 68 + (t.currentIndex - 1) * 6 + 2));
					if(e > 1e3)then
						fullLevelClears = e;
						e = e - 1;
						l = f(e, 100);
						e = (e - l) / 100;
						if(e >= 30)then
							n = 1;
							e = e - 30;
						else
							n = 0;
							e = e - 10;
						end
						e = S(c(o, 68 + (t.currentIndex - 1) * 6 + 3, 68 + (t.currentIndex * 6)));
						if(t.list[t.currentID][1][t.currentIndex] < e)then
							t.list[t.currentID][1][t.currentIndex] = e;
							t.list[t.currentID][2][t.currentIndex] = n;
							t.list[t.currentID][3][t.currentIndex] = fullLevelClears;
							t.updated = true;
						end
					end
				else
					t.elapsed = 4;
					t.processing = nil;
					t.process = nil;
					if(t.updated)then
						t.updated = nil;
						local e = "";
						local a;
						for o = 1, #l do
							if(t.list[t.currentID][1][o] == 0)then
								e = e..c(n[g], 3 + 69 + (o - 1) * 6, 3 + 68 + (o * 6));
							else
								a = t.list[t.currentID][3][o]
								e = e..h(a, 2)..h(t.list[t.currentID][1][o], 4)
							end
						end
						n[g] = U(c(t.list[t.currentID][5], 1, 68)..e, p(n[o[4]]));
					else
					end
				end
			elseif(t.processing == 2)then
				for e = t.currentIndex + 1, #l do
					if(i[l[e]] == 2)then
						t.currentIndex = e;
						a = l[e];
						break;
					end
				end
				if(a)and(n[o[14]] == nil)then
					J(a, n, true)
				else
					t.processing = nil;
					t.currentNode = 0;
					t.currentIndex = 0;
					t.currentID = t.currentID + 1;
					if(t.currentID > #t.tracking)then
						t.currentID = 1;
					end
				end
			end
		end
	end);
	i.Populate = function(o, n)
		local e = o.tracking[n];
		local a = o.list[n];
		local r = e.names;
		local i = L(e[g], p(e.creator));
		local l, e, o, n;
		for t = 1, #r do
			e = S(c(i, 68 + (t - 1) * 6 + 1, 68 + (t - 1) * 6 + 2));
			if(e == 1e3)then
				l = 0;
				e = 1;
				o = 0;
				n = 0;
			else
				o = f(e, 100) - 1;
				e = (e - o + 1) / 100;
				if(e > 30)then
					n = e - 30;
					e = 1;
				else
					n = e - 10;
					e = 0;
				end
				l = S(c(i, 68 + (t - 1) * 6 + 3, 68 + (t * 6)));
			end
			a[1][t] = l;
			a[2][t] = e;
			a[3][t] = o + n * 100;
		end
	end
	t.network.server = i;
end
local function T()
	for t = 1, #e.commands do
		e.commands[t] = e.commands[t].."+"..e.ping;
	end
	q = 0;
	H = UnitName("player");
	e.name = H;
	g = h(1378301, 4);
	v = S(L("w3K`f", p(D(512))));
	ae = S(L("0Brao", p(D(256)))) / 10;
	ze = S(L(":N2b@", p(D(128)))) / 10;
	W();
	w();
	G();
	E();
	mt();
	_();
	b();
	K();
	fe();
	he();
	ce();
	y();
	k();
	N();
	-- /peggle shots: opens each page in turn (and the menu in all three appearances) and takes a real game
	-- screenshot of each with Screenshot(); they land in the client's Screenshots folder. For listing pages.
	config.TakeListingShots = function(only)
		if config.shotsRunning then
			return;
		end
		config.shotsRunning = true;
		local settings = PeggleForeverData.settings;
		local savedScheme, savedOn, savedOff = settings.colorScheme, settings.mouseOnTrans, settings.mouseOffTrans;
		settings.mouseOnTrans, settings.mouseOffTrans = 1, 1;
		t:Show();
		t:SetAlpha(1);
		local tabs = {t.catagoryScreen.tabFrame:GetChildren()};
		local function tab(i)
			return function()
				local f = tabs[i];
				if f then
					-- a tab only switches pages while the mouse is over it (hover); fake that, as the duel invite code does
					f.hover = true;
					f:GetScript("OnMouseDown")(f, "LeftButton");
					f:GetScript("OnMouseUp")(f, "LeftButton");
					f.hover = nil;
				end
			end
		end
		local function scheme(name)
			return function()
				settings.colorScheme = name;
				config.ApplySkin();
				if PeggleColorSchemeDropdown then -- the Options page shows the appearance in use
					UIDropDownMenu_SetText(PeggleColorSchemeDropdown, name);
				end
				tab(1)();
			end
		end
		local steps = {
			-- one Alliance (blue) shot, then everything else in Horde red
			{"quick play (Alliance)", scheme("Alliance")},
			{"quick play (Horde)", scheme("Horde")},
			{"duel", tab(2)}, {"battle", tab(3)}, {"talents", tab(4)}, {"how to play", tab(5)}, {"options", tab(6)},
			{"stats", function() config.ShowStats(); end},
			{"hero select", function() t.stats:Hide(); tab(1)(); if t.charScreen then t.charScreen:Show(); end end},
			{"level", function()
				if t.charScreen then t.charScreen:Hide(); end
				tab(1)();
				local go = _G.PeggleButton_quickPlayGo;
				if go then go:Click(); end
			end},
		};
		-- /peggle shots <word>: only the steps whose name contains the word (e.g. alliance, duel, stats)
		only = only and string.lower(only) or "";
		if only ~= "" then
			local keep = {};
			for _, s in ipairs(steps) do
				if string.find(string.lower(s[1]), only, 1, true) then
					keep[#keep + 1] = s;
				end
			end
			if #keep == 0 then
				print("|cFFFFDD00Peggle Forever:|r no screenshot named like '"..only.."'.");
				config.shotsRunning = nil;
				settings.mouseOnTrans, settings.mouseOffTrans = savedOn, savedOff;
				return;
			end
			steps = keep;
		end
		local i = 0;
		local function step()
			i = i + 1;
			local s = steps[i];
			if not s then
				R(false); -- back to the menu from the level
				settings.colorScheme, settings.mouseOnTrans, settings.mouseOffTrans = savedScheme, savedOn, savedOff;
				config.ApplySkin();
				if PeggleColorSchemeDropdown then
					UIDropDownMenu_SetText(PeggleColorSchemeDropdown, savedScheme or config.DefaultScheme());
				end
				tab(1)();
				config.shotsRunning = nil;
				print("|cFFFFDD00Peggle Forever:|r "..#steps.." screenshots saved to your World of Warcraft Screenshots folder.");
				return;
			end
			s[2]();
			C_Timer.After(1.2, function()
				t:SetAlpha(1);
				Screenshot();
				C_Timer.After(1.3, step);
			end);
		end
		print("|cFFFFDD00Peggle Forever:|r taking "..#steps.." screenshots, about "..(#steps * 3).." seconds. Rest the mouse on an empty part of the window (not on a tab or button).");
		local function start() -- wait for the opening splash screen to finish
			if t.legal then -- first-run notice still open: the splash waits for its OK
				print("|cFFFFDD00Peggle Forever:|r click OK on the notice first, then /peggle shots again.");
				config.shotsRunning = nil;
				settings.mouseOnTrans, settings.mouseOffTrans = savedOn, savedOff;
			elseif t.splash and t.splash:IsShown() then
				C_Timer.After(.5, start);
			elseif not t.catagoryScreen:IsShown() then -- a level, duel or Battle is being played: never end it
				print("|cFFFFDD00Peggle Forever:|r finish or leave the level first, then /peggle shots again.");
				config.shotsRunning = nil;
				settings.mouseOnTrans, settings.mouseOffTrans = savedOn, savedOff;
			else
				step();
			end
		end
		start();
	end
	-- developer and tuning commands, only with /peggle dev on
	config.devCommands = {atlas = true, btninfo = true, buttonbright = true, face = true, npc = true, portraits = true, qplayout = true, play = true, setsound = true};
	SLASH_PEGGLE1 = "/peggle";
	SLASH_PEGGLE2 = "/peg";
	SlashCmdList["PEGGLE"] = function(n)
		local o = n;
		local n = o;
		local l = string.find(n, " ");
		if(l)then
			n = string.sub(n, 1, l - 1);
			o = string.sub(o, l + 1);
		else
			o = "";
		end
		n = string.lower(n);
		if config.devCommands[n] and not PeggleForeverData.settings.devMode then
			print("Peggle Forever: /peggle "..n.." is a developer command; /peggle dev turns them on.");
			return;
		end
		if(n == "dev")then
			PeggleForeverData.settings.devMode = (not PeggleForeverData.settings.devMode) or nil;
			print("Peggle Forever: developer commands "..(PeggleForeverData.settings.devMode and "on" or "off")..".");
		elseif(n == "shots")then
			config.TakeListingShots(o);
		elseif(n == "resetwindow")then
			t:ClearAllPoints();
			t:SetPoint("Center");
			t:SetWidth(e.windowWidth);
			t:SetHeight(e.windowHeight);
		elseif(n == "stats")then
			config.ShowStats();
		elseif(n == "crestsound")then
			-- next sound for the crest that is showing (saved), and play it
			local faction = config.CrestFaction();
			if not faction then
				print("Peggle Forever: choose the Horde or Alliance appearance in Options to show a faction crest.");
			else
				local saved = PeggleForeverData.settings.crestSound or {v = 3};
				if saved.v ~= 3 then -- choices from before the Alliance list was reordered
					saved.Alliance, saved.v = nil, 3;
				end
				PeggleForeverData.settings.crestSound = saved;
				local list = config.crestSounds[faction];
				saved[faction] = (tonumber(o) and math.max(1, math.min(#list, tonumber(o)))) or ((saved[faction] or 1) % #list + 1);
				local entry = config.PlayCrestSound() or list[saved[faction]];
				print("Peggle Forever: "..faction.." crest sound "..saved[faction].."/"..#list..": "..entry[2].."  (/peggle crestsound for the next one)");
			end
		elseif(n == "crest")then
			local size, x, y = string.match(o, "^(%-?[%d%.]+)%s+(%-?[%d%.]+)%s+(%-?[%d%.]+)$");
			if size then
				PeggleForeverData.settings.crestLayout = {tonumber(size), tonumber(x), tonumber(y)};
				config.UpdateFactionCrest();
				print("Peggle Forever: faction crest size "..size..", offset "..x..", "..y);
			else
				print("Usage: /peggle crest <size> <x> <y>   (default 42 -12 15; y is negative to move down)");
			end
		elseif(n == "buttonbright")then
			local v = tonumber(o);
			if v then
				PeggleForeverData.settings.buttonLift = math.max(0, math.min(3, v));
				config.ApplyButtonSkin();
				print("Peggle Forever: Horde/Alliance button brightness set to "..PeggleForeverData.settings.buttonLift.." (1 = default, try 0.5 to 2)");
			else
				print("Usage: /peggle buttonbright <0-3>   (1 = default; higher is brighter)");
			end
		elseif(n == "npc")then
			-- /peggle npc 1 29611   (try another NPC's model for a hero; "reset" restores the default)
			local id, value = string.match(o, "^(%d+)%s+(%S+)$");
			id = tonumber(id);
			if id and config.heroes[id] then
				PeggleForeverData.settings.npcOverride = PeggleForeverData.settings.npcOverride or {};
				PeggleForeverData.settings.npcOverride[id] = tonumber(value);
				config.heroDisplay[id] = nil;
				print("Peggle Forever: "..config.heroes[id].name.." model NPC is now "..tostring(config.HeroNpc(config.heroes[id])).." (reopen the screen or /reload)");
			else
				print("Usage: /peggle npc <hero 1-8> <npcID | reset>");
			end
		elseif(n == "face")then
			local id, rad = string.match(o, "^(%d+)%s+(%-?[%d%.]+)$");
			id, rad = tonumber(id), tonumber(rad);
			if id and rad and config.heroes[id] then
				PeggleForeverData.settings.faceFix = PeggleForeverData.settings.faceFix or {};
				PeggleForeverData.settings.faceFix[id] = rad;
				print("Peggle Forever: "..config.heroes[id].name.." model facing set to "..rad.." (reopen the screen or /reload)");
			else
				print("Usage: /peggle face <hero 1-8> <radians, e.g. 1 or -1 or 3.14>");
			end
		elseif(n == "portraits")then
			config.ShowPortraitTest(string.lower(o));
		elseif(n == "sounds")then
			config.TestSounds();
		elseif(n == "btninfo")then
			-- what art does the panel button really use? (atlas name or file, and its texture coordinates)
			local btn = config.styledButtons[1];
			if not btn then
				print("Peggle Forever: no styled button yet.");
				return;
			end
			local nm = btn.GetName and btn:GetName();
			for _, key in ipairs({"Left", "Middle", "Right"}) do
				local tex = btn[key] or (nm and _G[nm..key]);
				if tex and type(tex) ~= "function" then
					local atlas = tex.GetAtlas and tex:GetAtlas();
					local path = tex.GetTexture and tex:GetTexture();
					local l, r, tp, bt = 0, 0, 0, 0;
					if tex.GetTexCoord then
						local ulx, uly, llx, lly, urx, ury, lrx, lry = tex:GetTexCoord();
						l, r, tp, bt = ulx or 0, urx or 0, uly or 0, lly or 0;
					end
					print("btn "..key..": atlas="..tostring(atlas).." file="..tostring(path).." coords "..string.format("%.4f %.4f %.4f %.4f", l, r, tp, bt));
					if atlas and C_Texture and C_Texture.GetAtlasInfo then
						local info = C_Texture.GetAtlasInfo(atlas);
						if info then
							print("   atlas file="..tostring(info.file or info.filename).." size "..tostring(info.width).."x"..tostring(info.height));
						end
					end
				end
			end
			for _, getter in ipairs({"GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture"}) do
				local tex = btn[getter] and btn[getter](btn);
				if tex then
					print(getter..": atlas="..tostring(tex.GetAtlas and tex:GetAtlas()).." file="..tostring(tex.GetTexture and tex:GetTexture()));
				end
			end
		elseif(n == "atlas")then
			-- /peggle atlas <text>: lists atlas names containing the text (e.g. "button", "blue")
			if C_Texture and C_Texture.GetAtlasElements then
				local found, shown = 0, 0;
				local want = string.lower(o or "");
				for _, name in ipairs(C_Texture.GetAtlasElements()) do
					if string.find(string.lower(name), want, 1, true) then
						found = found + 1;
						if shown < 40 then
							shown = shown + 1;
							print(name);
						end
					end
				end
				print("Peggle Forever: "..found.." atlas names match '"..want.."'"..(found > shown and " (first 40 shown)" or ""));
			else
				print("Peggle Forever: this client has no C_Texture.GetAtlasElements.");
			end
		elseif(n == "qplayout")then
			-- /peggle qplayout old | new: the original Quick Play layout, or the new one (default)
			local want = string.lower(o or "");
			if want == "old" or want == "new" then
				PeggleForeverData.settings.qpLayout = (want == "old") and "old" or nil;
				config.ApplyQuickPlayLayout();
				print("Peggle Forever: Quick Play layout set to "..want..".");
			else
				print("Usage: /peggle qplayout old | new");
			end
		elseif(n == "snd")then
			config.SndCommand(o);
		elseif(n == "play")then
			-- /peggle play kit:3170   /peggle play file:569947   /peggle play Sound\Spells\HeroicStrike.wav
			config.PlaySpec(o, "SFX");
		elseif(n == "setsound")then
			-- /peggle setsound ability 1 kit:3170   /peggle setsound voice 5 kit:5857   /peggle setsound voice 5 reset
			local kind, id, spec = string.match(o, "^(%a+)%s+(%d+)%s+(.+)$");
			id = tonumber(id);
			if(kind == "ability")then kind = "sound" end
			if(kind == "sound" or kind == "voice")and id and config.heroes[id] then
				local over = PeggleForeverData.settings.soundOverrides or {};
				PeggleForeverData.settings.soundOverrides = over;
				over[id] = over[id] or {};
				if spec == "reset" then
					over[id][kind] = nil;
					print("Peggle Forever: "..config.heroes[id].name.." "..kind.." reset to default.");
				else
					local num = tonumber(spec);
					over[id][kind] = num and ("kit:"..num) or spec;
					print("Peggle Forever: "..config.heroes[id].name.." "..kind.." set to "..over[id][kind]);
				end
			else
				print("Usage: /peggle setsound <ability|voice> <hero 1-8> <kit:ID | file:ID | path | reset>");
			end
		elseif(n == "boost")then
			local id, copies = string.match(o, "(%d+)%s+(%d+)");
			id, copies = tonumber(id), tonumber(copies);
			if id and copies and config.heroes[id] then
				PeggleForeverData.settings.soundBoost = PeggleForeverData.settings.soundBoost or {};
				PeggleForeverData.settings.soundBoost[id] = math.max(1, math.min(3, copies));
				print("Peggle Forever: "..config.heroes[id].name.." ability sound plays "..PeggleForeverData.settings.soundBoost[id].." time(s).");
			else
				print("Usage: /peggle boost <hero number 1-8> <1-3>   (see /peggle sounds)");
			end
		elseif(n == "help")or(n == "?")then
			print("|cFFFFDD00Peggle Forever commands:|r");
			for _, line in ipairs({
				"/peggle  (or /peg) - open or close the game",
				"/peggle stats - your stats and records",
				"/peggle about | credits - about the add-on and its credits",
				"/peggle resetwindow - put the window back in the middle of the screen",
				"/peggle sounds - play every hero's ability sound and a voice line",
				"/peggle snd hero <1-8> [voice|ability] - browse a hero's lines; n / p to step, use or add to keep one",
				"/peggle snd reset <voice|ability> <hero> - back to the default sounds",
				"/peggle boost <hero> <1-3> - make a quiet hero sound louder",
				"/peggle crest <size> <x> <y> - move the faction crest",
				"/peggle crestsound [n] - the sound the faction crest plays when double-clicked",
				"/peggle shots - screenshot every page (Screenshots folder)",
				"/peggleloot [item] - start a Peggle Loot round for your party or raid",
			})do
				print("   "..line);
			end
		elseif(n == "about")or(n == "credits")then
			t:Show();
			t.catagoryScreen.frames[6]:Hide();
			t[n]:Show();
		elseif(n == "achievement")then
			if(PeggleForeverData.exhibitA)then
				if(not AchievementFrame)then
					--AchievementFrame_LoadUI();
				end
				local e = t.achieve;
				e.elapsed = 0;
				e.state = nil;
				e:SetAlpha(0);
				e.id = 0;
				--e:SetScript("OnUpdate", AchievementAlertFrame_OnUpdate);
				e:UnregisterAllEvents();
				e:Show();
			end
		elseif(n ~= "")and not config.devCommands[n]then
			print("Peggle Forever: unknown command '"..n.."'. /peggle help lists them; /peggle alone opens the game.");
		else
			if(t:IsVisible())then
				t:Hide();
			else
				t:Show();
			end
		end
	end
	SLASH_PEGGLELOOT1 = "/peggleloot";
	SlashCmdList["PEGGLELOOT"] = function(l)
		if GetNumGroupMembers() == 0 then
			print("|CFFFFDD00Peggle Forever: You are not in a "..GROUP..".")
			return
		end
		l = strtrim(l);
		if not l or(l == "")then
			l = e.locale["_THE_ITEM"];
		end
			if(e[e.newInfo[11]])then
				print("|CFFFFDD00Peggle Forever: "..string.format(e.locale["_PEGGLELOOT_ISACTIVE"], ceil(t.peggleLootTimer.serverRemaining or math.max(0, t.peggleLootTimer.remaining or 0))));
				return;
			end
			if(de ~= true)then
				local e = getglobal("PeggleButton_menuAbandon");
				e:GetScript("OnClick")(e);
			end
			local c = string.format(e.locale["_PEGGLELOOT_NOTIFY"], l)
			local S = C(3 - 2, 5 + 7);
			Fe(S);
			local r = #B;
			local o = {};
			local a, n;
			local a = "";
			for e = 1, r do
				s(o, e);
			end
			for e = 1, 25 do
				n = C(1, #o);
				a = a..h(u(o, n), 2);
			end
			local s = (ae * 9) ^ 2;
			local d;
			local r;
			for e = 1, 2 do
				n = C(1, #o);
				d = nil;
				while(d == nil)do
					if(r)then
						if(((B[o[n]].x - B[o[r]].x) ^ 2) + ((B[o[n]].y - B[o[r]].y) ^ 2)) < s then
							if(#o > 0)then
								n = C(1, #o);
							end
						else
							d = true;
						end
					else
						r = n;
						d = true;
					end
				end
				a = a..h(u(o, n), 2);
			end
			n = C(1, #o);
			a = a..h(u(o, n), 2);
			a = U(a, p(e.name));
			local i = h(time() * 100 + i((p(e.name) % 100)), 7);
			e[e.newInfo[12]] = {};
			l = i.."+"..l.."+"..S.."+"..a
			a = nil;
			o = nil;
			collectgarbage();
			local o = e.newInfo;
			n = GetNumGroupMembers();
			t.peggleLootTimer.serverRemaining = 40;
			t.peggleLootTimer:Show();
			if IsInRaid() then -- (was n > 5: a raid of 5 or fewer only reached your own subgroup)
					SendChatMessage(c, "RAID")
				for n = 1, n do
					name = GetRaidRosterInfo(n);
					if(name)then
						t.network:Send(e.commands[20], l, "WHISPER", name);
					end
				end
			else
				SendChatMessage(c, "PARTY")
				t.network:Send(e.commands[20], l, "WHISPER", e.name);
				n = 4
				for n = 1, n do
					name = UnitName("party"..n);
					if(name)then
						t.network:Send(e.commands[20], l, "WHISPER", name);
					end
				end
			end
	end
	local l, l, n
	for t = 1, #e.polygon - 1 do
		for o = 1, #e.polygon[t]do
			n = i((o - 1) / 2) + 1
			if(n == e.polygonCorners[t][4])then
				if(f(o, 2) == 0)then
				end
			elseif(n == e.polygonCorners[t][3])then
				if(f(o, 2) == 0)then
				end
			end
		end
	end
	local n, n;
	for t = 1, #e.polygon do
		for n = 1, #e.polygon[t]do
			e.polygon[t][n] = e.polygon[t][n] * .85;
		end
	end
end
T();
