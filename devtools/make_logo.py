"""Builds the project logo images for CurseForge / Wago / WoWInterface / GitHub from the in-game art.

    python devtools/make_logo.py

The logo is the splash-screen lockup (sword, "Peggle", "ADD-ON FOR WOW", "FOREVER") cut from
images/banner2_2.tga with the same rectangle the add-on uses (e.artCut["splashBringer"], rows 368-550).
Writes to branding/ (never packaged):
    logo_transparent.png   the lockup alone, trimmed, transparent background
    logo_400.png           400x400 square avatar on the Dark Portal art (CurseForge / Wago / WoWI)
    logo_400_plain.png     400x400 square avatar on a plain dark-blue glow
    banner_1280x640.png    wide banner (GitHub social preview, project page header)
"""
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "branding")
IMG = os.path.join(ROOT, "images")


def lockup():
    art = Image.open(os.path.join(IMG, "banner2_2.tga")).convert("RGBA")
    logo = art.crop((60, 368, 512, 550))
    return logo.crop(logo.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox())


def glow(size, center, radius, color, strength):
    """Soft radial light (RGBA) to sit behind the logo."""
    w, h = size
    layer = Image.new("RGBA", size, color + (0,))
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    cx, cy = center
    d.ellipse((cx - radius[0], cy - radius[1], cx + radius[0], cy + radius[1]), fill=int(255 * strength))
    mask = mask.filter(ImageFilter.GaussianBlur(max(radius) * .45))
    layer.putalpha(mask)
    return layer


def vignette(img, amount=.65):
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).ellipse((-w * .15, -h * .15, w * 1.15, h * 1.15), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(min(w, h) * .18))
    dark = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    inv = ImageChops.invert(mask).point(lambda v: int(v * amount))
    return Image.composite(dark, img, inv)


def shadow(logo, offset=(0, 6), blur=8, alpha=200):
    pad = blur * 3
    s = Image.new("RGBA", (logo.width + pad * 2, logo.height + pad * 2), (0, 0, 0, 0))
    a = logo.getchannel("A").point(lambda v: v * alpha // 255)
    s.paste((0, 0, 0, 255), (pad + offset[0], pad + offset[1]), a)
    return s.filter(ImageFilter.GaussianBlur(blur)), pad


def scene_background(size, blur):
    bg = Image.open(os.path.join(IMG, "bg18.tga")).convert("RGBA")   # Dark Portal (same art as the splash screen)
    scale = max(size[0] / bg.width, size[1] / bg.height)
    bg = bg.resize((int(bg.width * scale + .5), int(bg.height * scale + .5)), Image.LANCZOS)
    left, top = (bg.width - size[0]) // 2, (bg.height - size[1]) // 2
    bg = bg.crop((left, top, left + size[0], top + size[1])).filter(ImageFilter.GaussianBlur(blur))
    return Image.blend(bg, Image.new("RGBA", size, (8, 14, 30, 255)), .3)


def plain_background(size):
    bg = Image.new("RGBA", size, (10, 18, 38, 255))
    bg.alpha_composite(glow(size, (size[0] // 2, size[1] // 2), (size[0] * .55, size[1] * .55), (40, 80, 150), .9))
    return bg


def place(canvas, logo, width, cy=None):
    logo = logo.resize((width, int(logo.height * width / logo.width + .5)), Image.LANCZOS)
    x = (canvas.width - logo.width) // 2
    y = (canvas.height - logo.height) // 2 if cy is None else cy - logo.height // 2
    canvas.alpha_composite(glow(canvas.size, (canvas.width // 2, y + logo.height // 2),
                                (logo.width * .5, logo.height * .6), (255, 190, 90), .45))
    sh, pad = shadow(logo, blur=max(4, width // 50))
    canvas.alpha_composite(sh, (x - pad, y - pad))
    canvas.alpha_composite(logo, (x, y))
    return canvas


def main():
    os.makedirs(OUT, exist_ok=True)
    logo = lockup()
    logo.save(os.path.join(OUT, "logo_transparent.png"))

    sq = vignette(scene_background((400, 400), 3))
    place(sq, logo, 392).convert("RGB").save(os.path.join(OUT, "logo_400.png"))
    place(plain_background((400, 400)), logo, 392).convert("RGB").save(os.path.join(OUT, "logo_400_plain.png"))

    wide = vignette(scene_background((1280, 640), 4), .55)
    place(wide, logo, 760).convert("RGB").save(os.path.join(OUT, "banner_1280x640.png"))
    print("wrote", ", ".join(sorted(os.listdir(OUT))), "to", OUT)


if __name__ == "__main__":
    main()
