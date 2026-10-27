import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/app.dart';
import 'package:hifz/audio/audio_store.dart';
import 'package:hifz/audio/ayah_audio.dart';
import 'package:hifz/features/mushaf/mushaf_page_view.dart';
import 'package:hifz/data/khatma.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/mushaf_repository.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:hifz/data/recitation_history.dart';
import 'package:hifz/features/mushaf/mushaf_screen.dart';
import 'package:hifz/recitation/alert_sound.dart';
import 'package:hifz/recitation/page_recitation.dart';
import 'package:hifz/recitation/recitation_matcher.dart';
import 'package:hifz/settings/app_settings.dart';
import 'package:hifz/recitation/speech_listener.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_listener.dart';
import 'fake_player.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  FakeListener? listener,
  bool askMode = false,
  String? settings,
}) async {
  // How strictly to check is asked before each recitation; most tests
  // recite with the mode chosen once for all.
  SharedPreferences.setMockInitialValues({
    if (settings != null)
      'settings': settings
    else if (!askMode)
      'settings': '{"askRecitationMode":false}',
  });
  final prefs = await SharedPreferences.getInstance();
  final mushaf = parseMushaf(File(mushafLayoutAssetPath).readAsStringSync());
  final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        mushafProvider.overrideWith((ref) async => mushaf),
        surahsProvider.overrideWith((ref) async => surahs),
        speechListenerProvider.overrideWithValue(listener ?? FakeListener()),
        mistakeAlertProvider.overrideWithValue(() {}),
        ayahPlayerProvider.overrideWithValue(FakePlayer()),
        audioStoreProvider.overrideWithValue(AudioStore.none()),
      ],
      child: child,
    ),
  );
  await tester.pumpAndSettle();
}

Finder _inSheet(String text) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

