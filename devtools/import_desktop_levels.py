"""Imports levels from the desktop "Peggle - World of Warcraft Edition" into this addon.

  python devtools/import_desktop_levels.py [path to the game folder]

Reads main.pak (XOR 0xF7 container), decodes the binary level (.dat) files and writes
  LevelsDesktop.lua           (rows in the addon's level format, appended to config.LEVELS)
  images/bgNN.tga, bgNN_thumb.tga  (level artwork)
Moving pegs and brick rings are imported with their movement (line / circle / tilted ellipse / rotating ring);
those whose path leaves the board stay static. Bumpers, portals and decoration are skipped.
Desktop coordinates -> addon: x * .85, y = 464 - y * .85 (addon y runs bottom-up).
"""
import io
import math
import os
import struct
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.abspath(os.path.join(HERE, '..'))
GAME = sys.argv[1] if len(sys.argv) > 1 else r"C:\Program Files (x86)\PopCap Games\Peggle - World of Warcraft Edition"

# (file stem, display name)  -- names come from the game's stages.cfg
LEVELS = [
    ('hogger', 'Wanted: Hogger'),
    ('storm', 'Valley of Heroes'),
    ('onyx', 'Deep Breath'),
    ('rag', 'Too Soon, Executus'),
    ('darkportal', 'The Dark Portal'),
    ('sigg', 'Arcane Affinity'),
    ('kael', 'Prince Sunstrider'),
    ('illidude', 'The Betrayer'),
    ('nexus', 'Ley of the Land'),
    ('lichking', 'The Traitor King'),
]
FIRST_INDEX = 14
SCALE = .85
BOARD_H = 464
BRICK_RADII = [10, 20, 30, 40, 60, 80, 100, 120, 140, 160, 180]
TILE = 26.0   # nominal tile length in addon px


def read_pak(path):
    d = bytes(b ^ 0xF7 for b in open(path, 'rb').read())
    pos = 8
    ents = []
    while True:
        fl = d[pos]
        pos += 1
        if fl & 0x80:
            break
        n = d[pos]
        pos += 1
        name = d[pos:pos + n].decode('latin1')
        pos += n
        size, = struct.unpack('<i', d[pos:pos + 4])
        pos += 12
        ents.append((name.replace('\\', '/'), size))
    files = {}
    for name, size in ents:
        files[name.lower()] = d[pos:pos + size]
        pos += size
    return files


def split_entries(d):
    import re
    ms = [m.start() + 9 for m in re.finditer(rb'\x01\x00\x00\x00[\x01-\x0f]\x00\x00\x00', d[9:])]
    ms.append(len(d))
    return [(d[a + 4], d[a:b]) for a, b in zip(ms, ms[1:])]


def f32(b):
    return struct.unpack('<f', b)[0]


def read_fields(F, G, data):
    """Optional movement fields in bit order: bits 0,1,4 are int16, bits 2,3 floats, bit 7 a byte; G bits 2,3 floats."""
    ints, floats, p = [], [], 0
    for bit in range(8):
        if not F & (1 << bit):
            continue
        if bit in (0, 1, 4):
            ints.append(struct.unpack('<H', data[p:p + 2])[0])
            p += 2
        elif bit in (2, 3):
            floats.append(struct.unpack('<f', data[p:p + 4])[0])
            p += 4
        elif bit == 7:
            p += 1
    for bit in range(8):
        if G & (1 << bit) and bit in (2, 3, 6):
            floats.append(struct.unpack('<f', data[p:p + 4])[0])
            p += 4
    return ints, floats, p == len(data)


