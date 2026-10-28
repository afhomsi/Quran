import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/recitation/arabic_normalizer.dart';
import 'package:hifz/recitation/recitation_matcher.dart';

/// Al-Fatiha as a speech recognizer writes it: plain spelling, no harakat.
const fatihaPlain =
    'بسم الله الرحمن الرحيم الحمد لله رب العالمين الرحمن الرحيم '
    'مالك يوم الدين إياك نعبد وإياك نستعين اهدنا الصراط المستقيم '
    'صراط الذين أنعمت عليهم غير المغضوب عليهم ولا الضالين';

List<String> words(String text) => text.split(' ');

void main() {
  final fatiha = parseSurahs(File(quranAssetPath).readAsStringSync()).first;
  final expected = wordsOfSurah(1, fatiha.ayahs);
  // The optional isti'adha comes first.
  const o = 5;

  test('Uthmani and plain spelling normalize to the same words', () {
    expect(normalizeWords(fatiha.ayahs.join(' ')), normalizeWords(fatihaPlain));
    expect(normalizeWord('ٱلۡعَٰلَمِينَ'), normalizeWord('العالمين'));
    expect(normalizeWord('ٱلضَّآلِّينَ'), normalizeWord('الضالين'));
  });

  test('long words may differ by one letter', () {
    expect(wordsMatch('المستقيم', 'المستقيم'), isTrue);
    expect(wordsMatch('المستقيم', 'المستقبم'), isTrue);
    expect(wordsMatch('المستقيم', 'المستقم'), isTrue);
    expect(wordsMatch('المستقيم', 'المستقييم'), isTrue);
    expect(wordsMatch('المستقيم', 'المسقيم'), isTrue);
    expect(wordsMatch('المستقيم', 'المتقم'), isFalse);
    expect(wordsMatch('المستقيم', 'الستقبم'), isFalse);
    expect(wordsMatch('رب', 'رد'), isFalse);
  });

  test('a correct recitation has no mistakes', () {
    final r = alignRecitation(expected, words(fatihaPlain));
    expect(expected, hasLength(o + 29));
    expect(r.isComplete, isTrue);
    expect(r.mistakeCount, 0);
  });

  test('stopping half way is not a mistake', () {
    final r = alignRecitation(expected, words('بسم الله الرحمن الرحيم الحمد'));
    expect(r.progress, o + 5);
    expect(r.isComplete, isFalse);
    expect(r.mistakeCount, 0);
    expect(r.words[o + 5].status, WordStatus.pending);
  });

  test('finds a wrong word', () {
    final r = alignRecitation(
      expected,
      words('بسم الله الرحمن الرحيم الحمد لله رب الناس الرحمن'),
    );
    expect(r.mistakeCount, 1);
    expect(r.words[o + 7].status, WordStatus.wrong);
    expect(r.words[o + 7].heard, 'الناس');
    expect(r.words[o + 7].ayah, 2);
  });

  test('finds a skipped word', () {
    final r = alignRecitation(
      expected,
      words('بسم الله الرحمن الحمد لله رب العالمين'),
    );
    expect(r.mistakeCount, 1);
    expect(r.words[o + 3].status, WordStatus.skipped);
    expect(r.words[o + 3].text, fatiha.ayahs[0].split(' ')[3]);
  });

  test('finds an extra word', () {
    final r = alignRecitation(
      expected,
      words('بسم الله الرحمن الرحيم الحمد الحمد لله'),
    );
    expect(r.mistakeCount, 1);
    expect(r.words[o + 4].extrasBefore, ['الحمد']);
  });

  test('holds back a mistake while the reciter is still speaking', () {
    final heard = words('بسم الله الرحمن الرحيم الحمد لله رب الناس');
    final speaking = alignRecitation(expected, heard, settled: false);
    expect(speaking.mistakeCount, 0);
    expect(speaking.words[o + 7].status, WordStatus.pending);

    final settled = alignRecitation(expected, heard);
    expect(settled.words[o + 7].status, WordStatus.wrong);
  });

  test('the isti\'adha may be said first', () {
    final r = alignRecitation(
      expected,
      words('أعوذ بالله من الشيطان الرجيم $fatihaPlain'),
    );
    expect(r.isComplete, isTrue);
    expect(r.mistakeCount, 0);
  });

  group('a surah with a basmala', () {
    final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
    final ikhlas = wordsOfSurah(112, surahs[111].ayahs);
    const plain =
        'قل هو الله أحد الله الصمد لم يلد ولم يولد ولم يكن له كفوا أحد';

    test('may be recited with the basmala', () {
      final r = alignRecitation(ikhlas, words('بسم الله الرحمن الرحيم $plain'));
      expect(r.isComplete, isTrue);
      expect(r.mistakeCount, 0);
    });

    test('may be recited without the basmala', () {
      final r = alignRecitation(ikhlas, words(plain));
      expect(r.isComplete, isTrue);
      expect(r.mistakeCount, 0);
    });

    test('has no basmala in At-Tawbah', () {
      final tawbah = wordsOfSurah(9, surahs[8].ayahs);
      expect(tawbah.where((w) => w.kind == WordKind.basmala), isEmpty);
    });
  });

  test('the basmala of the next surah is still ahead after a surah ends', () {
    final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
    final expected = wordsToRecite([
      (95, 8, surahs[94].ayahs[7]),
      (96, 1, surahs[95].ayahs[0]),
    ]);
    final r = alignRecitation(expected, surahs[94].ayahs[7].split(' '));
    expect(expected[r.end].kind, WordKind.basmala);
    // So its first word is taken for the basmala, not for «بِٱسۡمِ» of the
    // first ayah with «ٱقۡرَأۡ» left out.
    final next = alignRecitation(expected, ['بسم'], start: r.end);
    expect(next.words.where((w) => w.isMistake), isEmpty);
  });

  test('follows the reciter found again after many words were lost', () {
    // The recognizer lost ayat 2 to 5, as when it restarts, and the
    // reciter went on. The words heard are found where they are, not left
    // as extra words before ayah 2.
    final heard = words('اهدنا الصراط المستقيم صراط الذين');
    final r = alignRecitation(expected, heard, start: o + 4);
    final at = r.words.indexWhere((w) => w.ayah == 6);
    expect(r.end, at + 5);
    for (var k = at; k < at + 5; k++) {
      expect(r.words[k].status, WordStatus.correct);
    }
    expect(r.words[at].extrasBefore, isEmpty);
  });

  test('a few words heard alone do not move the reciter far ahead', () {
    final r = alignRecitation(expected, words('الرحمن الرحيم'), start: o + 4);
    // The first ayah ends with them; the third is not jumped to.
    expect(
      r.words.where((w) => w.ayah >= 3 && w.status != WordStatus.pending),
      isEmpty,
    );
  });

  test('still finds a word the reciter added', () {
    final r = alignRecitation(
      expected,
      words('بسم الله الرحمن الرحيم و الحمد لله رب العالمين'),
    );
    expect(r.mistakeCount, 1);
  });
}
