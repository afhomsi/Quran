import 'dart:math';

import 'mushaf_models.dart';
import 'quran_models.dart';

/// What the self-test asks about each ayah it shows.
enum SelfTestMode {
  /// Shows an ayah and asks for the one after it.
  nextAyah,

  /// Shows the first words of an ayah and asks for the rest.
  completeAyah,
}

/// Every ayah from [from] up to, but not including, [until] (the end of
/// the Quran when null).
List<AyahRef> ayahsBetween(List<Surah> surahs, AyahRef from, AyahRef? until) {
  final result = <AyahRef>[];
  for (var s = from.surah; s <= surahs.length; s++) {
    final first = s == from.surah ? from.ayah : 1;
    for (var a = first; a <= surahs[s - 1].ayahCount; a++) {
      final ayah = AyahRef(s, a);
      if (until != null && !(ayah < until)) return result;
      result.add(ayah);
    }
  }
  return result;
}

/// Picks up to [count] different ayat of [scope] to ask about, in a random
/// order. For [SelfTestMode.nextAyah] the last ayah is left out, since
/// nothing in the scope follows it.
List<AyahRef> pickQuestions(
  List<AyahRef> scope,
  SelfTestMode mode,
  int count,
  Random random,
) {
  final pool = mode == SelfTestMode.nextAyah && scope.isNotEmpty
      ? scope.sublist(0, scope.length - 1)
      : [...scope];
  pool.shuffle(random);
  return pool.take(count).toList();
}

/// How many words of [ayah] to show as the prompt in
/// [SelfTestMode.completeAyah]: about a third, at least one, never all.
int promptWordCount(String ayah) {
  final words = ayah.split(' ').length;
  if (words <= 1) return words;
  return (words / 3).ceil().clamp(1, words - 1);
}
