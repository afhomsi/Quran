import 'dart:math';

import 'mushaf_models.dart';
import 'mushaf_repository.dart';

/// One question of the hifz exam: recite ayat [from] to [to] of [surah]
/// from memory.
class ExamQuestion {
  const ExamQuestion(this.surah, this.from, this.to);

  final int surah;
  final int from;
  final int to;

  int get ayahCount => to - from + 1;

  @override
  bool operator ==(Object other) =>
      other is ExamQuestion &&
      other.surah == surah &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(surah, from, to);

  @override
  String toString() => '$surah:$from-$to';
}

/// The share of a surah's ayat the exam asks to recite, in all.
const examShare = 0.1;

/// The lines of a full mushaf page.
const _pageLines = 15;

/// The mushaf lines [surah] takes: its name, basmala and ayah lines.
int surahLines(Mushaf mushaf, int surah) {
  final first = mushaf.surahStartPage(surah);
  final last = mushaf.pageOf(AyahRef(surah, ayahCounts[surah - 1]));
  var lines = 0;
  for (var p = first; p <= last; p++) {
    for (final line in mushaf.page(p).lines) {
      if (switch (line) {
        SurahNameLine(surah: final s) ||
        BasmalaLine(surah: final s) => s == surah,
        AyahLine(:final words) => words.any((w) => w.ayah.surah == surah),
      }) {
        lines++;
      }
    }
  }
  return lines;
}

/// Whether the exam is given for [surah]: only for a surah longer than
/// one page of the mushaf, as a shorter one is recited whole.
bool examAllowed(Mushaf mushaf, int surah) =>
    surahLines(mushaf, surah) > _pageLines;

/// Picks ayat of [surah], which has [ayahCount] ayat, to recite from
/// memory: a few short groups of two to four ayat, about [examShare] of
/// the surah in all, spread over the surah at random, in order.
List<ExamQuestion> pickExam(int surah, int ayahCount, Random random) {
  final target = max(2, (ayahCount * examShare).round()).clamp(1, ayahCount);
  final count = max(1, (target / 3).round());
  final sizes = [
    for (var i = 0; i < count; i++)
      target ~/ count + (i < target % count ? 1 : 0),
  ]..shuffle(random);
  // Each group in its own stretch of the surah, so they do not overlap
  // and cover the whole of it.
  final questions = <ExamQuestion>[];
  for (var i = 0; i < count; i++) {
    final lo = i * ayahCount ~/ count + 1;
    final hi = (i + 1) * ayahCount ~/ count;
    final size = min(sizes[i], hi - lo + 1);
    final from = lo + random.nextInt(hi - lo - size + 2);
    questions.add(ExamQuestion(surah, from, from + size - 1));
  }
  return questions;
}
