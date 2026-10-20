"""List the FileDataIDs a local WoW install really contains (reads the CASC storage, read-only).

    python devtools/casc_files.py [product] [out.txt]
        product: wow_classic_beta (default), wow_classic_era, wow ...
        writes one FileDataID per line (default devtools/out/<product>_files.txt)

Only files whose data is present on disk (local index hit) are listed, so every ID in the output
can be played with PlaySoundFile(id) in that client. Used by sound_candidates.py.
"""
import os, struct, sys, zlib

WOW = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", ".."))
DATA = os.path.join(WOW, "Data")


def build_config(product):
    rows = open(os.path.join(WOW, ".build.info"), encoding="utf-8").read().splitlines()
    head = [h.split("!")[0] for h in rows[0].split("|")]
    for r in rows[1:]:
        f = dict(zip(head, r.split("|")))
        if f.get("Product") == product:
            key = f["Build Key"]
            path = os.path.join(DATA, "config", key[:2], key[2:4], key)
            cfg = {}
            for line in open(path, encoding="utf-8"):
                if " = " in line:
                    k, v = line.strip().split(" = ", 1)
                    cfg[k] = v.split()
            return cfg, f.get("Version")
    raise SystemExit("product not installed: " + product)


def load_indices():
    """9-byte ekey prefix -> (archive, offset, size) from the newest .idx of each bucket."""
    newest = {}
    for name in os.listdir(os.path.join(DATA, "data")):
        if name.endswith(".idx") and len(name) == 14:
            bucket, ver = int(name[:2], 16), int(name[2:10], 16)
            if bucket not in newest or ver > newest[bucket][0]:
                newest[bucket] = (ver, name)
    idx = {}
    for _, name in newest.values():
        b = open(os.path.join(DATA, "data", name), "rb").read()
        hsize = struct.unpack_from("<I", b, 0)[0]
        pos = (8 + hsize + 15) & ~15
        esize = struct.unpack_from("<I", b, pos)[0]
        pos += 8
        for i in range(esize // 18):
            e = b[pos + i * 18: pos + i * 18 + 18]
            hi = int.from_bytes(e[9:14], "big")
            idx.setdefault(e[:9], (hi >> 30, hi & 0x3FFFFFFF, struct.unpack_from("<I", e, 14)[0]))
    return idx


def blte(data):
    assert data[:4] == b"BLTE", data[:4]
    hsize = struct.unpack_from(">I", data, 4)[0]
    if hsize == 0:
        chunks = [(len(data) - 8, None)]
        pos = 8
    else:
        count = int.from_bytes(data[9:12], "big")
        chunks = [struct.unpack_from(">II", data, 12 + i * 24) for i in range(count)]
        pos = hsize
    out = []
    for csize, _ in chunks:
        c = data[pos:pos + csize]
        pos += csize
        mode = c[:1]
        if mode == b"N":
            out.append(c[1:])
        elif mode == b"Z":
            out.append(zlib.decompress(c[1:]))
        else:  # encrypted / frame chunks are not needed for the root and encoding files
            raise ValueError("chunk mode %r" % mode)
    return b"".join(out)


def read_ekey(idx, ekey):
    loc = idx.get(ekey[:9])
    if not loc:
        return None
    arc, off, size = loc
    with open(os.path.join(DATA, "data", "data.%03d" % arc), "rb") as f:
        f.seek(off)
        return blte(f.read(size)[30:])


def parse_encoding(data):
    ck, ek = data[3], data[4]
    cpage = struct.unpack_from(">H", data, 5)[0] * 1024
    ccount = struct.unpack_from(">I", data, 9)[0]
    espec = struct.unpack_from(">I", data, 18)[0]
    pos = 22 + espec + ccount * 32
    table = {}
    for p in range(ccount):
        page = data[pos + p * cpage: pos + (p + 1) * cpage]
        i = 0
        while i + 6 + ck <= len(page):
            n = page[i]
            if n == 0:
                break
            ckey = page[i + 6: i + 6 + ck]
            table[ckey] = page[i + 6 + ck: i + 6 + ck + ek]
            i += 6 + ck + ek * n
    return table


def parse_root(data):
    """Yields (fileDataID, ckey, localeFlags)."""
    assert data[:4] == b"TSFM", data[:4]
    a, b = struct.unpack_from("<II", data, 4)
    if a == 24 or a == 0x18:  # headerSize, version, total, named, pad
        version = b
        pos = a
    else:
        version, pos = 0, 12
    while pos < len(data):
        if version >= 2:
            n, locale, f1, f2, f3 = struct.unpack_from("<IIIIB", data, pos)
            flags = f1 | f2 | (f3 << 17)
            pos += 17
        else:
            n, flags, locale = struct.unpack_from("<III", data, pos)
            pos += 12
        deltas = struct.unpack_from("<%di" % n, data, pos)
        pos += 4 * n
        fid = -1
        for i in range(n):
            fid = fid + 1 + deltas[i]
            yield fid, data[pos + i * 16: pos + i * 16 + 16], locale
        pos += 16 * n
        if not (flags & 0x10000000):
            pos += 8 * n


def extract(product, ids, outdir, names=None):
    """Writes the given FileDataIDs to outdir/<id>.<ext> (ext from names, a {id: filename} map)."""
    cfg, _ = build_config(product)
    idx = load_indices()
    enc = parse_encoding(read_ekey(idx, bytes.fromhex(cfg["encoding"][1])))
    want = set(ids)
    os.makedirs(outdir, exist_ok=True)
    done = []
    for fid, ckey, locale in parse_root(read_ekey(idx, enc[bytes.fromhex(cfg["root"][0])])):
        if fid in want and (locale & 0x2 or locale == 0xFFFFFFFF):
            e = enc.get(ckey)
            try:
                data = e and read_ekey(idx, e)
            except ValueError:
                data = None
            if data:
                ext = os.path.splitext((names or {}).get(fid, ".ogg"))[1] or ".ogg"
                open(os.path.join(outdir, "%d%s" % (fid, ext)), "wb").write(data)
                done.append(fid)
                want.discard(fid)
    return done


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "extract":  # extract <outdir> <id> [id ...]
        done = extract("wow_classic_beta", [int(i) for i in sys.argv[3:]], sys.argv[2])
        print("extracted", len(done), "of", len(sys.argv) - 3)
        return
    product = sys.argv[1] if len(sys.argv) > 1 else "wow_classic_beta"
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "out", product + "_files.txt")
    cfg, version = build_config(product)
    print("build", version, cfg.get("build-name"))
    idx = load_indices()
    print("local index entries:", len(idx))
    enc = parse_encoding(read_ekey(idx, bytes.fromhex(cfg["encoding"][1])))
    print("encoding entries:", len(enc))
    ekey = enc[bytes.fromhex(cfg["root"][0])]
    root = read_ekey(idx, ekey)
    ids, missing = set(), 0
    for fid, ckey, locale in parse_root(root):
        if not (locale & 0x2 or locale == 0xFFFFFFFF):  # enUS or all locales
            continue
        e = enc.get(ckey)
        if e and e[:9] in idx:
            ids.add(fid)
        else:
            missing += 1
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w") as f:
        f.write("\n".join(str(i) for i in sorted(ids)))
    print("files present: %d  (listed but not downloaded: %d)  -> %s" % (len(ids), missing, out))


if __name__ == "__main__":
    main()
