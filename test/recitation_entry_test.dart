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
import 'package:hifz/features/mushaf/mushaf_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Skips real font loading, which needs the asset bundle.
class _FakePageFonts extends PageFonts {
  _FakePageFonts() : super(rootBundle);

  @override
  Future<String> load(int page, MushafPalette palette) async =>
      PageFonts.familyFor(page, palette);
}

Future<void> _pump(WidgetTester tester, Widget child) async {
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

    await tester.tap(find.text('تسميع'));
    await tester.pumpAndSettle();
    expect(_inSheet('تسميع سورة البقرة كاملة'), findsOneWidget);
    await tester.tap(_inSheet('تسميع هذه الصفحة (2)'));
    await tester.pumpAndSettle();
    expect(find.text('تسميع الصفحة 2'), findsOneWidget);
    expect(find.text('سورة البقرة'), findsOneWidget);
  });
}
