# devtools – run PeggleForever without starting WoW

`wowmock.lua` is a fake WoW UI API; `run.py` loads the real addon files into it with
[lupa](https://pypi.org/project/lupa/) (Lua 5.1), fires the login events, lets you click through
the UI and renders screenshots with Pillow using the addon's real art. Needs: `pip install lupa pillow`.

    python devtools/run.py boot                  # load + login, print any Lua errors
    python devtools/run.py shot devtools/out/a.png
    python devtools/test_powers.py [--shots]     # trigger a green peg for every hero
    python devtools/test_play.py [ids] [--shots] # autoplay real balls, report errors
    python devtools/test_duel.py                 # two addon copies duel each other (loopback addon messages)
    python devtools/test_battle.py               # two addon copies share and play a Battle challenge
    python devtools/test_loot.py                 # /peggleloot in a two-player party: play, decline, ignore, idle, late shot
    python devtools/check_globals.py             # fails if the add-on leaks a global variable (a missing `local`)
    python devtools/make_logo.py                 # listing logos/banner from the splash art -> branding/
    python devtools/package.py [--check]         # release checks + devtools/dist/PeggleForever-<version>.zip
    python devtools/casc_files.py                # list the FileDataIDs the Forever client really has (reads Data/, read-only)
    python devtools/sound_candidates.py <community-listfile.csv>   # rebuild SoundList.lua (hero voice lines and spell sounds)

Sound IDs: `casc_files.py` reads the local CASC storage (build config, encoding, root, .idx) and
writes `out/wow_classic_beta_files.txt`; `sound_candidates.py` matches that against the community
listfile (https://github.com/wowdev/wow-listfile/releases/latest/download/community-listfile.csv)
by folder and file name. Rerun both after a client patch.
`transcribe.py <listfile.csv> <hero folder>` (needs `pip install faster-whisper` and ffmpeg) extracts a
hero's voice files and writes what each says to `transcripts/<hero>.tsv`; sound_candidates.py then puts
the words in SoundList.lua (shown by `/peggle snd`). Hand-picked default lines go in its `PICKS` table.

In Python (see `scenarios.py`): `g = boot(); start_level(g, hero_id=5); g.screenshot("x.png")`,
`g.click(frame)`, `g.advance(seconds)`, `g.M.findByText("Choose Hero", True)`, `g.errors()`.

Screenshots land in `devtools/out/`. Limits: built-in Blizzard art (spell icons, fonts) is not on
disk, so those show as coloured placeholder squares; glow/particle effects are approximate; the
mock only implements what the addon uses (unknown methods are listed by `report()`), so a pass here
does not guarantee the real client has the same API. WoW ignores this folder (no TOC entry).
