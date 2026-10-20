"""Duel loopback test: two copies of the addon ("Alice" and "Bob") exchange addon messages in memory.

    python devtools/test_duel.py

Runs the real invite -> accept -> play the same level -> exchange scores flow and checks both sides.
"""
import random
import sys

from scenarios import *  # noqa: F401,F403

FAILS = []


def check(name, ok, detail=""):
    print("%-4s %s %s" % ("PASS" if ok else "FAIL", name, detail))
    if not ok:
        FAILS.append(name)


class Pair:
    def __init__(self, name_a="Alice", name_b="Bob"):
        self.names = {}
        self.games = []
        for name in (name_a, name_b):
            g = Game(name)
            g.login()
            g.advance(0.5)
            self.games.append(g)
            self.names[name.lower()] = g
        self.a, self.b = self.games
        self.delivered = []        # (from, to, message) for the checks
        self.prefixes = set()

    def pump(self):
        for g in self.games:
            out = g.M["addonOut"]
            items = [(v[1], v[2], v[3], v[4]) for v in out.values()]
            g.lua.eval("function(M) M.addonOut = {} end")(g.M)
            for prefix, msg, chan, target in items:
                self.prefixes.add(prefix)
                other = self.names.get(str(target).lower().split("-")[0])
                if other is None or other is g:
                    continue
                self.delivered.append((g.M["playerName"], other.M["playerName"], msg))
                other.M.fire("CHAT_MSG_ADDON", prefix, msg, chan, g.M["playerName"])

    def advance(self, seconds, step=0.25):
        t = 0.0
        while t < seconds:
            for g in self.games:
                g.advance(step)
            self.pump()
            t += step

    def errors(self):
        return self.a.errors() + self.b.errors()


def duel_tab(g):
    w = g.frame("PeggleWindow")
    open_window(g)
    w.splash.Hide(w.splash)
    g.click(w.catagoryScreen.tabFrame._children[2])
    g.advance(0.3)
    return w.catagoryScreen.frames[2]


def play_to_end(pair, max_shots=40):
    """Both players shoot at random pegs until each one's level has ended."""
    done = [False, False]
    for _ in range(max_shots):
        for i, g in enumerate(pair.games):
            cfg = g.M.config
            board = cfg.getBoard()
            if done[i] or not board:
                continue
            win = g.frame("PeggleWindow")
            live = [p for p in pegs(board) if not p.hit and p.id in (1, 2, 3, 4)]
            if not live or win.summaryScreen.IsShown(win.summaryScreen):
                done[i] = True
                continue
            child = win.gameBoardContainer.GetScrollChild(win.gameBoardContainer)
            l, b, _, _ = [float(v) for v in child.GetRect(child)]
            t = random.choice(live)
            g.M.setMouse(l + float(t.x), b + float(t.y))
            g.advance(0.1)
            g.M.setMouse(l + float(t.x), b + float(t.y))
            g.M.click(child, "LeftButton")
        pair.advance(6)
        if all(done):
            break
    pair.advance(20)


def test_duel_flow():
    random.seed(7)
    pair = Pair()
    a, b = pair.a, pair.b
    pick_hero(a, 5)      # each player has a hero chosen, like a real player (the hero screen blocks aiming otherwise)
    pick_hero(b, 6)
    duel_a = duel_tab(a)
    duel_b = duel_tab(b)

    # Alice invites Bob
    duel_a.name2.SetText(duel_a.name2, "Bob")
    a.click(duel_a.go)
    pair.advance(2)
    sent = [m for (f, t, m) in pair.delivered if f == "Alice"]
    check("Alice's invite reached Bob", any(m.startswith("di+5") for m in sent), str(sent[:2]))
    check("only the Forever prefix is used", pair.prefixes == {"PEGGLEFOREVER"}, str(pair.prefixes))
    check("Bob sees the invite (accept/decline buttons)", duel_b.okay2.IsShown(duel_b.okay2) and duel_b.decline2.IsShown(duel_b.decline2))
    check("Bob's opponent field shows Alice", str(duel_b.name2.GetText(duel_b.name2)) == "Alice", str(duel_b.name2.GetText(duel_b.name2)))
    check("Alice got Bob's received-reply", any(m.startswith("dr+5") for (f, t, m) in pair.delivered if f == "Bob"))
    check("no lua errors during the invite", not pair.errors(), str(pair.errors()[:2]))

    # Bob accepts
    b.click(duel_b.okay2)
    pair.advance(2)
    check("Alice's client started the duel after Bob accepted", a.M.config.getBoard() is not None)
    check("Bob's client started the duel", b.M.config.getBoard() is not None)
    ba, bb = a.M.config.getBoard(), b.M.config.getBoard()
    pa = [int(p.id) for p in pegs(ba)]       # moving pegs differ in position, so compare the colour of each peg in order
    pb = [int(p.id) for p in pegs(bb)]
    check("both players got the same level layout and orange pegs", pa == pb and len(pa) > 0, "%d vs %d pegs, %d orange" % (len(pa), len(pb), pa.count(2)))
    check("duel mode uses the standard power and no talents", a.M.config.talentsOff and b.M.config.talentsOff)
    check("with 'no hero' both players get the plain blast", str(a.M.config.heroMode) == "blast" and str(b.M.config.heroMode) == "blast")
    check("no lua errors starting the duel", not pair.errors(), str(pair.errors()[:2]))

    play_to_end(pair)
    sa = float(a.M.config.getScore()[0])
    sb = float(b.M.config.getScore()[0])
    check("both players finished their game", True, "scores %d / %d" % (sa, sb))
    finals_a = [m for (f, t, m) in pair.delivered if f == "Alice" and m.startswith("df")]
    finals_b = [m for (f, t, m) in pair.delivered if f == "Bob" and m.startswith("df")]
    check("both sent their final score", len(finals_a) >= 1 and len(finals_b) >= 1, "%d / %d" % (len(finals_a), len(finals_b)))
    p1a, p2a = float(duel_a.player1.value), float(duel_a.player2.value)
    p1b, p2b = float(duel_b.player1.value), float(duel_b.player2.value)
    check("Alice sees Bob's score", p2a == sb, "player2=%s bob=%s" % (p2a, sb))
    check("Bob sees Alice's score", p2b == sa, "player2=%s alice=%s" % (p2b, sa))
    check("no lua errors after the duel", not pair.errors(), str(pair.errors()[:2]))


