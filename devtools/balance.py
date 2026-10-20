"""Balance harness: autoplay many levels per hero / talent build and compare win rate and score.

    python devtools/balance.py                    # default sweep (all heroes, all builds)
    python devtools/balance.py --heroes 1,5 --builds none,sig --levels 1,8,14 --seeds 4
    python devtools/balance.py --json out.json

The "player" aims at a random remaining peg (70% orange) with a little jitter; it is an average
player, not an expert, so absolute numbers matter less than the differences between heroes/builds.
"""
import argparse
import math
import json
import os
import random
import statistics
import sys
from multiprocessing import Pool

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scenarios import *  # noqa: F401,F403,E402

DEFAULT_LEVELS = [1, 4, 8, 12, 14, 17, 20, 23]

# Priority lists (slots bought in order, each to max rank, as the tree rules allow).
# Slots: 1 style, 2 powerScore, 3 startRegreen, 4 bucket, 5 feverStart, 6 coin, 7 fever, 8 crit,
#        9 signature, 10/11 perks, 12/13 perks, 14/15 capstones.
BUILDS = {
    "none": [],
    # signature path: cheap tiers on the way, then 9 -> 11 -> 13 -> 15
    "sig": [3, 2, 1, 5, 9, 11, 13, 15, 4, 6, 7],
    # crit/generic path: cheap tiers, then 8 -> 10 -> 12 -> 14
    "alt": [3, 2, 1, 5, 8, 10, 12, 14, 9, 4, 6, 7],
    # "economy": cheap tiers only
    "eco": [1, 2, 3, 4, 5, 6, 7, 8, 9],
}


# Legacy tree (slots 1-11, same tiers/costs): 1 free ball on a miss, 2 style score, 3 fever notches, 4 bucket score,
# 5 crit chance, 6 purple fever, 7 crit value, 8 purple explosion, 9 power-peg crits, 10 extra green, 11 double fission.
LBUILDS = {
    "lall": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    # everything that helps clear pegs / win: free balls, fever, crit, the explosion and the extra green
    "lwin": [1, 3, 5, 2, 6, 8, 10, 4, 7, 9, 11],
    # score-only talents first (should not change the win rate)
    "lscore": [2, 4, 7, 9, 11, 1, 3, 5, 6, 8, 10],
}


def apply_legacy(cfg, build, points):
    ranks = cfg.LegacyTalents()
    for i in range(1, 12):
        ranks[i] = 0
    if build != "none" and points > 0:
        spend(cfg, ranks, points, LBUILDS[build], slots=11)
    cfg.ResyncTalents()


def tree_defs(cfg):
    return {i: (int(cfg.TREE_DEFS[i][1]), int(cfg.TREE_DEFS[i][2]), int(cfg.TREE_DEFS[i][3])) for i in range(1, 16)}


def spend(cfg, ranks, points, priority, slots=15):
    """Greedy purchase honouring the tree rules (tier gating by points spent, prerequisites, rank costs)."""
    defs = tree_defs(cfg)
    cost = lambda tier: int(cfg.TierCost(tier))
    spent = lambda: sum(ranks[i] * cost(defs[i][0]) for i in range(1, slots + 1))
    left = points
    progress = True
    while progress and left > 0:
        progress = False
        for slot in priority:
            tier, mx, pre = defs[slot]
            if ranks[slot] >= mx or left < cost(tier):
                continue
            if spent() < tier * 5:
                continue
            if pre and ranks[pre] < defs[pre][1]:
                continue
            ranks[slot] += 1
            left -= cost(tier)
            progress = True
            break          # restart so earlier priorities fill first
    return left


INSTRUMENT = """
function(cfg)
	local st = cfg.getState()
	cfg.uses, cfg.ph, cfg.po, cfg.saves = 0, 0, 0, 0
	local hp = cfg.HeroPower
	cfg.HeroPower = function(...) cfg.uses = cfg.uses + 1 return hp(...) end
	local ph = cfg.PowerHit
	cfg.PowerHit = function(p, c)
		if not p.hit then
			cfg.ph = cfg.ph + 1
			if p.id == 2 then cfg.po = cfg.po + 1 end
		end
		return ph(p, c)
	end
	local pc = st.PierceCheck
	st.PierceCheck = function(b, p)
		local was = p.pierced
		local r = pc(b, p)
		if r and not was and p.pierced then
			cfg.ph = cfg.ph + 1
			if p.id == 2 then cfg.po = cfg.po + 1 end
		end
		return r
	end
	local ss = st.ShieldSave
	st.ShieldSave = function(...)
		local r = ss(...)
		if r then cfg.saves = cfg.saves + 1 end
		return r
	end
	cfg.dets, cfg.detn = 0, 0
	local ht = st.HexTrigger
	if ht then
		st.HexTrigger = function(peg)
			local n = 0
			for i = 1, #st.hexList do if st.hexList[i].hexed then n = n + 1 end end
			cfg.dets = cfg.dets + 1
			cfg.detn = cfg.detn + n
			return ht(peg)
		end
	end
	local pl = st.PierceLeap
	st.PierceLeap = function(...)
		local r = pl(...)
		if r then cfg.saves = cfg.saves + 1 end
		return r
	end
end
"""


