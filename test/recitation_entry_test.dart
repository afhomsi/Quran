import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/app.dart';
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
import 'package:hifz/recitation/speech_listener.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_listener.dart';
import 'fake_player.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  FakeListener? listener,
}) async {
  SharedPreferences.setMockInitialValues({});
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
      ],
      child: child,
    ),
  );
  await tester.pumpAndSettle();
}

Finder _inSheet(String text) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

void main() {
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
    expect(
      container.read(pageRecitationProvider)!.recitedWords[const AyahRef(1, 2)],
      PageRecitation.allWords,
    );

    // A labelled button shows the whole page.
    await tester.tap(find.text('إظهار الآيات'));
    await tester.pump();
    expect(container.read(pageRecitationProvider)!.hideText, isFalse);
    expect(find.text('إخفاء الآيات'), findsOneWidget);
    expect(find.textContaining('خطأ في الآية 2'), findsOneWidget);
    final states = container.read(pageRecitationProvider)!.ayahStates;
    expect(states.values, [AyahRecitation.correct, AyahRecitation.mistake]);

    // Listening after reciting shows the ayat as the reciter reaches them,
    // even with the recitation hiding the rest.
    await tester.tap(find.text('إخفاء الآيات'));
    await tester.pump();
    await container.read(audioProvider.notifier).playFrom(const AyahRef(1, 3));
    await tester.pump();
    expect(listener.listening, isFalse);
    expect(
      tester.widget<MushafPageView>(find.byType(MushafPageView)).recitedWords,
      {const AyahRef(1, 3): PageRecitation.allWords},
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
}
