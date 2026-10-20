"""Generates the ability effect textures into images/ (white + alpha so the game can tint them).

    python devtools/make_fx_art.py
Outputs (32-bit uncompressed TGA, power-of-two sizes): fx_glow, fx_ring, fx_bolt, fx_flare, fx_rune, fx_slash, fx_bar, fx_circle
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "images")


def save(name, alpha):
    h, w = alpha.shape
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[..., :3] = 255
    rgba[..., 3] = np.clip(alpha * 255, 0, 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(os.path.join(OUT, name + ".tga"))


def grid(w, h):
    y, x = np.mgrid[0:h, 0:w]
    return (x + .5) / w * 2 - 1, (y + .5) / h * 2 - 1


# soft round glow
x, y = grid(128, 128)
r = np.sqrt(x * x + y * y)
save("fx_glow", np.clip(1 - r, 0, 1) ** 2.2)

# shockwave ring: bright thin front, soft inner haze
x, y = grid(256, 256)
r = np.sqrt(x * x + y * y)
ring = np.exp(-((r - .86) / .055) ** 2) + .55 * np.exp(-((r - .80) / .14) ** 2) * (r < .9)
haze = .14 * np.clip(1 - r / .86, 0, 1)
save("fx_ring", np.clip(ring + haze, 0, 1) * np.clip((1 - r) * 12, 0, 1))

# lightning/beam body: hot core + wide glow, tapered ends (horizontal, tinted in game)
x, y = grid(256, 64)
core = np.exp(-(y / .11) ** 2)
glow = .55 * np.exp(-(y / .42) ** 2)
taper = np.clip((1 - np.abs(x)) * 7, 0, 1)
save("fx_bolt", np.clip(core + glow, 0, 1) * taper)

# four-point flare for impacts
x, y = grid(128, 128)
r = np.sqrt(x * x + y * y)
h_arm = np.exp(-(y / .045) ** 2) * np.clip(1 - np.abs(x), 0, 1) ** 1.5
v_arm = np.exp(-(x / .045) ** 2) * np.clip(1 - np.abs(y), 0, 1) ** 1.5
dg = .5 * (np.exp(-((x - y) / .06) ** 2) + np.exp(-((x + y) / .06) ** 2)) * np.clip(1 - r, 0, 1) ** 2
center = np.exp(-(r / .16) ** 2)
save("fx_flare", np.clip(h_arm + v_arm + dg + center, 0, 1))

# voodoo rune circle with hexagram and tick marks
S = 256
im = Image.new("L", (S, S), 0)
d = ImageDraw.Draw(im)
c = S / 2
for rad, wd in ((118, 5), (96, 3)):
    d.ellipse([c - rad, c - rad, c + rad, c + rad], outline=255, width=wd)
pts = [(c + 96 * math.cos(math.radians(a)), c + 96 * math.sin(math.radians(a))) for a in range(-90, 270, 60)]
for tri in (pts[0::2], pts[1::2]):
    d.polygon(tri, outline=255)
for k in range(24):
    a = math.radians(k * 15)
    d.line([c + 106 * math.cos(a), c + 106 * math.sin(a), c + 116 * math.cos(a), c + 116 * math.sin(a)], fill=255, width=3)
im = im.filter(ImageFilter.GaussianBlur(1.1))
save("fx_rune", np.asarray(im, dtype=np.float32) / 255 * 1.2)

# crescent slash
S = 128
im = Image.new("L", (S, S), 0)
d = ImageDraw.Draw(im)
d.ellipse([8, 8, S - 8, S - 8], fill=255)
d.ellipse([26, 2, S + 14, S - 14], fill=0)
im = im.filter(ImageFilter.GaussianBlur(2.2))
save("fx_slash", np.asarray(im, dtype=np.float32) / 255)

# horizontal glow bar (shield): bright core, soft edges, faded ends
x, y = grid(256, 32)
bar = (np.exp(-(y / .25) ** 2) + .4 * np.exp(-(y / .8) ** 2)) * np.clip((1 - np.abs(x)) * 10, 0, 1)
save("fx_bar", np.clip(bar, 0, 1))
# round mask for portraits (white disc, soft 1px edge) used with a MaskTexture
x, y = grid(128, 128)
r = np.sqrt(x * x + y * y)
save("fx_circle", np.clip((1 - r) * 64, 0, 1))
print("wrote fx textures to", OUT)
