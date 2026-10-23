final _marks = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]');
final _arabicDigits = RegExp('[٠-٩]');

/// Reduces Arabic text to a form for loose matching: no diacritics or
/// Quranic marks, one form of alef, and ة/ى folded into ه/ي. Arabic-Indic
/// digits become Western digits, so "٢" finds page 2.
String normalizeForSearch(String text) => text
    .replaceAll(_marks, '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAllMapped(_arabicDigits, (m) => '${m[0]!.codeUnitAt(0) - 0x0660}')
    .trim();

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