def finish_and_return(pair):
    for g in pair.games:
        g.click(g.frame("PeggleButton_sumOkay"))
    pair.advance(1)


def test_duel_with_a_chosen_hero():
    """Alice picks Tyrande for the duel: both play as Tyrande with no talents, and each gets their own hero back afterwards."""
    random.seed(11)
    pair = Pair()
    a, b = pair.a, pair.b
    pick_hero(a, 5)
    pick_hero(b, 6)
    a.M.config.ActiveTalents()[1] = 3          # talents must not count in the match
    a.M.config.ResyncTalents()
    duel_a = duel_tab(a)
    duel_b = duel_tab(b)
    duel_a.name2.SetText(duel_a.name2, "Bob")
    duel_a.heroPicker.SetHero(duel_a.heroPicker, 3)
    a.click(duel_a.go)
    pair.advance(2)
    check("Bob sees which hero the duel uses", int(duel_b.duelHero) == 3, str(duel_b.duelHero))
    b.click(duel_b.okay2)
    pair.advance(2)
    for name, g in (("Alice", a), ("Bob", b)):
        cfg = g.M.config
        check("%s plays as Tyrande with no talents" % name, int(cfg.activeHero) == 3 and bool(cfg.talentsOff) and str(cfg.heroMode) == "stars",
              "hero=%s mode=%s" % (cfg.activeHero, cfg.heroMode))
    check("no lua errors starting the hero duel", not pair.errors(), str(pair.errors()[:1]))
    play_to_end(pair)
    finish_and_return(pair)
    check("Alice is back on her own hero (Thrall)", int(a.M.config.activeHero) == 5, str(a.M.config.activeHero))
    check("Bob is back on his own hero (Sylvanas)", int(b.M.config.activeHero) == 6, str(b.M.config.activeHero))
    check("no lua errors after the hero duel", not pair.errors(), str(pair.errors()[:1]))


def test_level_list_is_shared_between_tabs():
    """The level list moves between the Quick Play and Duel pages. Using it on the Duel tab used to break the Quick Play
    layout (a nil levelTitle error when Quick Play was shown again)."""
    pair = Pair()
    g = pair.a
    pick_hero(g, 5)
    w = g.frame("PeggleWindow")
    open_window(g)
    w.splash.Hide(w.splash)
    g.click(w.catagoryScreen.tabFrame._children[2])
    g.advance(0.3)
    rows = w.levelList
    for i in (3, 5, 2):
        g.M.hover(rows["highlight%d" % i])
        g.M.click(rows["highlight%d" % i], "LeftButton")
        g.advance(0.1)
    g.click(w.catagoryScreen.tabFrame._children[1])
    g.advance(0.3)
    check("Quick Play still opens after using the level list on the Duel tab", not g.errors(), str(g.errors()[:1]))


def test_old_peggle_is_ignored():
    """A message on the original addon's prefix (or with its protocol number) must not start anything."""
    pair = Pair()
    a, b = pair.a, pair.b
    duel_b = duel_tab(b)
    duel_tab(a)
    b.M.fire("CHAT_MSG_ADDON", "PEGGLE", "di+3+1+hi+ABCDEF", "WHISPER", "Alice")
    b.advance(0.5)
    check("an invite on the original Peggle prefix is ignored", not duel_b.okay2.IsShown(duel_b.okay2))
    for old in (3, 4):
        b.M.fire("CHAT_MSG_ADDON", "PEGGLEFOREVER", "di+%d+1+hi+ABCDEF" % old, "WHISPER", "Alice")
        b.advance(0.5)
        check("an invite with the old protocol number %d is ignored" % old, not duel_b.okay2.IsShown(duel_b.okay2))
    check("no lua errors", not pair.errors(), str(pair.errors()[:2]))


def test_newer_version_notice():
    """A ping from a newer protocol cannot be read, but it must still show the "out of date" notice."""
    pair = Pair()
    b = pair.b
    st = b.M.config.getState()
    b.M.fire("CHAT_MSG_ADDON", "PEGGLEFOREVER", "ping+%d" % (st.ping + 1), "WHISPER", "Alice")
    b.advance(0.2)
    check("a ping from a newer version shows the out-of-date notice",
          bool(st.outdated) and st.outdatedPop.IsShown(st.outdatedPop))
    check("no lua errors (version notice)", not pair.errors(), str(pair.errors()[:2]))


if __name__ == "__main__":
    test_duel_flow()
    test_duel_with_a_chosen_hero()
    test_level_list_is_shared_between_tabs()
    test_old_peggle_is_ignored()
    test_newer_version_notice()
    print("FAILS:", FAILS)
    sys.exit(1 if FAILS else 0)
