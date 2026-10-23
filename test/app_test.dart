import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/app.dart';
import 'package:hifz/data/mushaf_repository.dart';
import 'package:hifz/data/page_fonts.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Skips real font loading, which needs the asset bundle.
class _FakePageFonts extends PageFonts {
  _FakePageFonts() : super(rootBundle);

  @override
  Future<String> load(int page) async => PageFonts.familyFor(page);
}

void main() {
  testWidgets('opens a surah in the mushaf and remembers the page', (
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
          pageFontsProvider.overrideWithValue(_FakePageFonts()),
        ],
        child: const HifzApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('المصحف'), findsOneWidget);
    final dir = Directionality.of(tester.element(find.text('المصحف')));
    expect(dir, TextDirection.rtl);

    await tester.tap(find.text('البقرة'));
    await tester.pumpAndSettle();

    expect(find.text('سورة البقرة'), findsOneWidget);
    expect(find.text('الجزء 1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(prefs.getInt('last_page'), 2);
  });
}
