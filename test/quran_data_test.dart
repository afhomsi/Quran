import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/mushaf_repository.dart';
import 'package:hifz/data/quarters.dart';
import 'package:hifz/data/quran_repository.dart';

void main() {
  group('bundled text', () {
    final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());

    test('has 114 surahs and 6236 ayahs', () {
      expect(surahs, hasLength(114));
      expect(surahs.fold<int>(0, (n, s) => n + s.ayahCount), 6236);
    });

    test('has no hidden spaces that would split a word in two', () {
      // A thin space inside فَٱدَّٰرَٰٔتُمۡ (2:72) once made the recitation
      // check hear one word as two and report a mistake.
      for (final s in surahs) {
        for (final a in s.ayahs) {
          expect(a, isNot(matches(RegExp('[\u00A0\u2000-\u200F\u202F]'))));
        }
      }
    });

    test('surah metadata is parsed', () {
      expect(surahs.first.number, 1);
      expect(surahs.first.ayahCount, 7);
      expect(surahs.first.isMeccan, isTrue);
      expect(surahs[1].ayahCount, 286);
      expect(surahs[1].isMeccan, isFalse);
    });
  });

  group('mushaf layout', () {
    final mushaf = parseMushaf(File(mushafLayoutAssetPath).readAsStringSync());
    final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());

    test('has 604 pages of at most 15 lines', () {
      expect(mushaf.pages, hasLength(604));
      expect(mushaf.pages.every((p) => p.lines.length <= 15), isTrue);
      expect(mushaf.pages.where((p) => p.lines.length == 15).length, 602);
    });

    test('places every ayah, in order, with one end marker each', () {
      final words = mushaf.pages.expand((p) => p.words).toList();
      final ends = words.where((w) => w.isAyahEnd).map((w) => w.ayah).toList();
      expect(ends, hasLength(6236));
      for (var i = 1; i < ends.length; i++) {
        expect(ends[i - 1] < ends[i], isTrue, reason: '${ends[i]}');
      }
    });

    test('finds pages of surahs, juz and ayat', () {
      expect(mushaf.surahStartPage(1), 1);
      expect(mushaf.surahStartPage(2), 2);
      expect(mushaf.surahStartPage(18), 293);
      expect(mushaf.surahStartPage(114), 604);
      expect(mushaf.juzStartPage(2), 22);
      expect(mushaf.juzStartPage(30), 582);
      expect(mushaf.pageOf(const AyahRef(2, 255)), 42);
    });

    test('knows the juz of each page', () {
      expect(mushaf.juzOfPage(1), 1);
      expect(mushaf.juzOfPage(21), 1);
      expect(mushaf.juzOfPage(22), 2);
      expect(mushaf.juzOfPage(604), 30);
    });

    test('splits into 240 quarters that line up with the juz', () {
      expect(rubStarts, hasLength(240));
      for (var j = 0; j < 30; j++) {
        expect(rubStarts[j * 8], juzStarts[j]);
      }
      for (var i = 1; i < rubStarts.length; i++) {
        expect(rubStarts[i - 1] < rubStarts[i], isTrue);
      }
      expect(mushaf.rubStartPage(1), 1);
      expect(mushaf.rubStartPage(2), 5);
      expect(mushaf.hizbOfPage(1), 1);
      expect(mushaf.hizbOfPage(22), 3);
      expect(mushaf.hizbOfPage(604), 60);
    });

    test('quarters start where the mushaf text puts the ۞ sign', () {
      // The text marks every quarter that does not open a surah.
      final marked = {
        for (final s in surahs)
          for (var a = 0; a < s.ayahCount; a++)
            if (s.ayahs[a].contains('۞')) AyahRef(s.number, a + 1),
      };
      expect(rubStarts.where((r) => r.ayah != 1).toSet(), marked);
    });

    test('has a surah name line for every surah', () {
      final headers = mushaf.pages
          .expand((p) => p.lines)
          .whereType<SurahNameLine>()
          .map((l) => l.surah);
      expect(headers, List.generate(114, (i) => i + 1));
    });
  });
}
