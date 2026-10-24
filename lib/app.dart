import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'features/home/home_screen.dart';
import 'l10n/strings.dart';
import 'settings/app_settings.dart';

/// Keeps the screen on or lets it sleep. Replaced in tests, where the
/// platform plugin is missing.
final screenWakeProvider = Provider<Future<void> Function(bool on)>(
  (ref) => (on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (_) {
      // Not supported here; the screen just sleeps as usual.
    }
  },
);

class HifzApp extends ConsumerStatefulWidget {
  const HifzApp({super.key});

  @override
  ConsumerState<HifzApp> createState() => _HifzAppState();
}

class _HifzAppState extends ConsumerState<HifzApp> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      settingsProvider.select((s) => s.keepScreenOn),
      (_, on) => ref.read(screenWakeProvider)(on),
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final strings = S(settings.language, westernDigits: settings.westernDigits);
    return MaterialApp(
      title: 'حفظ',
      debugShowCheckedModeBanner: false,
      locale: settings.language.locale,
      supportedLocales: [for (final l in AppLanguage.values) l.locale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: settings.nightMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        Widget app = StringsScope(strings: strings, child: child!);
        if (!settings.followSystemFontSize) {
          app = MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.noScaling),
            child: app,
          );
        }
        return app;
      },
      home: const HomeScreen(),
    );
  }

  ThemeData _theme(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1B5E20),
      brightness: brightness,
    ),
    useMaterial3: true,
  );
}
