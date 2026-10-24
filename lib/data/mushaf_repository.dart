import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mushaf_models.dart';
import 'quarters.dart';

const mushafLayoutAssetPath = 'assets/mushaf/layout.json';
const mushafPageCount = 604;

/// First ayah of each of the 30 juz.
const juzStarts = [
  AyahRef(1, 1), AyahRef(2, 142), AyahRef(2, 253), AyahRef(3, 93), //
  AyahRef(4, 24), AyahRef(4, 148), AyahRef(5, 82), AyahRef(6, 111),
  AyahRef(7, 88), AyahRef(8, 41), AyahRef(9, 93), AyahRef(11, 6),
  AyahRef(12, 53), AyahRef(15, 1), AyahRef(17, 1), AyahRef(18, 75),
  AyahRef(21, 1), AyahRef(23, 1), AyahRef(25, 21), AyahRef(27, 56),
  AyahRef(29, 46), AyahRef(33, 31), AyahRef(36, 28), AyahRef(39, 32),
  AyahRef(41, 47), AyahRef(46, 1), AyahRef(51, 31), AyahRef(58, 1),
  AyahRef(67, 1), AyahRef(78, 1),
];

/// The 604-page Madinah mushaf (Hafs), line by line as printed.
class Mushaf {
  Mushaf(this.pages) {
    for (final p in pages) {
      for (final w in p.words) {
        _pageOfAyah.putIfAbsent(w.ayah, () => p.number);
      }
    }
  }

  final List<MushafPage> pages;
  final _pageOfAyah = <AyahRef, int>{};

  MushafPage page(int number) => pages[number - 1];

  /// The page where [ayah] starts.
  int pageOf(AyahRef ayah) => _pageOfAyah[ayah]!;

  int surahStartPage(int surah) => pageOf(AyahRef(surah, 1));

  int juzStartPage(int juz) => pageOf(juzStarts[juz - 1]);

  int rubStartPage(int rub) => pageOf(rubStarts[rub - 1]);

  /// The juz that the first ayah of [page] belongs to.
  int juzOfPage(int page) => _indexOf(juzStarts, page);

  /// The juz that [ayah] belongs to.
  int juzOfAyah(AyahRef ayah) =>
      juzStarts.lastIndexWhere((s) => !(ayah < s)) + 1;

  /// The quarter (1 to 240) that the first ayah of [page] belongs to.
  int rubOfPage(int page) => _indexOf(rubStarts, page);

  /// The hizb (1 to 60) that the first ayah of [page] belongs to.
  int hizbOfPage(int page) => (rubOfPage(page) - 1) ~/ 4 + 1;

  /// 1-based index of the last of [starts] at or before the top of [page].
  int _indexOf(List<AyahRef> starts, int page) {
    final first = this.page(page).firstAyah;
    return starts.lastIndexWhere((s) => !(first < s)) + 1;
  }
}

Mushaf parseMushaf(String raw) {
  final pages = <MushafPage>[];
  var number = 0;
  for (final page in jsonDecode(raw) as List) {
    number++;
    pages.add(
      MushafPage(
        number: number,
        lines: [for (final l in page as List) _parseLine(l as Map)],
      ),
    );
  }
  return Mushaf(pages);
}

MushafLine _parseLine(Map l) => switch (l['t']) {
  's' => SurahNameLine(l['s'] as int),
  'b' => BasmalaLine(l['s'] as int),
  _ => AyahLine(
    centered: l['c'] == 1,
    words: [
      for (final w in l['w'] as List)
        MushafWord(
          ayah: AyahRef(w[0] as int, w[1] as int),
          position: w[2] as int,
          glyph: w[3] as String,
          isAyahEnd: w[4] == 1,
        ),
    ],
  ),
};

final mushafProvider = FutureProvider<Mushaf>((ref) async {
  final raw = await rootBundle.loadString(mushafLayoutAssetPath);
  return parseMushaf(raw);
});
