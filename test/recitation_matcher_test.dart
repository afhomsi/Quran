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
  final expected = wordsOfAyahs(fatiha.ayahs);

  test('Uthmani and plain spelling normalize to the same words', () {
    expect(normalizeWords(fatiha.ayahs.join(' ')), normalizeWords(fatihaPlain));
    expect(normalizeWord('ٱلۡعَٰلَمِينَ'), normalizeWord('العالمين'));
    expect(normalizeWord('ٱلضَّآلِّينَ'), normalizeWord('الضالين'));
  });

  test('a correct recitation has no mistakes', () {
    final r = alignRecitation(expected, words(fatihaPlain));
    expect(expected, hasLength(29));
    expect(r.isComplete, isTrue);
    expect(r.mistakeCount, 0);
  });

  test('stopping half way is not a mistake', () {
    final r = alignRecitation(expected, words('بسم الله الرحمن الرحيم الحمد'));
    expect(r.progress, 5);
    expect(r.isComplete, isFalse);
    expect(r.mistakeCount, 0);
    expect(r.words[5].status, WordStatus.pending);
  });

  test('finds a wrong word', () {
    final r = alignRecitation(
      expected,
      words('بسم الله الرحمن الرحيم الحمد لله رب الناس الرحمن'),
    );
    expect(r.mistakeCount, 1);
    expect(r.words[7].status, WordStatus.wrong);
    expect(r.words[7].heard, 'الناس');
    expect(r.words[7].ayah, 2);
  });

  test('finds a skipped word', () {
    final r = alignRecitation(
      expected,
      words('بسم الله الرحمن الحمد لله رب العالمين'),
    );
    expect(r.mistakeCount, 1);
    expect(r.words[3].status, WordStatus.skipped);
    expect(r.words[3].text, fatiha.ayahs[0].split(' ')[3]);
  });

  test('finds an extra word', () {
    final r = alignRecitation(
      expected,
      words('بسم الله الرحمن الرحيم الحمد الحمد لله'),
    );
    expect(r.mistakeCount, 1);
    expect(r.words[4].extrasBefore, ['الحمد']);
  });

  test('holds back a mistake while the reciter is still speaking', () {
    final heard = words('بسم الله الرحمن الرحيم الحمد لله رب الناس');
    final speaking = alignRecitation(expected, heard, settled: false);
    expect(speaking.mistakeCount, 0);
    expect(speaking.words[7].status, WordStatus.pending);

    final settled = alignRecitation(expected, heard);
    expect(settled.words[7].status, WordStatus.wrong);
  });
}
