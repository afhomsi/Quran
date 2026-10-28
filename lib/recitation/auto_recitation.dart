import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/ayah_audio.dart';
import '../data/quran_repository.dart';
import 'page_recitation.dart';
import 'quran_finder.dart';
import 'recitation_matcher.dart';
import 'speech_listener.dart';

/// Reciting without choosing a surah or page: the app listens, finds
/// where in the Quran the reciter is, even part way through a surah or an
/// ayah, then opens that page and follows the recitation there.
class AutoRecitation {
  const AutoRecitation({
    required this.mode,
    this.heard = '',
    this.listening = false,
    this.error,
  });

  final RecitationMode mode;

  /// The last words heard, shown while searching.
  final String heard;
  final bool listening;

  /// Message to show when the microphone or recognizer cannot be used.
  final String? error;
}

final quranFinderProvider = FutureProvider<QuranFinder>(
  (ref) async => QuranFinder(await ref.watch(surahsProvider.future)),
);

/// Listens until the place recited is found, then hands the same
/// listening on to the page recitation, so no word said meanwhile is lost.
class AutoRecitationController extends Notifier<AutoRecitation?> {
  HandoverListener? _listener;
  int _sessionId = 0;
  bool _restartPending = false;

  /// Words of the listening sessions that ended.
  final _committed = <String>[];
  List<String> _current = const [];

  @override
  AutoRecitation? build() {
    ref.onDispose(() {
      _sessionId++;
      _listener?.stop();
      _listener = null;
    });
    ref.listen(audioProvider.select((a) => a.playing), (_, playing) {
      if (playing && state?.listening == true) stop();
    });
    // Once the offline model is downloaded, the search starts over with it.
    ref.listen(speechListenerProvider, (_, _) {
      final current = state;
      if (current != null) start(mode: current.mode);
    });
    return null;
  }

  /// Closes any recitation and listens for where the reciter is.
  Future<void> start({RecitationMode mode = RecitationMode.strict}) async {
    ref.read(pageRecitationProvider.notifier).close();
    close();
    _listener = HandoverListener(ref.read(speechListenerProvider));
    _committed.clear();
    _current = const [];
    state = AutoRecitation(mode: mode);
    // The search needs the whole Quran indexed first.
    await ref.read(quranFinderProvider.future);
    if (state == null) return;
    final ok = await _listener!.initialize(
      onError: _onError,
      onDone: _onSessionDone,
    );
    if (state == null) return;
    if (!ok) {
      state = AutoRecitation(
        mode: mode,
        error: 'لا يمكن استخدام الميكروفون. اسمح للتطبيق باستخدامه ثم حاول مرة أخرى.',
      );
      return;
    }
    await _listen();
  }

  /// Starts or stops listening while searching.
  Future<void> toggleListening() async {
    final current = state;
    if (current == null) return;
    if (current.listening) return stop();
    if (ref.read(audioProvider).playing) {
      await ref.read(audioProvider.notifier).togglePlay();
    }
    if (_listener == null) return start(mode: current.mode);
    state = AutoRecitation(mode: current.mode, heard: current.heard);
    await _listen();
  }

  Future<void> stop() async {
    final current = state;
    if (current == null) return;
    _sessionId++;
    _commit();
    state = AutoRecitation(mode: current.mode, heard: current.heard);
    await _listener?.stop();
  }

  /// Stops searching and closes the bar.
  void close() {
    _sessionId++;
    final listener = _listener;
    _listener = null;
    state = null;
    listener?.stop();
  }

  Future<void> _listen() async {
    final current = state;
    final listener = _listener;
    if (current == null || listener == null) return;
    final id = ++_sessionId;
    state = AutoRecitation(
      mode: current.mode,
      heard: current.heard,
      listening: true,
    );
    try {
      await listener.listen(
        onResult: (text, isFinal) {
          if (id != _sessionId) return;
          final words = [
            for (final w in text.trim().split(RegExp(r'\s+')))
              if (w.isNotEmpty) w,
          ];
          // Google's recognizer may start its text over after a pause in
          // the same session: the words before are kept.
          if (words.length + 3 <= _current.length &&
              (words.isEmpty || words.first != _current.first)) {
            _commit();
          }
          _current = words;
          if (isFinal) _commit();
          if (_search()) return;
          _showHeard();
          if (isFinal) _restart();
        },
      );
    } catch (e) {
      _onError('$e');
    }
  }

  void _commit() {
    _committed.addAll(_current);
    _current = const [];
    // Only the last words are searched; keep a few more than that.
    if (_committed.length > 2 * QuranFinder.maxWords) {
      _committed.removeRange(0, _committed.length - QuranFinder.maxWords);
    }
  }

  void _showHeard() {
    final current = state;
    if (current == null) return;
    final words = [..._committed, ..._current];
    state = AutoRecitation(
      mode: current.mode,
      heard: words.skip(words.length > 12 ? words.length - 12 : 0).join(' '),
      listening: current.listening,
    );
  }

