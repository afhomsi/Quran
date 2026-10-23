import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Turns the microphone into text, one listening session at a time.
///
/// Kept behind an interface so the recitation screen can be tested without
/// a microphone.
abstract class SpeechListener {
  /// Asks for the microphone and returns whether recognition is available.
  Future<bool> initialize({
    required void Function(String message) onError,
    required void Function() onDone,
  });

  /// Starts a session. [onResult] receives the whole text heard in this
  /// session so far; [isFinal] is true once the session's text is settled.
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
  });

  Future<void> stop();
}

/// Recognition through the platform: Google's recognizer on Android and in
/// Chrome, Apple's on iOS. Arabic recognition needs internet on most devices.
class PlatformSpeechListener implements SpeechListener {
  final _speech = SpeechToText();
  String? _localeId;

  @override
  Future<bool> initialize({
    required void Function(String message) onError,
    required void Function() onDone,
  }) async {
    final ok = await _speech.initialize(
      onError: (SpeechRecognitionError e) => onError(e.errorMsg),
      onStatus: (status) {
        if (status == SpeechToText.doneStatus) onDone();
        // In Chrome every result is partial, so a session the browser ends
        // by itself never turns final. Stopping makes the plugin send the
        // last result as final shortly after.
        if (status == SpeechToText.notListeningStatus) _speech.stop();
      },
    );
    if (!ok) return false;
    _localeId = await _arabicLocale();
    return true;
  }

  Future<String> _arabicLocale() async {
    try {
      final locales = await _speech.locales();
      final ids = locales.map((l) => l.localeId).toList();
      for (final preferred in ['ar_SA', 'ar-SA', 'ar_EG', 'ar-EG']) {
        if (ids.contains(preferred)) return preferred;
      }
      final anyArabic = ids.where((id) => id.startsWith('ar'));
      if (anyArabic.isNotEmpty) return anyArabic.first;
    } catch (_) {
      // Some platforms cannot list locales; ask for Arabic anyway.
    }
    return 'ar-SA';
  }

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    await _speech.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: _localeId,
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 6),
        listenFor: const Duration(minutes: 5),
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();
}

final speechListenerProvider = Provider<SpeechListener>(
  (ref) => PlatformSpeechListener(),
);