def fit_mover(mt, anchor, period, F, G, ints, floats, px, py):
    """Work out the motion shape from the fields and the object's starting position (px, py), desktop coords."""
    ints = list(ints)
    if F & 1 and ints:
        ints.pop(0)                         # time offset, irrelevant: the start position says it all
    r1 = ints[0] if ints else 0
    r2 = ints[1] if len(ints) > 1 else None
    if not r1:
        return None
    ax, ay = anchor
    dx, dy = px - ax, -(py - ay)            # y-up
    cands = [0.0]
    for f in floats:
        cands += [f, f - math.pi, f + math.pi]
    best = None
    if mt == 2:                             # back-and-forth line through the anchor, half-length r1
        for rot in cands:
            along = dx * math.cos(rot) + dy * math.sin(rot)
            perp = -dx * math.sin(rot) + dy * math.cos(rot)
            err = abs(perp) + max(0.0, abs(along) - r1)
            if best is None or err < best[0]:
                best = (err, rot, along)
        if best[0] > 3:
            return None
        return dict(shape='line', anchor=anchor, a=r1, rot=best[1], s0=max(-r1, min(r1, best[2])), period=period)
    b = r2 if r2 else r1
    for rot in cands:
        x = dx * math.cos(rot) + dy * math.sin(rot)
        y = -dx * math.sin(rot) + dy * math.cos(rot)
        err = abs(math.hypot(x / r1, y / b) - 1.0) * min(r1, b)
        if best is None or err < best[0]:
            best = (err, rot, math.atan2(y / b, x / r1))
    if best[0] > 3:
        return None
    return dict(shape='ellipse', anchor=anchor, a=r1, b=b, rot=best[1], theta0=best[2], period=period)


def parse_level(d):
    """-> list of
        ('peg', x, y, mover)                      round peg, mover is None or a dict from fit_mover
        ('arc', x, y, A, B, C, D, mover)          curved brick: sweep, thickness, radius, polar angle (deg)
        ('bar', x, y, B, L, ang, mover)           straight brick
    in desktop coordinates."""
    out = []
    for t, b in split_entries(d):
        fl = struct.unpack('<I', b[8:12])[0]
        body = b[12:]
        if t == 5 and (fl & 0xff) == 0xe4:
            x, y = struct.unpack('<ff', body[-12:-4])
            out.append(('peg', x, y, None))
        elif t == 5 and (fl & 0xff) == 0xec:
            k = 7 if body[1] == 0x22 else 6
            mt = body[k]
            anchor = struct.unpack('<ff', body[k + 1:k + 9])
            period, F, G = struct.unpack('<HBB', body[k + 9:k + 13])
            if not G & 0x20:
                continue
            px, py = struct.unpack('<ff', body[-14:-6])
            ints, floats, ok = read_fields(F, G, body[k + 13:-14])
            mover = fit_mover(mt, anchor, period, F, G, ints, floats, px, py) if ok else None
            out.append(('peg', px, py, mover))
        elif t == 6 and fl in (0x400018e4, 0x400010e4, 0x400008e4):
            p = 0
            if fl & 0x800:
                p += 4
            if fl & 0x1000:
                p += 4
            p += 4
            x, y = struct.unpack('<ff', body[p:p + 8])
            rest = body[p + 8:]
            tail = rest[-4:]
            if tail == b'\x01\x02\x00\x03' and len(rest) == 19:
                B, L, ang = struct.unpack('<fff', rest[-16:-4])
                out.append(('bar', x, y, B, L, ang, None))
            elif tail == b'\x03\x04\x00\x07' and len(rest) in (22, 23):
                A, B, C, D = struct.unpack('<ffff', rest[-20:-4])
                out.append(('arc', x, y, A, B, C, D, None))
            elif tail == b'\x03\x04\x00\x07' and len(rest) == 18:
                A, C, D = struct.unpack('<fff', rest[-16:-4])
                out.append(('arc', x, y, A, 20.0, C, D, None))
        elif t == 6 and (fl & 0xff) == 0xec:
            p = 0
            if fl & 0x800:
                p += 4
            if fl & 0x1000:
                p += 4
            k = p + (7 if body[p + 1] == 0x22 else 6)
            mt = body[k]
            anchor = struct.unpack('<ff', body[k + 1:k + 9])
            period, F, G = struct.unpack('<HBB', body[k + 9:k + 13])
            px, py = struct.unpack('<ff', body[-36:-28])
            ints, floats, ok = read_fields(F, G, body[k + 13:-36])
            mover = fit_mover(mt, anchor, period, F, G, ints, floats, px, py) if ok else None
            A, B, C, D = struct.unpack('<ffff', body[-20:-4])
            out.append(('arc', px, py, A, B, C, D, mover))
    return out


