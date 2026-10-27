import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'harakat.dart';
import 'recitation_matcher.dart';
import 'speech_listener.dart';

/// What kind of mistake a reciter made.
enum MistakeKind {
  /// A word or ayah said wrong, left out, or added: shown in red.
  word,

  /// The right word with a wrong haraka: shown in orange.
  harakat,
}

/// A mistake found while reciting, to alert the reciter about.
class Mistake {
  const Mistake(this.wordIndex, this.message, {this.kind = MistakeKind.word});

  /// Index of the surah word the mistake is at.
  final int wordIndex;
  final String message;
  final MistakeKind kind;
}

/// Listens to the reciter and keeps the comparison with the text up to
/// date.
///
/// Recognizers stop after a pause, so listening restarts by itself until the
/// reciter presses stop. Each finished listening session is compared once,
/// from where the previous one ended, so long surahs stay fast. Within a
/// long session, the words the recognizer has stopped changing are settled
/// the same way, so each new result compares only the last few words and
/// the page keeps up with the reciter.
class RecitationSession extends ChangeNotifier {
  RecitationSession({
    required this.listener,
    required this.expected,
    required this.surahName,
    this.mode = RecitationMode.strict,
  }) : _multiSurah =
           expected.map((w) => w.surah).where((s) => s > 0).toSet().length > 1 {
    _clear();
  }

  final SpeechListener listener;
  final List<ExpectedWord> expected;
  final String Function(int surah) surahName;

  /// How strictly the recitation is checked.
  final RecitationMode mode;
  final bool _multiSurah;

  /// Words compared so far, from finished listening sessions.
  late List<WordResult> _base;
  final _extrasAtEnd = <String>[];

  /// Index of the first word not reached by a finished session.
  int _pos = 0;

  final _committed = <String>[];
  String _current = '';

  /// How many words at the start of the current session are settled.
  int _frozen = 0;

  /// The words of the session's previous result.
  List<String> _lastHeard = const [];
  int _sessionId = 0;
  bool _initialized = false;
  bool _wantListening = false;
  bool _restartPending = false;

  /// Runs when the recognizer has sent nothing new for [quietDelay].
  Timer? _quiet;

  /// How long the last words may stay the same before a mistake in them
  /// is reported. Until then the recognizer may still correct them; after
  /// it, the reciter has likely stopped at the mistake.
  static const quietDelay = Duration(milliseconds: 1200);
  final _alerted = <String>{};
  final _mistakes = <Mistake>[];
  late RecitationResult _result;

  /// Whether the recognizer wrote harakat, so they could be checked.
  bool heardHarakat = false;

  /// Message to show when the microphone or recognizer cannot be used.
  String? error;

  /// Called once for each new mistake.
  void Function(Mistake mistake)? onMistake;

  RecitationResult get result => _result;

  /// The words settled so far, leaving out the recognizer's last words,
  /// which it may still change: a recognizer guessing ahead of the
  /// reciter, as Whisper may, then takes those words back.
  RecitationResult get settledResult =>
      RecitationResult(words: _base, endAt: _pos);
  bool get isListening => _wantListening;
  List<Mistake> get mistakes => List.unmodifiable(_mistakes);

  /// The words shown by [hint], as indexes in [result]'s words.
  Set<int> get hints => Set.unmodifiable(_hints);
  final Set<int> _hints = {};

