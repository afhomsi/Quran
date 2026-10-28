import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mushaf_models.dart';
import '../data/quran_models.dart';
import '../data/quran_repository.dart';
import 'arabic_normalizer.dart';
import 'recitation_matcher.dart';

/// Where a reciter is in the Quran, found from the words heard.
class FoundPlace {
  const FoundPlace(this.ayah, this.position, this.heardStart);

  /// The ayah the reciter started at.
  final AyahRef ayah;

  /// The position in [ayah] of the first word recited, from 1.
  final int position;

  /// How many of the words heard come before the recitation: the
  /// isti'adha, a basmala or words said before starting.
  final int heardStart;

  @override
  String toString() => '$ayah word $position (heard from $heardStart)';
}

/// Finds where in the whole Quran a reciter is from the first words they
/// recite, so reciting can start without choosing a surah or page, even
/// part way through an ayah.
///
/// Each word heard votes for the places in the Quran where it is written;
/// the place most words agree on, in order, wins once it is clearly ahead
/// of any other place, as a short phrase may be in several surahs.
class QuranFinder {
  QuranFinder(List<Surah> surahs) {
    for (final s in surahs) {
      for (var a = 0; a < s.ayahs.length; a++) {
        var position = 0;
        for (final w in s.ayahs[a].split(RegExp(r'\s+'))) {
          final key = normalizeWord(w);
          if (key.isEmpty) continue;
          position++;
          _index.putIfAbsent(key, () => []).add(_keys.length);
          _keys.add(key);
          _places.add((s.number, a + 1, position));
        }
      }
    }
  }

  /// The skeleton of every word of the Quran, in order.
  final _keys = <String>[];

  /// The surah, ayah and position of each of [_keys].
  final _places = <(int, int, int)>[];

  /// Where each skeleton is written, as indexes in [_keys].
  final _index = <String, List<int>>{};

  /// How many words of the Quran there are.
  int get length => _keys.length;

  /// Words heard that agree on a place before it is taken.
  static const minWords = 4;

  /// How many more words the best place needs than any other.
  static const margin = 2;

  /// Only the last words heard are searched, so the search stays fast
  /// and words said long before do not get in the way.
  static const maxWords = 24;

  /// Places this many words apart or less count as the same place.
  static const _near = 3;

  static final _istiadha = normalizeWords('أعوذ بالله من الشيطان الرجيم');
  static final _basmala = normalizeWords('بسم الله الرحمن الرحيم');

  /// The place [heard] is recited from, or null while it is not clear yet.
  FoundPlace? find(List<String> heard) {
    final skip = heard.length > maxWords ? heard.length - maxWords : 0;
    final keys = [for (final w in heard.skip(skip)) normalizeWord(w)];
    // The isti'adha and the basmala are said before many surahs, so they
    // tell nothing of where the reciter is.
    var lead = _prefix(keys, 0, _istiadha);
    final basmala = _prefix(keys, lead, _basmala);
    lead += basmala;

    // Votes for each shift between a word heard and the same word in the
    // Quran: a phrase recited in order has the same shift for all words.
    final votes = <int, List<int>>{};
    for (var j = lead; j < keys.length; j++) {
      final at = _index[keys[j]];
      if (at == null) continue;
      for (final i in at) {
        (votes[i - j] ??= []).add(j);
      }
    }
    if (votes.isEmpty) return null;

    // A word left out or added by the recognizer moves the shift a little,
    // so nearby shifts count together.
    var best = 0;
    var bestScore = 0;
    final scores = <int, int>{};
    for (final shift in votes.keys) {
      final words = <int>{};
      for (var d = shift - 1; d <= shift + 1; d++) {
        words.addAll(votes[d] ?? const []);
      }
      final score = words.length;
      scores[shift] = score;
      // The first place wins a tie, so the reciter's start is the match.
      if (score > bestScore || (score == bestScore && shift < best)) {
        best = shift;
        bestScore = score;
      }
    }
    if (bestScore < minWords) return null;
    for (final e in scores.entries) {
      if ((e.key - best).abs() > _near && e.value > bestScore - margin) {
        return null;
      }
    }

    // The first word heard that is at that place, in the shift as voted.
    var first = keys.length;
    var at = 0;
    for (var d = best - 1; d <= best + 1; d++) {
      for (final j in votes[d] ?? const <int>[]) {
        if (j < first) {
          first = j;
          at = j + d;
        }
      }
    }
    // A first word the recognizer got slightly wrong is still recited.
    while (first > lead &&
        at > 0 &&
        wordsMatch(_keys[at - 1], keys[first - 1], RecitationMode.lenient)) {
      first--;
      at--;
    }
    final (surah, ayah, position) = _places[at];
    // Recited from the start of a surah, the basmala heard belongs to it,
    // and in Al-Fatiha the basmala is its first ayah.
    if (basmala > 0 && first == lead) {
      if (position == 1 && ayah == 1) {
        return FoundPlace(AyahRef(surah, 1), 1, skip);
      }
      if (surah == 1 && ayah == 2 && position == 1) {
        return FoundPlace(const AyahRef(1, 1), 1, skip);
      }
    }
    return FoundPlace(AyahRef(surah, ayah), position, skip + first);
  }

  /// How many words at [from] in [keys] are the words of [phrase], all of
  /// them or none.
  static int _prefix(List<String> keys, int from, List<String> phrase) {
    if (keys.length - from <= phrase.length) return 0;
    for (var k = 0; k < phrase.length; k++) {
      if (keys[from + k] != phrase[k]) return 0;
    }
    return phrase.length;
  }
}

/// The whole Quran indexed for [QuranFinder.find], made once.
final quranFinderProvider = FutureProvider<QuranFinder>(
  (ref) async => QuranFinder(await ref.watch(surahsProvider.future)),
);
