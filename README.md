# Peggle Forever

### The Peggle Institute has opened a branch in Azeroth... again!

**Peggle Forever** is an unofficial, free fan edition of the Peggle add-on for World of Warcraft.
It keeps the classic game working on modern and Classic clients and adds:

- **Heroes**: pick a Classic-era race leader (Bolvar, Magni, Tyrande, Gelbin Mekkatorque, Thrall, Sylvanas, Cairne, Vol'jin), each with their own signature ability, voice lines and ability sounds from the game itself.
- **Talent trees**: every hero has their own talent tree, earned by clearing levels, plus a shared Legacy tree for playing many heroes.
- **More levels**: levels 14-23 re-created from the desktop game *Peggle: World of Warcraft Edition*.
- **Duels and Battles**: challenge other Peggle Forever players. Pick the hero everyone plays as (or Standard, no hero); talents are off so it is fair. Battles can be cancelled or removed.
- **Appearance**: Original, Horde (red) or Alliance (blue) themes in Options.
- **Stats page**: lifetime stats and records, per hero and overall (Stats button on Quick Play, or `/peggle stats`).

Peggle Forever uses its own multiplayer channel, so it does not connect to the original Peggle add-on. The two cannot be enabled at the same time (they share window and command names); if both are enabled, Peggle Forever turns itself off and tells you.

## Install

Copy the `PeggleForever` folder into your `Interface/AddOns/` folder, then `/reload` or restart WoW.
Open it with the minimap button or `/peggle`.

## Commands

| Command | What it does |
|---|---|
| `/peggle` | Open or close the game |
| `/peggle help` | List these commands in game |
| `/peggle stats` | Your stats and records |
| `/peggle about`, `/peggle credits` | About and credits |
| `/peggle resetwindow` | Put the window back to its default size and place |
| `/peggle shots` | Take a screenshot of every page (saved to your Screenshots folder) |
| `/peggle sounds` | Play every hero's ability sound and a voice line |
| `/peggle snd hero <1-8> [voice\|ability]` | Browse a hero's real lines (with their words); `n` / `p` to step, `use` or `add` to choose your own |
| `/peggle snd reset <voice\|ability> <hero>` | Back to the default sounds |
| `/peggle boost <hero> <1-3>` | Make a quiet hero sound louder |
| `/peggle crest <size> <x> <y>` | Move the faction crest |
| `/peggle crestsound` | Choose the sound the faction crest plays when double-clicked |
| `/peggleloot [item]` | Start a Peggle Loot round for your party or raid |

## Credits and origin

This project is **not original work**. Peggle and the original add-on belong to PopCap Games (now part of
Electronic Arts); the fork lineage is adamz01h -> Ketho -> this project. See [NOTICE.md](NOTICE.md)
for the full credits, third-party licenses and legal notes.

Original add-on: https://www.popcap.com/wow (offline) · Ketho's maintained update: https://github.com/ketho-wow/wow_peggle

## Disclaimer

Peggle Forever is an unofficial, free, non-commercial fan project. It is not affiliated with or endorsed by PopCap, Electronic Arts or Blizzard Entertainment.
If you are a rights holder and would like something changed or removed, open an issue and it will be handled promptly.

(c) 2007, 2009 PopCap Games, Inc. All rights reserved. The
PopCap Logo and all other trademarks used herein that are listed
at www.popcap.com/trademarks are owned by PopCap Games, Inc. or
its licensors and may be registered in some countries.
