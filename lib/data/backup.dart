import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../settings/app_settings.dart';

const _lastPageKey = 'last_page';
const _bookmarksKey = 'bookmarks';
const _app = 'hifz';

/// The user's data as text to keep somewhere safe: the settings, the
/// bookmarks and the last page read.
String exportBackup(SharedPreferences prefs) {
  final settings = prefs.getString(settingsKey);
  return jsonEncode({
    'app': _app,
    'version': 1,
    'last_page': ?prefs.getInt(_lastPageKey),
    'bookmarks': prefs.getStringList(_bookmarksKey) ?? const <String>[],
    if (settings != null) 'settings': jsonDecode(settings),
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
  return true;
}
