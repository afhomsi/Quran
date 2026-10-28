import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/ayah_audio.dart';
import 'handover_listener.dart';
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
