import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/data/page_fonts.dart';
import 'package:hifz/data/woff.dart';

void main() {
  test('converts a page font from WOFF to TrueType', () {
    final woff = File('assets/mushaf/fonts/p003.woff').readAsBytesSync();
    final ttf = woffToSfnt(woff);
    final data = ByteData.sublistView(ttf);

    expect(data.getUint32(0), ByteData.sublistView(woff).getUint32(4));
    final numTables = data.getUint16(4);
    expect(numTables, ByteData.sublistView(woff).getUint16(12));

    final tables = <String, (int, int)>{};
    for (var i = 0; i < numTables; i++) {
      final r = 12 + i * 16;
      final tag = String.fromCharCodes(ttf.sublist(r, r + 4));
      tables[tag] = (data.getUint32(r + 8), data.getUint32(r + 12));
    }
    expect(tables.keys, containsAll(['head', 'cmap', 'glyf', 'hmtx']));

    // The head table carries a fixed magic number after decompression.
    final (headOffset, _) = tables['head']!;
    expect(data.getUint32(headOffset + 12), 0x5F0F3CF5);

    for (final (offset, length) in tables.values) {
      expect(offset % 4, 0);
      expect(offset + length, lessThanOrEqualTo(ttf.length));
    }
  });

  test('rejects data that is not WOFF', () {
    expect(() => woffToSfnt(Uint8List(64)), throwsFormatException);
  });

  test('picks a colour palette of a page font', () {
    final woff = File('assets/mushaf/fonts/p001.woff').readAsBytesSync();
    int firstPaletteStart(Uint8List ttf) {
      final data = ByteData.sublistView(ttf);
      for (var i = 0; i < data.getUint16(4); i++) {
        final r = 12 + i * 16;
        if (String.fromCharCodes(ttf.sublist(r, r + 4)) == 'CPAL') {
          return data.getUint16(data.getUint32(r + 8) + 12);
        }
      }
      throw StateError('no CPAL');
    }

    final light = firstPaletteStart(selectPalette(woffToSfnt(woff), 0));
    final dark = firstPaletteStart(selectPalette(woffToSfnt(woff), 1));
    expect(light, 0);
    expect(dark, 17);
    expect(
      () => selectPalette(woffToSfnt(woff), MushafPalette.values.length),
      throwsRangeError,
    );
  });
}
