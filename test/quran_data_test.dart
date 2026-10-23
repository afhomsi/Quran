import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/data/quran_repository.dart';

void main() {
  final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());

  test('bundled text has 114 surahs and 6236 ayahs', () {
    expect(surahs, hasLength(114));
    expect(surahs.fold<int>(0, (n, s) => n + s.ayahCount), 6236);
  });

  test('surah metadata is parsed', () {
    expect(surahs.first.number, 1);
    expect(surahs.first.ayahCount, 7);
    expect(surahs.first.isMeccan, isTrue);
    expect(surahs[1].ayahCount, 286);
    expect(surahs[1].isMeccan, isFalse);
  });
}
