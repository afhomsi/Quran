import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/app.dart';
import 'package:hifz/data/mushaf_repository.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('opens a surah, turns pages and remembers the page', (
    tester,
  ) async {
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
        ],
        child: const HifzApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('المصحف'), findsOneWidget);
    final dir = Directionality.of(tester.element(find.text('المصحف')));
    expect(dir, TextDirection.rtl);

    await tester.tap(find.text('الفهرس'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('البقرة'));
    await tester.pumpAndSettle();

    // Running header as text, surah header as calligraphy.
    expect(find.text('2 البقرة (286)'), findsOneWidget);
    expect(find.text('سُورَةُ البقرة'), findsOneWidget);
    expect(find.text('الجزء 1 (1/8)'), findsOneWidget);
    // In the header and between the page buttons.
    expect(find.widgetWithText(InkWell, '2'), findsNWidgets(2));
    expect(prefs.getInt('last_page'), 2);

    await tester.tap(find.byTooltip('الصفحة التالية'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InkWell, '3'), findsNWidgets(2));
    expect(prefs.getInt('last_page'), 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InkWell, '4'), findsNWidgets(2));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('الصفحة السابقة'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InkWell, '2'), findsNWidgets(2));
    expect(prefs.getInt('last_page'), 2);
  });

  testWidgets('searches the index and opens the result', (tester) async {
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
        ],
        child: const HifzApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('الفهرس'));
    await tester.pumpAndSettle();

    // Without diacritics or hamza, as people type.
    await tester.enterText(find.byType(TextField), 'الكهف');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'الكهف'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'البقرة'), findsNothing);

    await tester.tap(find.text('الجزء'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '٣');
    await tester.pumpAndSettle();
    expect(find.text('جزء 30'), findsOneWidget);
    expect(find.text('جزء 3'), findsOneWidget);
    expect(find.text('جزء 2'), findsNothing);
    // Opens onto its pages: juz 30 runs from page 582 to the end.
    await tester.tap(find.text('جزء 30'));
    await tester.pumpAndSettle();
    expect(find.text('582'), findsOneWidget);
    expect(find.text('604'), findsOneWidget);
    expect(find.text('581'), findsNothing);

    await tester.tap(find.text('الربع'));
    await tester.pumpAndSettle();
    expect(find.text('الفاتحة: 1 - الصفحة 1'), findsOneWidget);
    expect(find.text('البقرة: 26 - الصفحة 5'), findsOneWidget);

    await tester.tap(find.text('الصفحة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '293');
    await tester.pumpAndSettle();
    expect(find.text('29'), findsNothing);
    await tester.tap(find.bySemanticsLabel('الصفحة 293'));
    await tester.pumpAndSettle();
    // Al-Kahf starts below the last ayah of al-Isra on this page.
    expect(find.text('17 الإسراء (111)'), findsOneWidget);
    expect(find.text('سُورَةُ الكهف'), findsOneWidget);
    expect(prefs.getInt('last_page'), 293);
  });
}
