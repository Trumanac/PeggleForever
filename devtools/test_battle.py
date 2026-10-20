"""Battle (challenge) loopback tests: two copies of the addon ("Alice" and "Bob") share a challenge over addon messages.

    python devtools/test_battle.py

1. Alice creates a challenge (with a chosen hero) for Bob; Bob plays it; Alice's copy must show Bob's score.
2. The creator cancels a Battle: the other player is told and it disappears from both lists.
3. An invited player removes a Battle from their own list: nobody else is affected.
"""
import random
import sys

from scenarios import *  # noqa: F401,F403
from test_duel import Pair, check, FAILS


def battle_tab(g):
    w = g.frame("PeggleWindow")
    open_window(g)
    w.splash.Hide(w.splash)
    g.click(w.catagoryScreen.tabFrame._children[3])
    g.advance(0.3)
    return w.catagoryScreen.frames[3]


def challenge_scores(game, frame):
    """Decodes the stored challenge (through the addon's own decoder) and returns each player's score (-1 = not played)."""
    out = game.lua.eval("""function(f)
      local up = {}
      local i = 1
      while true do local n, v = debug.getupvalue(f, i); if not n then break end; up[n] = v; i = i + 1 end
      up.ge(up.Y[1])
      return table.concat(up.e.currentView[7], ",")
    end""")(frame.content1.UpdateScreen)
    return [float(x) for x in str(out).split(",")]


def count(game):
    return len(list(game.G["PeggleForeverProfile"].challenges.values()))


def make_challenge(hero=0, seed=3):
    """Alice creates a Battle for Bob. Returns (pair, alice frame, bob frame)."""
    random.seed(seed)
    pair = Pair()
    a, b = pair.a, pair.b
    pick_hero(a, 5)
    pick_hero(b, 6)
    fa, fb = battle_tab(a), battle_tab(b)
    c2 = fa.content2
    c2.inviteList[1] = "Alice"       # the real UI puts the creator first when "New Challenge" is opened
    c2.inviteList[2] = "Bob"
    c2.info.selectedValue = 3
    c2.shots.SetValue(c2.shots, 3)
    c2.heroPicker.SetHero(c2.heroPicker, hero)
    a.click(a.frame("PeggleButton_challengeButton"))
    pair.advance(4)
    return pair, fa, fb


def open_details(game, frame):
    c = frame.content1
    c.state = 0
    c.Hide(c)
    c.Show(c)
    game.advance(0.5)
    game.click(c["highlight1"])
    game.advance(0.5)


def confirm_yes(game):
    box = game.M.config.confirmBox
    game.click(box.yes)
    game.advance(0.5)


def test_challenge_flow():
    pair, fa, fb = make_challenge(hero=2)
    a, b = pair.a, pair.b
    cmds = [m.split("+")[0] for (f, t, m) in pair.delivered]
    check("Alice's challenge invite reached Bob", "cnc" in cmds, str(cmds[:4]))
    check("Bob answered and the challenge details were exchanged", {"cdn", "ccs", "csn", "cgs", "csu"} <= set(cmds), str(sorted(set(cmds))))
    check("both players now have the challenge", count(a) == 1 and count(b) == 1)
    check("only the Forever prefix is used", pair.prefixes == {"PEGGLEFOREVER"}, str(pair.prefixes))
    check("both copies start with nobody having played", challenge_scores(a, fa) == [-1, -1] and challenge_scores(b, fb) == [-1, -1])
    check("both copies know the Battle's hero is Magni", int(a.M.config.ChallengeHero(list(a.G["PeggleForeverProfile"].challenges.values())[0])) == 2
          and int(b.M.config.ChallengeHero(list(b.G["PeggleForeverProfile"].challenges.values())[0])) == 2)
    check("no lua errors creating the challenge", not pair.errors(), str(pair.errors()[:1]))

    # Bob opens the challenge from his list and plays it
    open_details(b, fb)
    check("Bob's list shows the challenge details", int(fb.content1.state) == 2, "state=%s" % fb.content1.state)
    check("the details show the hero", "Magni" in str(fb.content1.stageDetails4a.GetText(fb.content1.stageDetails4a)), str(fb.content1.stageDetails4a.GetText(fb.content1.stageDetails4a)))
    b.click(b.frame("PeggleButton_startChallengeButton1"))
    pair.advance(3)
    board = b.M.config.getBoard()
    check("Bob's challenge game started", board is not None and len(list(pegs(board))) > 0)

    cfg = b.M.config
    check("Bob plays as Magni with no talents", int(cfg.activeHero) == 2 and bool(cfg.talentsOff), "hero=%s" % cfg.activeHero)
    win = b.frame("PeggleWindow")
    child = win.gameBoardContainer.GetScrollChild(win.gameBoardContainer)
    l, bt, _, _ = [float(v) for v in child.GetRect(child)]
    for _ in range(12):
        live = [p for p in pegs(board) if not p.hit and p.id in (1, 2, 3, 4)]
        if not live or win.summaryScreen.IsShown(win.summaryScreen):
            break
        t = random.choice(live)
        b.M.setMouse(l + float(t.x), bt + float(t.y))
        pair.advance(0.2)
        b.M.setMouse(l + float(t.x), bt + float(t.y))
        b.M.click(child, "LeftButton")
        pair.advance(8)
    pair.advance(25)
    sb = float(cfg.getScore()[0])
    check("Bob finished with a score", sb > 0 and win.summaryScreen.IsShown(win.summaryScreen), "score %d" % sb)
    check("Bob's own copy records his score", challenge_scores(b, fb) == [-1, sb], str(challenge_scores(b, fb)))
    check("Alice's copy shows Bob's score", challenge_scores(a, fa) == [-1, sb], "%s vs bob %d" % (challenge_scores(a, fa), sb))
    b.click(b.frame("PeggleButton_sumOkay"))
    b.advance(1)
    check("Bob gets his own hero (Sylvanas) back after the Battle", int(cfg.activeHero) == 6, str(cfg.activeHero))
    check("no lua errors after the challenge game", not pair.errors(), str(pair.errors()[:1]))


