import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hifz_exam.dart';

import 'mushaf_models.dart';
import 'mushaf_repository.dart';
import 'recitation_history.dart';

/// How well a mushaf page is known, from how it was recited.
enum PageStrength {
  /// Not recited yet.
  none,

  /// Recited with mistakes the last time.
  weak,

  /// Recited right once or twice in a row.
  medium,

  /// Recited right on three different days in a row or more.
  strong,
}

/// Days to wait before reviewing a page again, by how many days in a row
/// it was recited without a mistake: the more often it was recited right,
/// the longer it stays in memory, so the longer the wait. A page with a
/// mistake is reviewed again the next day.
const reviewIntervals = [1, 2, 4, 7, 15, 30, 60];

/// What the recitation history tells of one page.
class PageHifz {
  const PageHifz({
    required this.page,
    required this.lastRecited,
    required this.cleanDays,
    required this.lastMistakes,
  });

  final int page;
  final DateTime lastRecited;

  /// Different days in a row, up to the last recitation, the page was
  /// recited without a mistake.
  final int cleanDays;

  /// Mistakes on the page the last time it was recited.
  final int lastMistakes;

  PageStrength get strength => lastMistakes > 0
      ? PageStrength.weak
      : cleanDays >= 3
      ? PageStrength.strong
      : PageStrength.medium;

  /// The day the page should be reviewed on.
  DateTime get dueDate {
    final wait =
        reviewIntervals[cleanDays.clamp(0, reviewIntervals.length - 1)];
    final day = _day(lastRecited);
    return DateTime(day.year, day.month, day.day + wait);
  }

  /// Days past [dueDate] on [now]; 0 on the day itself, below 0 before.
  int overdueOn(DateTime now) => _day(now).difference(dueDate).inDays;

  bool isDueOn(DateTime now) => overdueOn(now) >= 0;
}

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// The pages a recitation went over: from the page it started on to the
/// last page it recited to the end, and any page it made a mistake on.
Set<int> pagesOf(RecitationRecord r, Mushaf m) {
  final first = m.pageOf(r.first);
  var last = m.pageOf(r.last);
  // The page of the last ayah reached counts once it is recited to its
  // end: the recitation is complete, or the ayah is the page's last.
  final lastPage = m.page(last);
  if (last > first && !r.complete && lastPage.words.last.ayah != r.last) {
    last--;
  }
  return {
    for (var p = first; p <= last; p++) p,
    for (final a in r.mistakeAyat) m.pageOf(a),
  };
}

/// How each recited page stands, from the recitation [records] (in any
/// order). Pages never recited are left out.
Map<int, PageHifz> pageHifzOf(List<RecitationRecord> records, Mushaf m) {
  final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
  final result = <int, PageHifz>{};
  for (final r in sorted) {
    final mistakesOnPage = <int, int>{};
    for (final a in r.mistakeAyat) {
      final p = m.pageOf(a);
      mistakesOnPage[p] = (mistakesOnPage[p] ?? 0) + 1;
    }
    for (final p in pagesOf(r, m)) {
      final before = result[p];
      final mistakes = mistakesOnPage[p] ?? 0;
      final int clean;
      if (mistakes > 0) {
        clean = 0;
      } else if (before == null || before.lastMistakes > 0) {
        clean = 1;
      } else if (_day(before.lastRecited) == _day(r.date)) {
        // Reciting a page again the same day does not make it stronger.
        clean = before.cleanDays;
      } else {
        clean = before.cleanDays + 1;
      }
      result[p] = PageHifz(
        page: p,
        lastRecited: r.date,
        cleanDays: clean,
        lastMistakes: mistakes,
      );
    }
  }
  return result;
}

/// Pages next to each other to review in one go.
class ReviewRun {
  const ReviewRun(this.firstPage, this.lastPage, this.strength);

  final int firstPage;
  final int lastPage;

  /// The weakest of its pages.
  final PageStrength strength;

  int get pageCount => lastPage - firstPage + 1;

  /// Where reciting the run stops: the first ayah after its last page, or
  /// null at the end of the Quran.
  AyahRef? until(Mushaf m) =>
      lastPage < mushafPageCount ? m.page(lastPage + 1).firstAyah : null;

  @override
  bool operator ==(Object other) =>
      other is ReviewRun &&
      other.firstPage == firstPage &&
      other.lastPage == lastPage &&
      other.strength == strength;

