import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Keeps study texts as files in the app's support folder, so an ayah read
/// once opens again without internet.
class StudyCache {
  Future<Directory>? _root;

  Future<Directory> _dir() => _root ??= getApplicationSupportDirectory().then(
    (d) => Directory('${d.path}/study'),
  );

  Future<File> _file(String key) async =>
      File('${(await _dir()).path}/$key.txt');

  Future<String?> read(String key) async {
    try {
      final file = await _file(key);
      return await file.exists() ? await file.readAsString() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, String text) async {
    try {
      final file = await _file(key);
      await file.parent.create(recursive: true);
      await file.writeAsString(text);
    } catch (_) {
      // Not kept; it is fetched again next time.
    }
  }
}
