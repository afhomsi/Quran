// Fast recitation of 20 ayat and more from random places, as the
// recognizers send it, checked the way the reciter sees it: no mistakes
// for a right recitation, the ayat recited stay shown, the page follows
// without going ahead, and the place recited is found.
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/audio/audio_store.dart';
import 'package:hifz/audio/ayah_audio.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/mushaf_repository.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:hifz/recitation/alert_sound.dart';
import 'package:hifz/recitation/auto_recitation.dart';
import 'package:hifz/recitation/page_recitation.dart';
import 'package:hifz/recitation/quran_finder.dart';
import 'package:hifz/recitation/recitation_matcher.dart';
import 'package:hifz/recitation/speech_listener.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_player.dart';
import 'recitation_simulator.dart';

final _surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
final _mushaf = parseMushaf(File(mushafLayoutAssetPath).readAsStringSync());
final _plain = PlainQuran(_surahs);
final _finder = QuranFinder(_surahs);

/// The page where each ayah ends.
final _endPage = {
  for (final p in _mushaf.pages)
    for (final w in p.words) w.ayah: p.number,
};

/// The ayah a word is in, the basmala counting as the surah's first ayah.
AyahRef _ayahOf(SpokenWord w) =>
    w.ayah.ayah == 0 ? AyahRef(w.ayah.surah, 1) : w.ayah;

/// The ayah before [a].
AyahRef _previous(AyahRef a) => a.ayah > 1
    ? AyahRef(a.surah, a.ayah - 1)
    : AyahRef(a.surah - 1, _surahs[a.surah - 2].ayahs.length);

/// The ayah after [a].
AyahRef _next(AyahRef a) => a.ayah < _surahs[a.surah - 1].ayahs.length
    ? AyahRef(a.surah, a.ayah + 1)
    : AyahRef(a.surah + 1, 1);

/// Ayah number [n] of the whole Quran, from 0.
AyahRef _nthAyah(int n) {
  for (final s in _surahs) {
    if (n < s.ayahs.length) return AyahRef(s.number, n + 1);
    n -= s.ayahs.length;
  }
  throw RangeError.value(n);
}

Future<(ProviderContainer, SimulatedListener)> _app({
  required bool offline,
}) async {
  SharedPreferences.setMockInitialValues({
    'settings': '{"askRecitationMode":false}',
  });
  final prefs = await SharedPreferences.getInstance();
  final listener = SimulatedListener(keepsResults: offline);
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      mushafProvider.overrideWith((ref) async => _mushaf),
      surahsProvider.overrideWith((ref) async => _surahs),
      quranFinderProvider.overrideWith((ref) async => _finder),
      speechListenerProvider.overrideWithValue(listener),
      mistakeAlertProvider.overrideWithValue(() {}),
      ayahPlayerProvider.overrideWithValue(FakePlayer()),
      audioStoreProvider.overrideWithValue(AudioStore.none()),
    ],
  );
  await container.read(mushafProvider.future);
  await container.read(surahsProvider.future);
  await container.read(quranFinderProvider.future);
  return (container, listener);
}

/// The ayat with a word the mushaf spells so unlike plain spelling that
/// it is taken for a mistake, as بَصۜۡطَةٗ (بسطة) and لۡـَٔيۡكَةِ (الأيكة).
final knownSpellings = {
  AyahRef(7, 69),
  AyahRef(9, 103),
  AyahRef(19, 12),
  AyahRef(20, 94),
  AyahRef(21, 88),
  AyahRef(26, 176),
  AyahRef(27, 36),
  AyahRef(38, 13),
  AyahRef(72, 16),
};

/// Words the page may follow behind the reciter at most.
const _maxPageLag = 30;

