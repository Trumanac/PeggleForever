"""Headless runner for the PeggleForever addon.

Loads the real addon Lua files against a fake WoW API (wowmock.lua) using lupa,
fires the client's login events, drives the UI and can render screenshots.

    python devtools/run.py boot                 # load addon, report Lua errors
    python devtools/run.py shot out.png         # boot + screenshot of the window

Scenarios (clicking through the UI, playing levels) live in devtools/scenarios.py.
"""
import hashlib
import os
import re
import sys

from lupa.lua51 import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON_DIR = os.path.dirname(HERE)
ADDON = os.path.basename(ADDON_DIR)


class Game:
    def __init__(self, player_name=None):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        mock = HERE.replace("\\", "/") + "/wowmock.lua"
        self.M = self.lua.eval("(function() return assert(loadfile(%r))() end)()" % mock)
        if player_name:
            self.M["playerName"] = player_name
        self.M.loadAddon(ADDON_DIR.replace("\\", "/"), ADDON)
        self.G = self.lua.globals()

    # ---- lifecycle
    def login(self):
        self.M.login(ADDON)

    def advance(self, seconds, fps=60):
        dt = 1.0 / fps
        for _ in range(int(seconds * fps)):
            self.M.advance(dt)

    # ---- helpers
    def frame(self, name):
        return self.G[name]

    def errors(self):
        return [(e["where"], e["msg"]) for _, e in self.M.errors.items()]

    def clear_errors(self):
        self.lua.eval("function(M) M.errors = {} end")(self.M)

    def missing(self):
        return {k: v for k, v in self.M.missing.items()}

    def click(self, frame, button="LeftButton"):
        self.M.click(frame, button)

    def eval(self, code):
        return self.lua.eval(code)

    def exec(self, code):
        return self.lua.execute(code)

    # ---- rendering
    def screenshot(self, path, crop="window", scale=1.0):
        from PIL import Image, ImageChops, ImageDraw, ImageFont

        self.lua.eval("function(M) M.invalidate() end")(self.M)
        items = self.M.renderList()
        W, H = int(self.M.screen["w"]), int(self.M.screen["h"])
        img = Image.new("RGBA", (W, H), (20, 20, 24, 255))
        cache, fonts = {}, {}

        def resolve_tex(p):
            if not p:
                return None
            q = str(p).replace("\\", "/")
            marker = "interface/addons/%s/" % ADDON.lower()
            if q.lower().startswith(marker):
                base = os.path.join(ADDON_DIR, q[len(marker):])
                for ext in ("", ".tga", ".blp", ".png"):
                    if os.path.isfile(base + ext):
                        return base + ext
                d, b = os.path.dirname(base), os.path.basename(base).lower()
                if os.path.isdir(d):
                    for f in os.listdir(d):
                        if os.path.splitext(f)[0].lower() == b or f.lower() == b:
                            return os.path.join(d, f)
            return None

        def load(p):
            if p not in cache:
                real = resolve_tex(p)
                try:
                    cache[p] = Image.open(real).convert("RGBA") if real else None
                except Exception:
                    cache[p] = None
            return cache[p]

        def placeholder(p, w, h):
            hh = int(hashlib.md5(str(p).encode()).hexdigest()[:6], 16)
            col = (60 + (hh >> 16) % 150, 60 + (hh >> 8) % 150, 60 + hh % 150, 255)
            im = Image.new("RGBA", (max(w, 1), max(h, 1)), col)
            ImageDraw.Draw(im).rectangle([0, 0, im.width - 1, im.height - 1], outline=(255, 255, 255, 160))
            return im

        def font(size):
            size = max(int(size), 6)
            if size not in fonts:
                try:
                    fonts[size] = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", size)
                except Exception:
                    fonts[size] = ImageFont.load_default()
            return fonts[size]

        def tint(im, rgb, a):
            if rgb:
                ch = im.split()
                im = Image.merge("RGBA", tuple(ch[i].point(lambda v, m=rgb[i]: int(v * m)) for i in range(3)) + (ch[3],))
            if a < 1:
                ch = im.split()
                im = Image.merge("RGBA", ch[:3] + (ch[3].point(lambda v: int(v * a)),))
            return im

        clip = [None]

        def paste(layer, x, y):
            c = clip[0]
            if c:
                cx0, cy0, cx1, cy1 = c
                nx0, ny0 = max(x, cx0), max(y, cy0)
                nx1, ny1 = min(x + layer.width, cx1), min(y + layer.height, cy1)
                if nx1 <= nx0 or ny1 <= ny0:
                    return
                layer = layer.crop((nx0 - x, ny0 - y, nx1 - x, ny1 - y))
                x, y = nx0, ny0
            img.paste(layer, (x, y), layer)

        for it in items.values():
            l, b, r, t = float(it["l"]), float(it["b"]), float(it["r"]), float(it["t"])
            x0, y0, x1, y1 = int(round(l)), int(round(H - t)), int(round(r)), int(round(H - b))
            w, h = x1 - x0, y1 - y0
            alpha = float(it["a"])
            kind = it["kind"]
            clip[0] = None
            if it["ccl"] is not None:
                clip[0] = (int(round(float(it["ccl"]))), int(round(H - float(it["cct"]))), int(round(float(it["ccr"]))), int(round(H - float(it["ccb"]))))
            if w <= 0 or h <= 0 or w > 4000 or h > 4000:
                continue
            if kind == "backdrop":
                bd, col = it["bd"], it["color"]
                bg = bd["bgFile"] if bd else None
                if bg:
                    base = load(bg)
                    layer = base.resize((w, h)) if base else placeholder(bg, w, h)
                    rgb = [float(col[i]) for i in (1, 2, 3)] if col else None
                    paste(tint(layer, rgb, alpha * (float(col[4]) if col else 1)), x0, y0)
                elif col:
                    layer = Image.new("RGBA", (w, h), tuple(int(float(col[i]) * 255) for i in (1, 2, 3)) + (int(255 * float(col[4]) * alpha),))
                    paste(layer, x0, y0)
                if bd and bd["edgeFile"]:
                    bc = it["border"]
                    rgb = tuple(int(float(bc[i]) * 255) for i in (1, 2, 3)) if bc else (255, 255, 255)
                    ImageDraw.Draw(img).rectangle([x0, y0, x1 - 1, y1 - 1], outline=rgb + (255,), width=2)
            elif kind == "tex":
                col = it["color"]
                if col:
                    layer = Image.new("RGBA", (w, h), tuple(int(float(col[i]) * 255) for i in (1, 2, 3)) + (int(255 * float(col[4])),))
                    layer = tint(layer, None, alpha)
                else:
                    src = load(it["path"]) if it["path"] else None
                    if src is None and it["path"] and "white8x8" in str(it["path"]).lower():
                        src = Image.new("RGBA", (8, 8), (255, 255, 255, 255))
                    if src is None:
                        layer = placeholder(it["path"] or it["atlas"], w, h)
                    else:
                        coord = it["coord"]
                        if coord:
                            cs = [float(v) for v in coord.values()]
                            sw, sh = src.size
                            if len(cs) >= 8:
                                # corner order UL, LL, UR, LR -> PIL quad order NW, SW, SE, NE (handles rotated/flipped art)
                                ul, ll, ur, lr = (cs[0], cs[1]), (cs[2], cs[3]), (cs[4], cs[5]), (cs[6], cs[7])
                                quad = (ul[0] * sw, ul[1] * sh, ll[0] * sw, ll[1] * sh, lr[0] * sw, lr[1] * sh, ur[0] * sw, ur[1] * sh)
                                src = src.transform((w, h), Image.QUAD, quad, Image.BICUBIC)
                            else:
                                cl, cr, ct, cb = cs[:4]
                                box = (int(cl * sw), int(ct * sh), max(int(cr * sw), int(cl * sw) + 1), max(int(cb * sh), int(ct * sh) + 1))
                                src = src.crop(box)
                        layer = src.resize((w, h))
                    vc = it["vcolor"]
                    rgb = [float(vc[i]) for i in (1, 2, 3)] if vc else None
                    layer = tint(layer, rgb, alpha * (float(vc[4]) if vc else 1))
                    if it["desat"]:
                        g = layer.convert("L")
                        layer = Image.merge("RGBA", (g, g, g, layer.split()[3]))
                if it["masked"]:
                    from PIL import ImageDraw as _ID
                    m = Image.new("L", layer.size, 0)
                    _ID.Draw(m).ellipse([0, 0, layer.width - 1, layer.height - 1], fill=255)
                    ch = layer.split()
                    layer = Image.merge("RGBA", ch[:3] + (Image.composite(ch[3], Image.new("L", layer.size, 0), m),))
                rot = float(it["rot"] or 0)
                if rot:
                    import math
                    big = layer.rotate(math.degrees(rot), expand=True, resample=Image.BICUBIC)
                    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
                    x0, y0 = cx - big.width // 2, cy - big.height // 2
                    x1, y1 = x0 + big.width, y0 + big.height
                    layer = big
                    if x0 < 0 or y0 < 0 or x1 > W or y1 > H:
                        continue
                if it["blend"] == "ADD":
                    # additive blend: scale colour by the layer's alpha so transparent highlights add nothing
                    rgb_layer = ImageChops.multiply(layer.convert("RGB"), Image.merge("RGB", (layer.split()[3],) * 3))
                    add = ImageChops.add(img.crop((x0, y0, x1, y1)).convert("RGB"), rgb_layer)
                    img.paste(add.convert("RGBA"), (x0, y0))
                else:
                    paste(layer, x0, y0)
            elif kind == "text":
                if clip[0] and not (clip[0][1] <= (y0 + y1) / 2 <= clip[0][3] and clip[0][0] <= (x0 + x1) / 2 <= clip[0][2]):
                    continue
                d = ImageDraw.Draw(img)
                f = font(float(it["size"]))
                tc = it["color"]
                color = (tuple(int(float(tc[i]) * 255) for i in (1, 2, 3)) if tc else (255, 210, 0)) + (int(255 * alpha),)
                lines = [re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", ln) for ln in str(it["text"]).replace("|n", "\n").split("\n")]
                y = y0 + (h - len(lines) * f.size * 1.15) / 2
                for ln in lines:
                    tw = d.textlength(ln, font=f)
                    jh = it["justH"]
                    x = x0 if jh == "LEFT" else (x1 - tw if jh == "RIGHT" else x0 + (w - tw) / 2)
                    d.text((x, y), ln, font=f, fill=color)
                    y += f.size * 1.15
        if crop == "window":
            wl, wb, wr, wt = [float(v) for v in self.M.layout(self.G["PeggleWindow"])]
            img = img.crop((max(int(wl) - 20, 0), max(int(H - wt) - 20, 0), min(int(wr) + 20, W), min(int(H - wb) + 20, H)))
        if scale != 1.0:
            img = img.resize((int(img.width * scale), int(img.height * scale)))
        img.convert("RGB").save(path)
        return path


def report(g, limit=8):
    errs = g.errors()
    print("Lua errors: %d" % len(errs))
    seen = {}
    for where, msg in errs:
        key = msg.split("\n")[0]
        seen.setdefault(key, [where, msg, 0])[2] += 1
    for key, (where, msg, count) in list(seen.items())[:limit]:
        print("--- %s (x%d)" % (where, count))
        print(msg[:1200])
    miss = g.missing()
    if miss:
        print("Unimplemented mock methods used (%d): %s" % (len(miss), ", ".join("%s x%d" % kv for kv in sorted(miss.items()))))


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "boot"
    g = Game()
    g.login()
    g.advance(0.5)
    report(g)
    if cmd == "shot":
        print("saved", g.screenshot(sys.argv[2] if len(sys.argv) > 2 else "shot.png"))


if __name__ == "__main__":
    main()