def nearest_radius(r):
    return min(BRICK_RADII, key=lambda v: abs(v - r))


def phase_delay(frac, flags):
    return int(round((frac % 1.0) * 400)) * 10 + flags


def board_xy(x, y):
    return x * SCALE, BOARD_H - y * SCALE


def path_points(m, n=24):
    """addon-space points along a mover's path"""
    pts = []
    ax, ay = m['anchor']
    for i in range(n):
        th = 2 * math.pi * i / n
        if m['shape'] == 'line':
            s = m['a'] * math.cos(th)
            dx, dy = s * math.cos(m['rot']), s * math.sin(m['rot'])
        else:
            ex, ey = m['a'] * math.cos(th), m['b'] * math.sin(th)
            dx = ex * math.cos(m['rot']) - ey * math.sin(m['rot'])
            dy = ex * math.sin(m['rot']) + ey * math.cos(m['rot'])
        pts.append(board_xy(ax + dx, ay - dy))
    return pts


def mover_inside(m):
    return all(6 <= x <= 548 and 12 <= y <= BOARD_H - 8 for x, y in path_points(m))


def mover_fields(m, brick=False, brick_rot=0.0):
    """-> (ani, x, y, time, delay, v1, v2, v3, v4) for an addon row (x, y in addon px)"""
    T = max(1.0, m['period'] / 100.0)
    ax, ay = m['anchor']
    if m['shape'] == 'line':
        d = (math.cos(m['rot']), math.sin(m['rot']))             # y-up direction
        sx, sy = ax - m['a'] * d[0], ay + m['a'] * d[1]
        t0 = (m['s0'] + m['a']) / (2.0 * m['a'])
        f = math.acos(max(-1.0, min(1.0, 1 - 2 * t0))) / (2 * math.pi)
        x, y = board_xy(sx, sy)
        return (1, round(x, 1), round(y, 1), round(T, 2), phase_delay(f, 3), 0, 0, round(math.degrees(m['rot']), 1), round(2 * m['a'] * SCALE, 1))
    f = m['theta0'] / (2 * math.pi)
    x, y = board_xy(ax, ay)
    v1, v2 = round(m['a'] - 8.5, 1), round(m['b'] - 8.5, 1)
    tilt = round(math.degrees(m['rot']), 1)
    if brick:
        # keep the brick's own angle relative to where it sits on the orbit
        delta = round((brick_rot - math.degrees(m['theta0'])) % 360, 1)
        return (5, round(x, 1), round(y, 1), round(T, 2), phase_delay(f, 1), v1, v2, tilt, delta)
    return (2, round(x, 1), round(y, 1), round(T, 2), phase_delay(f, 1), v1, v2, tilt, 0)


