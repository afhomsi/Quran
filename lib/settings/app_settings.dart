import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reading_state.dart';

const settingsKey = 'settings';

/// The range of the auto page turn slider, in seconds.
const minAutoPageSeconds = 15;
const maxAutoPageSeconds = 300;

/// How much the mushaf text can be shrunk or enlarged, 1 being the size
/// that fits the printed page on the screen.
const minMushafTextScale = 0.8;
const maxMushafTextScale = 2.0;

enum AppLanguage {
  ar('العربية', TextDirection.rtl),
  en('English', TextDirection.ltr),
  bn('বাংলা', TextDirection.ltr),
  ur('اردو', TextDirection.rtl);

  const AppLanguage(this.nativeName, this.direction);

  /// The language's name in itself, as shown in the language picker.
  final String nativeName;
  final TextDirection direction;

  Locale get locale => Locale(name);
}

/// Background colors for the mushaf pages in day mode.
enum PageTheme {
  cream(Color(0xFFFFFBF2)),
  sand(Color(0xFFFFF3E3)),
  mint(Color(0xFFEDF6EE)),
  white(Color(0xFFFCFAFA)),
  sky(Color(0xFFE5F1FA));

  const PageTheme(this.color);

  final Color color;
}

/// Everything on the settings screen, saved as one JSON string.
class AppSettings {
  const AppSettings({
    this.language = AppLanguage.ar,
    this.nightMode = false,
    this.pageTheme = PageTheme.cream,
    this.twoPagesInLandscape = false,
    this.autoPageTurn = false,
    this.autoPageSeconds = 60,
    this.verticalScroll = false,
    this.tapOpensAyahMenu = false,
    this.keepScreenOn = true,
    this.westernDigits = true,
    this.followSystemFontSize = true,
    this.hideRecitationButton = false,
    this.hideWhileListening = true,
    this.showHizbMarks = true,
    this.tajweedColors = false,
    this.mushafTextScale = 1.0,
  });

  final AppLanguage language;
  final bool nightMode;
  final PageTheme pageTheme;

  /// Show two facing pages side by side when the screen is wider than tall.
  final bool twoPagesInLandscape;

  /// Turn to the next page every [autoPageSeconds] while reading.
  final bool autoPageTurn;
  final int autoPageSeconds;

  /// Scroll the pages up and down instead of swiping them sideways.
  final bool verticalScroll;

  /// A single tap on an ayah opens its menu, not only a long press.
  final bool tapOpensAyahMenu;
  final bool keepScreenOn;

  /// 123 instead of the language's own digits, such as ١٢٣.
  final bool westernDigits;
  final bool followSystemFontSize;
  final bool hideRecitationButton;

  /// While listening, hide the ayat of the page and show each one as the
  /// reciter reaches it.
  final bool hideWhileListening;

  /// The ۞ sign where each quarter of a hizb starts.
  final bool showHizbMarks;

  /// Color the letters of the mushaf by the rules of tajweed.
  final bool tajweedColors;

  /// The size of the mushaf text. Above 1 the words of the page flow on
  /// as many lines as they need, and the page scrolls.
  final double mushafTextScale;

