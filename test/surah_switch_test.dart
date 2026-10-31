import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/app.dart';
import 'package:hifz/audio/audio_store.dart';
import 'package:hifz/audio/ayah_audio.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/mushaf_repository.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:hifz/features/mushaf/mushaf_page_view.dart';
import 'package:hifz/features/mushaf/mushaf_screen.dart';
import 'package:hifz/features/shell/navigation.dart';
import 'package:hifz/recitation/alert_sound.dart';
import 'package:hifz/recitation/page_recitation.dart';
import 'package:hifz/recitation/speech_listener.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_listener.dart';
import 'fake_player.dart';

final _surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
final _mushaf = parseMushaf(File(mushafLayoutAssetPath).readAsStringSync());

/// The words of an ayah from word [from] on (counted from 1).
List<String> _ayah(int surah, int ayah, [int from = 1]) =>
    _surahs[surah - 1].ayahs[ayah - 1].split(' ').sublist(from - 1);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeListener listener, {
  Widget? child,
}) async {
  SharedPreferences.setMockInitialValues({
    'settings': '{"askRecitationMode":false}',
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        mushafProvider.overrideWith((ref) async => _mushaf),
        surahsProvider.overrideWith((ref) async => _surahs),
        speechListenerProvider.overrideWithValue(listener),
        mistakeAlertProvider.overrideWithValue(() {}),
        ayahPlayerProvider.overrideWithValue(FakePlayer()),
        audioStoreProvider.overrideWithValue(AudioStore.none()),
      ],
      child:
          child ??
          const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: MushafScreen(initialPage: 1),
            ),
          ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(child == null ? MushafScreen : HifzApp)),
  );
}

