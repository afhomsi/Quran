import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/recitation/recitation_matcher.dart';
import 'package:hifz/recitation/recitation_session.dart';
import 'package:hifz/recitation/speech_listener.dart';

/// Plays back text instead of listening to a microphone.
class _FakeListener implements SpeechListener {
  void Function(String text, bool isFinal)? _onResult;

  void say(String text, {bool isFinal = true}) =>
      _onResult?.call(text, isFinal);

  @override
  Future<bool> initialize({
    required void Function(String message) onError,
    required void Function() onDone,
  }) async => true;

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
  }) async => _onResult = onResult;

  @override
  Future<void> stop() async {}
}

void main() {
  testWidgets('follows a whole long surah, a few ayat per listening session', (
    tester,
  ) async {
    final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
    final baqarah = surahs[1].ayahs;
    final listener = _FakeListener();
    final session = RecitationSession(
      listener: listener,
      expected: wordsOfSurah(2, baqarah),
      surahName: (s) => surahs[s - 1].name,
    );
    final mistakes = <Mistake>[];
    session.onMistake = mistakes.add;
    await session.start();

    final watch = Stopwatch()..start();
    listener.say('أعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم');
    for (var a = 0; a < baqarah.length; a += 3) {
      var text = baqarah.skip(a).take(3).join(' ');
      if (a == 99) text = text.replaceFirst(RegExp(r'^\S+'), 'كتاب');
      // Let the restarted listening session begin.
      await tester.pump(const Duration(milliseconds: 350));
      listener.say(text);
    }
    watch.stop();

    expect(session.result.isComplete, isTrue);
    expect(mistakes, hasLength(1));
    expect(mistakes.single.message, contains('الآية 100'));
    expect(session.isListening, isFalse);
    // Comparing each session from where the last one ended keeps it fast.
    expect(watch.elapsedMilliseconds, lessThan(5000));
  });

  test('keeps up word by word within one long listening session', () async {
    final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
    final baqarah = surahs[1].ayahs;
    final listener = _FakeListener();
    final session = RecitationSession(
      listener: listener,
      expected: wordsOfSurah(2, baqarah),
      surahName: (s) => surahs[s - 1].name,
    );
    final mistakes = <Mistake>[];
    session.onMistake = mistakes.add;
    await session.start();

    // As Chrome does, each result is the whole session so far, and the
    // last word is first heard wrongly, then corrected.
    final words = baqarah.take(30).join(' ').split(' ');
    words[150] = 'كتاب';
    final watch = Stopwatch()..start();
    var worst = 0;
    for (var k = 1; k <= words.length; k++) {
      final before = watch.elapsedMicroseconds;
      listener.say([...words.take(k - 1), 'سيارة'].join(' '), isFinal: false);
      listener.say(words.take(k).join(' '), isFinal: false);
      worst = max(worst, watch.elapsedMicroseconds - before);
    }

    expect(session.result.progress, greaterThan(words.length));
    expect(mistakes, hasLength(1));
    expect(mistakes.single.message, contains('«كتاب»'));
    // Only the last words are compared again, however long the session.
    expect(worst, lessThan(50000));
  });
}
