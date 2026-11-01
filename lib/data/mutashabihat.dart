import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../recitation/arabic_normalizer.dart';
import 'hifz_exam.dart';
import 'mushaf_models.dart';
import 'quran_models.dart';
import 'quran_repository.dart';

/// How many first words two ayat must share to be taken for alike.
const similarStartWords = 4;

/// Openings shared by more ayat than this are common phrases, such as
/// «يا أيها الذين آمنوا», not ayat easily mixed up, and are left out.
const maxSimilarGroup = 6;

/// Ayat that start alike, so are easily taken one for another while
/// reciting: each ayah that has such ayat, with the others alike, in
/// reading order. Found from the text: ayat whose first
/// [similarStartWords] words are the same, in groups of at most
/// [maxSimilarGroup].
Map<AyahRef, List<AyahRef>> findSimilarAyat(List<Surah> surahs) {
  final groups = <String, List<AyahRef>>{};
  for (final s in surahs) {
    for (var a = 1; a <= s.ayahCount; a++) {
      final words = normalizeWords(s.ayahs[a - 1]);
      if (words.length < similarStartWords) continue;
      final key = words.take(similarStartWords).join(' ');
      (groups[key] ??= []).add(AyahRef(s.number, a));
    }
  }
  final result = <AyahRef, List<AyahRef>>{};
  for (final g in groups.values) {
    if (g.length < 2 || g.length > maxSimilarGroup) continue;
    for (final a in g) {
      result[a] = [
        for (final b in g)
          if (b != a) b,
      ];
    }
  }
  return result;
}

/// Each ayah with the ayat that start like it; empty until the Quran
/// loads.
final similarAyatProvider = Provider<Map<AyahRef, List<AyahRef>>>((ref) {
  final surahs = ref.watch(surahsProvider).value;
  return surahs == null ? const {} : findSimilarAyat(surahs);
});

/// How many ayat the similar-ayat drill asks about, each with one alike.
const similarDrillCount = 4;

/// Questions for the similar-ayat drill: some ayat on the [pages]
/// recited that have ayat alike, each followed by one of its alike ayat,
/// so the reciter learns where each goes on. [pageOf] gives the page of
/// an ayah.
List<ExamQuestion> similarQuestions(
  Map<AyahRef, List<AyahRef>> similar,
  Set<int> pages,
  int Function(AyahRef) pageOf,
  Random random, {
  int count = similarDrillCount,
}) {
  final candidates = [
    for (final a in similar.keys)
      if (pages.contains(pageOf(a))) a,
  ]..sort();
  candidates.shuffle(random);
  final asked = <AyahRef>{};
  final questions = <ExamQuestion>[];
  for (final a in candidates) {
    if (questions.length >= count * 2) break;
    if (asked.contains(a)) continue;
    final others = similar[a]!.where((b) => !asked.contains(b)).toList();
    if (others.isEmpty) continue;
    final b = others[random.nextInt(others.length)];
    asked.addAll([a, b]);
    questions
      ..add(ExamQuestion(a.surah, a.ayah, a.ayah))
      ..add(ExamQuestion(b.surah, b.ayah, b.ayah));
  }
  return questions;
}