/// Recites [words] to the app through [events] after [start], and returns
/// what went wrong, each problem a line.
Future<List<String>> _recite(
  WidgetTester tester, {
  required String name,
  required List<SpokenWord> words,
  required List<RecognizerEvent> events,
  required bool offline,
  required Future<void> Function(ProviderContainer) start,
  Noise? noise,
}) async {
  final only = Platform.environment['STRESS_ONLY'];
  if (only != null && !name.startsWith(only)) return const [];
  final (container, listener) = await _app(offline: offline);
  addTearDown(container.dispose);
  await start(container);
  await tester.pump();
  final problems = <String>[];
  void problem(String p) => problems.add('$name: $p');

  var now = 0;
  Object? session;
  var shown = <AyahRef>{};
  final reached = <int, int>{};
  final shownAt = <int, int>{};
  var worst = 0;
  for (final e in events) {
    if (e.at > now) {
      await tester.pump(Duration(milliseconds: e.at - now));
      now = e.at;
    }
    final watch = Stopwatch()..start();
    listener.say(e.text, e.isFinal);
    worst = max(worst, watch.elapsedMilliseconds);
    await tester.pump();
    final r = container.read(pageRecitationProvider);
    if (only != null) {
      // ignore: avoid_print
      print(
        '${e.at} ${e.isFinal ? 'FINAL' : ''} [${e.text}] spoken ${e.spoken} '
        '${r == null ? '' : 'settled ${r.settledWord} page ${r.pageToShow(_mushaf)} '
            'expected to ${r.session.expected.last.surah}:${r.session.expected.last.ayah} '
            'mistakes ${r.session.mistakes.length} '
            'shown ${[for (final e in r.recitedWords.entries) '${e.key.ayah}:${e.value == PageRecitation.allWords ? 'all' : e.value}'].join(',')} '
            'stop ${r.stopIndex}'}',
      );
    }
    if (r == null) continue;
    if (r.session != session) {
      session = r.session;
      shown = {};
    }
    final nowShown = {
      for (final e in r.recitedWords.entries)
        if (e.value == PageRecitation.allWords) e.key,
    };
    // «الرحمن» after the basmala may be its last word or Ar-Rahman's
    // first ayah until the next word tells.
    final hidden = shown.difference(nowShown)..remove(const AyahRef(55, 1));
    if (hidden.isNotEmpty) {
      problem('ayat ${hidden.join(', ')} hid again after word ${e.spoken}');
    }
    shown = nowShown;

    // Once all is said, the page with the next ayah may show.
    if (e.spoken >= words.length) continue;
    final at = _ayahOf(words[e.spoken]);
    final page = r.pageToShow(_mushaf);
    // Until the place recited is found, the page open is shown.
    if (page > _endPage[at]! && r.covers(_mushaf.pageOf(at))) {
      problem('page $page shown ahead of the reciter at $at');
    }
    reached.putIfAbsent(_mushaf.pageOf(at), () => e.spoken);
    for (var p = 1; p <= page; p++) {
      shownAt.putIfAbsent(p, () => e.spoken);
    }
  }
  await tester.pump(const Duration(seconds: 2));
  final r = container.read(pageRecitationProvider);
  if (r == null) {
    problem('the place recited was never found');
    return problems;
  }
  if (r.session.isListening) await r.session.stop();
  await tester.pump(const Duration(seconds: 6));

  // The pages shown once all is said, for those reached by its last words.
  for (var p = 1; p <= r.pageToShow(_mushaf); p++) {
    shownAt.putIfAbsent(p, () => words.length);
  }

  final last = _ayahOf(words.last);
  final recited = {
    for (final w in words)
      if (w.ayah.ayah > 0) w.ayah,
  };
  final mistakes = r.session.mistakes;
  if (noise == null) {
    final counts = r.recitedWords;
    final notShown = [
      for (final a in recited)
        if (counts[a] != PageRecitation.allWords) a,
    ];
    if (notShown.isNotEmpty) {
      problem('ayat recited but not shown: ${notShown.join(', ')}');
    }
    for (final m in mistakes) {
      problem('a right recitation has a mistake: ${m.message}');
    }
    // The page where the last ayah ends, or the next with the ayah to
    // recite next when it ends a page.
    final end = r.pageToShow(_mushaf);
    if (end != _endPage[last] &&
        !(end == _endPage[last]! + 1 && _mushaf.pageOf(_next(last)) == end)) {
      problem(
        'ends on page ${r.pageToShow(_mushaf)}, not ${_endPage[last]}',
      );
    }
  } else {
    if (mistakes.length > 2 * noise.total + 2) {
      problem(
        '${mistakes.length} mistakes for ${noise.total} words '
        'misheard: ${mistakes.map((m) => m.message).join(' / ')}',
      );
    }
    // Followed to the end; a recognizer that loses the first word of the
    // last ayah may leave its other words to be taken for another try at
    // the ayah before, which is a fair reading of what it heard.
    final settled = r.session.settledResult.words;
    final reachedLast = [
      for (final a in [last, _previous(last)])
        settled.any(
          (w) =>
              w.word.kind == WordKind.ayah &&
              w.surah == a.surah &&
              w.ayah == a.ayah &&
              w.status != WordStatus.pending,
        ),
    ];
    if (!reachedLast.first && !reachedLast.last) {
      problem('lost track before the end at ${r.settledWord.$1}');
    }
  }
  for (final e in reached.entries) {
    final shownFrom = shownAt[e.key];
    if (e.key == reached.keys.first) continue;
    if (shownFrom == null) {
      if (noise == null) problem('page ${e.key} was never shown');
    } else if (shownFrom - e.value > _maxPageLag) {
      problem(
        'page ${e.key} shown ${shownFrom - e.value} words after the '
        'reciter reached it',
      );
    }
  }
  if (worst > 200) problem('a result took $worst ms to compare');
  return problems;
}

