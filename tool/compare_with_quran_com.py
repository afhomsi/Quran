"""Compares the bundled Quran text with Quran.com's QPC Hafs text.

Quran.com's data comes from the Quranic Universal Library (QUL). Its QPC
Hafs word-by-word text is packaged in quran_library 5.0.1
(assets/jsons/qpc-hafs-word-by-word.json.gz); download and unpack the
pub.dev archive first.

Usage:
  python3 tool/compare_with_quran_com.py <quran_library dir>

Prints every ayah whose words differ. Two differences are only how the
text is encoded and are not reported: a tatweel before a dagger alef
(ـٰ, which our text keeps so that common fonts draw it well) and the
space after ۞ or before ۩. Quran.com's كـَلَّا also carries a tatweel
for its own font; those are counted but not listed.
"""

import difflib
import gzip
import json
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
app = json.load(open(root / "assets/quran/hafs_uthmani.json", encoding="utf-8"))
words = json.load(
    gzip.open(Path(sys.argv[1]) / "assets/jsons/qpc-hafs-word-by-word.json.gz")
)

ref = {}
for w in sorted(words.values(), key=lambda w: w["id"]):
    if re.fullmatch("[٠-٩]+", w["text"]):  # ayah number
        continue
    ref.setdefault((int(w["surah"]), int(w["ayah"])), []).append(w["text"])
mine = {(s["id"], i): t for s in app for i, t in enumerate(s["ayahs"], 1)}


def norm(text):
    text = text.replace("ـٰ", "ٰ").replace("۞ ", "۞")
    text = text.replace(" ۩", "۩").replace("كـ", "ك")
    return text.split(" ")


assert sorted(ref) == sorted(mine), "ayah lists differ"
bad = 0
for key in sorted(ref):
    a, b = norm(mine[key]), norm(" ".join(ref[key]))
    if a == b:
        continue
    bad += 1
    for op, i1, i2, j1, j2 in difflib.SequenceMatcher(None, a, b).get_opcodes():
        if op != "equal":
            print(f"{key[0]}:{key[1]}  ours {' '.join(a[i1:i2])!r}  quran.com {' '.join(b[j1:j2])!r}")
print(f"{len(ref)} ayat compared, {bad} differ")
sys.exit(1 if bad else 0)