def to_addon(objs):
    """-> rows (objtype, x, y, enc, ani, time, delay, v1, v2, v3, v4); objtype 0 peg, 1 curved brick, 2 straight brick"""
    rows = []

    def add(kind, x, y, enc=0):
        ax, ay = board_xy(x, y)
        if ax < 6 or ax > 548 or ay < 10 or ay > BOARD_H - 6:
            return
        rows.append((kind, round(ax, 1), round(ay, 1), enc, 0, 0, 0, 0, 0, 0, 0))

    for o in objs:
        if o[0] == 'peg':
            m = o[3]
            if m and mover_inside(m):
                ani, x, y, tm, dl, v1, v2, v3, v4 = mover_fields(m)
                rows.append((0, x, y, 0, ani, tm, dl, v1, v2, v3, v4))
            else:
                add(0, o[1], o[2])
        elif o[0] == 'bar':
            _, x, y, B, L, ang, m = o
            n = max(1, int(round(L * SCALE / TILE)))
            th = math.radians(ang)
            rot = int(round((-ang - 90) % 360))
            for i in range(n):
                s = (i - (n - 1) / 2.0) * (L / n)
                add(2, x + math.cos(th) * s, y + math.sin(th) * s, 100000 + rot)
        else:
            _, x, y, A, B, C, D, m = o
            Dr = math.radians(D)
            cx, cy = x - C * math.cos(Dr), y + C * math.sin(Dr)
            arc_len = C * math.radians(abs(A))
            n = 1 if m else max(1, int(round(arc_len * SCALE / TILE)))
            ra = C * SCALE
            if ra > 260:
                kind, rad = 2, 0
            else:
                kind, rad = 1, nearest_radius(ra)
            for i in range(n):
                di = D + (i - (n - 1) / 2.0) * (A / n)
                dr = math.radians(di)
                px, py = cx + C * math.cos(dr), cy - C * math.sin(dr)
                rot = int(round(di % 360))
                enc = (rad + 100) * 1000 + rot if kind == 1 else 100000 + rot
                if m and m['shape'] == 'ellipse' and mover_inside(m):
                    ani, mx, my, tm, dl, v1, v2, v3, v4 = mover_fields(m, brick=True, brick_rot=rot)
                    rows.append((kind, mx, my, enc, ani, tm, dl, v1, v2, v3, v4))
                else:
                    add(kind, px, py, enc)
    # drop near-duplicates among the static objects (same kind within 5px)
    kept = []
    for r in rows:
        if r[4] == 0 and any(k[4] == 0 and k[0] == r[0] and abs(k[1] - r[1]) < 5 and abs(k[2] - r[2]) < 5 for k in kept):
            continue
        kept.append(r)
    return kept


ART_INSET = {'kael': 44}   # artwork with soft white edges


def art_box(art, inset=3):
    """bounding box of the real picture: edges that are one flat colour (white / grey / black padding) are trimmed"""
    import numpy as np
    im = np.array(art.convert('RGB')).astype(float)
    g = im.mean(2)
    H, W = g.shape
    padding = (im.min(2) > 232) | (im.max(2) < 20)        # white / black padding pixels

    def is_pad(std, frac):
        return std < 14 or frac > .6

    rs, cs = g.std(1), g.std(0)
    rp, cp = padding.mean(1), padding.mean(0)

    def first(std, frac):
        run = 0
        for i in range(len(std)):
            if is_pad(std[i], frac[i]):
                run = 0
            else:
                run += 1
                if run >= 3:
                    return i - 2
        return 0
    l, t = first(cs, cp), first(rs, rp)
    r, b = W - 1 - first(cs[::-1], cp[::-1]), H - 1 - first(rs[::-1], rp[::-1])
    # a little inset hides the soft fringe, then crop to the board's aspect ratio around the centre
    l, t, r, b = l + inset, t + inset, r - inset, b - inset
    w, h = r - l, b - t
    want = 554.0 / BOARD_H
    if w / h > want:
        nw = int(h * want)
        l += (w - nw) // 2
        r = l + nw
    else:
        nh = int(w / want)
        t += (h - nh) // 2
        b = t + nh
    return l, t, r, b


def save_art(n, art, rows, inset=3):
    """bgNN.tga: the picture without its padding, placed like the existing backgrounds (rows 43..468 of 512)."""
    crop = art.crop(art_box(art, inset))
    bg = crop.resize((512, 426), Image.LANCZOS).convert('RGBA')
    sheet = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
    sheet.paste(bg, (0, 43))
    sheet.save(os.path.join(ADDON, 'images', 'bg%d.tga' % n))
    # thumbnail: the whole playfield squashed to 128x128 with the pegs drawn on it
    th = crop.resize((128, 128), Image.LANCZOS).convert('RGBA')
    dr = ImageDraw.Draw(th)
    for kind, x, y, enc, *_ in rows:
        px, py = x / 554 * 128, (BOARD_H - y) / BOARD_H * 128
        col = (90, 150, 255, 255) if kind == 0 else (60, 110, 230, 255)
        r = 1.6 if kind == 0 else 1.8
        dr.ellipse([px - r, py - r, px + r, py + r], fill=col)
    th.save(os.path.join(ADDON, 'images', 'bg%d_thumb.tga' % n))


