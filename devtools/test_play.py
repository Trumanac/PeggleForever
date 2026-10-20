"""Autoplay: fires real balls with real physics for each hero and reports errors.

    python devtools/test_play.py [hero_id ...] [--shots] [--shots-n N]
"""
import random
import sys

from scenarios import *  # noqa: F401,F403


def play(hero_id, max_shots=12, seed=1, shots=False):
    random.seed(seed)
    g = boot()
    cfg = g.M.config
    board = start_level(g, hero_id=hero_id)
    win = g.frame("PeggleWindow")
    container = win.gameBoardContainer
    child = container.GetScrollChild(container)
    l, b, w, h = [float(v) for v in container.GetRect(container)]
    g.clear_errors()
    start_pegs = len(pegs(board))
    fired = 0
    power_hits = 0
    for shot in range(max_shots):
        # aim somewhere in the middle of the board, then fire
        ax = l + w * random.uniform(0.15, 0.85)
        ay = b + h * random.uniform(0.2, 0.6)
        g.M.setMouse(ax, ay)
        g.advance(0.2)
        before = hit_count(board)
        g.M.setMouse(ax, ay)
        g.M.click(child, "LeftButton")
        fired += 1
        # let the ball play out (cap 25s of game time per shot)
        g.advance(25)
        if g.errors():
            break
    if shots:
        g.screenshot(OUT + "/play_%d.png" % hero_id)
    return {"hero": cfg.GetHero(hero_id).name, "fired": fired, "cleared": start_pegs - len(pegs(board)), "pegs": start_pegs, "errors": g.errors()}


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    ids = [int(a) for a in args] or list(range(1, 9))
    bad = 0
    for hid in ids:
        r = play(hid, shots="--shots" in sys.argv)
        print("%-22s shots=%-2d pegs cleared=%-3d/%d errors=%d" % (r["hero"], r["fired"], r["cleared"], r["pegs"], len(r["errors"])))
        for where, msg in r["errors"][:2]:
            bad += 1
            print("    ", where, msg.split("\n")[0])
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
