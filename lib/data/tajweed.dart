import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mushaf_models.dart';
import 'quran_models.dart';
import 'quran_repository.dart';
import 'study.dart';

/// The tajweed rules the app marks, with their colours on a light and a
/// dark page, as in the Dar al-Ma'rifah tajweed mushaf.
///
/// The order is the order of precedence when one letter takes two rules.
enum TajweedRule {
  silent(Color(0xFFA5A5A5), Color(0xFF9D9999)),
  maddLazim(Color(0xFFB50000), Color(0xFFE30000)),
  maddWajib(Color(0xFFF40000), Color(0xFFFF5E8E)),
  maddJaiz(Color(0xFFFF7B00), Color(0xFFFF8E3B)),
  maddTabii(Color(0xFFCE9E00), Color(0xFFFFC1E0)),
  ghunna(Color(0xFF09B000), Color(0xFF26B55D)),
  qalqala(Color(0xFF2FADFF), Color(0xFF00DEFF)),
  tafkhim(Color(0xFF3F48E6), Color(0xFF3C84D5));

  const TajweedRule(this.light, this.dark);

  final Color light;
  final Color dark;

  Color color(bool darkPage) => darkPage ? dark : light;
}

/// One letter of a word, with its marks, that takes [rule]: the characters
/// from [start] to [end] of the word.
typedef TajweedSpan = ({int start, int end, TajweedRule rule});

/// The tajweed rules of every ayah, found from the Uthmani text by
/// [tajweedOfAyah].
class TajweedMap {
  TajweedMap(this._surahs);

  final List<Surah> _surahs;
  final _cache = <AyahRef, List<List<TajweedSpan>>>{};

  /// The spans of each word of [ayah], one list per word in the order of
  /// [ayahWords].
  List<List<TajweedSpan>> spansOf(AyahRef ayah) => _cache[ayah] ??=
      tajweedOfAyah(ayahWords(_surahs[ayah.surah - 1].ayahs[ayah.ayah - 1]));

  /// The rules on each word of [ayah] that has any, by word position.
  Map<int, Set<TajweedRule>> ofAyah(AyahRef ayah) => {
    for (final (i, spans) in spansOf(ayah).indexed)
      if (spans.isNotEmpty) i + 1: {for (final s in spans) s.rule},
  };
}

final tajweedProvider = FutureProvider<TajweedMap>(
  (ref) async => TajweedMap(await ref.watch(surahsProvider.future)),
);

// Letters and marks of the KFGQPC Uthmani text.
const _fatha = 'َ', _damma = 'ُ', _kasra = 'ِ';
const _shadda = 'ّ', _madda = 'ٓ', _sukun = 'ۡ';
const _silent = 'ْ', _silentInWasl = '۠';
const _dagger = 'ٰ', _smallWaw = 'ۥ', _smallYa = 'ۦ';
const _wasl = 'ٱ';
const _vowels = {_fatha, _damma, _kasra};
const _tanween = {'ً', 'ٌ', 'ٍ'};

/// Tanween written with the two marks apart: ikhfa, idgham or iqlab
/// follows.
const _openTanween = {'ٗ', 'ٞ', 'ٖ'};
const _openFathatan = 'ٗ';
const _iqlab = {'ۢ', 'ۭ'};
const _pauses = {'ۖ', 'ۗ', 'ۘ', 'ۚ', 'ۛ'};
const _hamzas = {'ء', 'أ', 'إ', 'ؤ', 'ئ'};
const _qalqala = {'ق', 'ط', 'ب', 'ج', 'د'};
const _heavy = {'خ', 'ص', 'ض', 'غ', 'ط', 'ق', 'ظ'};
const _idghamWithGhunna = {'ي', 'ن', 'م', 'و'};
const _idghamOfTanween = {'ي', 'ر', 'م', 'ل', 'ن', 'و'};
const _vowelMarks = {
  ..._vowels,
  ..._tanween,
  ..._openTanween,
  _sukun,
  _shadda,
  _silent,
  _silentInWasl,
  _madda,
};

/// A letter with the marks over or under it, characters [start] to [end]
/// of its word.
class _Letter {
  _Letter(this.base, this.start) : end = start + 1;

  final String base;
  final int start;
  int end;
  final marks = <String>{};

  bool has(String mark) => marks.contains(mark);
  bool hasAny(Set<String> set) => marks.any(set.contains);
  bool get bare => !hasAny(_vowelMarks);
  bool get sounded => !has(_silent) && !has(_silentInWasl);
}

bool _isMark(int c) =>
    (c >= 0x064B && c <= 0x065F) ||
    (c >= 0x06D6 && c <= 0x06DC) ||
    (c >= 0x06DF && c <= 0x06E4) ||
    c == 0x06E7 ||
    c == 0x06E8 ||
    (c >= 0x06EA && c <= 0x06ED);