# ---------------------------------------------------------------- extra content
# Levels that came out sparse get extra pegs, brick arcs and moving groups placed in free space
# (deterministic: seeded by the level name).
EXTRAS = {
    'onyx':   dict(fill_to=84, arcs=[(210, 80), (160, 70), (240, 60)], orbits=[(58, 7, 9.0), (46, 6, 7.0)], sliders=[(80, 3, 6.0), (70, 3, 7.0)]),
    'hogger': dict(orbits=[(38, 5, 10.0)], sliders=[(70, 3, 6.0)]),
    'storm':  dict(orbits=[(50, 6, 9.0)], sliders=[(60, 3, 6.0)]),
    'sigg':   dict(orbits=[(52, 6, 9.0)], sliders=[(60, 3, 6.0)]),
    'kael':   dict(orbits=[(48, 6, 8.0)], sliders=[(60, 3, 6.0)]),
    'illidude': dict(orbits=[(34, 4, 8.0)], sliders=[(70, 3, 6.0)]),
}


def occupied(rows):
    """points (addon px) that placed objects must stay away from, including the paths of moving ones"""
    pts = []
    for kind, x, y, enc, ani, tm, dl, v1, v2, v3, v4 in rows:
        if ani in (2, 5):
            a, b, tilt = (v1 + 8.5) * SCALE, (v2 + 8.5) * SCALE, math.radians(v3)
            for i in range(16):
                th = 2 * math.pi * i / 16
                ex, ey = a * math.cos(th), b * math.sin(th)
                pts.append((x + ex * math.cos(tilt) - ey * math.sin(tilt), y + ex * math.sin(tilt) + ey * math.cos(tilt)))
        elif ani == 1:
            ang = math.radians(v3)
            for i in range(9):
                pts.append((x + v4 * i / 8 * math.cos(ang), y + v4 * i / 8 * math.sin(ang)))
        else:
            pts.append((x, y))
    return pts


def blocked(x, y):
    """the area under the cannon: a peg up there can never be reached by the ball"""
    return y > BOARD_H - 120 and abs(x - 277) < 120


def clearance(pts, x, y):
    if blocked(x, y):
        return 0
    return min((math.hypot(x - px, y - py) for px, py in pts), default=999)


