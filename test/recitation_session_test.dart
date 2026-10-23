import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/recitation/recitation_matcher.dart';
import 'package:hifz/recitation/recitation_session.dart';
import 'package:hifz/recitation/speech_listener.dart';

/// Plays back text instead of listening to a microphone.
class _FakeListener implements SpeechListener {
  void Function(String text, bool isFinal)? _onResult;

  void say(String text) => _onResult?.call(text, true);

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
}
