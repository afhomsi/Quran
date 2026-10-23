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

/// One word of the surah being recited and how it was recited.
class WordResult {
  const WordResult({
    required this.ayah,
    required this.text,
    required this.status,
    this.heard,
    this.extrasBefore = const [],
  });

  /// 1-based ayah number.
  final int ayah;

  /// The word as written in the mushaf.
  final String text;
  final WordStatus status;

  /// What was said instead, for [WordStatus.wrong].
  final String? heard;

  /// Words said just before this one that do not belong to the surah.
  final List<String> extrasBefore;

  bool get isMistake =>
      status == WordStatus.wrong ||
      status == WordStatus.skipped ||
      extrasBefore.isNotEmpty;
}

/// The surah's words with their status after comparing them to what was
/// heard.
class RecitationResult {
  const RecitationResult({required this.words, this.extrasAtEnd = const []});

  final List<WordResult> words;

  /// Extra words said after the last word of the surah.
  final List<String> extrasAtEnd;

  /// Number of words recited so far, mistakes included.
  int get progress =>
      words.lastIndexWhere((w) => w.status != WordStatus.pending) + 1;

  bool get isComplete => words.every((w) => w.status != WordStatus.pending);

  int get mistakeCount =>
      words.where((w) => w.isMistake).length + (extrasAtEnd.isEmpty ? 0 : 1);
}

/// A word of the surah, with the ayah it belongs to.
class ExpectedWord {
  ExpectedWord(this.ayah, this.text) : key = normalizeWord(text);

  final int ayah;
  final String text;
  final String key;
}

/// Splits the ayahs of a surah into words.
List<ExpectedWord> wordsOfAyahs(List<String> ayahs) => [
  for (var a = 0; a < ayahs.length; a++)
    for (final w in ayahs[a].split(RegExp(r'\s+')))
      if (normalizeWord(w).isNotEmpty) ExpectedWord(a + 1, w),
];

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
/// The alignment is a word-level edit distance where the unrecited end of the
/// surah is free, so stopping half way is not a mistake. While the reciter is
/// still speaking ([settled] false) the recognizer's last words can still
/// change, so mistakes after the last correctly recited word are held back.
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

  // cost[i][j]: best cost of aligning expected[0, i) with heard[0, j).
  final cost = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = 0; i <= n; i++) {
    cost[i][0] = i;
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
        min(cost[i - 1][j], cost[i][j - 1]) + 1,
      );
    }
  }

  // Everything heard is used; the expected words after `end` are pending.
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
    if (i > 0 && cost[i][j] == cost[i - 1][j] + 1) {
      status[i - 1] = WordStatus.skipped;
      i--;
    } else {
      extras[i].insert(0, hRaw[j - 1]);
      j--;
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
          ayah: expected[k].ayah,
          text: expected[k].text,
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
