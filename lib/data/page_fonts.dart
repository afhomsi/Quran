import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'woff.dart';

/// Colour palettes in the page fonts, as written by
/// tool/build_mushaf_data.py. Every palette draws the ayah numbers as green
/// medallions; they differ in the colour of the letters.
enum MushafPalette {
  /// Black letters, for a light page.
  light,

  /// Light letters, for night mode.
  dark,

  /// Tajweed colours on a light page.
  tajweedLight,

  /// Tajweed colours on a dark page.
  tajweedDark,
}

/// Loads the QCF font of each mushaf page on first use. Every page has its
/// own font, and the word glyphs only make sense in that page's font.
class PageFonts {
  PageFonts(this._bundle);

  final AssetBundle _bundle;
  final _loading = <String, Future<String>>{};
  final _ready = <String, Future<void>>{};

  static String familyFor(int page, MushafPalette palette) =>
      'QCF_P${page.toString().padLeft(3, '0')}_${palette.index}';

  /// Returns the font family for [page] once it is ready to draw.
  Future<String> load(int page, MushafPalette palette) =>
      _loading[familyFor(page, palette)] ??= _load(page, palette);

  /// Completes once [page] can be drawn: its own font plus the page 1 font,
  /// which draws the basmala. Returns the same future on every call, so a
  /// [FutureBuilder] does not restart.
  Future<void> ready(int page, MushafPalette palette) =>
      _ready[familyFor(page, palette)] ??= Future.wait([
        load(page, palette),
        load(1, palette),
      ]);

  Future<String> _load(int page, MushafPalette palette) async {
    final family = familyFor(page, palette);
    final path = 'assets/mushaf/fonts/p${page.toString().padLeft(3, '0')}.woff';
    final woff = await _bundle.load(path);
    final ttf = selectPalette(
      woffToSfnt(
        woff.buffer.asUint8List(woff.offsetInBytes, woff.lengthInBytes),
      ),
      palette.index,
    );
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(ttf)));
    await loader.load();
    return family;
  }
}

/// Makes [palette] the first colour palette of the font in [sfnt], in place.
/// Text engines always draw colour fonts with the first palette.
///
/// Spec: https://learn.microsoft.com/typography/opentype/spec/cpal
Uint8List selectPalette(Uint8List sfnt, int palette) {
  final data = ByteData.sublistView(sfnt);
  final numTables = data.getUint16(4);
  for (var i = 0; i < numTables; i++) {
    final record = 12 + i * 16;
    if (data.getUint32(record) != 0x4350414C) continue; // 'CPAL'
    final offset = data.getUint32(record + 8);
    final length = data.getUint32(record + 12);
    final numPalettes = data.getUint16(offset + 4);
    if (palette >= numPalettes) {
      throw RangeError.range(palette, 0, numPalettes - 1, 'palette');
    }
    // colorRecordIndices[] starts after the 12 byte header.
    data.setUint16(offset + 12, data.getUint16(offset + 12 + palette * 2));
    data.setUint32(record + 4, _checksum(data, offset, length));
    return sfnt;
  }
  throw const FormatException('Font has no colour palettes');
}

int _checksum(ByteData data, int offset, int length) {
  var sum = 0;
  for (var i = 0; i < length; i += 4) {
    var word = 0;
    for (var j = 0; j < 4; j++) {
      word = word << 8 | (i + j < length ? data.getUint8(offset + i + j) : 0);
    }
    sum = (sum + word) & 0xFFFFFFFF;
  }
  return sum;
}

final pageFontsProvider = Provider<PageFonts>((ref) => PageFonts(rootBundle));
