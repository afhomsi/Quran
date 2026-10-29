/// Turns the text of the pieces a voice detector cuts speech into, each
/// transcribed on its own, into the results of listening sessions.
///
/// A piece ends at a pause, and its text is a final result. One cut only
/// because it grew too long may end in the middle of a word, which the
/// next piece then starts with: its text is not final but goes on into
/// the next piece's, its last word joined to the next piece's first, so
/// the two halves of a word make it whole again. Two whole words joined
/// so are still found, as words written together.
class SpeechPieces {
  SpeechPieces(this.send);

  /// Receives each result: the whole text of the listening session so far.
  final void Function(String text, bool isFinal) send;

  /// The text of pieces cut for being too long, still going on.
  String _before = '';

  /// What was said so far of the piece being recited.
  void partial(String text) {
    if (text.trim().isEmpty) return;
    send(_join(text), false);
  }

  /// The whole text of a piece that ended; [cut] when it was cut for
  /// being too long rather than at a pause.
  void piece(String text, {required bool cut}) {
    final joined = _join(text);
    if (cut) {
      _before = joined;
      if (joined.isNotEmpty) send(joined, false);
    } else {
      _before = '';
      send(joined, true);
    }
  }

  /// Forgets a piece going on, when listening stops.
  void reset() => _before = '';

  String _join(String text) => '$_before${text.trim()}'.trim();
}
