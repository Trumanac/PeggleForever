"""Write down what each hero voice line says (offline speech recognition), so lines can be picked by text.

    python devtools/transcribe.py <listfile.csv> <hero folder pattern> [name]
        e.g.  python devtools/transcribe.py community-listfile.csv bolvar
    -> devtools/transcripts/<name>.tsv  (FileDataID <tab> file name <tab> text); sound_candidates.py adds
       the text to SoundList.lua, and /peggle snd prints it.

Needs: pip install faster-whisper numpy, and ffmpeg on PATH. The audio is read from the Forever client
(casc_files.extract) into devtools/out/audio/ and can be deleted afterwards. Grunts and pain sounds are skipped.
Whisper mishears names now and then (e.g. "Ebon Blade"), so check by ear before relying on a line.
"""
import os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import casc_files  # noqa: E402


def main():
    listfile, pattern = sys.argv[1], sys.argv[2].lower()
    name = sys.argv[3] if len(sys.argv) > 3 else pattern
    present = set(open(os.path.join(HERE, "out", "wow_classic_beta_files.txt")).read().split())
    files = {}
    for line in open(listfile, encoding="utf-8"):
        fid, path = line.rstrip("\n").split(";", 1)
        parts = path.split("/")
        if (fid in present and path.startswith("sound/creature/") and pattern in parts[2]
                and not re.search(r"wound|death|attack|choking", parts[-1])):
            files[int(fid)] = parts[-1]
    audio = os.path.join(HERE, "out", "audio", name)
    casc_files.extract("wow_classic_beta", list(files), audio, files)

    import numpy as np
    from faster_whisper import WhisperModel
    model = WhisperModel("small.en", device="cpu", compute_type="int8")
    os.makedirs(os.path.join(HERE, "transcripts"), exist_ok=True)
    out = os.path.join(HERE, "transcripts", name + ".tsv")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        for fid in sorted(files, key=lambda i: files[i]):
            path = os.path.join(audio, "%d%s" % (fid, os.path.splitext(files[fid])[1]))
            if not os.path.exists(path):
                continue
            pcm = subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-i", path, "-f", "s16le",
                                  "-ac", "1", "-ar", "16000", "-"], capture_output=True).stdout
            segs, _ = model.transcribe(np.frombuffer(pcm, np.int16).astype(np.float32) / 32768, beam_size=3)
            text = " ".join(s.text.strip() for s in segs).replace("\t", " ")
            f.write("%d\t%s\t%s\n" % (fid, files[fid], text))
    print("wrote", out, len(files), "lines")


if __name__ == "__main__":
    main()
