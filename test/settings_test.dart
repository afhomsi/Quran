import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/app.dart';
import 'package:hifz/data/backup.dart';
import 'package:hifz/data/mushaf_repository.dart';
import 'package:hifz/data/page_fonts.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:hifz/l10n/strings.dart';
import 'package:hifz/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Skips real font loading, which needs the asset bundle.
class _FakePageFonts extends PageFonts {
  _FakePageFonts() : super(rootBundle);

  @override
  Future<String> load(int page) async => PageFonts.familyFor(page);
}

/// Starts the app with [settings] already saved.
Future<SharedPreferences> _start(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(),
  List<bool>? screenWake,
}) async {
  SharedPreferences.setMockInitialValues({
    settingsKey: jsonEncode(settings.toJson()),
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
        pageFontsProvider.overrideWithValue(_FakePageFonts()),
        screenWakeProvider.overrideWithValue((on) async => screenWake?.add(on)),
      ],
      child: const HifzApp(),
    ),
  );
  await tester.pumpAndSettle();
  // The app opens on the mushaf; start from the index.
  await tester.tap(find.text(const S(AppLanguage.ar).tabIndex));
  await tester.pumpAndSettle();
  return prefs;
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('الإعدادات'));
  await tester.pumpAndSettle();
}

/// Scrolls the settings list to [text] and taps it.
Future<void> _tapSetting(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  test('settings survive a round trip and ignore unknown values', () {
    const changed = AppSettings(
      language: AppLanguage.ur,
      nightMode: true,
      pageTheme: PageTheme.sky,
      autoPageSeconds: 90,
    );
    final back = AppSettings.fromJson(changed.toJson());
    expect(back.toJson(), changed.toJson());

    final odd = AppSettings.fromJson({'language': 'xx', 'nightMode': 'yes'});
    expect(odd.language, AppLanguage.ar);
    expect(odd.nightMode, isFalse);
  });

  test('numbers use the digits of the language unless 123 is chosen', () {
    expect(const S(AppLanguage.ar, westernDigits: false).n(604), '٦٠٤');
    expect(const S(AppLanguage.ur, westernDigits: false).n(604), '۶۰۴');
    expect(const S(AppLanguage.bn, westernDigits: false).n(604), '৬০৪');
    expect(const S(AppLanguage.en, westernDigits: false).n(604), '604');
    expect(const S(AppLanguage.ar).n(604), '604');
  });

  test('a backup restores settings, bookmarks and the last page', () async {
    SharedPreferences.setMockInitialValues({
      'last_page': 77,
      'bookmarks': ['2:255', '18:1'],
      settingsKey: jsonEncode(
        const AppSettings(language: AppLanguage.en).toJson(),
      ),
    });
    final prefs = await SharedPreferences.getInstance();
    final backup = exportBackup(prefs);

    await prefs.clear();
    expect(await importBackup(prefs, 'not a backup'), isFalse);
    expect(await importBackup(prefs, '{"app": "other"}'), isFalse);
    expect(prefs.getKeys(), isEmpty);

    expect(await importBackup(prefs, backup), isTrue);
    expect(prefs.getInt('last_page'), 77);
    expect(prefs.getStringList('bookmarks'), ['2:255', '18:1']);
    final settings = AppSettings.fromJson(
      jsonDecode(prefs.getString(settingsKey)!) as Map<String, dynamic>,
    );
    expect(settings.language, AppLanguage.en);
  });

  testWidgets('switching the language changes the app and its direction', (
    tester,
  ) async {
    final prefs = await _start(tester);
    await _openSettings(tester);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Mushaf'), findsOneWidget);
    expect(find.text('Al-Baqarah'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('Mushaf'))),
      TextDirection.ltr,
    );
    expect(prefs.getString(settingsKey), contains('"language":"en"'));

    // The mushaf page itself stays right to left.
    await tester.tap(find.text('Al-Baqarah'));
    await tester.pumpAndSettle();
    expect(find.text('Surah Al-Baqarah'), findsOneWidget);
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('night mode, digits and the recite button follow the settings', (
    tester,
  ) async {
    await _start(tester);
    expect(find.text('تسميع'), findsOneWidget);
    await _openSettings(tester);

    await _tapSetting(tester, 'الوضع الليلي');
    expect(
      Theme.of(tester.element(find.text('الإعدادات'))).brightness,
      Brightness.dark,
    );
    await _tapSetting(tester, 'استخدام الأرقام (123 بدلا من ١٢٣)');
    await _tapSetting(tester, 'إخفاء زر التسميع');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('تسميع'), findsNothing);
    // Al-Baqarah has 286 ayat.
    expect(find.text('مدنية · ٢٨٦ آية'), findsOneWidget);
  });

  testWidgets('keeps the screen on only while the setting is on', (
    tester,
  ) async {
    final wake = <bool>[];
    await _start(tester, screenWake: wake);
    expect(wake, [true]);
    await _openSettings(tester);
    await _tapSetting(tester, 'عدم قفل الشاشة عند استخدام التطبيق');
    expect(wake, [true, false]);
  });

  testWidgets('shows two facing pages on a wide screen', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _start(
      tester,
      settings: const AppSettings(twoPagesInLandscape: true),
    );

    await tester.tap(find.text('البقرة'));
    await tester.pumpAndSettle();
    expect(find.text('1 – 2'), findsOneWidget);
    expect(find.text('سورة الفاتحة'), findsWidgets);

    await tester.tap(find.byTooltip('الصفحة التالية'));
    await tester.pumpAndSettle();
    expect(find.text('3 – 4'), findsOneWidget);
  });

  testWidgets('turns pages automatically and can pause', (tester) async {
    final prefs = await _start(
      tester,
      settings: const AppSettings(autoPageTurn: true, autoPageSeconds: 20),
    );
    await tester.tap(find.text('البقرة'));
    await tester.pumpAndSettle();
    expect(prefs.getInt('last_page'), 2);

    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    expect(prefs.getInt('last_page'), 3);

    await tester.tap(find.byTooltip('القائمة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إيقاف التقليب التلقائي'));
    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();
    expect(prefs.getInt('last_page'), 3);
  });

  testWidgets('scrolls pages vertically when chosen', (tester) async {
    await _start(tester, settings: const AppSettings(verticalScroll: true));
    await tester.tap(find.text('البقرة'));
    await tester.pumpAndSettle();
    final view = tester.widget<PageView>(find.byType(PageView));
    expect(view.scrollDirection, Axis.vertical);
  });

  testWidgets('marks where each quarter of a hizb starts', (tester) async {
    await _start(tester);
    // Page 5 has the quarter that starts at al-Baqarah 26.
    await tester.tap(find.byTooltip('انتقال إلى صفحة'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '5',
    );
    await tester.pump();
    await tester.tap(find.text('انتقال'));
    await tester.pumpAndSettle();
    expect(find.text('۞'), findsOneWidget);
  });
}
