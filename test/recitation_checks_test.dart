import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/audio/audio_store.dart';
import 'package:hifz/audio/ayah_audio.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/mushaf_repository.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:hifz/data/recitation_history.dart';
import 'package:hifz/recitation/alert_sound.dart';
import 'package:hifz/recitation/page_recitation.dart';
import 'package:hifz/recitation/recitation_matcher.dart';
import 'package:hifz/recitation/recitation_session.dart';
import 'package:hifz/recitation/speech_listener.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_player.dart';

/// A microphone that can be refused, fail, or send results, as the real
/// recognizers do.
class _Mic implements SpeechListener {
  _Mic({this.allowed = true});

  final bool allowed;
  late void Function(String message) _onError;
  late void Function() _onDone;
  void Function(String text, bool isFinal)? _onResult;
  var sessions = 0;
  var stops = 0;

  void say(String text, {bool isFinal = false}) =>
      _onResult?.call(text, isFinal);

  void fail(String message) => _onError(message);

  /// The recognizer stopped by itself after a pause.
  void pause() => _onDone();

  @override
  Future<bool> initialize({
    required void Function(String message) onError,
    required void Function() onDone,
  }) async {
    _onError = onError;
    _onDone = onDone;
    return allowed;
  }

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    sessions++;
    _onResult = onResult;
  }

  @override
  Future<void> stop() async => stops++;
}

const _fatiha =
    'بسم الله الرحمن الرحيم الحمد لله رب العالمين الرحمن الرحيم '
    'مالك يوم الدين إياك نعبد وإياك نستعين اهدنا الصراط المستقيم '
    'صراط الذين أنعمت عليهم غير المغضوب عليهم ولا الضالين';

