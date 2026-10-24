import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/app.dart';
import 'package:hifz/data/mushaf_repository.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:hifz/l10n/strings.dart';
import 'package:hifz/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every on/off setting: its name in [AppSettings.toJson], how to read it,
/// how to change it and its title on the settings screen.
final _switches =
    <
      (
        String,
        bool Function(AppSettings),
        AppSettings Function(AppSettings, bool),
        String Function(S),
      )
    >[
      (
        'nightMode',
        (s) => s.nightMode,
        (s, v) => s.copyWith(nightMode: v),
        (t) => t.nightMode,
      ),
      (
        'tajweedColors',
        (s) => s.tajweedColors,
        (s, v) => s.copyWith(tajweedColors: v),
        (t) => t.tajweed,
      ),
      (
        'showHizbMarks',
        (s) => s.showHizbMarks,
        (s, v) => s.copyWith(showHizbMarks: v),
        (t) => t.showHizbMarks,
      ),
      (
        'verticalScroll',
        (s) => s.verticalScroll,
        (s, v) => s.copyWith(verticalScroll: v),
        (t) => t.verticalScroll,
      ),
      (
        'twoPagesInLandscape',
        (s) => s.twoPagesInLandscape,
        (s, v) => s.copyWith(twoPagesInLandscape: v),
        (t) => t.twoPagesInLandscape,
      ),
      (
        'autoPageTurn',
        (s) => s.autoPageTurn,
        (s, v) => s.copyWith(autoPageTurn: v),
        (t) => t.autoPageTurn,
      ),
      (
        'tapOpensAyahMenu',
        (s) => s.tapOpensAyahMenu,
        (s, v) => s.copyWith(tapOpensAyahMenu: v),
        (t) => t.tapOpensAyahMenu,
      ),
      (
        'keepScreenOn',
        (s) => s.keepScreenOn,
        (s, v) => s.copyWith(keepScreenOn: v),
        (t) => t.keepScreenOn,
      ),
      (
        'hideRecitationButton',
        (s) => s.hideRecitationButton,
        (s, v) => s.copyWith(hideRecitationButton: v),
        (t) => t.hideRecitationButton,
      ),
      (
        'hideWhileListening',
        (s) => s.hideWhileListening,
        (s, v) => s.copyWith(hideWhileListening: v),
        (t) => t.hideWhileListening,
      ),
      (
        'westernDigits',
        (s) => s.westernDigits,
        (s, v) => s.copyWith(westernDigits: v),
        (t) => t.westernDigitsTitle,
      ),
      (
        'followSystemFontSize',
        (s) => s.followSystemFontSize,
        (s, v) => s.copyWith(followSystemFontSize: v),
        (t) => t.followSystemFontSize,
      ),
    ];

Future<(SharedPreferences, ProviderContainer)> _load(
  Map<String, Object> saved,
) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return (prefs, container);
}

void main() {
  test('the defaults suit someone memorizing', () {
    const d = AppSettings();
    expect(d.language, AppLanguage.ar);
    expect(d.nightMode, isFalse);
    expect(d.keepScreenOn, isTrue);
    expect(d.hideWhileListening, isTrue);
    expect(d.showHizbMarks, isTrue);
    expect(d.hideRecitationButton, isFalse);
    expect(d.autoPageSeconds, 60);
    expect(AppSettings.fromJson({}).toJson(), d.toJson());
  });

  test('every setting is saved and read back on its own', () {
    expect(_switches.map((s) => s.$1).toSet(), hasLength(_switches.length));
    for (final (name, read, change, _) in _switches) {
      const d = AppSettings();
      final changed = change(d, !read(d));
      expect(read(changed), !read(d), reason: name);
      final back = AppSettings.fromJson(
        jsonDecode(jsonEncode(changed.toJson())) as Map<String, dynamic>,
      );
      expect(read(back), !read(d), reason: name);
      // Nothing else changed.
      final others = {...back.toJson()}..remove(name);
      final defaults = {...d.toJson()}..remove(name);
      expect(others, defaults, reason: name);
    }
  });

  test('every on/off setting is listed here', () {
    final bools = {
      for (final e in const AppSettings().toJson().entries)
        if (e.value is bool) e.key,
    };
    expect(bools, {for (final s in _switches) s.$1});
  });

  test('each value of the wrong type keeps its default', () {
    final odd = AppSettings.fromJson({
      for (final s in _switches) s.$1: 'yes',
      'language': 7,
      'pageTheme': 'purple',
      'autoPageSeconds': '90',
    });
    expect(odd.toJson(), const AppSettings().toJson());
  });

  test('every language and page colour is saved and read back', () {
    for (final language in AppLanguage.values) {
      for (final theme in PageTheme.values) {
        final s = AppSettings(language: language, pageTheme: theme);
        final back = AppSettings.fromJson(s.toJson());
        expect(back.language, language);
        expect(back.pageTheme, theme);
      }
    }
  });

  test('changes are kept for the next time the app opens', () async {
    var (prefs, c) = await _load({});
    c
        .read(settingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            language: AppLanguage.bn,
            pageTheme: PageTheme.mint,
            hideWhileListening: false,
            autoPageSeconds: 120,
          ),
        );
    final saved = prefs.getString(settingsKey)!;
    (_, c) = await _load({settingsKey: saved});
    final s = c.read(settingsProvider);
    expect(s.language, AppLanguage.bn);
    expect(s.pageTheme, PageTheme.mint);
    expect(s.hideWhileListening, isFalse);
    expect(s.autoPageSeconds, 120);
  });

  test('damaged saved settings open with the defaults', () async {
    for (final raw in ['', 'null', '[]', '"x"', '{', '{"nightMode": true']) {
      final (_, c) = await _load({settingsKey: raw});
      expect(
        c.read(settingsProvider).toJson(),
        const AppSettings().toJson(),
        reason: raw,
      );
    }
  });

  testWidgets('each switch on the settings screen changes its setting', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final mushaf = parseMushaf(File(mushafLayoutAssetPath).readAsStringSync());
    final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        mushafProvider.overrideWith((ref) async => mushaf),
        surahsProvider.overrideWith((ref) async => surahs),
        screenWakeProvider.overrideWithValue((on) async {}),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HifzApp()),
    );
    await tester.pumpAndSettle();
    const t = S(AppLanguage.ar);
    await tester.tap(find.text(t.tabIndex));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('الإعدادات'));
    await tester.pumpAndSettle();

    for (final (name, read, _, title) in _switches) {
      final before = read(container.read(settingsProvider));
      final tile = find.widgetWithText(SwitchListTile, title(t));
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      final after = container.read(settingsProvider);
      expect(read(after), !before, reason: name);
      final saved = AppSettings.fromJson(
        jsonDecode(prefs.getString(settingsKey)!) as Map<String, dynamic>,
      );
      expect(read(saved), !before, reason: name);
    }
    // Turning pages on their own is off again before the test ends.
    container
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(autoPageTurn: false));
    await tester.pumpAndSettle();
  });
}
