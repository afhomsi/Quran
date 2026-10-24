import 'dart:math';

import 'arabic_normalizer.dart';

enum WordStatus {
  /// Not recited yet.
  pending,
  correct,

  /// Another word was said in its place.
  wrong,

  /// Left out: the reciter went on to a later word.
  skipped,
}

/// What a word to recite belongs to.
enum WordKind {
  ayah,

  /// The basmala said before a surah. It is not an ayah (except in
  /// Al-Fatiha), so leaving it out is not a mistake.
  basmala,

  /// "أعوذ بالله من الشيطان الرجيم" said before reciting. Optional and not
  /// shown.
  istiadha,
}

/// One word to recite and how it was recited.
class WordResult {
  const WordResult({
    required this.word,
    required this.status,
    this.heard,
    this.extrasBefore = const [],
  });

  final ExpectedWord word;
  final WordStatus status;

  /// What was said instead, for [WordStatus.wrong].
  final String? heard;

  /// Words said just before this one that do not belong to the recitation.
  final List<String> extrasBefore;

  int get surah => word.surah;
  int get ayah => word.ayah;

  /// The word as written in the mushaf.
  String get text => word.text;

  bool get isMistake =>
      status == WordStatus.wrong ||
      status == WordStatus.skipped ||
      extrasBefore.isNotEmpty;
}

/// The words to recite with their status after comparing them to what was
/// heard.
class RecitationResult {
  const RecitationResult({required this.words, this.extrasAtEnd = const []});

  final List<WordResult> words;

  /// Extra words said after the last word.
  final List<String> extrasAtEnd;

  /// Number of words recited so far, mistakes included.
  int get progress =>
      words.lastIndexWhere((w) => w.status != WordStatus.pending) + 1;

  bool get isComplete => words.every(
    (w) => w.status != WordStatus.pending || w.word.kind != WordKind.ayah,
  );

  int get mistakeCount =>
      words.where((w) => w.isMistake).length + (extrasAtEnd.isEmpty ? 0 : 1);
}

/// A word to recite, with the ayah it belongs to.
class ExpectedWord {
  ExpectedWord(this.surah, this.ayah, this.text, {this.kind = WordKind.ayah})
    : key = normalizeWord(text);

  final int surah;
  final int ayah;
  final String text;
  final WordKind kind;
  final String key;

  bool get optional => kind != WordKind.ayah;
}

const _basmala = 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ';
const _istiadha = 'أعوذ بالله من الشيطان الرجيم';

List<String> _split(String text) => [
  for (final w in text.split(RegExp(r'\s+')))
    if (normalizeWord(w).isNotEmpty) w,
];

/// The words of [ayahs], given as `(surah, ayah, text)` in reading order.
///
/// The optional isti'adha comes first, and an optional basmala before the
/// first ayah of every surah except Al-Fatiha, where it is the first ayah,
/// and At-Tawbah, which has none.
List<ExpectedWord> wordsToRecite(Iterable<(int, int, String)> ayahs) {
  final words = [
    for (final w in _split(_istiadha))
      ExpectedWord(0, 0, w, kind: WordKind.istiadha),
  ];
  for (final (surah, ayah, text) in ayahs) {
    if (ayah == 1 && surah != 1 && surah != 9) {
      for (final w in _split(_basmala)) {
        words.add(ExpectedWord(surah, 0, w, kind: WordKind.basmala));
      }
    }
    for (final w in _split(text)) {
      words.add(ExpectedWord(surah, ayah, w));
    }
  }
  return words;
}

/// The words of a whole surah, given its ayah texts.
List<ExpectedWord> wordsOfSurah(int surah, List<String> ayahs) => wordsToRecite(
  [for (var i = 0; i < ayahs.length; i++) (surah, i + 1, ayahs[i])],
);

/// Whether a heard word counts as the expected one. Long words may differ by
/// one letter, because recognizers often misspell a letter that was recited
/// correctly.
bool wordsMatch(String expected, String heard) {
  if (expected == heard) return true;
  if (min(expected.length, heard.length) < 5) return false;
  return _editDistance(expected, heard) <= 1;
}