/// What Google's recognizer writes: no harakat.
String _plain(String w) =>
    w.replaceAll(RegExp('[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '');

/// Says [words] one more in each partial result, as Google does, and
/// ends the recognizer's session with them when [end].
Future<void> _sayWordByWord(
  WidgetTester tester,
  FakeListener listener,
  List<String> words, {
  bool end = false,
}) async {
  for (var n = 1; n <= words.length; n++) {
    listener.say(words.take(n).map(_plain).join(' '));
    await tester.pump(const Duration(milliseconds: 300));
  }
  if (end) {
    listener.say(words.map(_plain).join(' '), isFinal: true);
    await tester.pump(const Duration(milliseconds: 400));
  }
  await tester.pumpAndSettle();
}

List<String> _surah(int s, [int from = 1, int? to]) => [
  for (var a = from; a <= (to ?? _surahs[s - 1].ayahs.length); a++)
    ..._ayah(s, a),
];

int _shownPage(WidgetTester tester) =>
    tester.widget<MushafPageView>(find.byType(MushafPageView)).page.number;

void main() {
  group('reciting another surah at any time moves there', () {
    testWidgets('Al-Fatiha open, Al-Ikhlas recited, then Al-Fatiha again', (
      t,
    ) async {
      final listener = FakeListener();
      final c = await _pump(t, listener);
      await c.read(pageRecitationProvider.notifier).start(1);
      await t.pumpAndSettle();
      await _sayWordByWord(t, listener, _surah(112), end: true);
      var r = c.read(pageRecitationProvider)!;
      expect(r.from?.surah, 112);
      expect(_shownPage(t), 604);
      await _sayWordByWord(t, listener, _surah(1, 1, 4));
      r = c.read(pageRecitationProvider)!;
      expect(r.from?.surah, 1, reason: 'should move back to Al-Fatiha');
      expect(_shownPage(t), 1);
      await t.tap(find.byTooltip('إغلاق التسميع'));
      await t.pumpAndSettle();
    });

    testWidgets('stopped after Al-Ikhlas, the bar microphone, then Al-Fatiha', (
      t,
    ) async {
      final listener = FakeListener();
      final c = await _pump(t, listener);
      await c.read(pageRecitationProvider.notifier).start(1);
      await t.pumpAndSettle();
      await _sayWordByWord(t, listener, _surah(112), end: true);
      await t.pump(const Duration(seconds: 7));
      await t.pumpAndSettle();
      if (c.read(pageRecitationProvider)!.session.isListening) {
        await t.tap(find.byTooltip('إيقاف'));
        await t.pumpAndSettle();
      }
      await t.tap(find.byTooltip('ابدأ التسميع'));
      await t.pumpAndSettle();
      await _sayWordByWord(t, listener, _surah(1, 1, 4));
      final r = c.read(pageRecitationProvider)!;
      expect(r.from?.surah ?? r.session.expected.first.surah, 1);
      expect(_shownPage(t), 1);
      await t.tap(find.byTooltip('إغلاق التسميع'));
      await t.pumpAndSettle();
    });

    testWidgets(
      'from Al-Ikhlas on to Al-Baqarah 2:17, Al-Fatiha, Ayat al-Kursi',
      (t) async {
        final listener = FakeListener();
        final c = await _pump(t, listener);
        await c.read(pageRecitationProvider.notifier).start(1);
        await t.pumpAndSettle();
        await _sayWordByWord(t, listener, _surah(112), end: true);
        expect(c.read(pageRecitationProvider)!.from?.surah, 112);
        await _sayWordByWord(t, listener, _surah(2, 17, 18), end: true);
        var r = c.read(pageRecitationProvider)!;
        expect(r.from, const AyahRef(2, 17));
        expect(_shownPage(t), 4);
        expect(r.recitedWords[const AyahRef(2, 17)], PageRecitation.allWords);
        // And back to Al-Fatiha, then Ayat al-Kursi, in one listening.
        await _sayWordByWord(t, listener, _surah(1, 1, 4), end: true);
        r = c.read(pageRecitationProvider)!;
        expect(r.from?.surah, 1);
        expect(_shownPage(t), 1);
        await _sayWordByWord(t, listener, _surah(2, 255, 255));
        r = c.read(pageRecitationProvider)!;
        expect(r.from, const AyahRef(2, 255));
        expect(r.recitedWords[const AyahRef(2, 255)], PageRecitation.allWords);
        await t.tap(find.byTooltip('إغلاق التسميع'));
        await t.pumpAndSettle();
      },
    );

    testWidgets('a word misheard in 2:17 does not hide the ayat after it', (
      t,
    ) async {
      final listener = FakeListener();
      final c = await _pump(t, listener);
      c.read(mushafJumpProvider.notifier).jump(4);
      await t.pumpAndSettle();
      await c.read(pageRecitationProvider.notifier).start(4);
      await t.pumpAndSettle();
      final words = _surah(2, 17, 18);
      words[3] = 'كتابا';
      await _sayWordByWord(t, listener, words);
      final r = c.read(pageRecitationProvider)!;
      expect(r.recitedWords[const AyahRef(2, 18)], PageRecitation.allWords);
      await t.tap(find.byTooltip('إغلاق التسميع'));
      await t.pumpAndSettle();
    });

    for (final page in [4, 3, 2, 1]) {
      testWidgets('page $page open, reciting 2:17 shows it', (t) async {
        final listener = FakeListener();
        final c = await _pump(t, listener);
        c.read(mushafJumpProvider.notifier).jump(page);
        await t.pumpAndSettle();
        await c.read(pageRecitationProvider.notifier).start(page);
        await t.pumpAndSettle();
        await _sayWordByWord(t, listener, _surah(2, 17, 18));
        final r = c.read(pageRecitationProvider)!;
        expect(_shownPage(t), 4);
        expect(r.recitedWords[const AyahRef(2, 17)], PageRecitation.allWords);
        expect(r.recitedWords[const AyahRef(2, 18)], PageRecitation.allWords);
        await t.tap(find.byTooltip('إغلاق التسميع'));
        await t.pumpAndSettle();
      });
    }
  });
}
