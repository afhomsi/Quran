import 'package:flutter/foundation.dart';

import 'recitation_matcher.dart';
import 'speech_listener.dart';

/// A mistake found while reciting, to alert the reciter about.
class Mistake {
  const Mistake(this.wordIndex, this.message);

  /// Index of the surah word the mistake is at.
  final int wordIndex;
  final String message;
}

/// Listens to the reciter and keeps the comparison with the surah up to
/// date.
///
/// Recognizers stop after a pause, so listening restarts by itself until the
/// reciter presses stop. The text of every finished session is kept and the
/// comparison always runs over everything heard since the start.
class RecitationSession extends ChangeNotifier {
  RecitationSession({
    required this.listener,
    required this.surahName,
    required List<String> ayahs,
  }) : expected = wordsOfAyahs(ayahs) {
    _result = alignRecitation(expected, const []);
  }

  final SpeechListener listener;
  final String surahName;
  final List<ExpectedWord> expected;

  final _committed = <String>[];
  String _current = '';
  int _sessionId = 0;
  bool _initialized = false;
  bool _wantListening = false;
  bool _restartPending = false;
  final _alerted = <String>{};
  final _mistakes = <Mistake>[];
  late RecitationResult _result;

  /// Message to show when the microphone or recognizer cannot be used.
  String? error;

  /// Called once for each new mistake.
  void Function(Mistake mistake)? onMistake;

  RecitationResult get result => _result;
  bool get isListening => _wantListening;
  List<Mistake> get mistakes => List.unmodifiable(_mistakes);

  /// Everything heard so far, for showing to the reciter.
  String get heardText => [..._committed, _current].join(' ').trim();

  Future<void> start() async {
    error = null;
    if (!_initialized) {
      final ok = await listener.initialize(
        onError: _onError,
        onDone: _onSessionDone,
      );
      if (!ok) {
        error = 'لا يمكن استخدام الميكروفون. اسمح للتطبيق باستخدامه ثم حاول مرة أخرى.';
        notifyListeners();
        return;
      }
      _initialized = true;
    }
    _wantListening = true;
    notifyListeners();
    await _listen();
  }

  Future<void> stop() async {
    _wantListening = false;
    _commit();
    notifyListeners();
    await listener.stop();
  }

  /// Clears everything heard, to recite again from the start.
  Future<void> reset() async {
    if (_wantListening) await stop();
    _committed.clear();
    _current = '';
    _alerted.clear();
    _mistakes.clear();
    error = null;
    _update();
  }

  Future<void> _listen() async {
    final id = ++_sessionId;
    try {
      await listener.listen(
        onResult: (text, isFinal) {
          if (id != _sessionId) return;
          _current = text;
          if (isFinal) {
            _commit();
            _restart();
          }
          _update();
        },
      );
    } catch (e) {
      _onError('$e');
    }
  }

  /// Keeps the current session's text and ignores anything it still sends.
  void _commit() {
    _sessionId++;
    if (_current.trim().isNotEmpty) _committed.add(_current.trim());
    _current = '';
  }

  void _onSessionDone() {
    _commit();
    _update();
    _restart();
  }

  void _restart() {
    if (!_wantListening || _result.isComplete) {
      _wantListening = false;
      notifyListeners();
      return;
    }
    if (_restartPending) return;
    _restartPending = true;
    // A short gap lets the recognizer release the microphone first.
    Future.delayed(const Duration(milliseconds: 300), () {
      _restartPending = false;
      if (_wantListening) _listen();
    });
  }

  void _onError(String message) {
    // Silence and "nothing recognized" are normal pauses while reciting.
    if (message.contains('no_match') ||
        message.contains('no-speech') ||
        message.contains('speech_timeout') ||
        message.contains('aborted')) {
      return;
    }
    if (message.contains('not-allowed') || message.contains('permission')) {
      error =
          'لم يُسمح باستخدام الميكروفون. اسمح به من إعدادات المتصفح أو الهاتف.';
    } else if (message.contains('audio-capture') ||
        message.contains('error_audio')) {
      error =
          'لم يُعثر على ميكروفون. صِل ميكروفونًا أو سماعة بميكروفون ثم حاول.';
    } else if (message.contains('network')) {
      error = 'التعرف على الصوت يحتاج إلى اتصال بالإنترنت.';
    } else {
      error = 'حدث خطأ في الاستماع: $message';
    }
    _wantListening = false;
    notifyListeners();
  }

  void _update() {
    final heard = heardText.split(RegExp(r'\s+'));
    _result = alignRecitation(expected, heard, settled: _current.isEmpty);
    if (_result.isComplete && _wantListening) {
      _wantListening = false;
      listener.stop();
    }
    _reportMistakes();
    notifyListeners();
  }

  void _reportMistakes() {
    final words = _result.words;
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.extrasBefore.isNotEmpty) {
        _alert(
          'extra:$i:${w.extrasBefore.join(' ')}',
          Mistake(
            i,
            'كلمة زائدة «${w.extrasBefore.join(' ')}» قبل «${w.text}» '
            '(الآية ${w.ayah})',
          ),
        );
      }
      if (w.status == WordStatus.wrong) {
        _alert(
          'wrong:$i:${w.heard}',
          Mistake(
            i,
            'خطأ في الآية ${w.ayah}: سمعت «${w.heard}» والصواب «${w.text}»',
          ),
        );
      } else if (w.status == WordStatus.skipped) {
        _alert(
          'skipped:$i',
          Mistake(i, 'نسيت كلمة «${w.text}» في الآية ${w.ayah}'),
        );
      }
    }
    if (_result.extrasAtEnd.isNotEmpty) {
      _alert(
        'end:${_result.extrasAtEnd.join(' ')}',
        Mistake(
          words.length - 1,
          'كلمات زائدة بعد نهاية السورة: «${_result.extrasAtEnd.join(' ')}»',
        ),
      );
    }
  }

  void _alert(String key, Mistake mistake) {
    if (!_alerted.add(key)) return;
    _mistakes.add(mistake);
    onMistake?.call(mistake);
  }

  @override
  void dispose() {
    _wantListening = false;
    _sessionId++;
    listener.stop();
    super.dispose();
  }
}
