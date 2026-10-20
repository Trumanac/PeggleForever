"""Peggle Loot loopback test: "Alice" starts /peggleloot in a two-player party with "Bob".

    python devtools/test_loot.py

Both copies get the invite, play the one-shot level (or decline), their scores go back to Alice and Alice's
copy posts the results and the winner to party chat after 40 seconds.
"""
import random

from scenarios import *  # noqa: F401,F403
from test_duel import Pair, check, FAILS

PARTY = """
function(M, other)
    M.chat = {}
    GetNumGroupMembers = function() return 2 end
    UnitName = function(unit)
        if unit == "party1" then return other end
        if unit and string.match(unit, "^party") then return nil end
        return M.playerName
    end
    SendChatMessage = function(msg, chan) table.insert(M.chat, chan .. ": " .. msg) end
end
"""


class LootPair(Pair):
    def pump(self):
        # like Pair.pump, but a whisper to yourself is delivered too (the leader plays their own round)
        for g in self.games:
            out = g.M["addonOut"]
            items = [(v[1], v[2], v[3], v[4]) for v in out.values()]
            g.lua.eval("function(M) M.addonOut = {} end")(g.M)
            for prefix, msg, chan, target in items:
                to = self.names.get(str(target).lower().split("-")[0])
                if to is not None:
                    to.M.fire("CHAT_MSG_ADDON", prefix, msg, chan, g.M["playerName"])


def chat(g):
    return [str(v) for v in g.M.chat.values()]


def stat(g, key):
    return g.eval("PeggleForeverData.newData.stats and PeggleForeverData.newData.stats.%s or 0" % key)


def shoot_once(g):
    win = g.frame("PeggleWindow")
    board = g.M.config.getBoard()
    live = [p for p in pegs(board) if not p.hit and p.id in (1, 2, 3, 4)]
    child = win.gameBoardContainer.GetScrollChild(win.gameBoardContainer)
    l, b, _, _ = [float(v) for v in child.GetRect(child)]
    t = random.choice(live)
    g.M.setMouse(l + float(t.x), b + float(t.y))
    g.advance(0.1)
    g.M.setMouse(l + float(t.x), b + float(t.y))
    g.M.click(child, "LeftButton")


def round_for(mode):
    """mode: play | decline | ignore (never answers) | idle (clicks Go, never shoots) | late (shoots as time runs out)"""
    random.seed(3)
    pair = LootPair()
    a, b = pair.a, pair.b
    for g, other in ((a, "Bob"), (b, "Alice")):
        pick_hero(g, 5)
        g.lua.eval(PARTY)(g.M, other)
        w = g.frame("PeggleWindow")
        w.splash.Hide(w.splash)
    started = (stat(a, "started"), stat(b, "started"))
    streak = stat(a, "streak")
    a.exec('SlashCmdList["PEGGLELOOT"]("Shiny Sword")')
    pair.advance(2)
    check("leader announces the round in party chat", any("PARTY: Peggle One-Shot Loot" in c for c in chat(a)), chat(a)[:1])
    for g in (a, b):
        dlg = g.frame("PeggleWindow").peggleLootDialog
        check("%s gets the Peggle Loot dialog" % g.M["playerName"], dlg.IsShown(dlg))
    b.exec('SlashCmdList["PEGGLELOOT"]("Other Item")')
    check("Bob cannot start a second round during Alice's", not b.errors() and not any("Other Item" in c for c in chat(b)), b.errors()[:1])
    a.click(a.frame("PeggleButton_lootGo"))
    if mode == "decline":
        b.click(b.frame("PeggleButton_lootDecline"))
    elif mode in ("play", "idle", "late"):
        b.click(b.frame("PeggleButton_lootGo"))
    pair.advance(1.5)
    check("loot round plays with no hero", a.M.config.heroMode == "blast", a.M.config.heroMode)
    shoot_once(a)
    if mode == "play":
        shoot_once(b)
    if mode == "late":  # shoots with about a second left: the ball is stopped when time runs out and still scores
        pair.advance(25.5)  # the invite came ~3.4s ago: shoots at ~29s of 30
        shoot_once(b)
    pair.advance(45)
    lines = chat(a)
    print("    leader's party chat:", lines[1:])
    check("results posted once", sum("Peggle Loot Results" in c for c in lines) == 1)
    check("Alice is listed with a score", any("Alice - " in c and "pts" in c for c in lines))
    bob = [c for c in lines if "Bob - " in c]
    if mode in ("play", "late"):
        check("Bob is listed with a score", bob and "pts" in bob[0], bob)
    elif mode == "decline":
        check("Bob is listed as declined", bob and "Decline" in bob[0], bob)
    elif mode == "idle":
        check("Bob (clicked Go, never shot) is listed as declined", bob and "Decline" in bob[0], bob)
        w = b.frame("PeggleWindow")
        check("Bob is back on the menu when time runs out", w.catagoryScreen.IsShown(w.catagoryScreen))
    else:
        check("Bob (never answered) is not listed", not bob, bob)
    check("a winner is named", any("Winner:" in c for c in lines))
    check("Bob's copy posts nothing (only the leader reports)", not any("Results" in c for c in chat(b)))
    check("loot rounds are not counted in Stats", (stat(a, "started"), stat(b, "started")) == started)
    check("loot round does not end the win streak", stat(a, "streak") == streak)
    for g in (a, b):
        w = g.frame("PeggleWindow")
        board_on = not w.catagoryScreen.IsShown(w.catagoryScreen)
        print("    %s after the round: level screen %s, summary %s" % (g.M["playerName"], "on" if board_on else "off",
              w.summaryScreen.IsShown(w.summaryScreen)))
    # a second round works
    a.lua.eval("function(M) M.chat = {} end")(a.M)
    for g in (a, b):
        w = g.frame("PeggleWindow")
        if w.summaryScreen.IsShown(w.summaryScreen):
            g.click(g.frame("PeggleButton_sumOkay"))
    pair.advance(1)
    a.exec('SlashCmdList["PEGGLELOOT"]("Second Item")')
    pair.advance(2)
    check("leader can start another round afterwards", any("Second Item" in c for c in chat(a)), chat(a)[:1])
    check("no lua errors", not pair.errors(), pair.errors()[:3])


if __name__ == "__main__":
    for mode in ("play", "decline", "ignore", "idle", "late"):
        print("-- Bob:", mode)
        round_for(mode)
    print("FAILS:", FAILS)
