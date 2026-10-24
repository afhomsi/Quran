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

/// Listens to the reciter and keeps the comparison with the text up to
/// date.
///
/// Recognizers stop after a pause, so listening restarts by itself until the
/// reciter presses stop. Each finished listening session is compared once,
/// from where the previous one ended, so long surahs stay fast.
class RecitationSession extends ChangeNotifier {
  RecitationSession({
    required this.listener,
    required this.expected,
    required this.surahName,
  }) : _multiSurah =
           expected.map((w) => w.surah).where((s) => s > 0).toSet().length > 1 {
    _clear();
  }

  final SpeechListener listener;
  final List<ExpectedWord> expected;
  final String Function(int surah) surahName;
  final bool _multiSurah;

  /// Words compared so far, from finished listening sessions.
  late List<WordResult> _base;
  final _extrasAtEnd = <String>[];

  /// Index of the first word not reached by a finished session.
  int _pos = 0;

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

  /// The last words heard, for showing to the reciter.
  String get heardText {
    final words = [..._committed, _current].join(' ').trim().split(' ');
    return words.skip(words.length > 20 ? words.length - 20 : 0).join(' ');
  }

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
    _clear();
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
          if (isFinal) _commit();
          _update();
          if (isFinal) _restart();
        },
      );
    } catch (e) {
      _onError('$e');
    }
  }

  void _clear() {
    _committed.clear();
    _current = '';
    _base = [
      for (final w in expected) WordResult(word: w, status: WordStatus.pending),
    ];
    _extrasAtEnd.clear();
    _pos = 0;
    _result = RecitationResult(words: _base);
  }

  /// Keeps the current session's text and ignores anything it still sends.
  void _commit() {
    _sessionId++;
    final text = _current.trim();
    _current = '';
    if (text.isEmpty) return;
    _committed.add(text);
    final (from, sub) = _alignFromPos(text, settled: true);
    _base = _overlay(_base, from, sub);
    if (from + sub.words.length == expected.length) {
      _extrasAtEnd.addAll(sub.extrasAtEnd);
    }
    _pos = from + sub.progress;
  }

  /// Compares [text] with the words from [_pos] on, in a window long enough
  /// for everything that was said.
  (int, RecitationResult) _alignFromPos(String text, {required bool settled}) {
    final heard = text.split(RegExp(r'\s+'));
    final end = (_pos + 2 * heard.length + 30).clamp(0, expected.length);
    final window = expected.sublist(_pos, end);
    var sub = alignRecitation(window, heard, settled: settled);
    if (end < expected.length && sub.extrasAtEnd.isNotEmpty) {
      // Left over past a window that is not the end of the text. The window
      // is twice as long as what was heard, so this is only noise; drop it.
      sub = RecitationResult(words: sub.words);
    }
    return (_pos, sub);
  }

  List<WordResult> _overlay(
    List<WordResult> base,
    int from,
    RecitationResult sub,
  ) => [
    ...base.take(from),
    for (var k = 0; k < sub.words.length; k++)
      WordResult(
        word: sub.words[k].word,
        status: sub.words[k].status,
        heard: sub.words[k].heard,
        extrasBefore: [
          ...base[from + k].extrasBefore,
          ...sub.words[k].extrasBefore,
        ],
      ),
    ...base.skip(from + sub.words.length),
  ];

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
      error =
          'التعرف على الصوت يحتاج إلى اتصال بالإنترنت، '
          'أو حمّل نموذج التلاوة ليعمل بدونه.';
    } else {
      error = 'حدث خطأ في الاستماع: $message';
    }
    _wantListening = false;
    notifyListeners();
  }

  void _update() {
    var words = _base;
    var extrasAtEnd = _extrasAtEnd;
    if (_current.trim().isNotEmpty) {
      final (from, sub) = _alignFromPos(_current, settled: false);
      words = _overlay(_base, from, sub);
      if (from + sub.words.length == expected.length) {
        extrasAtEnd = [..._extrasAtEnd, ...sub.extrasAtEnd];
      }
    }
    _result = RecitationResult(words: words, extrasAtEnd: extrasAtEnd);
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
            '(${_where(w)})',
          ),
        );
      }
      if (w.status == WordStatus.wrong) {
        _alert(
          'wrong:$i:${w.heard}',
          Mistake(
            i,
            'خطأ في ${_where(w)}: سمعت «${w.heard}» والصواب «${w.text}»',
          ),
        );
      } else if (w.status == WordStatus.skipped) {
        _alert(
          'skipped:$i',
          Mistake(i, 'نسيت كلمة «${w.text}» في ${_where(w)}'),
        );
      }
    }
    if (_result.extrasAtEnd.isNotEmpty) {
      _alert(
        'end:${_result.extrasAtEnd.join(' ')}',
        Mistake(
          words.length - 1,
          'كلمات زائدة بعد النهاية: «${_result.extrasAtEnd.join(' ')}»',
        ),
      );
    }
  }

  /// Where a word is, e.g. "الآية 5" or "الآية 5 من سورة البقرة".
  String _where(WordResult w) {
    final place = switch (w.word.kind) {
      WordKind.ayah => 'الآية ${w.ayah}',
      WordKind.basmala => 'البسملة',
      WordKind.istiadha => 'الاستعاذة',
    };
    if (!_multiSurah || w.surah == 0) return place;
    return '$place من سورة ${surahName(w.surah)}';
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
