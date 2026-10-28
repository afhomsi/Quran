import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/mushaf_repository.dart';
import 'package:hifz/recitation/page_recitation.dart';
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

  test('keeps what was recited when the recognizer starts over after a '
      'pause', () async {
    // Google's recognizer on Android may start over after a pause within
    // one listening session: its results then hold only the words said
    // since. The ayat recited before must not hide again.
    final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
    final mushaf = parseMushaf(File(mushafLayoutAssetPath).readAsStringSync());
    final listener = _FakeListener();
    final session = RecitationSession(
      listener: listener,
      expected: wordsOfPages([
        for (var p = 2; p <= 4; p++) mushaf.page(p),
      ], surahs),
      surahName: (s) => surahs[s - 1].name,
    );
    final mistakes = <Mistake>[];
    session.onMistake = mistakes.add;
    await session.start();
    final recitation = PageRecitation(2, session, 0, lastPage: 4);

    final baqarah = surahs[1].ayahs;
    var shown = 0;
    for (var a = 0; a < 12; a += 2) {
      final segment = '${baqarah[a]} ${baqarah[a + 1]}'.split(' ');
      for (var k = 1; k <= segment.length; k++) {
        listener.say(segment.take(k).join(' '), isFinal: false);
        final now = recitation.recitedWords.values
            .where((n) => n == PageRecitation.allWords)
            .length;
        expect(now, greaterThanOrEqualTo(shown), reason: 'ayah ${a + 1}');
        shown = now;
      }
    }
    expect(shown, greaterThanOrEqualTo(11));
    expect(mistakes, isEmpty);
  });

  test(
    'keeps up while the recognizer rewrites words it heard long ago',
    () async {
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

      // Reciting fast without a pause: one listening session, and the
      // recognizer spells its first word one way, then another, each time.
      final words = baqarah.take(40).join(' ').split(' ');
      final watch = Stopwatch()..start();
      var worst = 0;
      for (var k = 1; k <= words.length; k++) {
        final heard = [...words.take(k)];
        if (k.isOdd) heard[0] = 'الف';
        final before = watch.elapsedMicroseconds;
        listener.say(heard.join(' '), isFinal: false);
        worst = max(worst, watch.elapsedMicroseconds - before);
        // What is settled stays close behind what is heard.
        expect(
          session.settledResult.progress,
          greaterThan(k - 40),
          reason: 'after $k words',
        );
      }

      expect(session.result.progress, greaterThan(words.length));
      expect(mistakes, hasLength(1));
      // The words compared again stay few, however long the session.
      expect(worst, lessThan(50000));
    },
  );

  group('a mistake', () {
    late List<String> ayahs;
    late _FakeListener listener;
    late RecitationSession session;
    late List<Mistake> mistakes;

    setUp(() async {
      final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
      ayahs = surahs[1].ayahs.take(5).toList();
      listener = _FakeListener();
      session = RecitationSession(
        listener: listener,
        expected: wordsOfSurah(2, ayahs),
        surahName: (s) => surahs[s - 1].name,
      );
      mistakes = [];
      session.onMistake = mistakes.add;
      await session.start();
    });

    List<String> withMistake() {
      final ayah2 = ayahs[1].split(' ');
      return [...ayahs[0].split(' '), ...ayah2.take(2), 'كتاب'];
    }

    testWidgets('is reported soon after the reciter stops at it', (
      tester,
    ) async {
      final said = withMistake();
      for (var k = 1; k <= said.length; k++) {
        listener.say(said.take(k).join(' '), isFinal: false);
      }
      expect(mistakes, isEmpty);
      await tester.pump(RecitationSession.quietDelay);
      expect(mistakes.single.message, contains('«كتاب»'));
    });

    test('is corrected by reciting the ayah again', () {
      final said = [
        ...withMistake(),
        ...ayahs[1].split(' ').skip(3),
        // Going back to recite the ayah again, then on.
        ...ayahs[1].split(' '),
        ...ayahs[2].split(' '),
      ];
      for (var k = 1; k <= said.length; k++) {
        listener.say(said.take(k).join(' '), isFinal: false);
      }
      listener.say(said.join(' '));

      expect(mistakes.single.message, contains('«كتاب»'));
      final ayah2 = session.result.words.where(
        (w) => w.ayah == 2 && w.word.kind == WordKind.ayah,
      );
      expect(ayah2.every((w) => w.status == WordStatus.correct), isTrue);
      final ayah3 = session.result.words.where((w) => w.ayah == 3);
      expect(ayah3.every((w) => w.status == WordStatus.correct), isTrue);
      final page = PageRecitation(2, session, 0);
      expect(page.recitedWords[const AyahRef(2, 2)], PageRecitation.allWords);
      expect(page.recitedWords[const AyahRef(2, 3)], PageRecitation.allWords);
      expect(page.wrongWords, isEmpty);
    });

    testWidgets('also after a pause, in the next listening session', (
      tester,
    ) async {
      listener.say(withMistake().join(' '));
      // Let the restarted listening session begin.
      await tester.pump(const Duration(milliseconds: 350));
      final again = [...ayahs[1].split(' '), ...ayahs[2].split(' ')];
      listener.say(again.join(' '));

      expect(mistakes, hasLength(1));
      final page = PageRecitation(2, session, 0);
      expect(page.recitedWords[const AyahRef(2, 2)], PageRecitation.allWords);
      expect(page.ayahStates[const AyahRef(2, 2)], AyahRecitation.correct);
      await tester.pump(const Duration(milliseconds: 350));
    });

    test('keeps only the wrong word hidden while it is not recited again', () {
      final said = [
        ...withMistake(),
        ...ayahs[1].split(' ').skip(3),
        ...ayahs[2].split(' '),
      ];
      listener.say(said.join(' '));
      final page = PageRecitation(2, session, 0);
      expect(page.recitedWords[const AyahRef(2, 2)], PageRecitation.allWords);
      expect(page.wrongWords, {(const AyahRef(2, 2), 3)});
      expect(page.recitedWords[const AyahRef(2, 3)], PageRecitation.allWords);
      expect(session.isListening, isTrue);
      expect(page.ayahStates[const AyahRef(2, 2)], AyahRecitation.mistake);
    });

    test('colours only the wrong word red, the words after it green', () {
      final said = [...withMistake(), ...ayahs[1].split(' ').skip(3)];
      listener.say(said.join(' '));
      final states = PageRecitation(2, session, 0).wordStates;
      expect(states[(const AyahRef(2, 2), 2)], AyahRecitation.correct);
      expect(states[(const AyahRef(2, 2), 3)], AyahRecitation.mistake);
      expect(states[(const AyahRef(2, 2), 4)], AyahRecitation.correct);
    });

    test('help shows the next word, also the first of the next ayah', () {
      listener.say(ayahs[0]);
      expect(session.hint(), isTrue);
      var page = PageRecitation(2, session, 0);
      expect(page.recitedWords[const AyahRef(2, 2)], 1);
      session.hint();
      page = PageRecitation(2, session, 0);
      expect(page.recitedWords[const AyahRef(2, 2)], 2);
      expect(page.ayahStates[const AyahRef(2, 2)], isNull);
    });

    test('help shows the word just said wrong, then the next one', () {
      listener.say(withMistake().join(' '));
      var page = PageRecitation(2, session, 0);
      expect(page.wrongWords, {(const AyahRef(2, 2), 3)});
      session.hint();
      page = PageRecitation(2, session, 0);
      expect(page.wrongWords, isEmpty);
      session.hint();
      page = PageRecitation(2, session, 0);
      expect(page.recitedWords[const AyahRef(2, 2)], 4);
    });
  });

  testWidgets('each page of Juz Amma is recited on from surah to surah', (
    tester,
  ) async {
    final mushaf = parseMushaf(File(mushafLayoutAssetPath).readAsStringSync());
    final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
    for (var page = 582; page <= mushafPageCount; page++) {
      final last = mushaf.page(page).words.last.ayah.surah;
      final lastPage = mushaf.pageOf(
        AyahRef(last, surahs[last - 1].ayahs.length),
      );
      final listener = _FakeListener();
      final session = RecitationSession(
        listener: listener,
        expected: wordsOfPages([
          for (var p = page; p <= lastPage; p++) mushaf.page(p),
        ], surahs),
        surahName: (s) => surahs[s - 1].name,
      );
      await session.start();
      final ayat = {
        for (final w in session.expected)
          if (w.kind == WordKind.ayah) AyahRef(w.surah, w.ayah),
      };
      // An ayah or two per listening session, each surah with its basmala.
      for (final a in ayat) {
        final text = surahs[a.surah - 1].ayahs[a.ayah - 1];
        final words = [
          if (a.ayah == 1) ...'بسم الله الرحمن الرحيم'.split(' '),
          ...text.split(' '),
        ];
        for (var k = 1; k <= words.length; k++) {
          listener.say(words.take(k).join(' '), isFinal: k == words.length);
        }
        await tester.pump(const Duration(milliseconds: 350));
      }
      expect(
        session.mistakes.map((m) => m.message),
        isEmpty,
        reason: 'page $page',
      );
      expect(session.result.isComplete, isTrue, reason: 'page $page');
      session.dispose();
    }
    await tester.pump(const Duration(seconds: 2));
  });
}