void main() {
  _modeTests();
  testWidgets('any surah can be recited from the home screen', (tester) async {
    await _pump(tester, const HifzApp());
    await tester.tap(find.text('الفهرس'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('تسميع'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      _inSheet('الإخلاص'),
      500,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(_inSheet('الإخلاص'));
    await tester.pumpAndSettle();
    expect(find.text('تسميع سورة الإخلاص'), findsOneWidget);
  });

  testWidgets('a mushaf page can be recited from the page', (tester) async {
    await _pump(
      tester,
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MushafScreen(initialPage: 2),
        ),
      ),
    );

    await tester.tap(find.byTooltip('القائمة'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'تسميع'));
    await tester.pumpAndSettle();
    expect(_inSheet('تسميع سورة البقرة كاملة'), findsOneWidget);
    await tester.tap(_inSheet('تسميع هذه الصفحة (2)'));
    await tester.pumpAndSettle();
    expect(find.text('تسميع الصفحة 2'), findsOneWidget);
    expect(find.text('سورة البقرة'), findsOneWidget);
  });

  testWidgets('the page is recited in place, like listening', (tester) async {
    final listener = FakeListener();
    await _pump(
      tester,
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MushafScreen(initialPage: 1),
        ),
      ),
      listener: listener,
    );

    // The recite button sits beside the page number, next to listen.
    expect(find.widgetWithText(FilledButton, 'استماع'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'تسميع'));
    await tester.pumpAndSettle();
    expect(find.byType(MushafScreen), findsOneWidget);
    expect(listener.listening, isTrue);
    expect(find.textContaining('تسميع الصفحة 1'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MushafScreen)),
    );
    // The words are hidden until recited.
    expect(container.read(pageRecitationProvider)!.hideText, isTrue);
    expect(container.read(pageRecitationProvider)!.recitedWords, isEmpty);

    listener.say('بسم الله الرحمن الرحيم الحمد لله', isFinal: true);
    await tester.pump();
    expect(container.read(pageRecitationProvider)!.recitedWords, {
      const AyahRef(1, 1): PageRecitation.allWords,
      const AyahRef(1, 2): 2,
    });
    await tester.pump(const Duration(seconds: 1));
    listener.say('رب الناس', isFinal: true);
    await tester.pump();
    // Only the word recited wrongly stays hidden; the rest of its ayah
    // shows and the microphone keeps listening.
    expect(container.read(pageRecitationProvider)!.recitedWords, {
      const AyahRef(1, 1): PageRecitation.allWords,
      const AyahRef(1, 2): PageRecitation.allWords,
    });
    expect(container.read(pageRecitationProvider)!.wrongWords, {
      (const AyahRef(1, 2), 4),
    });
    expect(
      tester.widget<MushafPageView>(find.byType(MushafPageView)).wrongWords,
      {(const AyahRef(1, 2), 4)},
    );
    expect(listener.listening, isTrue);

    // A labelled button shows the whole page.
    await tester.tap(find.text('إظهار الآيات'));
    await tester.pump();
    expect(container.read(pageRecitationProvider)!.hideText, isFalse);
    expect(find.text('إخفاء الآيات'), findsOneWidget);
    expect(find.textContaining('خطأ في الآية 2'), findsOneWidget);
    final states = container.read(pageRecitationProvider)!.ayahStates;
    expect(states.values, [AyahRecitation.correct, AyahRecitation.mistake]);

    // Listening after reciting shows the whole text, even with the
    // recitation hiding it.
    await tester.tap(find.text('إخفاء الآيات'));
    await tester.pump();
    await container.read(audioProvider.notifier).playFrom(const AyahRef(1, 3));
    await tester.pump();
    expect(listener.listening, isFalse);
    expect(
      tester.widget<MushafPageView>(find.byType(MushafPageView)).recitedWords,
      isNull,
    );
    await container.read(audioProvider.notifier).close();
    await tester.pump();

    // Let listening restart after the pause, as it does on a phone.
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('إغلاق التسميع'));
    await tester.pumpAndSettle();
    expect(container.read(pageRecitationProvider), isNull);
    expect(container.read(recitationHistoryProvider).single.page, 1);
  });

  testWidgets('a surah longer than a page is recited on, turning pages', (
    tester,
  ) async {
    final listener = FakeListener();
    final mushaf = parseMushaf(File(mushafLayoutAssetPath).readAsStringSync());
    final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
    // Al-Mulk starts on page 562 and ends on page 564.
    const start = 562;
    await _pump(
      tester,
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MushafScreen(initialPage: start),
        ),
      ),
      listener: listener,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'تسميع'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MushafScreen)),
    );
    expect(container.read(pageRecitationProvider)!.lastPage, 564);

    final ayat = {for (final w in mushaf.page(start).words) w.ayah};
    final text = [
      'بسم الله الرحمن الرحيم',
      for (final a in ayat) surahs[a.surah - 1].ayahs[a.ayah - 1],
    ].join(' ');
    listener.say(text);
    await tester.pumpAndSettle();
    // Words still being recognized do not turn the page yet.
    expect(
      tester.widget<MushafPageView>(find.byType(MushafPageView)).page.number,
      start,
    );
    // The reciter pauses at the end of the page.
    listener.say(text, isFinal: true);
    await tester.pumpAndSettle();

    expect(listener.listening, isTrue);
    expect(container.read(pageRecitationProvider)!.session.mistakes, isEmpty);
    final shown = tester.widget<MushafPageView>(find.byType(MushafPageView));
    expect(shown.page.number, start + 1);
    // The next page is hidden too, until recited.
    expect(shown.recitedWords, isNotNull);
  });

  group('the page turns only once the page shown is recited', () {
    // Al-Baqarah 1 to 5 are on page 2, 6 to 16 on page 3.
    final baqarah = parseSurahs(
      File(quranAssetPath).readAsStringSync(),
    )[1].ayahs;
    String ayat(int from, int to) => baqarah.sublist(from - 1, to).join(' ');

    Future<ProviderContainer> recite(
      WidgetTester tester,
      FakeListener listener, {
      String? settings,
    }) async {
      await _pump(
        tester,
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: MushafScreen(initialPage: 2),
          ),
        ),
        listener: listener,
        settings: settings,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'تسميع'));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(MushafScreen)),
      );
    }

    // A pause ends what the recognizer heard; it listens again shortly.
    Future<void> pause(
      WidgetTester tester,
      FakeListener listener,
      String text,
    ) async {
      listener.say(text, isFinal: true);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    int shownPage(WidgetTester tester) =>
        tester.widget<MushafPageView>(find.byType(MushafPageView)).page.number;

    testWidgets('not when the recognizer guesses ahead of the reciter', (
      tester,
    ) async {
      final listener = FakeListener();
      final container = await recite(tester, listener);
      await pause(tester, listener, ayat(1, 3));
      expect(shownPage(tester), 2);

      // Reciting ayah 4, the recognizer guesses on into page 3, as
      // Whisper may, then takes the guess back.
      listener.say(ayat(4, 7));
      await tester.pumpAndSettle();
      expect(container.read(pageRecitationProvider)!.currentWord.$1.ayah, 8);
      expect(shownPage(tester), 2);
      listener.say(baqarah[3].split(' ').take(6).join(' '));
      await tester.pumpAndSettle();
      expect(shownPage(tester), 2);

      await pause(tester, listener, ayat(4, 4));
      expect(shownPage(tester), 2);
      await pause(tester, listener, ayat(5, 5));
      expect(shownPage(tester), 3);
      expect(container.read(pageRecitationProvider)!.session.mistakes, isEmpty);
    });

    testWidgets('reciting fast without a pause turns it too', (tester) async {
      final listener = FakeListener();
      await recite(tester, listener);
      // One listening session, the recognizer spelling its first word one
      // way, then another, as it goes.
      final words = '${ayat(1, 5)} ${ayat(6, 7)}'.split(' ');
      for (var k = 1; k <= words.length; k++) {
        final heard = [...words.take(k)];
        if (k.isOdd) heard[0] = 'الف';
        listener.say(heard.join(' '));
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pumpAndSettle();
      expect(shownPage(tester), 3);
    });

    testWidgets('a pause half way through the page does not turn it', (
      tester,
    ) async {
      final listener = FakeListener();
      await recite(tester, listener);
      for (var a = 1; a <= 4; a++) {
        listener.say(ayat(a, a));
        await tester.pump();
        // Silence after the ayah, before the recognizer ends.
        await tester.pump(const Duration(seconds: 2));
        await pause(tester, listener, ayat(a, a));
        expect(shownPage(tester), 2, reason: 'after ayah $a');
      }
      await pause(tester, listener, ayat(5, 5));
      expect(shownPage(tester), 3);
    });

    testWidgets('and the page does not turn on its own while reciting', (
      tester,
    ) async {
      final listener = FakeListener();
      await recite(
        tester,
        listener,
        settings: '{"askRecitationMode":false,"autoPageTurn":true,"autoPageSeconds":10}',
      );
      await pause(tester, listener, ayat(1, 2));
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(shownPage(tester), 2);
    });
  });

  group('a mistake hides and colours only the wrong word', () {
    // Al-Baqarah 1 to 5 are on page 2.
    final baqarah = parseSurahs(
      File(quranAssetPath).readAsStringSync(),
    )[1].ayahs;
    final ayah4 = baqarah[3].split(' ');

    Future<FakeListener> recite(WidgetTester tester) async {
      final listener = FakeListener();
      await _pump(
        tester,
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: MushafScreen(initialPage: 2),
          ),
        ),
        listener: listener,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'تسميع'));
      await tester.pumpAndSettle();
      listener.say(baqarah.take(3).join(' '), isFinal: true);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      return listener;
    }

    MushafPageView shown(WidgetTester tester) =>
        tester.widget<MushafPageView>(find.byType(MushafPageView));

    /// Ayat 1 to [ayat] show, green, except the word [extraBefore] that
    /// extra words were said before, which shows red where they were.
    void expectRecitedRight(
      WidgetTester tester,
      int ayat, {
      (AyahRef, int)? extraBefore,
    }) {
      final page = shown(tester);
      for (var a = 1; a <= ayat; a++) {
        final ayah = AyahRef(2, a);
        expect(page.recitedWords![ayah], PageRecitation.allWords);
        expect(page.wrongWords.where((w) => w.$1 == ayah), isEmpty);
        for (final w in page.page.words) {
          if (w.ayah == ayah &&
              !w.isAyahEnd &&
              (ayah, w.position) != extraBefore) {
            // Green, not red.
            final colour = page.wordColors[(ayah, w.position)]!;
            expect(colour.g, greaterThan(colour.r), reason: '$ayah');
          }
        }
      }
    }

    testWidgets('a wrong word leaves the ayat before it as recited', (
      tester,
    ) async {
      final listener = await recite(tester);
      listener.say(([...ayah4]..[4] = 'كتب').join(' '));
      await tester.pumpAndSettle();
      expectRecitedRight(tester, 3);
      expect(shown(tester).wrongWords, {(const AyahRef(2, 4), 5)});
      expect(shown(tester).recitedWords![const AyahRef(2, 4)], isNonZero);
    });

    testWidgets('a slip, then going back, does not undo what was recited', (
      tester,
    ) async {
      final listener = await recite(tester);
      // The reciter stumbles after four words of ayah 4, then recites it
      // again from its third word.
      listener.say(
        [
          ...ayah4.take(4),
          'يا',
          'رب',
          'ما',
          'هو',
          'لا',
          'ادري',
          ...ayah4.skip(2),
        ].join(' '),
        isFinal: true,
      );
      await tester.pumpAndSettle();
      expectRecitedRight(tester, 4, extraBefore: (const AyahRef(2, 4), 3));
    });

    testWidgets('a wrong word, then reciting the ayah again', (tester) async {
      final listener = await recite(tester);
      listener.say([...ayah4.take(4), 'كتب', ...ayah4].join(' '));
      await tester.pumpAndSettle();
      expectRecitedRight(tester, 4, extraBefore: (const AyahRef(2, 4), 1));
    });
  });

  testWidgets('reciting goes on from where it last stopped', (tester) async {
    final listener = FakeListener();
    final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
    final mulk = surahs[66].ayahs;
    await _pump(
      tester,
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MushafScreen(initialPage: 562),
        ),
      ),
      listener: listener,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MushafScreen)),
    );
    expect(container.read(lastRecitationProvider), isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'تسميع'));
    await tester.pumpAndSettle();
    listener.say(mulk.take(2).join(' '));
    await tester.pump();
    await tester.tap(find.byTooltip('إغلاق التسميع'));
    await tester.pumpAndSettle();
    expect(container.read(lastRecitationProvider), const AyahRef(67, 3));

    await container.read(pageRecitationProvider.notifier).resume();
    await tester.pumpAndSettle();
    final recitation = container.read(pageRecitationProvider)!;
    expect(recitation.from, const AyahRef(67, 3));
    expect(recitation.session.expected.firstWhere((w) => !w.optional).ayah, 3);
    // The ayat before it show; the rest are hidden until recited.
    final shown = tester.widget<MushafPageView>(find.byType(MushafPageView));
    expect(shown.recitedWords, {
      const AyahRef(67, 1): PageRecitation.allWords,
      const AyahRef(67, 2): PageRecitation.allWords,
    });
    await tester.tap(find.byTooltip('إغلاق التسميع'));
    await tester.pumpAndSettle();
  });

  testWidgets('a recitation plan portion is recited and ticked off', (
    tester,
  ) async {
    final listener = FakeListener();
    final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
    await _pump(
      tester,
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MushafScreen(initialPage: 2),
        ),
      ),
      listener: listener,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MushafScreen)),
    );
    // A page a day: the second portion is page 2, al-Baqarah 1 to 5.
    final plan = container
        .read(khatmaPlansProvider.notifier)
        .add(
          type: KhatmaType.custom,
          title: 'r',
          color: 0,
          customDays: 604,
          recite: true,
        );
    await container.read(pageRecitationProvider.notifier).startPortion(plan, 1);
    await tester.pumpAndSettle();
    final recitation = container.read(pageRecitationProvider)!;
    expect(recitation.lastPage, 2);
    expect(
      {
        for (final w in recitation.session.expected)
          if (w.kind == WordKind.ayah) (w.surah, w.ayah),
      },
      {for (var a = 1; a <= 5; a++) (2, a)},
    );

    listener.say(surahs[1].ayahs.take(5).join(' '), isFinal: true);
    await tester.pumpAndSettle();
    expect(container.read(khatmaPlansProvider).single.done, {1});
    expect(container.read(lastRecitationProvider), const AyahRef(2, 6));
    await tester.tap(find.byTooltip('إغلاق التسميع'));
    await tester.pumpAndSettle();
  });

  group('a page where a surah starts part way down', () {
    // Page 583 starts in the middle of An-Naba and An-Nazi'at starts on it.
    const page = 583;
    final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());

    Future<ProviderContainer> open(
      WidgetTester tester,
      FakeListener listener,
    ) async {
      await _pump(
        tester,
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: MushafScreen(initialPage: page),
          ),
        ),
        listener: listener,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'تسميع'));
      await tester.pumpAndSettle();
      expect(find.text('من أين تبدأ التسميع؟'), findsOneWidget);
      expect(_inSheet('من أول الصفحة'), findsOneWidget);
      return ProviderScope.containerOf(
        tester.element(find.byType(MushafScreen)),
      );
    }

    testWidgets('asks where to start, and starts at the surah chosen', (
      tester,
    ) async {
      final listener = FakeListener();
      final container = await open(tester, listener);
      await tester.tap(_inSheet('من أول سورة النازعات'));
      await tester.pumpAndSettle();
      final recitation = container.read(pageRecitationProvider)!;
      expect(recitation.from, const AyahRef(79, 1));
      expect(listener.listening, isTrue);

      listener.say(
        ['بسم الله الرحمن الرحيم', ...surahs[78].ayahs.take(5)].join(' '),
      );
      await tester.pumpAndSettle();
      expect(recitation.session.mistakes, isEmpty);
      // The end of An-Naba before it shows.
      final shown = tester.widget<MushafPageView>(find.byType(MushafPageView));
      expect(
        shown.recitedWords![const AyahRef(78, 40)],
        PageRecitation.allWords,
      );
      await tester.tap(find.byTooltip('إغلاق التسميع'));
      await tester.pumpAndSettle();
    });

    testWidgets('or at the top of the page, on into the next surah', (
      tester,
    ) async {
      final listener = FakeListener();
      final container = await open(tester, listener);
      await tester.tap(_inSheet('من أول الصفحة'));
      await tester.pumpAndSettle();
      final recitation = container.read(pageRecitationProvider)!;
      expect(recitation.from, isNull);

      listener.say(
        [
          ...surahs[77].ayahs.skip(30),
          'بسم الله الرحمن الرحيم',
          ...surahs[78].ayahs.take(5),
        ].join(' '),
      );
      await tester.pumpAndSettle();
      expect(recitation.session.mistakes, isEmpty);
      expect(recitation.ayahStates.values.toSet(), {AyahRecitation.correct});
      await tester.tap(find.byTooltip('إغلاق التسميع'));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('reciting a page again starts anew', (tester) async {
    final listener = FakeListener();
    final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
    // Page 604 holds the last three surahs, each with its basmala, so it
    // also asks where to start.
    await _pump(
      tester,
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MushafScreen(initialPage: 604),
        ),
      ),
      listener: listener,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MushafScreen)),
    );
    final all = [
      for (final s in [112, 113, 114]) ...[
        'بسم الله الرحمن الرحيم',
        ...surahs[s - 1].ayahs,
      ],
    ].join(' ');
    await tester.tap(find.widgetWithText(FilledButton, 'تسميع'));
    await tester.pumpAndSettle();
    expect(_inSheet('من أول سورة الفلق'), findsOneWidget);
    expect(_inSheet('من أول سورة الناس'), findsOneWidget);
    await tester.tap(_inSheet('من أول الصفحة'));
    await tester.pumpAndSettle();
    listener.say(all);
    await tester.pumpAndSettle();
    var recitation = container.read(pageRecitationProvider)!;
    expect(recitation.session.result.isComplete, isTrue);
    expect(recitation.session.mistakes, isEmpty);
    expect(listener.listening, isFalse);
    // The mistakes report shows at the end.
    expect(_inSheet('تقرير الأخطاء'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Pressing it again recites the page anew, not as words after its end.
    await tester.tap(find.widgetWithText(FilledButton, 'تسميع'));
    await tester.pumpAndSettle();
    await tester.tap(_inSheet('من أول الصفحة'));
    await tester.pumpAndSettle();
    recitation = container.read(pageRecitationProvider)!;
    expect(recitation.session.result.progress, 0);
    listener.say(all);
    await tester.pumpAndSettle();
    expect(recitation.session.mistakes, isEmpty);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('إغلاق التسميع'));
    await tester.pumpAndSettle();
  });
}

