import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/mushaf_repository.dart';
import 'package:hifz/data/mushaf_text.dart';
import 'package:hifz/features/mushaf/mushaf_page_view.dart';

/// The width of [text] in em of the mushaf font.
double _em(String text) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(fontFamily: mushafFont, fontSize: 100),
    ),
    textDirection: TextDirection.rtl,
  )..layout();
  return painter.width / 100;
}

void main() {
  testWidgets('every line of the mushaf fits the line width, so all the '
      'text is one size', (tester) async {
    final font = FontLoader(mushafFont)
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/madina.otf').readAsBytesSync(),
          ),
        ),
      );
    await font.load();
    final mushaf = parseMushaf(File(mushafLayoutAssetPath).readAsStringSync());
    var widest = 0.0;
    final tooWide = <String>[];
    for (var n = 1; n <= mushafPageCount; n++) {
      var i = 0;
      for (final line in mushaf.page(n).lines) {
        i++;
        if (line is! AyahLine) continue;
        var width = (line.words.length - 1) * mushafWordGapEm;
        for (final w in line.words) {
          width += _em(
            w.isAyahEnd
                ? ayahEndMark(w.ayah.ayah)
                : mushafDisplayText(w.text.replaceAll('۞', '')),
          );
        }
        if (width > widest) widest = width;
        if (width > mushafLineWidthEm) tooWide.add('page $n line $i: $width');
      }
    }
    expect(tooWide, isEmpty);
    // Not much wider than needed either, or all the text is set smaller.
    expect(widest, greaterThan(mushafLineWidthEm - 0.2));
  });
}
