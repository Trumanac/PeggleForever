"""Check the add-on and build the release zip (nothing in the add-on folder is changed).

    python devtools/package.py            # checks + devtools/dist/PeggleForever-<version>.zip
    python devtools/package.py --check    # checks only

The zip holds one top-level PeggleForever/ folder with only what the game needs plus the docs:
no devtools/, archive/ or PLAN.md. Checks: every TOC file exists, the TOC version matches the
CHANGELOG, every file referenced in the Lua as "...\\images\\<name>" / "...\\sounds\\<name>" exists, and
the add-on boots in the headless mock with no Lua errors.
"""
import os, re, subprocess, sys, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
NAME = "PeggleForever"
DOCS = ["README.md", "NOTICE.md", "LICENSE", "CHANGELOG.md"]
# kept in the folder for reference, never shipped
EXCLUDE = {"PLAN.md"}  # archive/ and devtools/ are never collected
# source art the game cannot load (WoW reads .tga / .blp); keep it in the folder, never ship it
EXCLUDE_EXT = {".png", ".psd", ".xcf"}


def toc():
    lines = open(os.path.join(ROOT, NAME + ".toc"), encoding="utf-8-sig").read().splitlines()
    version = next((l.split(":", 1)[1].strip() for l in lines if l.startswith("## Version:")), "dev")
    files = [l.strip().replace("\\", "/") for l in lines if l.strip() and not l.startswith("#")]
    return version, files


def release_toc():
    """The TOC without the old save names (PeggleData / PeggleProfile), which development copies keep only
    to move existing progress to PeggleForeverData; in a release they would clash with the original Peggle."""
    text = open(os.path.join(ROOT, NAME + ".toc"), encoding="utf-8-sig").read()
    # same rule as the BigWigs packager: drop #@do-not-package@ ... #@end-do-not-package@ blocks
    text = re.sub(r"#@do-not-package@.*?#@end-do-not-package@\r?\n?", "", text, flags=re.S)
    assert "PeggleData" not in text and "PeggleProfile" not in text
    return text


def problems():
    out = []
    version, files = toc()
    for f in files:
        if not os.path.exists(os.path.join(ROOT, f)):
            out.append("TOC lists a missing file: " + f)
    if "## " + version not in open(os.path.join(ROOT, "CHANGELOG.md"), encoding="utf-8").read():
        out.append("CHANGELOG.md has no '## %s' section" % version)
    media = set(os.listdir(os.path.join(ROOT, "images"))) | set(os.listdir(os.path.join(ROOT, "sounds")))
    stems = {os.path.splitext(m)[0].lower() for m in media}
    for lua in [f for f in files if f.endswith(".lua")]:
        text = open(os.path.join(ROOT, lua), encoding="utf-8", errors="replace").read()
        refs = re.findall(r'artPath\s*\.\.\s*"([A-Za-z0-9_+\-]+)"(?!\s*\.\.)', text)  # whole names only
        refs += re.findall(r'\\\\(?:images|sounds)\\\\([A-Za-z0-9_+\-]+)', text)
        for ref in sorted(set(refs)):
            if ref.lower() not in stems:
                out.append("%s refers to a missing image/sound: %s" % (lua, ref))
        print("%s: %d image/sound names checked" % (lua, len(set(refs))))
    boot = subprocess.run([sys.executable, os.path.join(HERE, "run.py"), "boot"], capture_output=True, text=True)
    if "Lua errors: 0" not in boot.stdout:
        out.append("boot test failed:\n" + boot.stdout[-1500:] + boot.stderr[-1500:])
    return version, out


def shipped(version):
    _, files = toc()
    keep = set(files) | set(DOCS) | {NAME + ".toc"}
    for folder in ("images", "sounds", "Libs"):
        for base, _, names in os.walk(os.path.join(ROOT, folder)):
            for n in names:
                keep.add(os.path.relpath(os.path.join(base, n), ROOT).replace("\\", "/"))
    return sorted(f for f in keep if f not in EXCLUDE and os.path.splitext(f)[1].lower() not in EXCLUDE_EXT
                  and os.path.isfile(os.path.join(ROOT, f)))


def main():
    version, issues = problems()
    for i in issues:
        print("PROBLEM:", i)
    if issues:
        sys.exit("not packaged: fix the problems above")
    print("checks passed (version %s)" % version)
    if "--check" in sys.argv:
        return
    os.makedirs(os.path.join(HERE, "dist"), exist_ok=True)
    zpath = os.path.join(HERE, "dist", "%s-%s.zip" % (NAME, version))
    files = shipped(version)
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        for f in files:
            if f == NAME + ".toc":
                z.writestr(NAME + "/" + f, release_toc())
            else:
                z.write(os.path.join(ROOT, f), NAME + "/" + f)
    print("wrote %s (%d files, %.1f MB)" % (zpath, len(files), os.path.getsize(zpath) / 1e6))


if __name__ == "__main__":
    main()
