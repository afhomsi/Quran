import 'ayah_audio.dart';

/// Keeps nothing: on the web recordings always play over the internet.
class AudioStore {
  /// [root] is a folder on other platforms; unused here.
  AudioStore({Object? root});

  bool get supported => false;

  Future<Set<String>> files(Reciter reciter) async => {};

  Future<String?> find(Reciter reciter, String name) async => null;

  Future<String?> readText(Reciter reciter, String name) async => null;

  Future<void> save(
    Reciter reciter,
    String name,
    Stream<List<int>> bytes,
  ) async => throw UnsupportedError('No files on the web');

  Future<void> delete(Reciter reciter, Iterable<String> names) async {}

  Future<void> deleteAll(Reciter reciter) async {}

  Future<int> size(Reciter reciter) async => 0;
}
