/// Finding lafz al-jalala, the name of Allah, in the words of the
/// Uthmani text, so that the mushaf can show it in its own colour.
library;

/// The name with what may come before and after it, matched on the
/// letters of a word without their marks: a hamza of question (ءآلله،
/// أبالله), و or ف, ب or ت, then ٱلله or لله (لِلَّهِ), and the م of
/// ٱللَّهُمَّ. Words that only share the letters, such as خِلَٰلِهِۦ or
/// ٱللَّهۡوِ, do not match.
final _name = RegExp(r'^([ءأ]?[وف]?[بت]?)([ٱاآ]?لله|لله)(م?)$');

final _cache = <String, ({int start, int end})?>{};

/// The characters of [word] from `start` to `end` that spell the name of
/// Allah, leaving out a و, ف, ب or ت before it and the pause marks after
/// it; null when [word] is not the name.
({int start, int end})? jalalaIn(String word) =>
    _cache.putIfAbsent(word, () => _find(word));

({int start, int end})? _find(String word) {
  final letters = StringBuffer();
  final at = <int>[];
  for (var i = 0; i < word.length; i++) {
    if (_isLetter(word.codeUnitAt(i))) {
      letters.write(word[i]);
      at.add(i);
    }
  }
  final m = _name.firstMatch(letters.toString());
  if (m == null) return null;
  var end = word.length;
  while (end > 0 && _isPause(word.codeUnitAt(end - 1))) {
    end--;
  }
  return (start: at[m.group(1)!.length], end: end);
}

bool _isLetter(int c) => (c >= 0x0621 && c <= 0x064A) || c == 0x0671;

/// The small pause signs written after a word, such as ۚ and ۖ.
bool _isPause(int c) => c >= 0x06D6 && c <= 0x06DC;
