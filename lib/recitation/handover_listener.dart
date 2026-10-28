import 'speech_listener.dart';

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
    _done.clear();
    // The user handing over lets go of the listener without stopping it.
    _handingOver = true;
  }

  /// Hands over from word [start] of [heard] on.
  void handOverFrom(int start) {
    if (start < _done.length) {
      handOver(_done.sublist(start).join(' '), 0);
    } else {
      handOver('', start - _done.length);
    }
  }

  /// The words heard since the last hand over, as the recognizer wrote
  /// them: those of sessions that ended, then the session going on.
  List<String> get heard => [..._done, ..._lastWords];
  final _done = <String>[];

  bool _handingOver = false;

  @override
  Future<bool> initialize({
    required void Function(String message) onError,
    required void Function() onDone,
  }) async {
    _onError = onError;
    _onDone = onDone;
    _handingOver = false;
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
      _done.addAll(_lastWords);
    }
    if (isFinal) _done.addAll(words);
    // Only the last words are needed to find a place.
    if (_done.length > 64) _done.removeRange(0, _done.length - 32);
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
  Future<void> stop() async {
    if (_handingOver) return;
    _listening = false;
    _lastText = '';
    _lastWords = const [];
    _carry = '';
    _skip = 0;
    _done.clear();
    await inner.stop();
  }
}
