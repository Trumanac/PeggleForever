# Notices, credits and legal

## What this is

**Peggle Forever** is an **unofficial, free, non-commercial fan project**. It continues the
"Peggle" add-on for World of Warcraft that PopCap Games released free of charge in 2009, and adds
fan-made features (heroes, talent trees, extra levels, Classic/"Forever" client support).

It is **not made by, affiliated with, sponsored by or endorsed by PopCap Games, Electronic Arts or
Blizzard Entertainment.** Most of the game, art and audio is not ours; see the credits below.
It is provided free and always will be. No donations are requested in the add-on.

If you are a rights holder and want something changed or removed, please open an issue or contact
SuperBirdy and it will be handled promptly.

## Original work and ownership

- **Peggle** and the original add-on: (c) 2007, 2009 PopCap Games, Inc. All rights reserved.
  The PopCap logo and other trademarks are owned by PopCap Games, Inc. or its licensors.
  Original add-on: <https://www.popcap.com/wow> (no longer online). See `LICENSE` (unmodified original notice).
- **Peggle: World of Warcraft Edition** (desktop game): (c) PopCap Games, Inc. Levels 14-23 and their
  backgrounds in this add-on are re-creations of levels from that game, which is no longer sold or
  distributed by its publisher.
- **World of Warcraft**, the Warcraft names and characters used for the heroes (e.g. Highlord Bolvar Fordragon,
  Thrall, Sylvanas Windrunner), and the in-game icons referenced by path are (c) Blizzard Entertainment, Inc.
  Icons are loaded from the user's own WoW client; none are redistributed here.
- "Peggle", "PopCap" and "World of Warcraft" are trademarks of their respective owners and are used
  only to identify the games this fan project relates to.

## Fan-edition credits

- **SuperBirdy**: Peggle Forever (hero system, talent trees, new abilities, desktop level import, WoW Classic/"Forever" updates).
- **adamz01h**: original GitHub port of the PopCap add-on.
- **Ketho**: long-time maintainer of the unofficial "Peggle" update, which this project is forked from
  (<https://github.com/ketho-wow/wow_peggle>). Also credited in-game: Nimos, ZombieProtectionAgency, Andy1210, C0rn3j, chrisliebaer.
- **Original PopCap team** (in-game credits screen): Michael Fromwiller, T. Carl Kwoh, Tysen Henderson,
  Noah Maas, Stephen Notley, Ed Miller, Eric Olson and everyone listed under "Special Thanks" and "Peggle Credits".

## Third-party libraries (in `Libs/`)

| Library | Notes |
|---|---|
| LibStub | Public domain (per its own header). |
| CallbackHandler-1.0 | Standard WowAce library, written by Nevcairiel/Ace3 team. |
| LibDataBroker-1.1 | By Tekkub and contributors. |
| LibDBIcon-1.0 | By Rabbit and contributors. |

These are the standard embeddable libraries published on WowAce/CurseForge, included unmodified.
Their authors keep all credit and rights. Their source files do not carry full license texts;
see each project's WowAce/CurseForge page for the authoritative terms.

## Lua and LuaSrcDiet

Original add-on code was processed with LuaSrcDiet and includes notices for:

- **Lua** (c) 1994-2008 Lua.org, PUC-Rio, and **LuaSrcDiet** (c) 2005-2008 Kein-Hong Man, both under the MIT license.
  The full MIT text is reproduced in `LICENSE`.

## Warranty

This add-on is provided "as is", without warranty of any kind. See `LICENSE` for the full disclaimer.

## Hero voices and ability sounds

Hero voice lines and spell sounds are played by file ID from the player's own WoW client
((c) Blizzard Entertainment); no Blizzard audio is bundled. `SoundList.lua` lists those IDs with
the file names (from the community WoW listfile, <https://github.com/wowdev/wow-listfile>) and short
machine-made transcripts of the lines, so players can browse them with `/peggle snd`.

## Fonts

The add-on uses the fonts that ship with World of Warcraft (Friz Quadrata and Morpheus, (c) Blizzard Entertainment). No font files are bundled.

## Alliance button art

The blue Alliance panel-button textures (`images/btn_B_up.tga`, `btn_B_down.tga`, `btn_B_hl.tga`) come from
**Blue Buttons** by **darkenscale** (version 1.1.3, 2010), a free WoWInterface download that recolours Blizzard's
stock panel buttons: <https://www.wowinterface.com/downloads/info14975-BlueButtons.html>. The download page states no
license; the textures are used here with credit to darkenscale, converted to TGA. The underlying button design is
Blizzard Entertainment's. The original download is not redistributed here. If the author asks for
them to be removed or credited differently, that will be done.
