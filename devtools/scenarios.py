"""Reusable steps for driving the addon headlessly (used by run.py and tests)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, report  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
os.makedirs(OUT, exist_ok=True)


def boot():
    g = Game()
    g.login()
    g.advance(0.5)
    return g


def open_window(g):
    g.click(g.frame("PeggleWindow").minimap)
    g.advance(0.3)


def pick_hero(g, hero_id):
    cfg = g.M.config
    assert cfg.SetHero(hero_id), "bad hero id"
    cfg.ApplyHero()


def start_level(g, hero_id=None, level=1):
    """Quick Play -> Go, like a player would. Returns the board object."""
    if hero_id:
        pick_hero(g, hero_id)
    w = g.frame("PeggleWindow")
    if not w.IsVisible(w):
        open_window(g)
    g.click(w.catagoryScreen.tabFrame._children[1])   # Quick Play tab
    g.advance(0.2)
    g.click(g.frame("PeggleButton_quickPlayGo"))
    g.advance(1.0)
    return g.M.config.getBoard()


def pegs(board, peg_id=None):
    out = []
    for _, p in board.animationStack.items():
        if peg_id is None or p.id == peg_id:
            out.append(p)
    return out


def hit_count(board):
    return sum(1 for p in pegs(board) if p.hit)


GREEN = 4
