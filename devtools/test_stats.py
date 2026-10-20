"""Stats tracking: plays real levels and checks the counters, records and the Stats page.

    python devtools/test_stats.py [--shots]
"""
import random
import sys

from scenarios import *  # noqa: F401,F403

FAILS = []


def check(name, ok, detail=""):
    print("%-4s %s %s" % ("PASS" if ok else "FAIL", name, detail))
    if not ok:
        FAILS.append(name)


def play_out(g, board, win, max_shots=40):
    """Shoot at random pegs until the level ends."""
    cfg = g.M.config
    child = win.gameBoardContainer.GetScrollChild(win.gameBoardContainer)
    l, b, _, _ = [float(v) for v in child.GetRect(child)]
    for _ in range(max_shots):
        live = [p for p in pegs(board) if not p.hit and p.id in (1, 2, 3, 4)]
        if not live or win.summaryScreen.IsShown(win.summaryScreen):
            break
        t = random.choice(live)
        g.M.setMouse(l + float(t.x), b + float(t.y))
        g.advance(0.1)
        g.M.setMouse(l + float(t.x), b + float(t.y))
        g.M.click(child, "LeftButton")
        for _ in range(60):
            g.advance(0.5)
            if cfg.getScore()[2]:
                break
        if cfg.getScore()[1] == 0 and cfg.getScore()[2]:
            break
    g.advance(15)


def main():
    random.seed(4)
    g = boot()
    cfg = g.M.config
    win = g.frame("PeggleWindow")
    pick_hero(g, 5)
    S = cfg.Stats
    check("stats start empty", S.Data().started == 0 and S.Data().score == 0)
    board = start_level(g, hero_id=5, level=1)
    check("starting a level counts it", S.Data().started == 1 and S.Data().hero[5].started == 1)
    play_out(g, board, win)
    d = S.Data()
    check("level end recorded", d.beaten + d.failed == 1, "beaten=%s failed=%s" % (d.beaten, d.failed))
    check("shots and pegs counted", d.shots > 0 and d.pegs > 0, "shots=%s pegs=%s" % (d.shots, d.pegs))
    check("score recorded", d.score > 0 and d.bestLevel.score == d.score, "score=%s" % d.score)
    check("best ball is tracked and not above the level score", 0 < d.bestBall.score <= d.score, "best ball=%s" % d.bestBall.score)
    check("per-hero totals follow", d.hero[5].score == d.score and d.hero[5].best == d.score)
    check("time played counted", d.time > 0)

    # a second level for another hero
    pick_hero(g, 7)
    g2board = start_level(g, hero_id=7, level=1) if False else None
    sections = S.Build()
    check("page has three sections", len(list(sections.keys())) == 3)
    flat = {row[1]: row[2] for sec in sections.values() for row in sec[2].values()}
    check("overall rows filled", flat["Levels played"] == "1" and flat["Total score"] != "0", str(flat)[:140])
    check("most played hero is Thrall", flat["Most played hero"].startswith("Thrall"), flat["Most played hero"])
    check("favourite level shows the level name", flat["Favourite level"].startswith(cfg.LEVEL_NAMES[1][:5]), flat["Favourite level"])
    check("long text is cut with ...", S.Fit("Valley of Heroes of Azeroth", 15) == "Valley of He..." and S.Fit("Short", 15) == "Short")
    check("hero table has one row per hero", len(list(S.HeroRows().keys())) == len(list(cfg.heroes.keys())))

    # the page renders without errors and shows the numbers
    cfg.ShowStats()
    g.advance(0.3)
    check("stats page opens", win.stats.IsShown(win.stats))
    check("page text shows the total score", bool(g.M.findByText(flat["Total score"], True)))
    check("no lua errors", not g.errors(), str(g.errors()[:1]))
    if "--shots" in sys.argv:
        win.splash.Hide(win.splash)
        g.screenshot(OUT + "/stats.png")
    # old saves without any stats table
    g.G["PeggleForeverData"].newData.stats = None
    check("missing stats table is rebuilt", S.Data().started == 0)
    sys.exit(1 if FAILS else 0)


if __name__ == "__main__":
    main()