bool _isLetter(int c) =>
    (c >= 0x0621 && c <= 0x064A) ||
    c == 0x0640 ||
    c == 0x0670 ||
    c == 0x0671 ||
    c == 0x06E5 ||
    c == 0x06E6;

/// The letters of [word]. Signs that are not letters, as ۞, are left out.
List<_Letter> _lettersOf(String word) {
  final letters = <_Letter>[];
  _Letter? last;
  for (var i = 0; i < word.length; i++) {
    final c = word.codeUnitAt(i);
    if (_isMark(c) && last != null) {
      last
        ..marks.add(word[i])
        ..end = i + 1;
    } else if (_isLetter(c)) {
      letters.add(last = _Letter(word[i], i));
    } else {
      last = null;
    }
  }
  return letters;
}

/// The tajweed rules of each word of one ayah, as [ayahWords] gives them,
/// for a reader who stops at the ayah's end and at its pause marks.
List<List<TajweedSpan>> tajweedOfAyah(List<String> words) {
  final letters = [for (final w in words) _lettersOf(w)];
  return [
    for (var i = 0; i < words.length; i++)
      _rulesOfWord(
        word: words[i],
        letters: letters[i],
        previous: i > 0 ? letters[i - 1] : null,
        next: i + 1 < letters.length ? letters[i + 1] : null,
        ayahEnd: i == words.length - 1,
      ),
  ];
}

List<TajweedSpan> _rulesOfWord({
  required String word,
  required List<_Letter> letters,
  required List<_Letter>? previous,
  required List<_Letter>? next,
  required bool ayahEnd,
}) {
  final found = <_Letter, Set<TajweedRule>>{};
  void add(TajweedRule rule, _Letter l) => (found[l] ??= {}).add(rule);

  final ayahStart = previous == null;
  final stop = ayahEnd || _pauses.any(word.contains);
  // In wasl the next word is heard from its first sounded letter, so a
  // hamzat wasl hides it.
  final firstNext = next == null || next.isEmpty || next.first.base == _wasl
      ? null
      : next.first;
  // The word before ends in a tanween or a bare noon that merges into this
  // word.
  final previousMerges =
      previous != null &&
      previous.isNotEmpty &&
      (previous.any((l) => l.hasAny(_openTanween)) ||
          (previous.last.base == 'ن' &&
              !previous.last.hasAny({..._vowels, _sukun, _shadda})));

  for (var k = 0; k < letters.length; k++) {
    final l = letters[k];
    final b = l.base;
    final prv = k > 0 ? letters[k - 1] : null;
    final nxt = k + 1 < letters.length ? letters[k + 1] : null;
    final atEnd = nxt == null;
    final follow = nxt ?? firstNext;
    final bare = l.bare;

    // Letters not pronounced.
    if (l.has(_silent) || l.has(_silentInWasl)) add(TajweedRule.silent, l);
    if (b == _wasl && !(ayahStart && k == 0)) add(TajweedRule.silent, l);
    if (bare && !'اويىٱمنـ'.contains(b) && b != _dagger && !_smallLetter(b)) {
      // Lam shamsiyya, and a letter merged into the next.
      if (nxt != null && nxt.has(_shadda)) add(TajweedRule.silent, l);
    }
    if (b == 'ن' &&
        bare &&
        follow != null &&
        follow.base != 'ن' &&
        (follow.has(_shadda) ||
            (atEnd && _idghamWithGhunna.contains(follow.base)))) {
      add(TajweedRule.silent, l);
    }
    if (l.hasAny(_openTanween) &&
        atEnd &&
        follow != null &&
        _idghamOfTanween.contains(follow.base)) {
      add(TajweedRule.silent, l);
    }
    if ((b == 'ا' || b == 'ى') &&
        bare &&
        prv != null &&
        prv.has(_openFathatan) &&
        !ayahEnd) {
      add(TajweedRule.silent, l);
    }
    if (b == 'ن' && l.hasAny(_iqlab)) add(TajweedRule.silent, l);

    // Ghunna: noon and meem with shadda, ikhfa, iqlab and idgham.
    if ((b == 'ن' || b == 'م') && l.has(_shadda)) add(TajweedRule.ghunna, l);
    if (b == 'ن' &&
        bare &&
        follow != null &&
        !follow.has(_shadda) &&
        !(atEnd && _idghamWithGhunna.contains(follow.base))) {
      add(TajweedRule.ghunna, l);
    }
    if (b == 'م' && bare && follow != null && follow.base == 'ب') {
      add(TajweedRule.ghunna, l);
    }
    if (l.hasAny(_iqlab)) add(TajweedRule.ghunna, l);
    if (l.hasAny(_openTanween) &&
        atEnd &&
        follow != null &&
        !_idghamOfTanween.contains(follow.base)) {
      add(TajweedRule.ghunna, l);
    }
    if (k == 0 && previousMerges && (b == 'ي' || b == 'و') && !l.has(_shadda)) {
      add(TajweedRule.ghunna, l);
    }

    // Qalqala.
    if (_qalqala.contains(b) &&
        (l.has(_sukun) || (stop && atEnd && !l.has(_shadda)))) {
      add(TajweedRule.qalqala, l);
    }

    // Madd written with a madda.
    if (l.has(_madda)) {
      final rest = letters.skip(k + 1).where((r) => r.sounded).toList();
      if (b == 'أ' || (b == 'ا' && prv?.base == 'ء')) {
        add(TajweedRule.maddTabii, l);
      } else if (!'اويى'.contains(b) && b != _dagger && !_smallLetter(b)) {
        // The opening letters of a surah, as الٓمٓ.
        add(TajweedRule.maddLazim, l);
      } else if (rest.isNotEmpty &&
          (rest.first.has(_shadda) || rest.first.has(_sukun)) &&
          !_hamzas.contains(rest.first.base)) {
        add(TajweedRule.maddLazim, l);
      } else {
        // A hamza follows, in this word or the next.
        add(TajweedRule.maddWajib, l);
      }
    }

    // Natural madd written with a small letter.
    if ((b == _dagger || _smallLetter(b)) &&
        !l.has(_madda) &&
        prv?.base != 'ى') {
      add(TajweedRule.maddTabii, l);
    }

    // Heavy letters, ra and the lam of the name of Allah.
    if (_heavy.contains(b)) add(TajweedRule.tafkhim, l);
    if (b == 'ر' && _heavyRa(l, prv, letters, k, stop && atEnd)) {
      add(TajweedRule.tafkhim, l);
    }
    if (b == 'ل' &&
        l.has(_shadda) &&
        nxt?.base == 'ه' &&
        prv?.base == 'ل' &&
        k >= 2 &&
        letters[k - 2].base == _wasl &&
        _afterOpenVowel(letters, k - 2, previous)) {
      add(TajweedRule.tafkhim, l);
    }
  }

  // Madd at a stop: a long vowel or a leen before the last letter.
  if (stop) {
    final sounded = letters.where((l) => l.sounded).toList();
    if (sounded.length >= 2) {
      final pen = sounded[sounded.length - 2];
      final leen =
          (pen.base == 'و' || pen.base == 'ي') &&
          pen.has(_sukun) &&
          sounded.length >= 3 &&
          sounded[sounded.length - 3].has(_fatha);
      final natural =
          ('اوىي'.contains(pen.base) &&
              !pen.hasAny({..._vowels, _sukun, _shadda, _madda})) ||
          pen.base == _dagger;
      if (natural || leen) {
        found[pen]?.remove(TajweedRule.maddTabii);
        add(TajweedRule.maddJaiz, pen);
      }
    }
  }

  return [
    for (final l in letters)
      for (final rule in found[l] ?? const <TajweedRule>{})
        (start: l.start, end: l.end, rule: rule),
  ];
}

