final _marks = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]');
final _arabicDigits = RegExp('[٠-٩]');
final _persianDigits = RegExp('[۰-۹]');
final _bengaliDigits = RegExp('[০-৯]');

/// Reduces Arabic text to a form for loose matching: no diacritics or
/// Quranic marks, one form of alef, and ة/ى folded into ه/ي. Arabic-Indic,
/// Urdu and Bengali digits become Western digits, so "٢" finds page 2.
/// Latin letters are lowercased and dashes read as spaces, so "al kahf"
/// finds "Al-Kahf".
String normalizeForSearch(String text) => text
    .replaceAll(_marks, '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAllMapped(_arabicDigits, (m) => '${m[0]!.codeUnitAt(0) - 0x0660}')
    .replaceAllMapped(_persianDigits, (m) => '${m[0]!.codeUnitAt(0) - 0x06F0}')
    .replaceAllMapped(_bengaliDigits, (m) => '${m[0]!.codeUnitAt(0) - 0x09E6}')
    .toLowerCase()
    .replaceAll(RegExp("['‘’]"), '')
    .replaceAll('-', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
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
