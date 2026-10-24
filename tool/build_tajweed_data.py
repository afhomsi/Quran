"""Writes assets/mushaf/tajweed.json: the tajweed rules on each word.

The colour page fonts (assets/mushaf/fonts/pNNN.woff, see
build_mushaf_data.py) draw each word in layers, and each layer takes a
palette slot named after a tajweed rule. This reads which slots every word
of the layout uses, so the app can name the rules of an ayah or a word.

Output: one list per surah, one entry per ayah, each a list of
[word position, slot, slot, ...] for the words that carry a rule.

Usage: python3 tool/build_tajweed_data.py  (needs fonttools and brotli)
"""

import json
from pathlib import Path

from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
LAYOUT = ROOT / "assets/mushaf/layout.json"
QURAN = ROOT / "assets/quran/hafs_uthmani.json"
FONTS = ROOT / "assets/mushaf/fonts"
OUT = ROOT / "assets/mushaf/tajweed.json"

# Palette slots that mark a rule; lib/data/tajweed.dart names them.
RULE_SLOTS = {1, 2, 3, 4, 5, 6, 7, 8, 9, 15}


def main():
    layout = json.loads(LAYOUT.read_text())
    rules = {}
    for number, page in enumerate(layout, start=1):
        font = TTFont(FONTS / f"p{number:03d}.woff")
        cmap = font.getBestCmap()
        layers = font["COLR"].ColorLayers
        for line in page:
            for surah, ayah, position, glyph, is_end in line.get("w", []):
                if is_end:
                    continue
                slots = set()
                for ch in glyph:
                    name = cmap.get(ord(ch))
                    for layer in layers.get(name, []):
                        if layer.colorID in RULE_SLOTS:
                            slots.add(layer.colorID)
                if slots:
                    rules.setdefault((surah, ayah), []).append(
                        [position, *sorted(slots)]
                    )
    quran = json.loads(QURAN.read_text())
    out = [
        [rules.get((s["id"], a), []) for a in range(1, len(s["ayahs"]) + 1)]
        for s in quran
    ]
    OUT.write_text(json.dumps(out, separators=(",", ":")))


if __name__ == "__main__":
    main()
