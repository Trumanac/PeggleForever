"""Per-hero progress, talents, effects and Full Reset.

    python devtools/test_heroes.py
"""
import sys

from scenarios import *  # noqa: F401,F403

FAILS = []


def check(name, ok, detail=""):
    print("%-4s %s %s" % ("PASS" if ok else "FAIL", name, detail))
    if not ok:
        FAILS.append(name)


def test_isolation():
    g = boot()
    cfg = g.M.config
    data = g.G["PeggleForeverData"].newData
    cfg.SetHero(1)
    data.levelScores[1].progress = 3          # hero 1 beats + fully clears level 1 (= 2 points)
    data.levelScores[2].progress = 2          # and beats level 2 (= 1 point)
    cfg.ActiveTalents()[1] = 2
    check("hero 1 earned 3 points", cfg.HeroPoints(1) == 3, str(cfg.HeroPoints(1)))
    cfg.SetHero(2)
    check("hero 2 starts with 0 points / no ranks", cfg.HeroPoints(2) == 0 and cfg.ActiveTalents()[1] == 0)
    check("hero 2 levels are separate", data.levelScores[1].progress == 0)
    data.levelScores[3].progress = 2
    cfg.SetHero(1)
    check("hero 1 kept its progress and talents", cfg.HeroPoints(1) == 3 and cfg.ActiveTalents()[1] == 2)
    check("hero 2 progress did not leak", cfg.HeroPoints(2) == 1 and cfg.HeroPoints(1) == 3)
    check("no lua errors", not g.errors(), str(g.errors()[:1]))


def test_full_reset():
    g = boot()
    cfg = g.M.config
    data = g.G["PeggleForeverData"].newData
    cfg.SetHero(1)
    data.levelScores[1].progress = 3
    cfg.ActiveTalents()[2] = 4
    cfg.FullReset()
    data = g.G["PeggleForeverData"].newData
    check("full reset clears hero", cfg.activeHero is None and g.G["PeggleForeverProfile"].hero is None)
    check("full reset clears progress", all(cfg.HeroPoints(i) == 0 for i in range(1, 9)))
    cfg.SetHero(1)
    check("hero starts new after reset", cfg.HeroPoints(1) == 0 and cfg.ActiveTalents()[2] == 0
          and data.levelScores[1].progress == 0)
    check("no lua errors", not g.errors(), str(g.errors()[:1]))


def test_effects_and_ui():
    for hid in range(1, 9):
        g = boot()
        cfg = g.M.config
        board = start_level(g, hero_id=hid)
        g.clear_errors()
        cfg.PowerHit(pegs(board, GREEN)[0], 0)
        n = len(cfg.FX.active)
        g.advance(4.0)
        left = len(cfg.FX.active)
        pending = len(cfg.FX.timers)
        check("hero %d effects spawn and clean up" % hid, n > 0 and left == 0 and pending == 0 and not g.errors(),
              "spawned=%d after_4s=%d timers=%d %s" % (n, left, pending, g.errors()[:1]))
    g = boot()
    open_window(g)
    w = g.frame("PeggleWindow")
    w.splash.Hide(w.splash)
    pick_hero(g, 3)
    g.click(w.catagoryScreen.tabFrame._children[4])
    g.advance(0.3)
    g.click(g.M.findByText("Reset All", True))
    box = g.M.config.confirmBox
    check("Reset All opens a confirmation", box.IsShown(box))
    g.click(g.M.findByText("No", True))
    check("No keeps everything", g.M.config.activeHero == 3 and not box.IsShown(box))
    g.click(g.M.findByText("Reset All", True))
    g.click(g.M.findByText("Yes", True))
    check("Yes resets everything", g.M.config.activeHero is None)
    check("ui no lua errors", not g.errors(), str(g.errors()[:1]))