void main() {
  final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
  final mushaf = parseMushaf(File(mushafLayoutAssetPath).readAsStringSync());

  RecitationSession fatiha(_Mic mic) => RecitationSession(
    listener: mic,
    expected: wordsOfSurah(1, surahs[0].ayahs),
    surahName: (s) => surahs[s - 1].name,
  );

  group('the recitation check', () {
    test('says so when the microphone is refused', () async {
      final session = fatiha(_Mic(allowed: false));
      await session.start();
      expect(session.isListening, isFalse);
      expect(session.error, contains('الميكروفون'));
    });

    test('explains each kind of listening error and stops', () async {
      for (final (message, expected) in [
        ('error_permission', 'لم يُسمح'),
        ('not-allowed', 'لم يُسمح'),
        ('error_audio', 'لم يُعثر على ميكروفون'),
        ('network', 'الإنترنت'),
        ('error_busy', 'حدث خطأ'),
      ]) {
        final mic = _Mic();
        final session = fatiha(mic);
        await session.start();
        mic.fail(message);
        expect(session.isListening, isFalse, reason: message);
        expect(session.error, contains(expected), reason: message);
      }
    });

    test('silence is a normal pause, not an error', () async {
      final mic = _Mic();
      final session = fatiha(mic);
      await session.start();
      for (final m in ['error_no_match', 'no-speech', 'error_speech_timeout']) {
        mic.fail(m);
      }
      expect(session.isListening, isTrue);
      expect(session.error, isNull);
    });

    testWidgets('listens again after the recognizer pauses', (tester) async {
      final mic = _Mic();
      final session = fatiha(mic);
      await session.start();
      mic.say('بسم الله الرحمن الرحيم', isFinal: true);
      await tester.pump(const Duration(milliseconds: 350));
      expect(mic.sessions, 2);
      mic.pause();
      await tester.pump(const Duration(milliseconds: 350));
      expect(mic.sessions, 3);
      expect(session.result.progress, greaterThan(5));
      await session.stop();
      session.dispose();
    });

    testWidgets('does not listen again once stopped', (tester) async {
      final mic = _Mic();
      final session = fatiha(mic);
      await session.start();
      await session.stop();
      mic.pause();
      await tester.pump(const Duration(seconds: 1));
      expect(mic.sessions, 1);
      session.dispose();
    });

    test('a complete recitation stops listening by itself', () async {
      final mic = _Mic();
      final session = fatiha(mic);
      await session.start();
      mic.say(_fatiha);
      expect(session.result.isComplete, isTrue);
      expect(session.isListening, isFalse);
      expect(session.mistakes, isEmpty);
      expect(mic.stops, 1);
    });

    test('alerts once for a mistake that comes back in each result', () async {
      final mic = _Mic();
      final session = fatiha(mic);
      final alerts = <Mistake>[];
      session.onMistake = alerts.add;
      await session.start();
      const wrong = 'بسم الله الرحمن الرحيم الحمد لله رب الناس الرحمن الرحيم';
      mic
        ..say(wrong)
        ..say('$wrong مالك')
        ..say('$wrong مالك يوم');
      expect(alerts, hasLength(1));
      expect(alerts.single.message, contains('«الناس»'));
      expect(alerts.single.message, contains('الآية 2'));
    });

    test('names a forgotten word and an extra one', () async {
      final mic = _Mic();
      final session = fatiha(mic);
      await session.start();
      mic.say(
        'بسم الله الرحمن الرحيم الحمد لله العالمين الرحمن الرحيم '
        'مالك يوم يوم الدين إياك',
        isFinal: true,
      );
      final messages = session.mistakes.map((m) => m.message).toList();
      expect(messages, hasLength(2));
      expect(
        messages.any((m) => m.startsWith('نسيت كلمة') && m.contains('الآية 2')),
        isTrue,
      );
      expect(messages.any((m) => m.contains('كلمة زائدة «يوم»')), isTrue);
      await session.stop();
    });

    test('the isti\'adha and basmala may be said or left out', () async {
      for (final start in [
        'أعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم',
        'بسم الله الرحمن الرحيم',
        '',
      ]) {
        final mic = _Mic();
        final session = RecitationSession(
          listener: mic,
          expected: wordsOfSurah(112, surahs[111].ayahs),
          surahName: (s) => surahs[s - 1].name,
        );
        await session.start();
        mic.say(
          '$start قل هو الله أحد الله الصمد لم يلد ولم يولد '
          'ولم يكن له كفوا أحد',
        );
        expect(session.result.isComplete, isTrue, reason: start);
        expect(session.mistakes, isEmpty, reason: start);
      }
    });

    test('starting over clears what was heard and the mistakes', () async {
      final mic = _Mic();
      final session = fatiha(mic);
      await session.start();
      mic.say('بسم الله الرحمن الرحيم الحمد لله رب الناس', isFinal: true);
      expect(session.mistakes, isNotEmpty);
      await session.reset();
      expect(session.mistakes, isEmpty);
      expect(session.result.progress, 0);
      expect(session.heardText, isEmpty);
      expect(session.isListening, isFalse);
    });

    test('results of a stopped session are ignored', () async {
      final mic = _Mic();
      final session = fatiha(mic);
      await session.start();
      final heard = mic._onResult!;
      await session.stop();
      heard('بسم الله الرحمن الرحيم الحمد', false);
      expect(session.result.progress, 0);
    });

    test('shows only the last 20 words heard', () async {
      final mic = _Mic();
      final session = fatiha(mic);
      await session.start();
      mic.say(_fatiha.split(' ').take(25).join(' '));
      expect(session.heardText.split(' '), hasLength(20));
    });

    test('names the surah of a mistake on a page with several', () async {
      final mic = _Mic();
      final session = RecitationSession(
        listener: mic,
        expected: wordsOfPage(mushaf.page(604), surahs),
        surahName: (s) => surahs[s - 1].name,
      );
      await session.start();
      mic.say(
        'قل هو الله أحد الله الصمد لم يلد ولم يولد ولم يكن له كفوا أحد '
        'قل أعوذ برب الناس',
        isFinal: true,
      );
      expect(session.mistakes.first.message, contains('سورة الفلق'));
      await session.stop();
    });
  });

  group('reciting a mushaf page', () {
    late _Mic mic;
    late FakePlayer player;
    late ProviderContainer c;
    var alerts = 0;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      mic = _Mic();
      player = FakePlayer();
      alerts = 0;
      c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mushafProvider.overrideWith((ref) async => mushaf),
          surahsProvider.overrideWith((ref) async => surahs),
          speechListenerProvider.overrideWithValue(mic),
          mistakeAlertProvider.overrideWithValue(() => alerts++),
          ayahPlayerProvider.overrideWithValue(player),
          audioStoreProvider.overrideWithValue(AudioStore.none()),
        ],
      );
      c.listen(pageRecitationProvider, (_, _) {});
      await c.read(mushafProvider.future);
      await c.read(surahsProvider.future);
    });

    tearDown(() => c.dispose());

    PageRecitationController page() => c.read(pageRecitationProvider.notifier);

    test('starts listening with the words hidden, shown as recited', () async {
      await page().start(1);
      final state = c.read(pageRecitationProvider)!;
      expect(state.page, 1);
      expect(state.hideText, isTrue);
      expect(state.session.isListening, isTrue);
      expect(state.recitedWords, isEmpty);

      mic.say('بسم الله الرحمن الرحيم الحمد لله');
      final words = c.read(pageRecitationProvider)!.recitedWords;
      expect(words[const AyahRef(1, 1)], PageRecitation.allWords);
      expect(words[const AyahRef(1, 2)], 2);
    });

    test('colors each ayah right or wrong once it is reached', () async {
      await page().start(1);
      mic.say('بسم الله الرحمن الرحيم الحمد لله رب الناس الرحمن');
      final states = c.read(pageRecitationProvider)!.ayahStates;
      expect(states[const AyahRef(1, 1)], AyahRecitation.correct);
      expect(states[const AyahRef(1, 2)], AyahRecitation.mistake);
      // Al-Fatiha 3 is not finished, so not right yet.
      expect(states.containsKey(const AyahRef(1, 3)), isFalse);
      expect(alerts, 1);
    });

    test('the words can be shown and hidden again', () async {
      await page().start(1);
      page().toggleHideText();
      expect(c.read(pageRecitationProvider)!.hideText, isFalse);
      page().toggleHideText();
      expect(c.read(pageRecitationProvider)!.hideText, isTrue);
    });

    test('closing keeps the recitation in the history once', () async {
      await page().start(1);
      mic.say('بسم الله الرحمن الرحيم الحمد لله رب العالمين');
      page().close();
      page().close();
      expect(c.read(pageRecitationProvider), isNull);
      final history = c.read(recitationHistoryProvider);
      expect(history, hasLength(1));
      expect(history.single.page, 1);
      expect(history.single.last, const AyahRef(1, 2));
      expect(history.single.complete, isFalse);
    });

    test('nothing recited is not kept', () async {
      await page().start(1);
      page().close();
      expect(c.read(recitationHistoryProvider), isEmpty);
    });

    test('a finished page is kept once and stops listening', () async {
      await page().start(1);
      mic.say(_fatiha);
      final state = c.read(pageRecitationProvider)!;
      expect(state.session.isListening, isFalse);
      page().close();
      final history = c.read(recitationHistoryProvider);
      expect(history, hasLength(1));
      expect(history.single.complete, isTrue);
      expect(history.single.mistakes, isEmpty);
    });

    test('starting over keeps the try and begins again', () async {
      await page().start(1);
      mic.say('بسم الله الرحمن الرحيم الحمد لله رب الناس', isFinal: true);
      await page().restart();
      expect(c.read(recitationHistoryProvider), hasLength(1));
      final session = c.read(pageRecitationProvider)!.session;
      expect(session.result.progress, 0);
      expect(session.isListening, isFalse);
      await page().toggleListening();
      mic.say('بسم الله', isFinal: true);
      page().close();
      expect(c.read(recitationHistoryProvider), hasLength(2));
    });

    test('a new page starts a new recitation', () async {
      await page().start(1);
      mic.say('بسم الله الرحمن الرحيم');
      await page().start(2);
      expect(c.read(pageRecitationProvider)!.page, 2);
      expect(c.read(recitationHistoryProvider), hasLength(1));
    });

    test('the reciter playing stops the microphone, and the microphone '
        'pauses the reciter', () async {
      await page().start(1);
      await c.read(audioProvider.notifier).playFrom(const AyahRef(1, 1));
      expect(c.read(pageRecitationProvider)!.session.isListening, isFalse);

      await page().toggleListening();
      expect(c.read(audioProvider).playing, isFalse);
      expect(c.read(pageRecitationProvider)!.session.isListening, isTrue);
    });

    test('every page has words to recite, and only its own ayat', () {
      for (var p = 1; p <= mushafPageCount; p++) {
        final words = wordsOfPage(mushaf.page(p), surahs);
        final ayat = {
          for (final w in words)
            if (w.kind == WordKind.ayah) AyahRef(w.surah, w.ayah),
        };
        final onPage = {for (final w in mushaf.page(p).words) w.ayah};
        expect(ayat, onPage, reason: 'page $p');
      }
    });
  });
}