def add_extras(stem, rows):
    spec = EXTRAS.get(stem)
    if not spec:
        return rows
    import random
    rng = random.Random(stem)
    rows = list(rows)
    pts = occupied(rows)

    def free_spot(radius_needed, margin, ring_r=0, tries=1500):
        best = None
        for _ in range(tries):
            x = rng.uniform(margin, 554 - margin)
            y = rng.uniform(margin + 50, BOARD_H - margin - 20)
            c = clearance(pts, x, y)
            ring = all(not blocked(x + radius_needed * math.cos(k), y + radius_needed * math.sin(k)) for k in (0, 1, 2, 3, 4, 5)) if not ring_r else all(not blocked(x + ring_r * math.cos(k), y + ring_r * math.sin(k)) for k in (0, 1, 2, 3, 4, 5))
            if c >= radius_needed and ring and (best is None or c > best[0] + 4):
                best = (c, x, y)
        return best

    # brick arcs
    for R, sweep in spec.get('arcs', []):
        for _ in range(500):
            cx, cy = rng.uniform(40, 514), rng.uniform(60, 420)
            a0 = rng.uniform(0, 360)
            n = int(R * math.radians(sweep) / 26)
            tiles = []
            ok = n >= 4
            rad = nearest_radius(R)
            for i in range(n):
                th = a0 + sweep * (i + .5) / n
                x, y = cx + R * math.cos(math.radians(th)), cy + R * math.sin(math.radians(th))
                if not (24 <= x <= 530 and 40 <= y <= BOARD_H - 24) or clearance(pts, x, y) < 32:
                    ok = False
                    break
                tiles.append((1, round(x, 1), round(y, 1), (rad + 100) * 1000 + int(round(th)) % 360, 0, 0, 0, 0, 0, 0, 0))
            if ok:
                rows += tiles
                pts += [(t[1], t[2]) for t in tiles]
                break
    # orbiting rings of pegs
    for R, count, period in spec.get('orbits', []):
        spot = free_spot(R + 22, R + 18, R)
        if not spot:
            continue
        _, cx, cy = spot
        for i in range(count):
            rows.append((0, round(cx, 1), round(cy, 1), 0, 2, period, phase_delay(i / float(count), 1), round(R / SCALE - 8.5, 1), round(R / SCALE - 8.5, 1), 0, 0))
        pts += [(cx + R * math.cos(2 * math.pi * i / 16), cy + R * math.sin(2 * math.pi * i / 16)) for i in range(16)]
    # horizontal sliders
    for A, count, period in spec.get('sliders', []):
        best = None
        for _ in range(900):
            cx, cy = rng.uniform(A + 30, 554 - A - 30), rng.uniform(80, BOARD_H - 50)
            c = min(clearance(pts, cx + A * k / 4.0, cy) for k in range(-4, 5))
            if c >= 30 and (best is None or c > best[0] + 3):
                best = (c, cx, cy)
        if not best:
            continue
        _, cx, cy = best
        for i in range(count):
            rows.append((0, round(cx - A, 1), round(cy, 1), 0, 1, period, phase_delay(i / (2.0 * count), 3), 0, 0, 0.0, round(2 * A, 1)))
        pts += [(cx + A * k / 4.0, cy) for k in range(-4, 5)]
    # fill remaining space with static pegs up to the target
    target = spec.get('fill_to', 0)
    guard = 0
    while target and sum(1 for r in rows if r[0] == 0) < target and guard < 4000:
        guard += 1
        x, y = rng.uniform(24, 530), rng.uniform(60, BOARD_H - 28)
        if clearance(pts, x, y) >= 34:
            rows.append((0, round(x, 1), round(y, 1), 0, 0, 0, 0, 0, 0, 0, 0))
            pts.append((x, y))
    return rows


def main():
    files = read_pak(os.path.join(GAME, 'main.pak'))
    lua = ['-- Levels imported from the desktop "Peggle - World of Warcraft Edition" (see devtools/import_desktop_levels.py).',
           '-- Row format matches Levels.lua (id, animation, object, x, y, rotation, time, delay, v1..v4).',
           'local AddOn, config = ...', '']
    names = []
    for k, (stem, title) in enumerate(LEVELS):
        n = FIRST_INDEX + k
        data = files['levels/%s.dat' % stem]
        objs = parse_level(data)
        rows = add_extras(stem, to_addon(objs))
        art = None
        for ext in ('jpg', 'jp2'):
            key = 'levels/%s.%s' % (stem, ext)
            if key in files:
                art = Image.open(io.BytesIO(files[key])).convert('RGB')
        save_art(n, art, rows, ART_INSET.get(stem, 3))
        lua.append('config.LEVELS[%d] = {' % n)
        for i, (kind, x, y, enc, ani, tm, dl, v1, v2, v3, v4) in enumerate(rows, 1):
            lua.append('\t{%d,%d,%d,%s,%s,%d,%s,%d,%s,%s,%s,%s}%s' % (i, ani, kind, x, y, enc, tm, dl, v1, v2, v3, v4, ',' if i < len(rows) else ''))
        lua.append('}')
        names.append('config.LEVEL_NAMES[%d] = "%s"' % (n, title))
        moving = sum(1 for r in rows if r[4])
        print(n, title, len(objs), '->', len(rows), 'rows,', moving, 'moving')
    lua.append('')
    lua += names
    open(os.path.join(ADDON, 'LevelsDesktop.lua'), 'w', encoding='utf-8').write('\n'.join(lua) + '\n')


if __name__ == '__main__':
    main()