  /// Looks for the place recited; once found, starts reciting there.
  bool _search() {
    final finder = ref.read(quranFinderProvider).value;
    final current = state;
    final listener = _listener;
    if (finder == null || current == null || listener == null) return false;
    final words = [..._committed, ..._current];
    final found = finder.find(words);
    if (found == null) return false;
    // The words heard from the place found on go to the recitation: those
    // of sessions that ended as they are, and the session still listening
    // without its first words.
    final start = found.heardStart;
    if (start < _committed.length) {
      listener.handOver(_committed.sublist(start).join(' '), 0);
    } else {
      listener.handOver('', start - _committed.length);
    }
    _sessionId++;
    _listener = null;
    state = null;
    ref
        .read(pageRecitationProvider.notifier)
        .startAt(
          found.ayah,
          position: found.position,
          mode: current.mode,
          listener: listener,
        );
    return true;
  }

  void _onSessionDone() {
    if (state?.listening != true) return;
    _sessionId++;
    _commit();
    if (!_search()) _restart();
  }

  void _restart() {
    if (state?.listening != true || _restartPending) return;
    _restartPending = true;
    // A short gap lets the recognizer release the microphone first.
    Future.delayed(const Duration(milliseconds: 300), () {
      _restartPending = false;
      if (state?.listening == true && _listener != null) _listen();
    });
  }

  void _onError(String message) {
    final current = state;
    if (current == null) return;
    // Silence and "nothing recognized" are normal pauses while reciting.
    if (message.contains('no_match') ||
        message.contains('no-speech') ||
        message.contains('speech_timeout') ||
        message.contains('aborted')) {
      return;
    }
    final String error;
    if (message.contains('not-allowed') || message.contains('permission')) {
      error =
          'لم يُسمح باستخدام الميكروفون. اسمح به من إعدادات المتصفح أو الهاتف.';
    } else if (message.contains('network')) {
      error =
          'التعرف على الصوت يحتاج إلى اتصال بالإنترنت، '
          'أو حمّل نموذج التلاوة ليعمل بدونه.';
    } else {
      error = 'حدث خطأ في الاستماع: $message';
    }
    _sessionId++;
    state = AutoRecitation(
      mode: current.mode,
      heard: current.heard,
      error: error,
    );
  }
}

final autoRecitationProvider =
    NotifierProvider<AutoRecitationController, AutoRecitation?>(
      AutoRecitationController.new,
    );

/// Passes a listener on from one user to the next while it is listening:
/// the next one gets the words heard so far in the listening session, as
/// if it had listened from the start, less words handed over to skip.
class HandoverListener implements SpeechListener {
  HandoverListener(this.inner);

  final SpeechListener inner;
  bool _initialized = false;

  /// Whether a session of [inner] is going on.
  bool _listening = false;
  String _lastText = '';
  void Function(String message)? _onError;
  void Function()? _onDone;
  void Function(String text, bool isFinal)? _onResult;

  /// Words to put before what the session still listening hears.
  String _carry = '';

  /// Words at the start of the session still listening to leave out.
  int _skip = 0;

  /// What the next user gets: [carry] first, then what the session going
  /// on hears without its first [skip] words.
  void handOver(String carry, int skip) {
    _carry = carry;
    _skip = skip;
    _onResult = null;
  }

  @override
  Future<bool> initialize({
    required void Function(String message) onError,
    required void Function() onDone,
  }) async {
    _onError = onError;
    _onDone = onDone;
    if (_initialized) return true;
    _initialized = await inner.initialize(
      onError: (message) => _onError?.call(message),
      onDone: () {
        _listening = false;
        _onDone?.call();
      },
    );
    return _initialized;
  }

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    _onResult = onResult;
    if (_listening) {
      // Taking over a session going on: what it heard so far comes first.
      if (_lastText.isNotEmpty || _carry.isNotEmpty) _forward(_lastText, false);
      return;
    }
    _listening = true;
    _lastText = '';
    _lastWords = const [];
    await inner.listen(
      onResult: (text, isFinal) {
        _lastText = text;
        if (isFinal) _listening = false;
        _forward(text, isFinal);
      },
    );
  }

  /// The words of the last result of the session going on.
  List<String> _lastWords = const [];

  void _forward(String text, bool isFinal) {
    final words = [
      for (final w in text.trim().split(RegExp(r'\s+')))
        if (w.isNotEmpty) w,
    ];
    // Google's recognizer may start its text over after a pause in the
    // same session; what it sends then holds only new words, so nothing
    // handed over belongs before them.
    if (words.length + 3 <= _lastWords.length &&
        (words.isEmpty || words.first != _lastWords.first)) {
      _carry = '';
      _skip = 0;
    }
    _lastWords = isFinal ? const [] : words;
    final out = [
      if (_carry.isNotEmpty) _carry,
      ...words.skip(_skip < words.length ? _skip : words.length),
    ].join(' ');
    if (isFinal) {
      _carry = '';
      _skip = 0;
      _lastText = '';
    }
    _onResult?.call(out, isFinal);
  }

  @override
  Future<void> stop() {
    _listening = false;
    _lastText = '';
    _lastWords = const [];
    _carry = '';
    _skip = 0;
    return inner.stop();
  }
}
