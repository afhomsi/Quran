import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'ayah_audio.dart';

/// Keeps downloaded recordings as files in the app's support folder, one
/// folder for each reciter, so they play without internet.
class AudioStore {
  /// Files go in [root]; by default the app's support folder.
  AudioStore({Directory? root})
    : _root = root == null ? null : Future.value(root);

  Future<Directory>? _root;

  /// Whether recordings can be kept on this device.
  bool get supported => true;

  Future<Directory> _dir(Reciter reciter) async {
    final root = await (_root ??= getApplicationSupportDirectory().then(
      (d) => Directory('${d.path}/audio'),
    ));
    return Directory('${root.path}/${reciter.folder.replaceAll('/', '_')}');
  }

  /// Names of the files kept for [reciter].
  Future<Set<String>> files(Reciter reciter) async {
    try {
      final dir = await _dir(reciter);
      if (!await dir.exists()) return {};
      return {
        await for (final f in dir.list())
          if (f is File && !f.path.endsWith('.part')) f.uri.pathSegments.last,
      };
    } catch (_) {
      return {};
    }
  }

  /// The path of the file [name] of [reciter], or null if it is not kept.
  Future<String?> find(Reciter reciter, String name) async {
    try {
      final file = File('${(await _dir(reciter)).path}/$name');
      return await file.exists() ? file.path : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> readText(Reciter reciter, String name) async {
    final path = await find(reciter, name);
    if (path == null) return null;
    try {
      return await File(path).readAsString();
    } catch (_) {
      return null;
    }
  }

  /// Keeps [bytes] as the file [name] of [reciter]. The file only appears
  /// once all of it is written, so a broken download is never played.
  Future<void> save(
    Reciter reciter,
    String name,
    Stream<List<int>> bytes,
  ) async {
    final dir = await _dir(reciter);
    await dir.create(recursive: true);
    final part = File('${dir.path}/$name.part');
    final sink = part.openWrite();
    try {
      await sink.addStream(bytes);
      await sink.close();
    } catch (_) {
      await sink.close().catchError((_) {});
      if (await part.exists()) await part.delete();
      rethrow;
    }
    await part.rename('${dir.path}/$name');
  }

  Future<void> delete(Reciter reciter, Iterable<String> names) async {
    final dir = await _dir(reciter);
    for (final name in names) {
      final file = File('${dir.path}/$name');
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> deleteAll(Reciter reciter) async {
    final dir = await _dir(reciter);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Bytes taken by the files kept for [reciter].
  Future<int> size(Reciter reciter) async {
    try {
      final dir = await _dir(reciter);
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final f in dir.list()) {
        if (f is File) total += await f.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
