"""Builds the bundled mushaf assets from upstream open data.

Inputs (download and unpack the pub.dev archives first):
  quran_library 5.0.1  assets/jsons/qpc-v4.json.gz            word glyphs (QUL, QPC v4)
                       assets/jsons/qpc_v4_ayah_info.json.gz  15-line page layout
  qcf_quran 0.0.5      assets/fonts/qcf4/QCF4NNN_X-Regular.woff  page fonts

Usage:
  python3 tool/build_mushaf_data.py <quran_library dir> <qcf_quran dir>

Outputs:
  assets/mushaf/layout.json  604 pages; each page is a list of lines:
      {"t": "s", "s": 2}            surah name line
      {"t": "b", "s": 2}            basmala line
      {"t": "a", "c": 0, "w": [...]} ayah line, c = centered,
          w = [[surah, ayah, word, glyph, isAyahEnd], ...]
  assets/mushaf/fonts/pNNN.woff  page fonts, unchanged
"""

import gzip
import json
import shutil
import sys
from pathlib import Path

# Glyphs that the QPC v4 word data and the QCF4 page fonts disagree on.
# Each value is the glyph the page font actually contains.
GLYPH_FIXES = {
    "19:38:5": "ﳘ",
    "24:19:2": "ﱂ",
}

ql, qcf = Path(sys.argv[1]), Path(sys.argv[2])
out = Path(__file__).resolve().parent.parent / "assets" / "mushaf"

words = json.load(gzip.open(ql / "assets/jsons/qpc-v4.json.gz"))
info = json.load(gzip.open(ql / "assets/jsons/qpc_v4_ayah_info.json.gz"))

by_id = {}
ayah_len = {}
for loc, w in words.items():
    s, a, n = map(int, loc.split(":"))
    by_id[w["id"]] = (s, a, n, GLYPH_FIXES.get(loc, w["text"]))
    ayah_len[(s, a)] = max(ayah_len.get((s, a), 0), n)

pages = [[] for _ in range(604)]
for line in sorted(info, key=lambda l: (l["page_number"], l["line_number"])):
    page = pages[line["page_number"] - 1]
    kind = line["line_type"]
    if kind == "surah_name":
        page.append({"t": "s", "s": int(line["surah_number"])})
    elif kind == "basmallah":
        # The layout leaves surah_number empty on basmala lines; it always
        # follows the surah name line.
        page.append({"t": "b", "s": page[-1]["s"]})
    else:
        ws = []
        for i in range(int(line["first_word_id"]), int(line["last_word_id"]) + 1):
            s, a, n, g = by_id[i]
            ws.append([s, a, n, g, int(n == ayah_len[(s, a)])])
        page.append({"t": "a", "c": int(line["is_centered"]), "w": ws})

assert sum(len(l.get("w", [])) for p in pages for l in p) == len(words)
assert all(len(p) <= 15 for p in pages)

out.mkdir(parents=True, exist_ok=True)
with open(out / "layout.json", "w", encoding="utf-8") as f:
    json.dump(pages, f, ensure_ascii=False, separators=(",", ":"))

(out / "fonts").mkdir(exist_ok=True)
for p in range(1, 605):
    shutil.copy(
        qcf / f"assets/fonts/qcf4/QCF4{p:03d}_X-Regular.woff",
        out / "fonts" / f"p{p:03d}.woff",
    )
print("ok")
