"""Build SoundList.lua: real voice lines and ability sounds for each hero, as FileDataIDs.

    python devtools/casc_files.py                       # once per client patch: what the client really has
    python devtools/sound_candidates.py <listfile.csv>  # community-listfile.csv from
        https://github.com/wowdev/wow-listfile/releases/latest/download/community-listfile.csv

Names come from the community listfile; only files present in the Forever client (casc_files.py output)
are kept, so every ID plays in game. In game: /peggle snd hero <1-8> [voice|ability], then n / p / use.
"""
import glob, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
PRESENT = os.path.join(HERE, "out", "wow_classic_beta_files.txt")
OUT = os.path.join(HERE, "..", "SoundList.lua")

# hero id -> (voice folder pattern, ability file-name pattern)
HEROES = {
    1: ("bolvar", r"heroicstrike|battleshout"),
    2: ("magni", r"earthshield|earthshock|stoneform"),
    3: ("tyrande", r"starfall|starfire|moonfire"),
    4: ("mekkatorque", r"dynamite|grenade"),
    5: ("thrall", r"chainlightning|lightningbolt"),
    6: ("sylvanas", r"blackarrow"),
    7: ("cairne", r"thunderclap|warstomp|stomp_impact"),
    8: ("voljin", r"hex_frog|^hex|^curse|shadowcast|precastshadowmagic|agony|shadow_fear|^fear$"),  # classic Hex of Weakness = shadowcast + curse
}
# voice categories in the order they are listed; "greet" lines are what the hero says when chosen
CATEGORIES = [
    ("greet", r"greet|hello"),
    ("farewell", r"farewell|goodbye|bye"),
    ("pissed", r"pissed"),
    ("aggro", r"aggro"),
    ("shout", r"battleshout|battlecry"),
    ("alert", r"alert|intro"),
]
# hand-picked lines (heard / transcribed) that become the hero's default pool, ahead of "greet"
PICKS = {
    1: [545248,   # Never! I will never serve you!  (Icecrown, Wrath)
        3698912,  # Fight for Azeroth!
        4093156,  # For Azeroth!
        3698920,  # We stand together against the darkness.
        3698917,  # We will face whatever comes.
        3698921,  # There is much to be done.
        3698922,  # We all have a duty to fulfill.
        3698919,  # I will aid you as best I can.
        3698918,  # What news?
        4324152], # We will finish this.
    2: [553258,   # Strength, honor. I see them in you. Why have you come?
        553256,   # What brings you to Ironforge?
        553257,   # How can the dwarves help you?
        553259,   # What do you seek within the mountain?
        553254,   # For Khaz Modan!
        553255,   # Feel the fury of the mountain!
        5715297,  # We must forge ahead!
        5715296,  # Champion! Good to see you!
        5715293,  # I'm ready for anything!
        5715300,  # Who knows what we'll find deep in the earth!
        5715478,  # Always more work to be done.
        5715480], # Sometimes destiny whispers, sometimes she shouts.
    3: [562979,   # Ishnu-alah, may Elune light your path.
        562966,   # The goddess is my shield.
        562974,   # Elune give me strength.
        562969,   # I heed the voice of Elune.
        562973,   # My heart sleeps in the Emerald Dream.
        562968,   # This is our final stand. Make every blow count!
        562971,   # Give every ounce of strength, do not despair!
        5327758,  # I know we have the strength to face anything.
        5351438], # Elune-adore.
    4: [551919,   # Why hello there, how can I help you?
        551923,   # Necessity is the first cousin of invention.
        551924,   # I just love to tinker.
        551920,   # Welcome, friend!
        3192654,  # There's always time to tinker.
        3192652,  # Remember, safety first!
        3192653,  # Never reject an idea out of hand!
        3192655,  # When in doubt, plan it out!
        3192656,  # Perseverance is the true blueprint to success!
        3192657,  # For Gnomeregan!
        3192659,  # Well, fancy seeing you here!
        2443179,  # Time to unveil one of my latest inventions!
        2443173], # I've calculated your odds of survival. They are not in your favor!
    5: [562185,   # Lok'tar, friend. What is it you wish?
        562242,   # Welcome to Orgrimmar. Have you come to serve the Horde?
        1057964,  # For the Horde!
        1057965,  # Fight with honor.
        1057963,  # Our spirit will triumph.
        1057966,  # We will not be broken.
        1057969,  # Lok'tar ogar, champion.
        562233,   # For Doomhammer!
        562256,   # I'll never be chained again!
        562263,   # From this day on, I will rise to any challenge.
        562272],  # I will fight to the last.
    6: [561297,   # We are the Forsaken. We will slaughter anyone who stands in our way.
        561327,   # What are we if not slaves to this torment?
        561346,   # What joy is there in this curse?
        561301,   # I have no time for games.
        561350,   # The Dark Lady watches over you. Make haste.
        561280,   # May my aim be true.
        561322,   # Let none survive.
        897336,   # I will not fall. Not here, not now.
        1248858,  # One shot, one kill.
        1248860,  # Too easy.
        1245013,  # No. The Forsaken will never stop fighting.
        1801004,  # Greetings, champion.
        1801007], # Serve me well, and you will be rewarded.
    7: [545807,   # Take heart, young one. The Earth Mother is near.
        545805,   # Ishne-alo por-ah! May the Earth Mother smile upon you.
        545808,   # I am Cairne, Chief of the Bloodhoof tauren.
        545806,   # We tauren have always held a great respect for the works of the Earth Mother.
        2911901,  # Our way seeks not destruction, but harmony.
        2911905], # Remember always that the Earth Mother watches over you.
    8: [563872,   # Spirits be with you, stranger. How may I help?
        563884,   # You come to consult the spirits?
        563824,   # How can old Vol'jin help you?
        563830,   # For the Darkspear tribe!
        773857,   # The spirits be restless.
        773861,   # These be dark times.
        773863,   # The Darkspear never gonna give up!
        903193,   # Heh, Darkspear never die.
        773793,   # Spirits be with ya!
        851792],  # For the Horde.
}
SKIP = r"wound|death|attack|choking"  # grunts and pain sounds, not lines
EXTRA_LINES = 60  # other voiced lines (quests, events) kept per hero