/// Al-Fatiha with harakat, as the offline model writes it, with
/// al-hamdu said as al-hamda.
const _fatihaWrongHaraka =
    'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ الْحَمْدَ لِلَّهِ رَبِّ الْعَالَمِينَ '
    'الرَّحْمَنِ الرَّحِيمِ مَالِكِ يَوْمِ الدِّينِ '
    'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ '
    'صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ '
    'وَلَا الضَّالِّينَ';

void _modeTests() {
  testWidgets('before reciting, asks how strictly to check', (tester) async {
    final listener = FakeListener();
    await _pump(
      tester,
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MushafScreen(initialPage: 1),
        ),
      ),
      listener: listener,
      askMode: true,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MushafScreen)),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'تسميع'));
    await tester.pumpAndSettle();
    expect(_inSheet('كيف تريد التسميع؟'), findsOneWidget);
    expect(listener.listening, isFalse);
    await tester.tap(_inSheet('مخفف: الكلمات فقط'));
    await tester.pumpAndSettle();
    expect(listener.listening, isTrue);
    var recitation = container.read(pageRecitationProvider)!;
    expect(recitation.session.mode, RecitationMode.lenient);
    expect(
      container.read(settingsProvider).recitationMode,
      RecitationMode.lenient,
    );
    expect(find.textContaining('مخفف'), findsOneWidget);

    // Remembered: not asked again.
    await tester.tap(find.byTooltip('إغلاق التسميع'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'تسميع'));
    await tester.pumpAndSettle();
    await tester.tap(_inSheet('تذكّر اختياري ولا تسألني مرة أخرى'));
    await tester.pump();
    await tester.tap(_inSheet('دقيق: الكلمات والحركات'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).askRecitationMode, isFalse);
    await tester.tap(find.byTooltip('إغلاق التسميع'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'تسميع'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    recitation = container.read(pageRecitationProvider)!;
    expect(recitation.session.mode, RecitationMode.strict);
    await tester.tap(find.byTooltip('إغلاق التسميع'));
    await tester.pumpAndSettle();
  });

  testWidgets('a wrong haraka shows in orange and in the report', (
    tester,
  ) async {
    final listener = FakeListener();
    await _pump(
      tester,
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MushafScreen(initialPage: 1),
        ),
      ),
      listener: listener,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MushafScreen)),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'تسميع'));
    await tester.pumpAndSettle();
    listener.say(_fatihaWrongHaraka, isFinal: true);
    await tester.pumpAndSettle();
    final recitation = container.read(pageRecitationProvider)!;
    expect(recitation.session.result.isComplete, isTrue);
    expect(recitation.ayahStates[const AyahRef(1, 2)], AyahRecitation.harakat);
    expect(recitation.ayahStates[const AyahRef(1, 3)], AyahRecitation.correct);
    expect(recitation.harakatWords, {(const AyahRef(1, 2), 1)});
    expect(recitation.wrongWords, isEmpty);
    final view = tester.widget<MushafPageView>(find.byType(MushafPageView));
    expect(view.harakatWords, {(const AyahRef(1, 2), 1)});

    // The report lists it with the harakat mistakes.
    expect(_inSheet('تقرير الأخطاء'), findsOneWidget);
    expect(_inSheet('أخطاء الكلمات والآيات (0)'), findsOneWidget);
    expect(_inSheet('أخطاء الحركات (1)'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.textContaining('الْحَمْدَ'),
      ),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('إغلاق التسميع'));
    await tester.pumpAndSettle();
  });
}
