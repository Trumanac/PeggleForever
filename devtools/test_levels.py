"""Every level loads and can be played: pegs are in bounds, 25+ pegs exist, shots run without Lua errors.
    python devtools/test_levels.py [level ...]
"""
import random
import sys

from scenarios import *  # noqa: F401,F403


def check(name, ok, info=""):
    print(("PASS " if ok else "FAIL ") + name + (" " + str(info) if info else ""))
    return ok


def play_level(level, shots=4, seed=3):
    random.seed(seed)
    g = boot()
    pick_hero(g, 5)
    w = g.frame("PeggleWindow")
    open_window(g)
    w.splash.Hide(w.splash)
    g.click(w.catagoryScreen.tabFrame._children[1])
    g.advance(0.2)
    qp = w.catagoryScreen.frames[1]
    qp.showID = level
    qp.UpdateDisplay(qp, level)
    g.click(g.frame("PeggleButton_quickPlayGo"))
    g.advance(1.0)
    board = g.M.config.getBoard()
    ps = pegs(board)
    cfg = g.M.config
    inb = all(-5 <= float(p.x) <= 560 and -5 <= float(p.y) <= 470 for p in ps)
    orange = len(pegs(board, 2))
    container = w.gameBoardContainer
    child = container.GetScrollChild(container)
    l, b, ww, hh = [float(v) for v in container.GetRect(container)]
    g.clear_errors()
    for _ in range(shots):
        ax = l + ww * random.uniform(0.15, 0.85)
        ay = b + hh * random.uniform(0.2, 0.6)
        g.M.setMouse(ax, ay)
        g.advance(0.2)
        g.M.click(child, "LeftButton")
        g.advance(20)
    return len(ps), orange, inb, g.errors(), len(ps) - len(pegs(board))


def test_movement():
    """Imported moving pegs and bricks really move, and stay on the board while they do."""
    for lv in (17, 18, 20, 21, 22, 23):
        g = boot()
        pick_hero(g, 5)
        w = g.frame("PeggleWindow")
        open_window(g)
        w.splash.Hide(w.splash)
        g.click(w.catagoryScreen.tabFrame._children[1])
        g.advance(0.2)
        qp = w.catagoryScreen.frames[1]
        qp.showID = lv
        qp.UpdateDisplay(qp, lv)
        g.click(g.frame("PeggleButton_quickPlayGo"))
        g.advance(0.5)
        board = g.M.config.getBoard()
        movers = [p for p in pegs(board) if p.moveType and int(p.moveType) > 0]
        start = [(float(p.x), float(p.y)) for p in movers]
        worst = 0
        moved = 0
        for _ in range(12):
            g.advance(0.5)
            for p, (x0, y0) in zip(movers, start):
                if not (0 <= float(p.x) <= 554 and 0 <= float(p.y) <= 464):
                    worst += 1
                if abs(float(p.x) - x0) + abs(float(p.y) - y0) > 3:
                    moved += 1
        check("level %d: %d moving objects move and stay on the board" % (lv, len(movers)), len(movers) > 0 and moved > 0 and worst == 0 and not g.errors(),
              "moved=%d off-board=%d %s" % (moved, worst, g.errors()[:1]))


def main():
    test_movement()
    levels = [int(a) for a in sys.argv[1:]] or list(range(14, 24))
    bad = 0
    for lv in levels:
        n, orange, inb, errs, cleared = play_level(lv)
        ok = check("level %d plays" % lv, n >= 30 and orange >= 20 and inb and not errs and cleared > 0,
                   "pegs=%d orange=%d in-bounds=%s cleared=%d errors=%s" % (n, orange, inb, cleared, errs[:1]))
        bad += 0 if ok else 1
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