def test_recent_quickplay_and_ability_hover():
    g = boot()
    cfg = g.M.config
    cfg.SetHero(1)
    g.G["PeggleForeverData"].recent[1] = 111
    cfg.SetHero(2)
    check("most-recent scores are per hero", g.G["PeggleForeverData"].recent[1] is None)
    cfg.SetHero(1)
    check("hero 1 recent score is back", g.G["PeggleForeverData"].recent[1] == 111)
    # hero with progress but no recent score must not break the Quick Play screen (used to throw)
    cfg.SetHero(3)
    g.G["PeggleForeverData"].newData.levelScores[1].progress = 2
    g.G["PeggleForeverData"].newData.levelScores[1].score = 5000
    cfg.RefreshLevelScores()
    open_window(g)
    w = g.frame("PeggleWindow")
    w.splash.Hide(w.splash)
    g.click(w.catagoryScreen.tabFrame._children[1])
    g.advance(0.3)
    check("Quick Play shows the active hero", g.M.findByText("|cFFFFFFFFTyrande Whisperwind|r", True) is not None)
    check("Quick Play shows hero level", g.M.findByText("Level 1  |cFF999999Night Elf|r", True) is not None)
    check("Quick Play loads without errors for a hero with no recent score", not g.errors(), str(g.errors()[:1]))
    # Talents tab: Hero Ability row + hover
    g.click(w.catagoryScreen.tabFrame._children[4])
    g.advance(0.3)
    frame = w.catagoryScreen.frames[4]
    check("default info text is just the grey hint", frame.mouseOver._text == "|cFF999999Mouse over a talent for details|r")
    g.M.hover(cfg.abilityHover)
    hero = cfg.GetHero(3)
    check("hovering the Hero Ability shows it in the info box",
          frame.name._text == hero.powerName and frame.rank._text == "Hero Ability" and frame.desc._text == hero.powerDesc
          and frame.icon.IsShown(frame.icon) and not frame.mouseOver.IsShown(frame.mouseOver))
    g.M.unhover(cfg.abilityHover)
    check("leaving restores the hint", frame.mouseOver.IsShown(frame.mouseOver) and not frame.name.IsShown(frame.name))
    check("hover no lua errors", not g.errors(), str(g.errors()[:1]))


def test_first_launch_and_title():
    g = boot()
    w = g.frame("PeggleWindow")
    check("hero select is hidden before the window opens", not w.charScreen.IsShown(w.charScreen))
    open_window(g)
    # no hero chosen yet: the character's race hero is used (not saved), so the hero screen does not pop up
    check("first time the window opens, the race hero is used", not w.charScreen.IsShown(w.charScreen)
          and g.M.config.activeHero == g.M.config.RaceHero() and not g.eval("PeggleForeverProfile.hero"))
    check("hero select is drawn above everything (DIALOG strata)", w.charScreen.GetFrameStrata(w.charScreen) == "DIALOG")
    g.click(g.M.findByText("OK", True) or w.charScreen)       # OK with nothing selected must not close it or crash
    g.M.config.SetHero(2)
    g.M.config.ApplyHero()
    w.charScreen.Hide(w.charScreen)
    w.Hide(w)
    w.Show(w)
    check("returning player is not asked again", not w.charScreen.IsShown(w.charScreen))
    l, b, r, t = [float(v) for v in g.M.layout(w.logo)]
    fl, fb, fr, ft = [float(v) for v in g.M.layout(w.foreverLogo)]
    tabs_top = float(g.M.layout(w.catagoryScreen.tabFrame)[3])
    tab_label_top = tabs_top - 20           # tab labels sit around the middle of the 64px tab bar
    check("FOREVER only overlaps the very top edge of the tab bar (labels stay clear)", fb >= tab_label_top - 2,
          "forever bottom=%.0f tab label top~%.0f" % (fb, tab_label_top))
    # the Peggle lettering bottom (~row 70 of 72) sits in the gold flared top bar, FOREVER overlaps it slightly
    letters_bottom = t - 70
    window_top = float(g.M.layout(w)[3])
    check("Peggle letters end in the middle of the gold top bar", window_top - 26 < letters_bottom < window_top,
          "letters bottom=%.0f window top=%.0f" % (letters_bottom, window_top))
    check("FOREVER letters start just above the bottom of Peggle (slight overlap)", 0 <= (ft - 1.2) - letters_bottom <= 6,
          "overlap=%.1f" % ((ft - 1.2) - letters_bottom))
    check("title no lua errors", not g.errors(), str(g.errors()[:1]))


if __name__ == "__main__":
    test_first_launch_and_title()
    test_recent_quickplay_and_ability_hover()
    test_isolation()
    test_full_reset()
    test_effects_and_ui()
    sys.exit(1 if FAILS else 0)
