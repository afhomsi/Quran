import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/data/jalala.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/study.dart';
import 'package:hifz/settings/app_settings.dart';

void main() {
  test('finds the name of Allah 2699 times, and ٱللَّهُمَّ 5 times', () {
    final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
    var names = 0;
    for (final s in surahs) {
      for (final a in s.ayahs) {
        names += ayahWords(a).where((w) => jalalaIn(w) != null).length;
      }
    }
    expect(names, 2699 + 5);
  });

  test('colours the name only, not what comes before or after it', () {
    String name(String w) {
      final span = jalalaIn(w)!;
      return w.substring(span.start, span.end);
    }

    expect(name('ٱللَّهِ'), 'ٱللَّهِ');
    expect(name('وَٱللَّهُ'), 'ٱللَّهُ');
    expect(name('بِٱللَّهِۚ'), 'ٱللَّهِ');
    expect(name('فَلِلَّهِ'), 'لِلَّهِ');
    expect(name('ءَآللَّهُ'), 'آللَّهُ');
    expect(name('۞ٱللَّهُ'), 'ٱللَّهُ');
    expect(name('ٱللَّهُمَّ'), 'ٱللَّهُمَّ');
  });

  test('leaves words that only share the letters', () {
    for (final w in [
      'خِلَٰلِهِۦ',
      'ٱللَّهۡوِ',
      'ٱللَّهَبِ',
      'لَلۡهُدَىٰ',
      'يُضۡلِلۡهُ',
    ]) {
      expect(jalalaIn(w), isNull, reason: w);
    }
  });

  test('the chosen colour is saved', () {
    const s = AppSettings(jalalaColor: JalalaColor.green);
    expect(AppSettings.fromJson(s.toJson()).jalalaColor, JalalaColor.green);
    expect(const AppSettings().jalalaColors, isTrue);
  });
}