  @override
  int get hashCode => Object.hash(firstPage, lastPage, strength);

  @override
  String toString() => 'ReviewRun($firstPage-$lastPage, ${strength.name})';
}

/// How many pages the daily review asks for at most.
const reviewPagesPerDay = 5;

/// Today's review: the pages due on [now], weakest and longest overdue
/// first, at most [limit] of them, in runs of pages next to each other.
List<ReviewRun> dailyReview(
  Map<int, PageHifz> pages,
  DateTime now, {
  int limit = reviewPagesPerDay,
}) {
  final due = pages.values.where((p) => p.isDueOn(now)).toList()
    ..sort((a, b) {
      final weak = (b.lastMistakes > 0 ? 1 : 0) - (a.lastMistakes > 0 ? 1 : 0);
      if (weak != 0) return weak;
      final late = b.overdueOn(now) - a.overdueOn(now);
      if (late != 0) return late;
      return a.page - b.page;
    });
  final chosen = due.take(limit).toList()..sort((a, b) => a.page - b.page);
  final runs = <ReviewRun>[];
  for (final p in chosen) {
    final last = runs.lastOrNull;
    if (last != null && last.lastPage == p.page - 1) {
      runs[runs.length - 1] = ReviewRun(
        last.firstPage,
        p.page,
        _weaker(last.strength, p.strength),
      );
    } else {
      runs.add(ReviewRun(p.page, p.page, p.strength));
    }
  }
  // The weakest runs first.
  runs.sort((a, b) => a.strength.index - b.strength.index);
  return runs;
}

PageStrength _weaker(PageStrength a, PageStrength b) =>
    a.index <= b.index ? a : b;

/// How many pages are due on [now] in all, beyond today's [limit] too.
int duePageCount(Map<int, PageHifz> pages, DateTime now) =>
    pages.values.where((p) => p.isDueOn(now)).length;

/// Each recited page and how it stands; empty until the mushaf loads.
final pageHifzProvider = Provider<Map<int, PageHifz>>((ref) {
  final mushaf = ref.watch(mushafProvider).value;
  if (mushaf == null) return const {};
  return pageHifzOf(ref.watch(recitationHistoryProvider), mushaf);
});

/// The ayat recited with a mistake that were not recited right since,
/// in reading order: a later recitation that reached the ayah without a
/// mistake in it puts it right.
List<AyahRef> pendingMistakes(List<RecitationRecord> records) {
  final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
  final pending = <AyahRef>{};
  for (final r in sorted) {
    final wrong = r.mistakeAyat.toSet();
    pending.removeWhere(
      (a) => !wrong.contains(a) && !(a < r.first) && !(r.last < a),
    );
    pending.addAll(wrong);
  }
  return pending.toList()..sort();
}

/// Days in a row, up to today or yesterday, with at least one
/// recitation; 0 when the last one was before yesterday.
int recitationStreak(List<RecitationRecord> records, DateTime now) {
  final days = {for (final r in records) _day(r.date)};
  var day = _day(now);
  if (!days.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
  var count = 0;
  while (days.contains(day)) {
    count++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return count;
}

/// How many pages the page-linking drill asks about.
const linkingQuestionCount = 5;

/// Questions for the page-linking drill: for some of [pages], the last
/// ayah of the page and the first of the next, so the reciter goes from
/// the end of one page into the next without a pause. Only pages whose
/// next page goes on in the same surah are asked, in mushaf order.
List<ExamQuestion> linkingQuestions(
  Mushaf m,
  Iterable<int> pages,
  Random random, {
  int count = linkingQuestionCount,
}) {
  final candidates = [
    for (final p in pages.toSet())
      if (p < mushafPageCount &&
          m.page(p).words.last.ayah.surah == m.page(p + 1).firstAyah.surah &&
          m.page(p).words.last.ayah != m.page(p + 1).firstAyah)
        p,
  ]..shuffle(random);
  final chosen = candidates.take(count).toList()..sort();
  return [
    for (final p in chosen)
      ExamQuestion(
        m.page(p).words.last.ayah.surah,
        m.page(p).words.last.ayah.ayah,
        m.page(p + 1).firstAyah.ayah,
      ),
  ];
}

/// Questions to recite [ayat] again one by one, each after the ayat
/// before it.
List<ExamQuestion> mistakeQuestions(List<AyahRef> ayat) => [
  for (final a in ayat) ExamQuestion(a.surah, a.ayah, a.ayah),
];
