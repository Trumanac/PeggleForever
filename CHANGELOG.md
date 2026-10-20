# Peggle Forever (fan edition of Peggle by PopCap)

## 1.0.0-dev
Fan edition of the unofficial Peggle update (Ketho, 2.4.2). See NOTICE.md for credits.

- Added heroes (8 Classic races), per-hero talent trees, new abilities and levels 14-23.
- Hero roster uses Highlord Bolvar Fordragon (Human) and Gelbin Mekkatorque, with the game client's own hero portraits and ability sounds.
- Added a Stats page (lifetime and per-hero stats, records); page headings now follow the colour scheme (blue, Horde red, darker Alliance blue).
- Rebalanced heroes, powers and talents; Heroic Strike reworked.
- Restored the About and Credits buttons; added the fan-project disclaimer and a Peggle Forever credit.
- Added NOTICE.md; updated the README; removed another author's CurseForge/WoWInterface/Wago IDs from the TOC.
- The minimap icon blinks again for a duel invite (Options: Mini-map Icon Alert) and its tooltip says how to use it.
- Added `/peggle help`; chat messages now say "Peggle Forever:".
- Peggle Loot: rounds are no longer counted in Stats (they ended your win streak); a player who clicks Go but never shoots is listed as declined; a ball still flying when time runs out is now stopped and scored (this never worked); the results can no longer repeat in chat if something goes wrong; chat text says Peggle Forever.
- Hero voice at level start is now the match hero's in duels and Battles, and silent in no-hero rounds (Standard, Peggle Loot).
- `/peggle shots` no longer ends a level in progress (it asks you to finish or leave it first).
- Multiplayer: Peggle Forever uses its own addon-message prefix and protocol number, so it no longer connects to the original Peggle addon (and the original no longer sees our invites).
- Duels and challenges are fair: both players play with their hero's base power and no talents (hero or Legacy).
- New loopback tests for duels and challenges (devtools/test_duel.py, test_battle.py).
- Duels and Battles: choose the hero everyone plays as (or Standard, no hero); Battles can be removed from your list, or cancelled by their creator (everyone invited is told).
- The appearance starts as your character's faction (Alliance blue, Horde red) until you choose one in Options; your choice is saved.
- Escape closes the window from the menu (never during a level); the window can no longer be dragged off the screen.
- Developer/tuning commands are hidden behind `/peggle dev`; `/peggle shots` takes screenshots of every page for listings.
- The full hero voice list loads only when `/peggle snd` is used (about 0.7 MB less memory at login).
- Fixed: the "auto open on death" option never worked (it read a misspelled setting).
- Fixed: the first `/peggle crestsound` as Alliance raised a Lua error.
- Fixed: the add-on leaked many stray global variables (`tex`, `text`, `j`, `obj`, Blizzard's talent texture tables, ...) that could clash with Blizzard's UI or other add-ons; they are now private to the add-on.
- A new player starts as the hero of their character's race (other races, such as Skyborne: a hero of their own faction, picked per character) until they choose one; the choice is saved.
- Saves renamed to PeggleForeverData / PeggleForeverProfile (moved automatically) and the minimap icon renamed, so they no longer clash with the original Peggle add-on. If the original Peggle is enabled too, Peggle Forever turns itself off and says why.
- Green pegs play only the hero's own ability sound (Peggle's power-up sound no longer plays on top; Standard keeps Peggle's guide sound).
- Easter egg: double-click the faction crest for a Horde war drum / Alliance horn call (`/peggle crestsound` picks another).
- The Duel / Battle hero choice shows each hero's race (darker text) and faction crest, e.g. "Bolvar (Human)" with the Alliance crest.
- How to Play updated for duels, Battles and the new features; new Stats & Options topic.
- Hero sounds are now real game files: each hero greets you with one of their own city greetings (Bolvar, who has none: hand-picked lines such as "Never! I will never serve you!" and "For Azeroth!") and the ability sounds use the real spell files. New SoundList.lua lists every voice line and spell sound found for each hero; `/peggle snd hero <1-8> [voice|ability]` steps through them, `use` / `add` keeps one.
- Fixed the scroll bar thumb only appearing on mouse-over.
- Battle tab: Credits sword on the Battle list, a Back to Battles button on the New Battle page, and the active Battle limit raised from 5 to 10.
- Fixed: the "a newer version is out" notice could never appear (messages with another protocol number were dropped before it was checked).
- Fixed: Peggle Loot in a raid of 5 or fewer only reached your own subgroup and posted the results to party chat.
- The Brag / duel result chat messages and the out-of-date notice say Peggle Forever and no longer link to the original add-on's CurseForge page.
- `/peggle` with an unknown word now says so (it used to open or close the window).
- Made for WoW Forever only: the TOC lists just the Forever client (interface 16001), the retail / Classic Era code paths were removed, and if the add-on is forced on in another client it says in chat that the client is not supported.

---

## Previous history (Peggle (Unofficial) by Ketho)

## [2.4.2](https://github.com/ketho-wow/wow_peggle/tree/2.4.2) (2026-02-08)
[Full Changelog](https://github.com/ketho-wow/wow_peggle/compare/2.4.1...2.4.2) [Previous Releases](https://github.com/ketho-wow/wow_peggle/releases)

- Update for 12.0.0 and BCC anniversary  
- Update libs
