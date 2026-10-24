/// Keeps nothing: on the web the browser's own cache keeps the texts.
class StudyCache {
  Future<String?> read(String key) async => null;

  Future<void> write(String key, String text) async {}
}
