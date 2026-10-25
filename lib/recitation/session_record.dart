import '../data/mushaf_models.dart';
import '../data/recitation_history.dart';
import 'recitation_matcher.dart';
import 'recitation_session.dart';

/// What [session] recited so far and its mistakes, for the history; null
/// when no ayah was reached yet.
RecitationRecord? recordOf(RecitationSession session, {int? surah, int? page}) {
  final words = session.result.words;
  final reached = words
      .take(session.result.progress)
      .where((w) => w.word.kind == WordKind.ayah)
      .toList();
  if (reached.isEmpty) return null;
  final first = session.expected.firstWhere((w) => w.kind == WordKind.ayah);
  return RecitationRecord(
    date: DateTime.now(),
    surah: surah,
    page: page,
    first: AyahRef(first.surah, first.ayah),
    last: AyahRef(reached.last.surah, reached.last.ayah),
    wordsDone: reached.length,
    wordsTotal: words.where((w) => !w.word.optional).length,
    complete: session.result.isComplete,
    mistakes: [for (final m in session.mistakes) mistakeRecordOf(session, m)],
  );
}

MistakeRecord mistakeRecordOf(RecitationSession session, Mistake m) {
  final w = session.expected[m.wordIndex];
  return MistakeRecord(
    w.kind == WordKind.ayah ? AyahRef(w.surah, w.ayah) : null,
    m.message,
  );
}

/// The ayat recited wrongly so far, in order.
List<AyahRef> mistakeAyatOf(RecitationSession session) =>
    {for (final m in session.mistakes) ?mistakeRecordOf(session, m).ayah}
        .toList()
      ..sort();
