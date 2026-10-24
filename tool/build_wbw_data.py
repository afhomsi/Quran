"""Writes assets/quran/wbw_en.json.gz: the English meaning of every word.

Source: the npm package @kmaslesa/holy-quran-word-by-word-full-data (ISC),
which carries Quran.com's word-by-word English. Words are matched to the
mushaf layout by ayah and position, so `[surah-1][ayah-1][position-1]` is
the meaning of the word drawn at that position.

Usage: python3 tool/build_wbw_data.py path/to/package/data.json
"""

import gzip
import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LAYOUT = ROOT / "assets/mushaf/layout.json"
QURAN = ROOT / "assets/quran/hafs_uthmani.json"
OUT = ROOT / "assets/quran/wbw_en.json.gz"


def main(source):
    meanings = {}
    for page in json.loads(Path(source).read_text()):
        for ayah in page["ayahs"]:
            for w in ayah["words"] or []:
                if w and w["char_type_name"] == "word":
                    s, a = map(int, w["parentAyahVerseKey"].split(":"))
                    meanings[(s, a, w["position"])] = w["translation"]["text"]
    counts = Counter()
    for page in json.loads(LAYOUT.read_text()):
        for line in page:
            for s, a, _, _, is_end in line.get("w", []):
                if not is_end:
                    counts[(s, a)] += 1
    out = [
        [
            [meanings.get((s["id"], a, p), "") for p in range(1, counts[(s["id"], a)] + 1)]
            for a in range(1, len(s["ayahs"]) + 1)
        ]
        for s in json.loads(QURAN.read_text())
    ]
    raw = json.dumps(out, ensure_ascii=False, separators=(",", ":")).encode()
    OUT.write_bytes(gzip.compress(raw, 9, mtime=0))


if __name__ == "__main__":
    main(sys.argv[1])