/// Aligns [heard] (raw recognizer words) with [expected] and reports each
/// expected word's status.
///
/// The alignment is a word-level edit distance where the unrecited end is
/// free, so stopping half way is not a mistake, and so are optional words
/// (isti'adha, basmala). While the reciter is still speaking ([settled]
/// false) the recognizer's last words can still change, so mistakes after
/// the last correctly recited word are held back.
RecitationResult alignRecitation(
  List<ExpectedWord> expected,
  List<String> heard, {
  bool settled = true,
}) {
  final h = <String>[];
  final hRaw = <String>[];
  for (final w in heard) {
    final k = normalizeWord(w);
    if (k.isEmpty) continue;
    h.add(k);
    hRaw.add(w);
  }
  final n = expected.length, m = h.length;
  int skipCost(int i) => expected[i].optional ? 0 : 1;

  // cost[i][j]: best cost of aligning expected[0, i) with heard[0, j).
  final cost = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = 1; i <= n; i++) {
    cost[i][0] = cost[i - 1][0] + skipCost(i - 1);
  }
  for (var j = 0; j <= m; j++) {
    cost[0][j] = j;
  }
  final same = List.generate(
    n,
    (i) => List.generate(m, (j) => wordsMatch(expected[i].key, h[j])),
  );
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      cost[i][j] = min(
        cost[i - 1][j - 1] + (same[i - 1][j - 1] ? 0 : 1),
        min(cost[i - 1][j] + skipCost(i - 1), cost[i][j - 1] + 1),
      );
    }
  }

  // Everything heard is used; the expected words after `end` are pending.
  // On a tie the later end wins, so a wrong last word is reported as wrong
  // rather than as extra.
  var end = 0;
  for (var i = 1; i <= n; i++) {
    if (cost[i][m] <= cost[end][m]) end = i;
  }

  final status = List.filled(n, WordStatus.pending);
  final said = List<String?>.filled(n, null);
  final extras = List.generate(n + 1, (_) => <String>[]);
  var i = end, j = m;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0) {
      final match = same[i - 1][j - 1];
      if (cost[i][j] == cost[i - 1][j - 1] + (match ? 0 : 1)) {
        status[i - 1] = match ? WordStatus.correct : WordStatus.wrong;
        if (!match) said[i - 1] = hRaw[j - 1];
        i--;
        j--;
        continue;
      }
    }
    if (i > 0 && cost[i][j] == cost[i - 1][j] + skipCost(i - 1)) {
      if (!expected[i - 1].optional) status[i - 1] = WordStatus.skipped;
      i--;
    } else {
      extras[i].insert(0, hRaw[j - 1]);
      j--;
    }
  }

  // Optional words that were not said stay pending, also before the
  // current position.
  for (var k = 0; k < n; k++) {
    if (expected[k].optional && status[k] == WordStatus.wrong) {
      // A wrong word in place of an optional one is an extra word before
      // the next word.
      extras[k + 1].insert(0, said[k]!);
      status[k] = WordStatus.pending;
      said[k] = null;
      extras[k + 1].insertAll(0, extras[k]);
      extras[k].clear();
    }
  }

  if (!settled) {
    final lastCorrect = status.lastIndexOf(WordStatus.correct);
    for (var k = lastCorrect + 1; k < n; k++) {
      status[k] = WordStatus.pending;
      said[k] = null;
      extras[k].clear();
    }
    extras[n].clear();
  }

  return RecitationResult(
    words: [
      for (var k = 0; k < n; k++)
        WordResult(
          word: expected[k],
          status: status[k],
          heard: said[k],
          extrasBefore: extras[k],
        ),
    ],
    extrasAtEnd: extras[n],
  );
}

int _editDistance(String a, String b) {
  var prev = List.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final cur = List.filled(b.length + 1, i);
    for (var j = 1; j <= b.length; j++) {
      cur[j] = min(
        prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
        min(prev[j], cur[j - 1]) + 1,
      );
    }
    prev = cur;
  }
  return prev[b.length];
}