def test_standard_battle_has_no_hero():
    pair, fa, fb = make_challenge(hero=0, seed=5)
    b = pair.b
    open_details(b, fb)
    b.click(b.frame("PeggleButton_startChallengeButton1"))
    pair.advance(3)
    cfg = b.M.config
    check("a 'no hero' Battle gives everyone the plain blast with no talents", str(cfg.heroMode) == "blast" and bool(cfg.talentsOff), str(cfg.heroMode))
    check("no lua errors in a 'no hero' Battle", not pair.errors(), str(pair.errors()[:1]))


def test_creator_cancels():
    pair, fa, fb = make_challenge(seed=7)
    a, b = pair.a, pair.b
    open_details(a, fa)
    btn = a.frame("PeggleButton_cancelChallenge")
    check("the creator sees a Cancel Battle button", str(btn.GetText(btn)) == "Cancel Battle" and btn.IsShown(btn), str(btn.GetText(btn)))
    a.click(btn)
    confirm_yes(a)
    pair.advance(3)
    cmds = [m.split("+")[0] for (f, t, m) in pair.delivered]
    check("Bob was told the Battle was cancelled", "cxl" in cmds)
    check("the Battle is gone from both lists", count(a) == 0 and count(b) == 0, "%d / %d" % (count(a), count(b)))
    check("Bob saw a message", any("cancelled" in str(m) for m in b.M.printed.values()))
    check("no lua errors cancelling", not pair.errors(), str(pair.errors()[:1]))


def test_invitee_removes():
    pair, fa, fb = make_challenge(seed=9)
    a, b = pair.a, pair.b
    open_details(b, fb)
    btn = b.frame("PeggleButton_cancelChallenge")
    check("an invited player sees a Remove button", str(btn.GetText(btn)) == "Remove", str(btn.GetText(btn)))
    sent = len(pair.delivered)
    b.click(btn)
    confirm_yes(b)
    pair.advance(3)
    check("Bob's list is empty", count(b) == 0)
    check("Alice still has her Battle", count(a) == 1)
    check("removing it tells nobody", not any(m.startswith("cxl") for (f, t, m) in pair.delivered[sent:]))
    pair.advance(420, step=1.0)       # long enough for the creator's periodic re-invite pings
    check("a removed Battle does not come back", count(b) == 0, "bob has %d" % count(b))
    check("no lua errors removing", not pair.errors(), str(pair.errors()[:1]))


def test_back_button_and_limit():
    random.seed(2)
    pair = Pair()
    a = pair.a
    pick_hero(a, 5)
    fa = battle_tab(a)
    check("the Battle list shows the Credits sword", fa.content1.sword is not None and fa.content1.sword.IsShown(fa.content1.sword))
    a.click(fa.content1.newChallenge)
    a.advance(0.5)
    check("New Battle page is open", fa.content2.IsShown(fa.content2) and not fa.content1.IsShown(fa.content1))
    check("it has a Back to Battles button", str(a.frame("PeggleButton_newBattleBack").GetText(a.frame("PeggleButton_newBattleBack"))) == "Back to Battles")
    a.click(a.frame("PeggleButton_newBattleBack"))
    a.advance(0.5)
    check("Back returns to the Battle list without changing tabs", fa.content1.IsShown(fa.content1) and not fa.content2.IsShown(fa.content2) and int(fa.content1.state) == 0)
    check("no lua errors using Back", not pair.errors(), str(pair.errors()[:1]))
    st = a.M.config.getState()
    check("the active Battle limit is 10", int(st.maxBattles) == 10, str(st.maxBattles))
    for count, enabled in ((9, True), (10, False)):
        st.cCount = count
        fa.content1.Hide(fa.content1)
        fa.content1.Show(fa.content1)
        a.advance(0.2)
        on = bool(fa.content1.newChallenge.IsMouseEnabled(fa.content1.newChallenge))
        check("with %d Battles the New Challenge button is %s" % (count, "on" if enabled else "off"), on == enabled)
    st.cCount = 0


if __name__ == "__main__":
    test_challenge_flow()
    test_standard_battle_has_no_hero()
    test_creator_cancels()
    test_invitee_removes()
    test_back_button_and_limit()
    print("FAILS:", FAILS)
    sys.exit(1 if FAILS else 0)
