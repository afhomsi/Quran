"""Builds the bundled mushaf assets from upstream open data.

Inputs (download and unpack the pub.dev archive first):
  quran_library 5.0.1  assets/jsons/qpc-v4.json.gz            word glyphs (QUL, QPC v4)
                       assets/jsons/qpc_v4_ayah_info.json.gz  15-line page layout
                       assets/fonts/quran_fonts_qfc4/QCF4NNN_COLOR-Regular.ttf.gz
                                                              colour page fonts
                       assets/fonts/surah-name-v4.ttf         surah name calligraphy

Usage:
  pip install fonttools
  python3 tool/build_mushaf_data.py <quran_library dir>

Outputs:
  assets/mushaf/layout.json  604 pages; each page is a list of lines:
      {"t": "s", "s": 2}            surah name line
      {"t": "b", "s": 2}            basmala line
      {"t": "a", "c": 0, "w": [...]} ayah line, c = centered,
          w = [[surah, ayah, word, glyph, isAyahEnd], ...]
  assets/mushaf/fonts/pNNN.woff  page fonts with our own colours, see below
  assets/fonts/surah_names.ttf   surah name calligraphy, unchanged
"""

import gzip
import json
import io
import shutil
import sys
from pathlib import Path

from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._g_l_y_f import Glyph, GlyphCoordinates
from fontTools.ttLib.tables.C_O_L_R_ import LayerRecord
from fontTools.ttLib.tables.C_P_A_L_ import Color
from fontTools.ttLib.tables.ttProgram import Program

# Glyphs that the QPC v4 word data and the QCF4 page fonts disagree on.
# Each value is the glyph the page font actually contains.
GLYPH_FIXES = {
    "19:38:5": "ﳘ",
    "24:19:2": "ﱂ",
}

ql = Path(sys.argv[1])
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

# The colour fonts draw each ayah number as a medallion in four layers:
# centre bud, petals, inner fill and outline with the digits. Palette slots:
#   0-9, 14, 15  letters (tajweed classes; one colour without tajweed)
#   10    centre bud      11 petals      12 inner fill
#   13    outline and digits; a few letters and stop marks use it too, so
#         it keeps the letter colour
#   16    ring (added below)
# The ring between the outline's edges is left empty in the fonts. We add a
# layer under the others that fills the outline's outer edge, so the ring
# comes out green as in the printed mushaf.
RING = 16

# Palettes, in the order lib/data/page_fonts.dart picks them.
MEDALLION = {
    "light": {10: "5b6b3a", 11: "cfc4a0", 12: "faf5ea", RING: "6e7d47"},
    "dark": {10: "a9b77a", 11: "8a835f", 12: "1f2419", RING: "3e4a2a"},
}


def color(hex_rgb):
    r, g, b = (int(hex_rgb[i : i + 2], 16) for i in (0, 2, 4))
    return Color(red=r, green=g, blue=b, alpha=255)


def palette(source, letters, medallion):
    """Letter colours from [source] (or [letters] for all), our medallion."""
    entries = [color(letters) if letters else source[i] for i in range(16)]
    entries.append(color("000000"))
    for slot, value in medallion.items():
        entries[slot] = color(value)
    return entries


def add_rings(font):
    glyf, colr = font["glyf"], font["COLR"]
    for base, layers in list(colr.ColorLayers.items()):
        # Medallions have an inner fill; the outline is the top layer.
        if 12 not in [l.colorID for l in layers]:
            continue
        outline = glyf[layers[-1].name]
        coords, ends, flags = outline.getCoordinates(glyf)
        contours, start = [], 0
        for end in ends:
            xs = [p[0] for p in coords[start : end + 1]]
            ys = [p[1] for p in coords[start : end + 1]]
            contours.append((start, end, min(xs), min(ys), max(xs), max(ys)))
            start = end + 1

        def inside(a, b):
            return a is not b and b[2] <= a[2] and b[3] <= a[3] and a[4] <= b[4] and a[5] <= b[5]

        # Outer edges: contours that no other contour surrounds. Some glyphs
        # hold two medallions.
        outer = [c for c in contours if not any(inside(c, o) for o in contours)]
        ring = Glyph()
        ring.numberOfContours = len(outer)
        ring.coordinates = GlyphCoordinates(
            [p for c in outer for p in coords[c[0] : c[1] + 1]]
        )
        ring.flags = bytearray(f for c in outer for f in flags[c[0] : c[1] + 1])
        ring.endPtsOfContours = []
        n = -1
        for c in outer:
            n += c[1] - c[0] + 1
            ring.endPtsOfContours.append(n)
        ring.program = Program()
        ring.program.fromBytecode(b"")
        name = layers[-1].name + ".ring"
        glyf[name] = ring
        ring.recalcBounds(glyf)
        font["hmtx"][name] = font["hmtx"][layers[-1].name]
        colr.ColorLayers[base] = [LayerRecord(name, RING)] + layers
    font.setGlyphOrder(glyf.glyphOrder)


def page_font(page):
    path = ql / f"assets/fonts/quran_fonts_qfc4/QCF4{page:03d}_COLOR-Regular.ttf.gz"
    font = TTFont(io.BytesIO(gzip.open(path).read()))
    add_rings(font)
    cpal = font["CPAL"]
    # Upstream palettes: 0 tajweed on light, 1 tajweed on dark.
    tajweed_light, tajweed_dark = cpal.palettes[0], cpal.palettes[1]
    cpal.palettes = [
        palette(None, "000000", MEDALLION["light"]),
        palette(None, "eae6da", MEDALLION["dark"]),
        palette(tajweed_light, None, MEDALLION["light"]),
        palette(tajweed_dark, None, MEDALLION["dark"]),
    ]
    cpal.numPaletteEntries = 17
    cpal.version = 0
    font.flavor = "woff"
    font.save(out / "fonts" / f"p{page:03d}.woff")


(out / "fonts").mkdir(exist_ok=True)
for p in range(1, 605):
    page_font(p)

fonts = out.parent / "fonts"
fonts.mkdir(exist_ok=True)
shutil.copy(ql / "assets/fonts/surah-name-v4.ttf", fonts / "surah_names.ttf")
print("ok")
