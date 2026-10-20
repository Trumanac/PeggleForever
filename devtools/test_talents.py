"""Hero talent trees: spending rules, tooltips, migration, and every hero's talents changing their power.

    python devtools/test_talents.py [--shots]
"""
import random
import sys

from scenarios import *  # noqa: F401,F403

FAILS = []
SHOTS = "--shots" in sys.argv


def check(name, ok, detail=""):
    print("%-4s %s %s" % ("PASS" if ok else "FAIL", name, detail))
    if not ok:
        FAILS.append(name)


def open_talents(g, hero_id):
    open_window(g)
    w = g.frame("PeggleWindow")
    w.splash.Hide(w.splash)
    pick_hero(g, hero_id)
    g.click(w.catagoryScreen.tabFrame._children[4])
    g.advance(0.3)
    return w, w.catagoryScreen.frames[4]


def nodes_of(frame):
    return [frame.tree.node[i] for i in range(1, 16)]


def test_tree_rules():
    g = boot()
    cfg = g.M.config
    w, frame = open_talents(g, 5)
    data = g.G["PeggleForeverData"].newData
    nodes = nodes_of(frame)
    check("tree has 15 talent nodes", len(list(frame.tree.node.items())) == 15)
    levels = len(cfg.LEVELS)
    for i in range(1, levels + 1):
        data.levelScores[i].progress = 3          # every level x 2 points
    cfg.ResyncTalents()
    ranks = cfg.ActiveTalents()
    check("every level beaten twice = 2 points per level", cfg.HeroPoints(5) == 2 * levels, cfg.HeroPoints(5))
    check("rank cost grows with tier", [cfg.TierCost(t) for t in range(6)] == [1, 1, 2, 2, 3, 3])
    g.click(nodes[13])                            # capstone with nothing behind it
    check("locked capstone cannot be bought", ranks[14] == 0)

    def cost_spent():
        return sum(ranks[i] * cfg.TierCost(cfg.TREE_DEFS[i][1]) for i in range(1, 16))

    # tiers 0-2 first (1, 1, 2 points per rank), then slot 8 (tier 3, 2 points per rank)
    for slot, times in ((1, 5), (2, 5), (4, 5), (3, 2), (5, 3), (6, 5), (8, 5)):
        for _ in range(times):
            g.click(nodes[slot - 1])
    check("points spent by cost: 10 + 10 + 10 + 10 = 40", cost_spent() == 40, "spent=%d ranks=%s" % (cost_spent(), [ranks[i] for i in range(1, 16)]))
    g.click(nodes[9])                             # slot 10: tier 4 (3 points), needs slot 8 maxed + 20 spent
    check("slot 10 unlocks once its prerequisite is maxed", ranks[10] == 1)
    g.click(nodes[11])                            # slot 12: 3 points per rank but only 3 are left
    g.click(nodes[11])
    check("only the points that remain can be spent", ranks[12] == 1 and cost_spent() == 46, "spent=%d" % cost_spent())
    g.click(nodes[13])
    check("capstone is out of reach on this build", ranks[14] == 0)
    g.click(nodes[9])
    check("max rank is respected", ranks[10] == 1)
    g.M.hover(nodes[7])
    check("tooltip shows a rank costing more than one point", "points per rank" in str(frame.rank._text), frame.rank._text)
    check("tree click no lua errors", not g.errors(), str(g.errors()[:1]))
    if SHOTS:
        g.screenshot(OUT + "/tree_thrall.png")