/// Runs [count] recitations of 20 to 28 ayat from random places.
Future<void> _many(
  WidgetTester tester,
  int count,
  int seed,
  Future<List<String>> Function(Random rnd, AyahRef from, int ayat) run,
) async {
  // More and other runs can be asked for, as STRESS_RUNS=5 STRESS_SEED=9.
  final env = Platform.environment;
  final rnd = Random(seed + 100 * int.parse(env['STRESS_SEED'] ?? '0'));
  count *= int.parse(env['STRESS_RUNS'] ?? '1');
  final problems = <String>[];
  for (var n = 0; n < count; n++) {
    final from = _nthAyah(rnd.nextInt(6236 - 30));
    final ayat = 20 + rnd.nextInt(9);
    final recited = recitationOf(_plain, from, ayat).map((w) => w.ayah);
    if (recited.any(knownSpellings.contains)) {
      n--;
      continue;
    }
    problems.addAll(await run(rnd, from, ayat));
  }
  if (problems.isNotEmpty) {
    // ignore: avoid_print
    print(problems.join('\n'));
  }
  expect(problems, isEmpty);
}

void main() {
  test('the whole Quran in plain spelling has no mistakes', () {
    // As Google's recognizer writes it: «يا أيها» for يَـٰٓأَيُّهَا, شيئا
    // for شَيۡـٔٗا, الليل for ٱلَّيۡلِ, and so on.
    final wrong = <AyahRef>{};
    for (final s in _surahs) {
      for (var a = 1; a <= s.ayahs.length; a++) {
        final ayah = AyahRef(s.number, a);
        final r = alignRecitation(
          wordsToRecite([
            (s.number, a, s.ayahs[a - 1]),
          ]).where((w) => w.kind == WordKind.ayah).toList(),
          _plain.ayah(ayah),
        );
        if (r.mistakeCount > 0 || !r.isComplete) wrong.add(ayah);
      }
    }
    expect(wrong, knownSpellings);
  });

  group('reciting 20 ayat and more fast, from random places,', () {
    for (final offline in [false, true]) {
      final engine = offline ? 'offline model' : 'Google';

      testWidgets('with $engine, from the ayah reciting stopped at', (
        tester,
      ) async {
        await _many(tester, 12, offline ? 2 : 1, (rnd, from, ayat) {
          final words = recitationOf(_plain, from, ayat);
          return _recite(
            tester,
            name: '$engine $from +$ayat',
            words: words,
            events: offline
                ? offlineEvents(words, rnd)
                : googleEvents(words, rnd),
            offline: offline,
            start: (c) => c
                .read(pageRecitationProvider.notifier)
                .start(_mushaf.pageOf(from), from: from),
          );
        });
      });

      testWidgets('with $engine, found from anywhere, even mid-ayah', (
        tester,
      ) async {
        await _many(tester, 10, offline ? 4 : 3, (rnd, from, ayat) {
          final length = _plain.ayah(from).length;
          final position = 1 + rnd.nextInt(max(1, length ~/ 2));
          final words = recitationOf(
            _plain,
            from,
            ayat,
            position: position,
            istiadha: rnd.nextBool(),
          );
          return _recite(
            tester,
            name: '$engine auto $from word $position +$ayat',
            words: words,
            events: offline
                ? offlineEvents(words, rnd)
                : googleEvents(words, rnd),
            offline: offline,
            start: (c) => c.read(autoRecitationProvider.notifier).start(),
          );
        });
      });

      testWidgets('with $engine, from the page button of another page', (
        tester,
      ) async {
        await _many(tester, 8, offline ? 6 : 5, (rnd, from, ayat) {
          final words = recitationOf(_plain, from, ayat);
          final page = 1 + rnd.nextInt(604);
          return _recite(
            tester,
            name: '$engine page $page, reciting $from +$ayat',
            words: words,
            events: offline
                ? offlineEvents(words, rnd)
                : googleEvents(words, rnd),
            offline: offline,
            start: (c) =>
                c.read(pageRecitationProvider.notifier).start(page),
          );
        });
      });
    }

    testWidgets('with Google losing and mishearing words', (tester) async {
      await _many(tester, 10, 7, (rnd, from, ayat) {
        final words = recitationOf(_plain, from, ayat);
        final noise = Noise();
        return _recite(
          tester,
          name: 'noisy Google $from +$ayat',
          words: words,
          events: googleEvents(
            words,
            rnd,
            drop: 0.03,
            wrong: 0.02,
            noise: noise,
          ),
          offline: false,
          noise: noise,
          start: (c) => c
              .read(pageRecitationProvider.notifier)
              .start(_mushaf.pageOf(from), from: from),
        );
      });
    });
  });
}