def main():
    listfile = sys.argv[1]
    present = set(open(PRESENT).read().split())
    text = {}  # FileDataID -> spoken words, from devtools/transcripts/*.tsv (transcribe.py)
    for tsv in glob.glob(os.path.join(HERE, "transcripts", "*.tsv")):
        for row in open(tsv, encoding="utf-8"):
            cols = row.rstrip("\n").split("\t")
            if len(cols) == 3 and cols[2]:
                text[int(cols[0])] = cols[2]
    voice = {h: {c: [] for c, _ in [("pick", "")] + CATEGORIES + [("line", "")]} for h in HEROES}
    ability = {h: [] for h in HEROES}
    for line in open(listfile, encoding="utf-8"):
        fid, path = line.rstrip("\n").split(";", 1)
        if fid not in present or not path.startswith("sound/"):
            continue
        parts = path.split("/")
        name = parts[-1].rsplit(".", 1)[0]
        for h, (folder, abil) in HEROES.items():
            if parts[1] == "creature" and folder in parts[2]:
                if re.search(SKIP, parts[-1]):
                    continue
                if int(fid) in PICKS.get(h, []):
                    voice[h]["pick"].append((int(fid), name))
                    continue
                for cat, pat in CATEGORIES:
                    if re.search(pat, name):
                        voice[h][cat].append((int(fid), name))
                        break
                else:
                    if name.startswith("vo_") or name.endswith("_m"):
                        voice[h]["line"].append((int(fid), name))
            elif parts[1] in ("spells", "spell") and re.search(abil, name) and "creature" not in path:
                ability[h].append((int(fid), name))
    # Two tables: config.soundList (always loaded, only what the game plays: picked lines, greetings, shouts
    # and the ability sounds) and the full list for /peggle snd, kept as Lua source text and only turned
    # into tables on first use (about 1 MB of tables otherwise).
    PLAYED = ("pick", "greet", "shout")
    small, full = [], []
    for h in HEROES:
        for dest in (small, full):
            dest.append("\t[%d] = {" % h)
            dest.append("\t\tvoice = {")
        for cat, _ in [("pick", "")] + CATEGORIES + [("line", "")]:
            items = sorted(voice[h][cat], key=lambda x: x[1])
            if cat == "pick":
                items = sorted(voice[h][cat], key=lambda x: PICKS[h].index(x[0]))
            if cat == "line" and not any(f in text for f, _ in items):  # transcribed heroes keep every line
                items = items[:EXTRA_LINES]
            for fid, name in items:
                words = (", " + json.dumps(text[fid], ensure_ascii=False)) if fid in text else ""
                row = '\t\t\t{%d, "%s", "%s"%s},' % (fid, cat, name, words)
                full.append(row)
                if cat in PLAYED:
                    small.append(row)
        for dest in (small, full):
            dest.append("\t\t},")
            dest.append("\t\tsound = {")
        for fid, name in sorted(ability[h], key=lambda x: x[1]):
            for dest in (small, full):
                dest.append('\t\t\t{%d, "ability", "%s"},' % (fid, name))
        for dest in (small, full):
            dest.append("\t\t},")
            dest.append("\t},")
        counts = {c: len(v) for c, v in voice[h].items()}
        print(h, HEROES[h][0], counts, "ability", len(ability[h]))
    body = "\n".join(full)
    level = "=="
    while ("]" + level + "]") in body:
        level += "="
    out = ["-- Generated by devtools/sound_candidates.py: real hero voice lines and ability sounds (FileDataIDs)",
           "-- found in the community listfile and present in the Forever 1.60 client. Do not edit by hand.",
           "-- Entries: {FileDataID, category, file name, spoken words (machine transcribed, if known)}.",
           "-- In game: /peggle snd hero <1-8> [voice|ability], then n / p / use.",
           "local AddOn, config = ...", "",
           "-- what the game plays (hand-picked lines, greetings, ability sounds)",
           "config.soundList = {"] + small + ["}", "",
           "-- every line found, for /peggle snd; parsed on first use by config.SoundListFull()",
           "config.soundListSource = [%s[{\n%s\n}]%s]" % (level, body, level)]
    open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