bool _smallLetter(String b) => b == _smallWaw || b == _smallYa;

/// Whether the ra [l], the [k]th letter of [letters], is read heavy.
bool _heavyRa(
  _Letter l,
  _Letter? prv,
  List<_Letter> letters,
  int k,
  bool stopsHere,
) {
  if (l.hasAny({_fatha, _damma, 'ً', 'ٌ', 'ٗ', 'ٞ'})) {
    return true;
  }
  if ((l.has(_sukun) || l.bare) &&
      prv != null &&
      (prv.has(_fatha) || prv.has(_damma))) {
    return true;
  }
  // After a hamzat wasl, read with a kasra that is not its own.
  if (l.has(_sukun) && prv?.base == _wasl) return true;
  if (stopsHere && l.has(_kasra)) {
    // Stopped on, the ra takes the vowel before it.
    for (var j = k - 1; j >= 0; j--) {
      final p = letters[j];
      if (p.has(_fatha) || p.has(_damma)) return true;
      if (p.has(_kasra) || p.base == 'ي') return false;
    }
  }
  return false;
}

/// Whether the vowel heard before the hamzat wasl at [wasl] is a fatha or
/// a damma, as the lam of the name of Allah needs to be heavy.
bool _afterOpenVowel(List<_Letter> letters, int wasl, List<_Letter>? before) {
  if (wasl > 0) {
    final p = letters[wasl - 1];
    return p.has(_fatha) || p.has(_damma);
  }
  if (before == null || before.isEmpty) return true;
  final last = before.last;
  final vowel = last.marks.intersection({
    ..._vowels,
    ..._tanween,
    ..._openTanween,
    _sukun,
  });
  return !(vowel.contains(_kasra) ||
      vowel.contains('ٍ') ||
      vowel.contains('ٖ') ||
      vowel.contains(_sukun) ||
      (last.base == 'ي' && vowel.isEmpty));
}
