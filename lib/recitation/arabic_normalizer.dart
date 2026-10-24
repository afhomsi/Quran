/// Turns Uthmani Quran text and speech-recognizer output into comparable
/// letter skeletons.
///
/// Speech recognizers write plain modern Arabic without diacritics, while the
/// mushaf uses Uthmani spelling (ٱلۡعَٰلَمِينَ for العالمين). Both sides are
/// reduced to the same skeleton: diacritics and Quranic marks are removed,
/// hamza and alef forms are unified, and long alefs inside a word are dropped
/// because the two spellings disagree on exactly those.
library;

final _marks = RegExp(
  '['
  'ؐ-ؚ' // honorifics and small signs
  'ً-ٟ' // harakat, tanween, shadda, sukun
  'ٰ' // dagger alef
  'ۖ-ۭ' // Quranic pause and recitation marks
  'ـ' // tatweel
  ']',
);

final _nonLetters = RegExp('[^ء-ي]');

final _alefs = RegExp('[أإآٱ]');

/// Skeletons already made: the same words come back in every partial
/// result while reciting, so each is reduced only once.
final _cache = <String, String>{};

/// The comparable skeleton of a single word.
String normalizeWord(String word) {
  final cached = _cache[word];
  if (cached != null) return cached;
  if (_cache.length > 20000) _cache.clear();
  return _cache[word] = _normalize(word);
}

String _normalize(String word) {
  var w = word.replaceAll(_marks, '');
  w = w
      .replaceAll(_alefs, 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ئ', 'ي')
      .replaceAll('ؤ', 'و')
      .replaceAll('ة', 'ه')
      .replaceAll('ء', '');
  w = w.replaceAll(_nonLetters, '');
  if (w.length > 1) {
    w = w[0] + w.substring(1).replaceAll('ا', '');
  }
  return w;
}

/// Splits [text] into words and normalizes each, dropping empty ones.
List<String> normalizeWords(String text) => text
    .split(RegExp(r'\s+'))
    .map(normalizeWord)
    .where((w) => w.isNotEmpty)
    .toList();
