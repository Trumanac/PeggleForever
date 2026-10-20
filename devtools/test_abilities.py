"""Timeline checks for the redesigned hero abilities (delayed bombs, ripples, chains, hex links).

    python devtools/test_abilities.py [--shots]
"""
import random
import sys

from scenarios import *  # noqa: F401,F403

FAILS = []


def check(name, ok, detail=""):
    print("%-4s %s %s" % ("PASS" if ok else "FAIL", name, detail))
    if not ok:
        FAILS.append(name)


def timeline(hero_id, times, shots=False, seed=3):
    random.seed(seed)
    g = boot()
    cfg = g.M.config
    board = start_level(g, hero_id=hero_id)
    greens = pegs(board, GREEN)
    g.clear_errors()
    cfg.PowerHit(greens[0], 0)
    counts, elapsed = [], 0.0
    base = hit_count(board)
    for t in times:
        g.advance(t - elapsed)
        elapsed = t
        counts.append(hit_count(board) - base)
        if shots:
            g.screenshot(OUT + "/ability_%d_%03d.png" % (hero_id, int(t * 100)))
    return counts, g


def main():
    shots = "--shots" in sys.argv
    # (hero, name, times, predicate on counts)
    cases = [
        (4, "Thorium Grenade: nothing at t=0.2, detonates later", [0.2, 0.7, 1.4], lambda c: c[0] <= 1 and c[2] >= 8),
        (7, "War Stomp: ripples (more pegs over time)", [0.1, 0.4, 1.2], lambda c: c[2] >= 8 and c[0] < c[2]),
        (5, "Chain Lightning: hops arrive over time", [0.15, 0.4, 1.0], lambda c: c[2] >= 3 and c[0] < c[2]),
        (3, "Starfall: shower lands over time", [0.2, 0.6, 1.5], lambda c: c[2] >= 4 and c[0] < c[2]),  # Balance.stars.count = 4
    ]
    for hid, name, times, ok in cases:
        counts, g = timeline(hid, times, shots)
        check(name, ok(counts) and not g.errors(), "pegs hit at %s = %s %s" % (times, counts, g.errors()[:1]))

    # Hex: curse 4 pegs; hitting one detonates the rest.
    g = boot()
    cfg = g.M.config
    board = start_level(g, hero_id=8)
    st = cfg.getState()
    g.clear_errors()
    cfg.PowerHit(pegs(board, GREEN)[0], 0)
    cursed = [p for p in pegs(board) if p.hexed]
    check("hex curses 5 pegs", len(cursed) == 5, "cursed=%d" % len(cursed))
    before = hit_count(board)
    cfg.PowerHit(cursed[0], 0)
    g.advance(1.5)
    cursed_hit = sum(1 for p in cursed if p.hit)
    check("hitting one cursed peg detonates all cursed pegs", cursed_hit == 5 and not any(p.hexed for p in cursed),
          "cursed pegs hit=%d" % cursed_hit)
    check("hex no lua errors", not g.errors(), str(g.errors()[:1]))
    if shots:
        g.screenshot(OUT + "/ability_8_after.png")

    # Restarting the level must drop pending timers / marks.
    board = start_level(g, hero_id=8)
    check("level restart clears pending effects", len(cfg.FX.timers) == 0 and len(st.hexList) == 0)
    sys.exit(1 if FAILS else 0)


if __name__ == "__main__":
    main()