def test_balance():
    """One capstone path is affordable with every level beaten; both are not."""
    g = boot()
    cfg = g.M.config
    cost = lambda slot: cfg.TREE_DEFS[slot][2] * cfg.TierCost(cfg.TREE_DEFS[slot][1])
    tiers0_2 = sum(cost(s) for s in range(1, 8))          # slots 1-7 are tiers 0-2
    path_a = cost(8) + cost(10) + cost(12) + cost(14)
    path_b = cost(9) + cost(11) + cost(13) + cost(15)
    earned = 2 * len(cfg.LEVELS)
    # tier 3 needs 15 points spent first and tier 5 needs 25, both met by filling the cheap tiers on the way
    one = 15 + path_a
    both = 15 + path_a + path_b
    check("one capstone path fits in the points a full run earns", one <= earned, "need %d of %d" % (one, earned))
    check("both capstone paths do not", both > earned, "need %d of %d" % (both, earned))
    total = sum(cost(s) for s in range(1, 16))
    check("a maxed run funds roughly half the tree", .45 <= earned / float(total) <= .6, "%d of %d points" % (earned, total))


def test_tooltips():
    for hid in range(1, 9):
        g = boot()
        cfg = g.M.config
        w, frame = open_talents(g, hid)
        nodes = nodes_of(frame)
        names = []
        for i in (9, 10, 12, 14, 15):
            g.M.hover(nodes[i - 1])
            names.append(frame.name._text)
        expected = [cfg.HERO_TALENTS[hid][i].name for i in (9, 10, 12, 14, 15)]
        g.M.hover(nodes[0])
        first = cfg.HERO_TALENTS[hid][1].name
        check("hero %d tooltips show hero talents (all 15 slots are hero-specific)" % hid,
              names == expected and frame.name._text == first and not g.errors(), "%s %s" % (names, g.errors()[:1]))


def test_migration():
    g = boot()
    cfg = g.M.config
    data = g.G["PeggleForeverData"].newData
    cfg.SetHero(1)
    cfg.ActiveTalents()[9] = 3
    cfg.ActiveTalents()[2] = 4
    cfg.LegacyTalents()[1] = 2
    data.talentVersion = None
    cfg.MigrateTalents()
    data = g.G["PeggleForeverData"].newData
    check("old hero talents refunded once and legacy tree starts empty",
          cfg.ActiveTalents()[9] == 0 and cfg.ActiveTalents()[2] == 0 and cfg.LegacyTalents()[1] == 0 and data.talentVersion == 4)
    cfg.ActiveTalents()[9] = 2
    cfg.MigrateTalents()
    check("migration does not run twice", cfg.ActiveTalents()[9] == 2)


def test_legacy_tree():
    g = boot()
    cfg = g.M.config
    data = g.G["PeggleForeverData"].newData
    check("no progress = no legacy points", cfg.AccountPoints() == 0)
    cfg.SetHero(1)
    for i in (1, 2, 3):
        g.G["PeggleForeverData"].newData.levelScores[i].progress = 3     # both challenges on 3 levels with one hero
    check("1 legacy point per level any hero mastered", cfg.AccountPoints() == 3, str(cfg.AccountPoints()))
    for hid in range(2, 9):                                       # every other hero masters level 1 too
        cfg.SetHero(hid)
        g.G["PeggleForeverData"].newData.levelScores[1].progress = 3
    check("+1 more for a level every hero mastered", cfg.AccountPoints() == 4, str(cfg.AccountPoints()))
    beat_only = g.G["PeggleForeverData"].newData
    cfg.SetHero(1)
    g.G["PeggleForeverData"].newData.levelScores[4].progress = 2         # beating alone does not count
    check("beating a level without the full clear gives no legacy point", cfg.AccountPoints() == 4)
    # the Legacy tab: spend points on the shared tree
    open_window(g)
    w = g.frame("PeggleWindow")
    w.splash.Hide(w.splash)
    g.click(w.catagoryScreen.tabFrame._children[4])
    g.advance(0.3)
    frame = w.catagoryScreen.frames[4]
    legacy = [frame.tree.legacyNode[i] for i in range(1, 12)]
    check("legacy tree has the 11 original talents", len(list(frame.tree.legacyNode.items())) == 11)
    g.click(g.M.findByText("Legacy Talents", True))
    check("Legacy tab shows legacy nodes only", cfg.treeKind == "legacy" and legacy[0].IsShown(legacy[0])
          and not frame.tree.node[1].IsShown(frame.tree.node[1]))
    g.click(legacy[0])
    g.click(legacy[0])
    check("legacy points are spent on the shared tree", cfg.LegacyTalents()[1] == 2, str(cfg.LegacyTalents()[1]))
    g.M.hover(legacy[0])
    check("legacy tooltip uses the original talent text", frame.name._text == "TWO-SIDED COIN", str(frame.name._text))
    cfg.SetHero(5)
    check("legacy talents carry over to every hero", cfg.LegacyTalents()[1] == 2 and cfg.ActiveTalents()[1] == 0)
    g.click(g.M.findByText("Reset Talents", True) or frame)       # reset button has no text: use the frame fallback
    check("legacy no lua errors", not g.errors(), str(g.errors()[:1]))


