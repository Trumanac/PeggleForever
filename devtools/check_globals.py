"""Lists every global variable the add-on creates while it loads, logs in, plays a level and opens the
main pages, with the file:line that created it. Anything not in EXPECTED is a leak (a missing `local`).

    python devtools/check_globals.py
"""
import sys

from lupa.lua51 import LuaRuntime

import run
from scenarios import start_level

EXPECTED = {
    "PeggleForeverData", "PeggleForeverProfile", "PeggleGameWindow",
    "SLASH_PEGGLE1", "SLASH_PEGGLE2", "SLASH_PEGGLELOOT1",
    "AchievementShield_Desaturate", "AchievementShield_Saturate", "AchievementShield_OnLoad",
    "LibStub",                                        # embedded library
    "MouseIsOver", "getglobal", "SetDesaturation",   # Heroes.lua fallbacks, only when the client lacks them
}

HOOK = """
_G.__globals = {}
local mt = getmetatable(_G) or {}
local old = mt.__newindex
mt.__newindex = function(t, k, v)
  local info = debug.getinfo(2, 'Sl')
  local src = info and info.short_src or '?'
  if not string.find(src, 'wowmock') then
    __globals[k] = (__globals[k] or '') .. (src:match('[^/]*$') .. ':' .. (info.currentline or 0) .. ' ')
  end
  if old then old(t, k, v) else rawset(t, k, v) end
end
setmetatable(_G, mt)
"""


class HookedGame(run.Game):
    def __init__(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        mock = run.HERE.replace("\\", "/") + "/wowmock.lua"
        self.M = self.lua.eval("(function() return assert(loadfile(%r))() end)()" % mock)
        self.lua.execute(HOOK)
        self.M.loadAddon(run.ADDON_DIR.replace("\\", "/"), run.ADDON)
        self.G = self.lua.globals()


def main():
    g = HookedGame()
    g.login()
    g.advance(0.5)
    start_level(g, hero_id=5)
    g.advance(8)
    slash = g.G.SlashCmdList["PEGGLE"]
    for cmd in ("stats", "snd list", "crestsound"):
        slash(cmd)
        g.advance(0.5)
    leaks = {k: v for k, v in g.G.__globals.items() if k not in EXPECTED}
    for k in sorted(leaks, key=str):
        print("LEAK", k, "|", leaks[k][:100])
    print("errors:", g.errors()[:3])
    print("PASS no leaked globals" if not leaks else "FAIL %d leaked globals" % len(leaks))
    sys.exit(1 if leaks else 0)


if __name__ == "__main__":
    main()
