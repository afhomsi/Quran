import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../settings/app_settings.dart';
import 'mushaf_models.dart';
import 'mushaf_repository.dart' show mushafPageCount;

const _lastPageKey = 'last_page';
const _bookmarksKey = 'bookmarks';
const _app = 'hifz';

/// Other data saved as one JSON string each: markers, highlights, notes,
/// khatma plans, the audio player's choices and the recitation history.
const _jsonKeys = [
  'markers',
  'highlights',
  'notes',
  'khatma_plans',
  'audio_settings',
  'recitation_history',
];

/// The user's data as text to keep somewhere safe: the settings, the
/// bookmarks, the last page read and everything in [_jsonKeys].
String exportBackup(SharedPreferences prefs) {
  final settings = prefs.getString(settingsKey);
  return jsonEncode({
    'app': _app,
    'version': 1,
    'last_page': ?prefs.getInt(_lastPageKey),
    'bookmarks': prefs.getStringList(_bookmarksKey) ?? const <String>[],
    if (settings != null) 'settings': jsonDecode(settings),
    for (final key in _jsonKeys)
      if (prefs.getString(key) case final value?) key: jsonDecode(value),
  });
}

/// The largest backup restored, in characters. A real one, with a full
/// recitation history and many notes, is far smaller; anything bigger is
/// not this app's and could only slow the phone down.
const maxBackupLength = 5 * 1024 * 1024;

/// Restores what [exportBackup] wrote. Returns false, and changes nothing,
/// when [text] is not a backup of this app.
///
/// The text comes from outside the app, so nothing in it is trusted: each
/// value is checked, and values that are wrong are left out. Data saved as
/// JSON is checked again when it is read (see `readStored`).
Future<bool> importBackup(SharedPreferences prefs, String text) async {
  if (text.length > maxBackupLength) return false;
  final Map<String, dynamic> backup;
  try {
    final decoded = jsonDecode(text.trim());
    if (decoded is! Map<String, dynamic> || decoded['app'] != _app) {
      return false;
    }
    backup = decoded;
  } on FormatException {
    return false;
  }
  final lastPage = backup['last_page'];
  final bookmarks = backup['bookmarks'];
  final settings = backup['settings'];
  if (lastPage is int && lastPage >= 1 && lastPage <= mushafPageCount) {
    await prefs.setInt(_lastPageKey, lastPage);
  }
  if (bookmarks is List) {
    await prefs.setStringList(_bookmarksKey, [
      for (final b in bookmarks)
        if (AyahRef.tryParse(b) case final ayah?) '$ayah',
    ]);
  }
  if (settings is Map<String, dynamic>) {
    await prefs.setString(
      settingsKey,
      jsonEncode(AppSettings.fromJson(settings).toJson()),
    );
  }
  for (final key in _jsonKeys) {
    final value = backup[key];
    if (value is Map || value is List) {
      await prefs.setString(key, jsonEncode(value));
    }
  }
  return true;
}