def apply_overrides(cfg, overrides):
    """overrides: {"stars.count": 6, ...} sets cfg.Balance[group][key]; "talent.<hero>.<slot>.per" sets talent values."""
    for key, val in overrides.items():
        parts = key.split(".")
        if parts[0] == "talent":
            hero, slot, field = int(parts[1]), int(parts[2]), parts[3]
            cfg.HERO_TALENTS[hero][slot][field] = val
        elif parts[0] == "generic":
            raise ValueError("generic talent values are baked into the tree; use talent.<hero>.<slot>.per")
        else:
            cfg.Balance[parts[0]][parts[1]] = val


def apply_loadout(g, hero, build, points):
    cfg = g.M.config
    ranks = cfg.ActiveTalents()
    for i in range(1, 16):
        ranks[i] = 0
    if build.startswith("r:"):          # explicit ranks, tree rules ignored: r:3=2+6=5
        for part in build[2:].split("+"):
            slot, rank = part.split("=")
            ranks[int(slot)] = int(rank)
    elif build != "none":
        spend(cfg, ranks, points, BUILDS[build])
    cfg.ResyncTalents()


def start(g, level):
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
    return g.M.config.getBoard(), w


SKILL = 1   # 0 = random target, 1 = prefers dense clusters of oranges (set by --skill)


def pick_target(live):
    orange = [p for p in live if p.id == 2]
    if SKILL == 0:
        return random.choice(orange) if orange and random.random() < 0.7 else random.choice(live)
    pool = orange or live
    xy = [(float(p.x), float(p.y), 1.0 if p.id == 2 else 0.5) for p in live]

    def value(p):
        px, py = float(p.x), float(p.y)
        v = sum(w for x, y, w in xy if (x - px) ** 2 + (y - py) ** 2 < 50 ** 2)
        # lower pegs are harder to reach cleanly; a slight preference for the upper board
        return v + 0.004 * py + random.random() * 1.5
    best = sorted(pool, key=value, reverse=True)[:3]
    return random.choice(best)


def first_hit(angle_deg, live, bricks):
    """Predict what the ball touches first on its arc (speed 260, gravity 248, start (278, 428))."""
    x, y = 278.0, 428.0
    vx = 260.0 * math.cos(math.radians(angle_deg))
    vy = 260.0 * math.sin(math.radians(angle_deg))
    dt = 0.01
    for _ in range(400):
        x += vx * dt
        y += vy * dt
        vy -= 248.0 * dt
        if y < 5 or x < 5 or x > 549:
            return None
        for p in live:
            if (p[0] - x) ** 2 + (p[1] - y) ** 2 < 14.5 ** 2:
                return p
        for bx, by in bricks:
            if (bx - x) ** 2 + (by - y) ** 2 < 21 ** 2:
                return ("brick", bx, by)
    return None


def choose_aim(g, cfg, board, l, b):
    """A player who can see where the first contact will be: tries a spread of aim points and keeps the best one."""
    live_objs = [p for p in pegs(board) if not p.hit]
    live = [(float(p.x), float(p.y), int(p.id)) for p in live_objs if p.id in (1, 2, 3, 4)]
    bricks = [(float(p.x), float(p.y)) for p in live_objs if p.id not in (1, 2, 3, 4)]
    oranges = [q for q in live if q[2] == 2] or live
    cands = random.sample(oranges, min(len(oranges), 10)) + random.sample(live, min(len(live), 4))
    best, best_score = None, -1e9
    for cx, cy, _ in cands:
        for dx in (-9, 0, 9):
            ax, ay = l + cx + dx, b + cy
            g.M.setMouse(ax, ay)
            g.advance(0.02)
            g.M.setMouse(ax + 0.01, ay)
            g.advance(0.02)
            N = float(cfg.getAim()[0])
            hit = first_hit(N, live, bricks)
            if hit is None or hit[0] == "brick":
                sc = -5
            else:
                near = sum((1.0 if q[2] == 2 else 0.5) for q in live if (q[0] - hit[0]) ** 2 + (q[1] - hit[1]) ** 2 < 50 ** 2)
                sc = (6 if hit[2] == 2 else 3 if hit[2] in (3, 4) else 1) + near * 0.5 + (0.004 * hit[1])
            sc += random.random() * 0.8
            if sc > best_score:
                best, best_score = (ax, ay), sc
    return best


