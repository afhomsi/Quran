import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/reading_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The mushaf font's licence asks to travel with it.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'DigitalKhatt New Madina',
    ], await rootBundle.loadString('assets/fonts/LICENSE-madina.txt'));
  });
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const HifzApp(),
    ),
  );
}
