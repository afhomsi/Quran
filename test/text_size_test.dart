import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/app.dart';
import 'package:hifz/data/mushaf_repository.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:hifz/features/mushaf/mushaf_page_view.dart';
import 'package:hifz/l10n/strings.dart';
import 'package:hifz/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _t = S(AppLanguage.ar);

/// Starts the app on the mushaf with [scale] as the saved text size.
Future<SharedPreferences> _start(
  WidgetTester tester, {
  double scale = 1,
}) async {
  SharedPreferences.setMockInitialValues({
    settingsKey: jsonEncode(AppSettings(mushafTextScale: scale).toJson()),
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
        screenWakeProvider.overrideWithValue((on) async {}),
      ],
      child: const HifzApp(),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

double _savedScale(SharedPreferences prefs) => AppSettings.fromJson(
  jsonDecode(prefs.getString(settingsKey)!) as Map<String, dynamic>,
).mushafTextScale;

Finder get _pageScroll => find.descendant(
  of: find.byType(MushafPageView),
  matching: find.byType(SingleChildScrollView),
);

void main() {
  test('the text size is saved and kept in its range', () {
    expect(const AppSettings().mushafTextScale, 1);
    AppSettings read(Object? v) => AppSettings.fromJson({'mushafTextScale': v});
    expect(read(1.4).mushafTextScale, 1.4);
    expect(read(9).mushafTextScale, maxMushafTextScale);
    expect(read(0.1).mushafTextScale, minMushafTextScale);
    expect(read('big').mushafTextScale, 1);
    expect(read(double.nan).mushafTextScale, 1);
    final saved = AppSettings.fromJson(
      jsonDecode(jsonEncode(const AppSettings(mushafTextScale: 1.6).toJson()))
          as Map<String, dynamic>,
    );
    expect(saved.mushafTextScale, 1.6);
  });

  testWidgets('the printed page keeps its lines at the normal size', (
    tester,
  ) async {
    await _start(tester);
    expect(find.byType(MushafPageView), findsOneWidget);
    expect(_pageScroll, findsNothing);
  });

  testWidgets('a larger size lets the words flow and the page scroll', (
    tester,
  ) async {
    await _start(tester, scale: 1.8);
    expect(_pageScroll, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu sizes the text and saves it', (tester) async {
    final prefs = await _start(tester);
    await tester.tap(find.byTooltip(_t.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t.textSize));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(_t.largerText));
    await tester.pump();
    await tester.tap(find.byTooltip(_t.largerText));
    await tester.pumpAndSettle();
    expect(_savedScale(prefs), closeTo(1.2, 1e-9));
    expect(find.text('120%'), findsOneWidget);
    expect(_pageScroll, findsOneWidget);
    await tester.tap(find.text(_t.defaultTextSize));
    await tester.pumpAndSettle();
    expect(_savedScale(prefs), 1);
    await tester.tap(find.byTooltip(_t.smallerText));
    await tester.pumpAndSettle();
    expect(_savedScale(prefs), closeTo(0.9, 1e-9));
    expect(_pageScroll, findsNothing);
  });

  testWidgets('spreading two fingers on the page enlarges the text', (
    tester,
  ) async {
    final prefs = await _start(tester);
    final center = tester.getCenter(find.byType(MushafPageView));
    final a = await tester.startGesture(center - const Offset(0, 50));
    final b = await tester.startGesture(center + const Offset(0, 50));
    await tester.pump();
    await a.moveBy(const Offset(0, -25));
    await b.moveBy(const Offset(0, 25));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(_savedScale(prefs), closeTo(1.5, 1e-9));
    expect(_pageScroll, findsOneWidget);
  });
}
