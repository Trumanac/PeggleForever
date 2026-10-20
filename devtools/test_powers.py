"""Triggers a green peg for every hero and reports what each power did.

    python devtools/test_powers.py [--shots]
"""
import sys

from scenarios import *  # noqa: F401,F403


def run(hero_id, shots=False):
    g = boot()
    cfg = g.M.config
    board = start_level(g, hero_id=hero_id)
    hero = cfg.GetHero(hero_id)
    greens = pegs(board, GREEN)
    total = len(pegs(board))
    peg = greens[0]
    before = hit_count(board)
    g.clear_errors()
    cfg.PowerHit(peg, 0)          # same path as a ball hitting the peg
    g.advance(0.5)
    after = hit_count(board)
    win = g.frame("PeggleWindow")
    label_shown = win.powerLabel.IsShown(win.powerLabel)
    label = win.powerLabel.text._text if label_shown else None
    errs = g.errors()
    if shots:
        g.screenshot(OUT + "/power_%d_%s.png" % (hero_id, hero.power))
    return {
        "hero": hero.name, "power": hero.power, "name": hero.powerName,
        "pegs": total, "hit_by_power": after - before - 1, "label": label, "errors": errs,
    }


def main():
    shots = "--shots" in sys.argv
    bad = 0
    for hid in range(1, 9):
        r = run(hid, shots)
        status = "ok" if not r["errors"] else "ERRORS"
        print("%-22s %-7s %-16s hits_from_power=%-3s label=%s [%s]" % (
            r["hero"], r["power"], r["name"], r["hit_by_power"], r["label"], status))
        for where, msg in r["errors"][:2]:
            bad += 1
            print("    ", where, msg.split("\n")[0])
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