  AppSettings copyWith({
    AppLanguage? language,
    bool? nightMode,
    PageTheme? pageTheme,
    bool? twoPagesInLandscape,
    bool? autoPageTurn,
    int? autoPageSeconds,
    bool? verticalScroll,
    bool? tapOpensAyahMenu,
    bool? keepScreenOn,
    bool? westernDigits,
    bool? followSystemFontSize,
    bool? hideRecitationButton,
    bool? hideWhileListening,
    bool? showHizbMarks,
    bool? tajweedColors,
    double? mushafTextScale,
  }) => AppSettings(
    language: language ?? this.language,
    nightMode: nightMode ?? this.nightMode,
    pageTheme: pageTheme ?? this.pageTheme,
    twoPagesInLandscape: twoPagesInLandscape ?? this.twoPagesInLandscape,
    autoPageTurn: autoPageTurn ?? this.autoPageTurn,
    autoPageSeconds: autoPageSeconds ?? this.autoPageSeconds,
    verticalScroll: verticalScroll ?? this.verticalScroll,
    tapOpensAyahMenu: tapOpensAyahMenu ?? this.tapOpensAyahMenu,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    westernDigits: westernDigits ?? this.westernDigits,
    followSystemFontSize: followSystemFontSize ?? this.followSystemFontSize,
    hideRecitationButton: hideRecitationButton ?? this.hideRecitationButton,
    hideWhileListening: hideWhileListening ?? this.hideWhileListening,
    showHizbMarks: showHizbMarks ?? this.showHizbMarks,
    tajweedColors: tajweedColors ?? this.tajweedColors,
    mushafTextScale: mushafTextScale ?? this.mushafTextScale,
  );

  Map<String, Object> toJson() => {
    'language': language.name,
    'nightMode': nightMode,
    'pageTheme': pageTheme.name,
    'twoPagesInLandscape': twoPagesInLandscape,
    'autoPageTurn': autoPageTurn,
    'autoPageSeconds': autoPageSeconds,
    'verticalScroll': verticalScroll,
    'tapOpensAyahMenu': tapOpensAyahMenu,
    'keepScreenOn': keepScreenOn,
    'westernDigits': westernDigits,
    'followSystemFontSize': followSystemFontSize,
    'hideRecitationButton': hideRecitationButton,
    'hideWhileListening': hideWhileListening,
    'showHizbMarks': showHizbMarks,
    'tajweedColors': tajweedColors,
    'mushafTextScale': mushafTextScale,
  };

  /// Reads what [toJson] wrote. Missing or unknown values keep their
  /// defaults, so settings saved by an older version still load.
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    const d = AppSettings();
    T pick<T>(String key, T fallback) =>
        json[key] is T ? json[key] as T : fallback;
    E pickEnum<E extends Enum>(String key, List<E> values, E fallback) =>
        values.where((v) => v.name == json[key]).firstOrNull ?? fallback;
    return AppSettings(
      language: pickEnum('language', AppLanguage.values, d.language),
      nightMode: pick('nightMode', d.nightMode),
      pageTheme: pickEnum('pageTheme', PageTheme.values, d.pageTheme),
      twoPagesInLandscape: pick('twoPagesInLandscape', d.twoPagesInLandscape),
      autoPageTurn: pick('autoPageTurn', d.autoPageTurn),
      autoPageSeconds: pick(
        'autoPageSeconds',
        d.autoPageSeconds,
      ).clamp(minAutoPageSeconds, maxAutoPageSeconds),
      verticalScroll: pick('verticalScroll', d.verticalScroll),
      tapOpensAyahMenu: pick('tapOpensAyahMenu', d.tapOpensAyahMenu),
      keepScreenOn: pick('keepScreenOn', d.keepScreenOn),
      westernDigits: pick('westernDigits', d.westernDigits),
      followSystemFontSize: pick(
        'followSystemFontSize',
        d.followSystemFontSize,
      ),
      hideRecitationButton: pick(
        'hideRecitationButton',
        d.hideRecitationButton,
      ),
      hideWhileListening: pick('hideWhileListening', d.hideWhileListening),
      showHizbMarks: pick('showHizbMarks', d.showHizbMarks),
      tajweedColors: pick('tajweedColors', d.tajweedColors),
      mushafTextScale: switch (json['mushafTextScale']) {
        final num v when v.isFinite => v.toDouble().clamp(
          minMushafTextScale,
          maxMushafTextScale,
        ),
        _ => d.mushafTextScale,
      },
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(settingsKey);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Not JSON, or not an object: start over with the defaults.
      return const AppSettings();
    }
  }

  void update(AppSettings Function(AppSettings) change) {
    state = change(state);
    ref
        .read(sharedPreferencesProvider)
        .setString(settingsKey, jsonEncode(state.toJson()));
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