def test_new_effect_types():
    # every hero-specific type maps to a Mod() value
    g = boot()
    cfg = g.M.config
    cfg.SetHero(5)
    r = cfg.ActiveTalents()
    for slot, rank in ((1, 5), (2, 5), (3, 2), (4, 5), (5, 3), (6, 5), (7, 5), (8, 5)):
        r[slot] = rank
    expect = {"style": 40, "powerScore": 50, "startRegreen": 100, "bucket": 50, "feverStart": 3, "coin": 40, "fever": 30, "crit": 25}
    got = {k: cfg.Mod(k) for k in expect}
    check("slots 1-8 give their effect values", got == expect, str(got))
    # extra green pegs at the start of a level
    greens = []
    for ranks in ({}, {3: 2}):
        g = boot()
        cfg = g.M.config
        pick_hero(g, 5)
        for slot, rank in ranks.items():
            cfg.ActiveTalents()[slot] = rank
        cfg.ResyncTalents()
        board = start_level(g)
        greens.append(len(pegs(board, GREEN)))
    check("Start-of-level talent adds green pegs", greens[1] == greens[0] + 1, str(greens))


def hits_after(hero_id, ranks, seed, wait=3.0):
    random.seed(seed)
    g = boot()
    cfg = g.M.config
    pick_hero(g, hero_id)
    for slot, rank in ranks.items():
        cfg.ActiveTalents()[slot] = rank
    cfg.ResyncTalents()
    board = start_level(g)
    st = cfg.getState()
    g.clear_errors()
    cfg.PowerHit(pegs(board, GREEN)[0], 0)
    before = hit_count(board)
    g.advance(wait)
    return hit_count(board) - before, g, cfg, board, st


def avg(hero_id, ranks, n=6, wait=3.0):
    total = 0
    for seed in range(n):
        hits, g, *_ = hits_after(hero_id, ranks, seed, wait)
        if g.errors():
            return None, g.errors()
        total += hits
    return total / n, []


