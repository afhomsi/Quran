final _marks = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]');
final _arabicDigits = RegExp('[٠-٩]');
final _persianDigits = RegExp('[۰-۹]');
final _bengaliDigits = RegExp('[০-৯]');

/// Reduces Arabic text to a form for loose matching: no diacritics or
/// Quranic marks, one form of alef, and ة/ى folded into ه/ي. The mushaf's
/// وٰ (as in صلوٰة) reads as ا. Arabic-Indic, Urdu and Bengali digits become
/// Western digits, so "٢" finds page 2. Latin letters are lowercased and
/// dashes read as spaces, so "al kahf" finds "Al-Kahf".
String normalizeForSearch(String text) => NormalizedText(text).text;

/// [original] reduced as by [normalizeForSearch], remembering where each
/// character came from, so a match can be found in the original text.
class NormalizedText {
  factory NormalizedText(String original) {
    final out = StringBuffer();
    final offsets = <int>[];
    var lastSpace = true;
    void put(String s, int at) {
      for (var k = 0; k < s.length; k++) {
        out.write(s[k]);
        offsets.add(at);
      }
    }

    for (var i = 0; i < original.length; i++) {
      var c = original[i];
      if (c == '\u0648' &&
          i + 1 < original.length &&
          original[i + 1] == '\u0670') {
        c = 'ا';
      } else if (_marks.hasMatch(c) || _quotes.contains(c)) {
        continue;
      }
      if (c == '-' || c.trim().isEmpty) {
        if (!lastSpace) put(' ', i);
        lastSpace = true;
        continue;
      }
      lastSpace = false;
      final unit = c.codeUnitAt(0);
      if (_arabicDigits.hasMatch(c)) {
        c = '${unit - 0x0660}';
      } else if (_persianDigits.hasMatch(c)) {
        c = '${unit - 0x06F0}';
      } else if (_bengaliDigits.hasMatch(c)) {
        c = '${unit - 0x09E6}';
      } else {
        c = switch (c) {
          'أ' || 'إ' || 'آ' || 'ٱ' => 'ا',
          'ة' => 'ه',
          'ى' => 'ي',
          _ => c.toLowerCase(),
        };
      }
      put(c, i);
    }
    var text = out.toString();
    if (text.endsWith(' ')) {
      text = text.substring(0, text.length - 1);
      offsets.removeLast();
    }
    return NormalizedText._(original, text, offsets);
  }

  NormalizedText._(this.original, this.text, this._offsets);

  final String original;
  final String text;
  final List<int> _offsets;

  /// The part of [original] that the characters [start] to [end] of [text]
  /// came from, with the marks that follow the last letter.
  (int, int) originalRange(int start, int end) {
    final from = _offsets[start];
    var to = end < text.length ? _offsets[end] : original.length;
    while (to > from + 1 && original[to - 1].trim().isEmpty) {
      to--;
    }
    return (from, to);
  }
}

const _quotes = "'‘’";

final _digitsOnly = RegExp(r'^\d+$');

/// Whether an index entry matches what the user typed. A number matches
/// the start of any of [numbers] (typing 5 finds 5, 50 and 512); text
/// matches anywhere in [texts]. An empty query matches everything.
bool searchMatches(
  String query, {
  List<int> numbers = const [],
  List<String> texts = const [],
}) {
  final q = normalizeForSearch(query);
  if (q.isEmpty) return true;
  if (_digitsOnly.hasMatch(q)) {
    return numbers.any((n) => '$n'.startsWith(q));
  }
  return texts.any((t) => normalizeForSearch(t).contains(q));
}
