import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/app.dart';
import 'package:hifz/audio/audio_store.dart';
import 'package:hifz/audio/ayah_audio.dart';
import 'package:hifz/features/mushaf/mushaf_page_view.dart';
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
}) async {
  // How strictly to check is asked before each recitation; most tests
  // recite with the mode chosen once for all.
  SharedPreferences.setMockInitialValues({
    if (!askMode) 'settings': '{"askRecitationMode":false}',
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

    expect(listener.listening, isTrue);
    expect(container.read(pageRecitationProvider)!.session.mistakes, isEmpty);
    final shown = tester.widget<MushafPageView>(find.byType(MushafPageView));
    expect(shown.page.number, start + 1);
    // The next page is hidden too, until recited.
    expect(shown.recitedWords, isNotNull);
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
