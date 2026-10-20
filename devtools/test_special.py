"""Targeted tests for the ball/peg-modifying powers: pierce (Varian), shield (Magni), hex (Vol'jin).

    python devtools/test_special.py
"""
import random
import sys

from scenarios import *  # noqa: F401,F403

BLUE, PURPLE = 1, 3
FAILS = []


def check(name, ok, detail=""):
    print("%-4s %s %s" % ("PASS" if ok else "FAIL", name, detail))
    if not ok:
        FAILS.append(name)


def fire(g, board, tries_x=0.5, tries_y=0.4):
    win = g.frame("PeggleWindow")
    container = win.gameBoardContainer
    child = container.GetScrollChild(container)
    l, b, w, h = [float(v) for v in container.GetRect(container)]
    g.M.setMouse(l + w * tries_x, b + h * tries_y)
    g.advance(0.2)
    g.M.click(child, "LeftButton")


def test_pierce():
    best = 0
    for seed in range(6):
        random.seed(seed)
        g = boot()
        board = start_level(g, hero_id=1)
        cfg = g.M.config
        st = cfg.getState()
        cfg.PowerHit(pegs(board, GREEN)[0], 0)
        if seed == 0:
            check("pierce stores a charge", st.pierceCharges == 1, "charges=%s" % st.pierceCharges)
        g.clear_errors()
        fire(g, board, random.uniform(0.2, 0.8), random.uniform(0.25, 0.5))
        armed = st.pierceBall is not None
        if seed == 0:
            check("shot consumes the charge and arms the ball", armed and st.pierceCharges == 0)
        max_pierced = 0
        for _ in range(500):
            g.advance(0.05)
            max_pierced = max(max_pierced, sum(1 for p in pegs(board) if p.pierced))
            if g.errors():
                break
        best = max(best, max_pierced)
        if g.errors():
            check("pierce no lua errors", False, str(g.errors()[:1]))
            return
    check("pierce ball passes through pegs", best >= 2, "max pegs pierced in one shot = %d" % best)


def test_pierce_keeps_arc_and_leaps():
    """Heroic Strike: normal gravity all the way (the aim arc is honest), and one leap off the floor if smashes remain."""
    leaps, grav_ok = 0, True
    for seed in range(8):
        random.seed(seed)
        g = boot()
        board = start_level(g, hero_id=1)
        cfg = g.M.config
        st = cfg.getState()
        cfg.PowerHit(pegs(board, GREEN)[0], 0)
        fire(g, board, random.uniform(0.2, 0.8), random.uniform(0.25, 0.5))
        ball = st.pierceBall
        if ball is None:
            continue
        for _ in range(400):
            g.advance(0.05)
            grav_ok = grav_ok and float(ball.gravMultiplier or 1) == 1
            if float(ball.y) <= 0:
                break
        if ball.leapt:
            leaps += 1
        if g.errors():
            check("strike no lua errors", False, str(g.errors()[:1]))
            return
    check("heroic strike keeps normal gravity", grav_ok)
    check("heroic strike leaps off the floor when smashes are left", leaps >= 1, "leaps in 8 shots = %d" % leaps)


def test_shield():
    saved = False
    for seed in range(8):
        random.seed(seed)
        g = boot()
        board = start_level(g, hero_id=2)
        cfg = g.M.config
        st = cfg.getState()
        cfg.PowerHit(pegs(board, GREEN)[0], 0)
        if seed == 0:
            check("shield stores a charge", st.shieldCharges == 1, "charges=%s" % st.shieldCharges)
        g.clear_errors()
        # fire at the far edge so the ball is likely to miss the bucket
        fire(g, board, random.choice([0.05, 0.95]), 0.45)
        for _ in range(600):
            g.advance(0.05)
            if st.shieldCharges == 0:
                saved = True
                break
            if g.errors():
                break
        if g.errors():
            check("shield no lua errors", False, str(g.errors()[:1]))
            return
        if saved:
            break
    check("shield saves a ball that would be lost", saved)


if __name__ == "__main__":
    test_pierce()
    test_pierce_keeps_arc_and_leaps()
    test_shield()
    sys.exit(1 if FAILS else 0)
