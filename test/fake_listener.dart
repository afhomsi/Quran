import 'package:hifz/recitation/speech_listener.dart';

/// Plays back text instead of listening to a microphone.
class FakeListener implements SpeechListener {
  void Function(String text, bool isFinal)? _onResult;
  late void Function() _onDone;
  bool listening = false;

  void say(String text, {bool isFinal = false}) =>
      _onResult?.call(text, isFinal);

  @override
  Future<bool> initialize({
    required void Function(String message) onError,
    required void Function() onDone,
  }) async {
    _onDone = onDone;
    return true;
  }

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    _onResult = onResult;
    listening = true;
  }

  @override
  Future<void> stop() async {
    if (!listening) return;
    listening = false;
    _onDone();
  }
}
