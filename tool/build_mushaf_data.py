"""Builds assets/mushaf/layout.json, the 15-line page layout of the
Madinah mushaf, from upstream open data.

Inputs (download and unpack the pub.dev archive first):
  quran_library 5.0.1  assets/jsons/qpc-v4.json.gz            word ids (QUL)
                       assets/jsons/qpc_v4_ayah_info.json.gz  15-line page layout
  assets/quran/hafs_uthmani.json                              the words' text

Usage:
  python3 tool/build_mushaf_data.py <quran_library dir>

Output, 604 pages; each page is a list of lines:
  {"t": "s", "s": 2}             surah name line
  {"t": "b", "s": 2}             basmala line
  {"t": "a", "c": 0, "w": [...]} ayah line, c = centered,
      w = [[surah, ayah, word, text], ...]; the last word of an ayah is its
      number, with text "".

The pages are drawn with the DigitalKhatt New Madina font
(assets/fonts/madina.otf), so the words keep their Uthmani text.
"""

import gzip
import json
import sys
from pathlib import Path

ql = Path(sys.argv[1])
root = Path(__file__).resolve().parent.parent

quran = json.load(open(root / "assets/quran/hafs_uthmani.json", encoding="utf-8"))
words = json.load(gzip.open(ql / "assets/jsons/qpc-v4.json.gz"))
info = json.load(gzip.open(ql / "assets/jsons/qpc_v4_ayah_info.json.gz"))


def ayah_words(text):
    """The words of an ayah as lib/data/study.dart's ayahWords splits them."""
    out = []
    for w in text.split(" "):
        if not w.strip():
            continue
        # إِلۡ يَاسِينَ (37:130) is printed with a gap but is one word.
        if out and out[-1] == "إِلۡ":
            out[-1] += " " + w
        else:
            out.append(w)
    return out


by_id = {}
ayah_len = {}
for loc, w in words.items():
    s, a, n = map(int, loc.split(":"))
    by_id[w["id"]] = (s, a, n)
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
            s, a, n = by_id[i]
            text = ayah_words(quran[s - 1]["ayahs"][a - 1])
            # The layout counts the ayah number as the last word.
            assert len(text) == ayah_len[(s, a)] - 1, (s, a)
            ws.append([s, a, n, text[n - 1] if n <= len(text) else ""])
        page.append({"t": "a", "c": int(line["is_centered"]), "w": ws})

assert sum(len(l.get("w", [])) for p in pages for l in p) == len(words)
assert all(len(p) <= 15 for p in pages)

with open(root / "assets/mushaf/layout.json", "w", encoding="utf-8") as f:
    json.dump(pages, f, ensure_ascii=False, separators=(",", ":"))
print("ok")
