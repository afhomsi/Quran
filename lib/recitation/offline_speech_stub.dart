import 'speech_listener.dart';

/// Browsers recognize speech themselves; the offline model is for phones.
bool get offlineSpeechSupported => false;

int get offlineModelBytes => 0;

Future<bool> isOfflineModelInstalled() async => false;

Future<void> downloadOfflineModel(
  void Function(int received, int total) onProgress,
) => throw UnsupportedError('Offline speech is not available here');

Future<void> deleteOfflineModel() async {}

DisposableSpeechListener createOfflineSpeechListener() =>
    throw UnsupportedError('Offline speech is not available here');