  /// Shows a word the reciter is stuck on: the word just said wrong or
  /// left out when it is still hidden, else the next word to recite, even
  /// when it starts the next ayah. Each press shows one more word. Returns
  /// false when nothing is left to show.
  bool hint() {
    final words = _result.words;
    final end = _result.end;
    var i = end - 1;
    if (i < 0 ||
        _hints.contains(i) ||
        words[i].word.kind != WordKind.ayah ||
        (words[i].status != WordStatus.wrong &&
            words[i].status != WordStatus.skipped)) {
      i = end;
      while (i < words.length &&
          (words[i].word.kind != WordKind.ayah ||
              words[i].status != WordStatus.pending ||
              _hints.contains(i))) {
        i++;
      }
    }
    if (i >= words.length) return false;
    _hints.add(i);
    notifyListeners();
    return true;
  }

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
    _hints.clear();
    error = null;
    _update();
  }

  Future<void> _listen() async {
    final id = ++_sessionId;
    try {
      await listener.listen(
        onResult: (text, isFinal) {
          if (id != _sessionId) return;
          if (!heardHarakat && hasHarakat(text)) heardHarakat = true;
          if (!isFinal) _freezeStable(text);
          final words = _wordsOf(text);
          _current = words.skip(_frozen).join(' ');
          if (isFinal) _commit();
          _update();
          _quiet?.cancel();
          if (!isFinal) {
            _quiet = Timer(quietDelay, () {
              if (id == _sessionId) _update(settled: true);
            });
          }
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
    _frozen = 0;
    _lastHeard = const [];
    _base = [
      for (final w in expected) WordResult(word: w, status: WordStatus.pending),
    ];
    _extrasAtEnd.clear();
    _pos = 0;
    _result = RecitationResult(words: _base);
  }

  static List<String> _wordsOf(String text) => [
    for (final w in text.trim().split(RegExp(r'\s+')))
      if (w.isNotEmpty) w,
  ];

  /// Words this far from the end of a result may still change.
  static const _liveWords = 8;

  /// Settles the start of the session's text once enough words of it came
  /// back unchanged in two results in a row, keeping the last
  /// [_liveWords] open.
  void _freezeStable(String text) {
    final words = _wordsOf(text);
    var same = 0;
    while (same < words.length &&
        same < _lastHeard.length &&
        words[same] == _lastHeard[same]) {
      same++;
    }
    _lastHeard = words;
    final upTo = min(same, words.length - _liveWords);
    if (upTo - _frozen < _liveWords) return;
    _settle(words.sublist(_frozen, upTo).join(' '));
    _frozen = upTo;
  }

  /// Keeps the current session's text and ignores anything it still sends.
  void _commit() {
    _sessionId++;
    _quiet?.cancel();
    final text = _current;
    _current = '';
    _frozen = 0;
    _lastHeard = const [];
    _settle(text);
  }

  /// Compares [text] from where the last settled words ended and moves on.
  void _settle(String text) {
    text = text.trim();
    if (text.isEmpty) return;
    _committed.add(text);
    final (from, sub) = _alignFromPos(text, settled: true);
    _base = _overlay(_base, from, sub);
    if (from + sub.words.length == expected.length) {
      _extrasAtEnd.addAll(sub.extrasAtEnd);
    }
    _pos = from + sub.end;
  }

  /// Where a reciter going back may start again from: the start of the
  /// ayah before the one being recited.
  int _backLimit() {
    var k = _pos;
    for (var ayat = 0; ayat < 2 && k > 0; ayat++) {
      final w = expected[k - 1];
      while (k > 0 &&
          expected[k - 1].surah == w.surah &&
          expected[k - 1].ayah == w.ayah) {
        k--;
      }
    }
    return k;
  }

  /// Compares [text] with the words from [_pos] on, in a window long enough
  /// for everything that was said and starting where the reciter may go
  /// back to.
  (int, RecitationResult) _alignFromPos(String text, {required bool settled}) {
    final heard = text.split(RegExp(r'\s+'));
    final from = _backLimit();
    final end = (_pos + 2 * heard.length + 30).clamp(0, expected.length);
    final window = expected.sublist(from, end);
    var sub = alignRecitation(
      window,
      heard,
      settled: settled,
      start: _pos - from,
      mode: mode,
    );
    if (end < expected.length && sub.extrasAtEnd.isNotEmpty) {
      // Left over past a window that is not the end of the text. The window
      // is twice as long as what was heard, so this is only noise; drop it.
      sub = RecitationResult(words: sub.words, endAt: sub.endAt);
    }
    return (from, sub);
  }

  List<WordResult> _overlay(
    List<WordResult> base,
    int from,
    RecitationResult sub,
  ) => [
    ...base.take(from),
    for (var k = 0; k < sub.words.length; k++)
      _merge(base[from + k], sub.words[k]),
    ...base.skip(from + sub.words.length),
  ];

  /// A word not reached by [now] keeps what it was. One reached for the
  /// first time adds to the extra words said before it; one recited again
  /// takes only the new try, so an ayah recited again correctly is right.
  static WordResult _merge(WordResult before, WordResult now) {
    if (now.status == WordStatus.pending) {
      if (now.extrasBefore.isEmpty) return before;
      return WordResult(
        word: before.word,
        status: before.status,
        heard: before.heard,
        extrasBefore: [...before.extrasBefore, ...now.extrasBefore],
        wrongHarakat: before.wrongHarakat,
      );
    }
    return WordResult(
      word: now.word,
      status: now.status,
      heard: now.heard,
      extrasBefore: before.status == WordStatus.pending
          ? [...before.extrasBefore, ...now.extrasBefore]
          : now.extrasBefore,
      wrongHarakat: now.wrongHarakat,
    );
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
      error =
          'التعرف على الصوت يحتاج إلى اتصال بالإنترنت، '
          'أو حمّل نموذج التلاوة ليعمل بدونه.';
    } else {
      error = 'حدث خطأ في الاستماع: $message';
    }
    _wantListening = false;
    notifyListeners();
  }

  /// Compares the words heard so far. Mistakes in the last words, which
  /// the recognizer may still change, are held back unless [settled].
  void _update({bool settled = false}) {
    var words = _base;
    var extrasAtEnd = _extrasAtEnd;
    if (_current.trim().isNotEmpty) {
      final (from, sub) = _alignFromPos(_current, settled: settled);
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
    final leftOut = _ayatLeftOut(words);
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
        if (leftOut.contains((w.surah, w.ayah))) {
          _alert(
            'skippedAyah:${w.surah}:${w.ayah}',
            Mistake(i, 'نسيت ${_where(w)}'),
          );
        } else {
          _alert(
            'skipped:$i',
            Mistake(i, 'نسيت كلمة «${w.text}» في ${_where(w)}'),
          );
        }
      } else if (w.isHarakatMistake) {
        _alert(
          'harakat:$i:${w.wrongHarakat}',
          Mistake(
            i,
            'خطأ في الحركة في ${_where(w)}: سمعت «${w.wrongHarakat}» '
            'والصواب «${w.text}»',
            kind: MistakeKind.harakat,
          ),
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

  /// The ayat whose words were all left out.
  static Set<(int, int)> _ayatLeftOut(List<WordResult> words) {
    final all = <(int, int)>{};
    final not = <(int, int)>{};
    for (final w in words) {
      if (w.word.kind != WordKind.ayah) continue;
      (w.status == WordStatus.skipped ? all : not).add((w.surah, w.ayah));
    }
    return all.difference(not);
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
    _quiet?.cancel();
    _wantListening = false;
    _sessionId++;
    listener.stop();
    super.dispose();
  }
}