def test_talents_change_powers():
    # (hero, label, ranks that should increase the number of pegs hit by the power's own hit pattern)
    cases = [
        (5, "Thrall Overcharge + Storm Totem", {9: 5, 15: 1}),
        (3, "Tyrande Elune's Grace + Moonfire", {9: 5, 14: 1}),
        (4, "Mekkatorque Bigger Bombs + Cluster Overload", {9: 5, 14: 1}),
        (7, "Cairne Endurance + Raging Bull", {9: 5, 15: 1}),
    ]
    for hid, label, ranks in cases:
        base, err0 = avg(hid, {})
        boosted, err1 = avg(hid, ranks)
        ok = base is not None and boosted is not None and boosted > base
        check(label + " hit more pegs", ok, "base=%s boosted=%s %s" % (base, boosted, (err0 or err1)[:1]))

    # Hex: more cursed pegs and re-curse
    g = boot()
    cfg = g.M.config
    pick_hero(g, 8)
    cfg.ActiveTalents()[9] = 5
    cfg.ResyncTalents()
    board = start_level(g)
    cfg.PowerHit(pegs(board, GREEN)[0], 0)
    cursed = [p for p in pegs(board) if p.hexed]
    check("Hex: Curse of Agony curses 11-12 pegs (5 + 1.3 per rank, rounded at random)", len(cursed) in (11, 12), "cursed=%d" % len(cursed))

    # Heroic Strike: more pierces
    g = boot()
    cfg = g.M.config
    pick_hero(g, 1)
    cfg.ActiveTalents()[9] = 5
    cfg.ActiveTalents()[15] = 1
    cfg.ResyncTalents()
    board = start_level(g)
    cfg.PowerHit(pegs(board, GREEN)[0], 0)
    random.seed(1)
    win = g.frame("PeggleWindow")
    child = win.gameBoardContainer.GetScrollChild(win.gameBoardContainer)
    l, b, w_, h = [float(v) for v in win.gameBoardContainer.GetRect(win.gameBoardContainer)]
    g.M.setMouse(l + w_ * .5, b + h * .4)
    g.advance(0.2)
    g.M.click(child, "LeftButton")
    st = cfg.getState()
    check("Heroic Strike: 8 pegs x2 (Titan's Grip) = 16 piercings", st.pierceLeft == 16, "pierceLeft=%s" % st.pierceLeft)

    # Guide hero: extra guided shots
    g = boot()
    cfg = g.M.config
    pick_hero(g, 6)
    cfg.ActiveTalents()[9] = 5
    cfg.ResyncTalents()
    board = start_level(g)
    cfg.PowerHit(pegs(board, GREEN)[0], 0)      # PowerHit -> Ne -> guide branch
    win = g.frame("PeggleWindow")
    label = win.powerLabel.text._text
    check("Black Arrow: Dark Ranger adds arrows, not guided shots (still 3)", label.endswith("3"), str(label))
    check("talent effects no lua errors", not g.errors(), str(g.errors()[:1]))


def test_all_talents_all_heroes_run():
    """Every hero with every hero talent maxed: power use, echo, regreen, free balls... must not error."""
    for hid in range(1, 9):
        random.seed(hid)
        g = boot()
        cfg = g.M.config
        pick_hero(g, hid)
        r = cfg.ActiveTalents()
        for slot, m in enumerate((5, 5, 2, 5, 3, 5, 5, 5, 5, 1, 1, 3, 3, 1, 1), start=1):
            r[slot] = m
        cfg.LegacyTalents()[9] = 5
        cfg.LegacyTalents()[10] = 1
        cfg.LegacyTalents()[11] = 1
        cfg.LegacyTalents()[1] = 5
        cfg.LegacyTalents()[2] = 5
        cfg.ResyncTalents()
        board = start_level(g)
        g.clear_errors()
        for green in pegs(board, GREEN):
            cfg.PowerHit(green, 0)
        g.advance(4)
        # then play some real shots with everything maxed
        win = g.frame("PeggleWindow")
        child = win.gameBoardContainer.GetScrollChild(win.gameBoardContainer)
        l, b, w_, h = [float(v) for v in win.gameBoardContainer.GetRect(win.gameBoardContainer)]
        for _ in range(6):
            g.M.setMouse(l + w_ * random.uniform(.15, .85), b + h * random.uniform(.2, .6))
            g.advance(0.2)
            g.M.click(child, "LeftButton")
            g.advance(15)
        check("hero %d with every talent maxed plays without errors" % hid, not g.errors(), str(g.errors()[:1]))


if __name__ == "__main__":
    test_tree_rules()
    test_balance()
    test_tooltips()
    test_migration()
    test_legacy_tree()
    test_new_effect_types()
    test_talents_change_powers()
    test_all_talents_all_heroes_run()
    sys.exit(1 if FAILS else 0)