def play(job):
    hero, build, level, seed, points, skill, overrides, lbuild, lpoints = job
    global SKILL
    SKILL = skill
    random.seed(seed * 1000 + level * 10 + hero)
    g = boot()
    cfg = g.M.config
    pick_hero(g, hero)
    apply_overrides(cfg, overrides)
    apply_loadout(g, hero, build, points)
    apply_legacy(cfg, lbuild, lpoints)
    g.lua.eval(INSTRUMENT)(cfg)
    board, w = start(g, level)
    container = w.gameBoardContainer
    child = container.GetScrollChild(container)
    l, b, _, _ = [float(v) for v in child.GetRect(child)]
    g.clear_errors()
    total = len([p for p in pegs(board) if p.id == 2])
    shots = 0
    for _ in range(60):
        live = [p for p in pegs(board) if not p.hit and p.id in (1, 2, 3, 4)]
        if not live:
            break
        if SKILL >= 2:
            ax, ay = choose_aim(g, cfg, board, l, b)
        else:
            t = pick_target(live)
            jit = 6 if SKILL == 0 else 3
            ax = l + float(t.x) + random.gauss(0, jit)
            ay = b + float(t.y) + random.gauss(0, jit)
        g.M.setMouse(ax, ay)
        g.advance(0.1)
        g.M.setMouse(ax, ay)
        g.M.click(child, "LeftButton")
        shots += 1
        el = 0
        while el < 30:
            g.advance(0.5)
            el += 0.5
            if cfg.getScore()[2]:
                break
        left_orange = len([p for p in pegs(board) if p.id == 2 and not p.hit])
        if left_orange == 0 or w.summaryScreen.IsShown(w.summaryScreen) or cfg.getScore()[1] == 0 and cfg.getScore()[2]:
            break
    g.advance(12)
    score, balls, _ = cfg.getScore()
    left_orange = len([p for p in pegs(board) if p.id == 2 and not p.hit])
    return {"hero": hero, "build": build, "level": level, "seed": seed, "win": left_orange == 0,
            "orange": total, "orange_left": left_orange, "score": int(score), "balls": int(balls),
            "shots": shots, "uses": int(cfg.uses), "ph": int(cfg.ph), "po": int(cfg.po), "saves": int(cfg.saves), "dets": int(cfg.dets), "detn": int(cfg.detn), "errors": len(g.errors())}


def summarize(rows):
    out = {}
    for key in sorted({(r["hero"], r["build"]) for r in rows}):
        rs = [r for r in rows if (r["hero"], r["build"]) == key]
        out[key] = {
            "n": len(rs),
            "win": sum(r["win"] for r in rs) / float(len(rs)),
            "left": statistics.mean(r["orange_left"] / float(max(1, r["orange"])) for r in rs),
            "score": statistics.mean(r["score"] for r in rs),
            "shots": statistics.mean(r["shots"] for r in rs),
            "uses": statistics.mean(r["uses"] for r in rs),
            "ph": statistics.mean(r["ph"] for r in rs),
            "po": statistics.mean(r["po"] for r in rs),
            "saves": statistics.mean(r["saves"] for r in rs),
            "err": sum(r["errors"] for r in rs),
        }
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--heroes", default="1,2,3,4,5,6,7,8")
    ap.add_argument("--builds", default="none,sig,alt,eco")
    ap.add_argument("--levels", default=",".join(map(str, DEFAULT_LEVELS)))
    ap.add_argument("--seeds", type=int, default=4)
    ap.add_argument("--points", type=int, default=46)
    ap.add_argument("--skill", type=int, default=1)
    ap.add_argument("--set", default="", help="comma list: stars.count=6,pierce.pegs=10,talent.3.9.per=2")
    ap.add_argument("--lbuild", default="none", help="legacy tree priority: none, lall, lwin, lscore")
    ap.add_argument("--legacy", type=int, default=0, help="legacy points to spend")
    ap.add_argument("--json")
    ap.add_argument("--procs", type=int, default=12)
    a = ap.parse_args()
    global SKILL
    SKILL = a.skill
    heroes = [int(x) for x in a.heroes.split(",")]
    levels = [int(x) for x in a.levels.split(",")]
    builds = a.builds.split(",")
    overrides = {k: float(v) for k, v in (x.split('=') for x in a.set.split(',') if x)}
    jobs = [(h, b, lv, s, a.points, a.skill, overrides, a.lbuild, a.legacy) for h in heroes for b in builds for lv in levels for s in range(a.seeds)]
    with Pool(a.procs) as pool:
        rows = pool.map(play, jobs, chunksize=4)
    if a.json:
        json.dump(rows, open(a.json, "w"))
    names = ["?", "Bolvar", "Magni", "Tyrande", "Gelbin", "Thrall", "Sylvanas", "Cairne", "Vol'jin"]
    res = summarize(rows)
    print("%-12s %-5s %5s %7s %9s %6s %5s %6s %6s %5s %4s" % ("hero", "build", "win%", "oranges", "score", "shots", "uses", "pegs/g", "orng/g", "saves", "err"))
    for (h, b), r in res.items():
        print("%-12s %-5s %5.0f %7.0f%% %9.0f %6.1f %5.2f %6.1f %6.1f %5.2f %4d" % (names[h], b, r["win"] * 100, r["left"] * 100, r["score"], r["shots"], r["uses"], r["ph"], r["po"], r["saves"], r["err"]))


if __name__ == "__main__":
    main()
