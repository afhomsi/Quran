import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../settings/app_settings.dart';

const _lastPageKey = 'last_page';
const _bookmarksKey = 'bookmarks';
const _app = 'hifz';

/// Other data saved as one JSON string each: markers, highlights, notes,
/// khatma plans and the audio player's choices.
const _jsonKeys = [
  'markers',
  'highlights',
  'notes',
  'khatma_plans',
  'audio_settings',
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

/// Restores what [exportBackup] wrote. Returns false, and changes nothing,
/// when [text] is not a backup of this app.
Future<bool> importBackup(SharedPreferences prefs, String text) async {
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
  if (lastPage is int) await prefs.setInt(_lastPageKey, lastPage);
  if (bookmarks is List) {
    await prefs.setStringList(_bookmarksKey, [
      for (final b in bookmarks)
        if (b is String && RegExp(r'^\d+:\d+$').hasMatch(b)) b,
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
