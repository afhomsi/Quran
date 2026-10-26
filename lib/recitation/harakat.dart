/// Compares the harakat of a recited word with the mushaf's.
///
/// Only the offline recitation model writes harakat; other recognizers
/// write bare letters, and then nothing is compared. The two sides spell
/// words differently (Uthmani and modern spelling), so the harakat are
/// compared letter by letter on the same letter skeleton as the words
/// themselves, and only where both sides mark a letter: a letter left
/// bare in the mushaf, such as a noon merged into the next letter, says
/// nothing.
library;

import 'arabic_normalizer.dart';

/// The vowel on a letter.
enum Vowel { fatha, damma, kasra, sukun, fathatan, dammatan, kasratan }

/// Marks that stand for a vowel in the mushaf text. The Uthmani text has
/// its own sukun (ۡ) and open tanween (ٗ ٞ ٖ); its plain sukun sign (ْ) is
/// the round zero over a letter that is never said, so it is no vowel.
const _mushafVowels = {
  0x064E: Vowel.fatha,
  0x064F: Vowel.damma,
  0x0650: Vowel.kasra,
  0x06E1: Vowel.sukun,
  0x064B: Vowel.fathatan,
  0x0657: Vowel.fathatan,
  0x064C: Vowel.dammatan,
  0x065E: Vowel.dammatan,
  0x064D: Vowel.kasratan,
  0x0656: Vowel.kasratan,
};

/// Marks that stand for a vowel in what a recognizer writes.
const _heardVowels = {
  0x064E: Vowel.fatha,
  0x064F: Vowel.damma,
  0x0650: Vowel.kasra,
  0x0652: Vowel.sukun,
  0x064B: Vowel.fathatan,
  0x064C: Vowel.dammatan,
  0x064D: Vowel.kasratan,
};

/// Small meem after a vowel: tanween said as meem (iqlab).
const _iqlab = {0x06E2, 0x06ED};

const _tanweenOf = {
  Vowel.fatha: Vowel.fathatan,
  Vowel.damma: Vowel.dammatan,
  Vowel.kasra: Vowel.kasratan,
};

/// Pause marks in the mushaf, after which a reciter may stop.
final _pauseMarks = RegExp('[ۖ-ۜ]');

/// Whether a reciter may stop after [word], as at a pause mark.
bool isPauseWord(String word) => _pauseMarks.hasMatch(word);

bool _isLetter(int c) => (c >= 0x0621 && c <= 0x064A) || c == 0x0671;

/// The vowel on each letter of [word]'s skeleton (see [normalizeWord]),
/// null for letters left bare; null when the skeleton cannot be followed.
List<Vowel?>? _vowels(String word, Map<int, Vowel> marks) {
  final letters = <String>[];
  final vowels = <Vowel?>[];
  for (final c in word.runes) {
    if (_isLetter(c)) {
      letters.add(String.fromCharCode(c));
      vowels.add(null);
    } else if (vowels.isNotEmpty) {
      final v = marks[c];
      if (v != null) {
        vowels[vowels.length - 1] = v;
      } else if (_iqlab.contains(c) && _tanweenOf[vowels.last] != null) {
        vowels[vowels.length - 1] = _tanweenOf[vowels.last];
      }
    }
  }
  // The skeleton drops hamza on its own and long alefs inside the word.
  final keptLetters = StringBuffer();
  final kept = <Vowel?>[];
  for (var i = 0; i < letters.length; i++) {
    final l = normalizeWord(letters[i]);
    if (l.isEmpty) continue;
    if (l == 'ا' && kept.isNotEmpty) continue;
    keptLetters.write(l);
    kept.add(vowels[i]);
  }
  if (keptLetters.toString() != normalizeWord(word)) return null;
  return kept;
}

/// Whether [heard] carries harakat at all, so they can be compared.
bool hasHarakat(String heard) =>
    heard.runes.any((c) => _heardVowels.containsKey(c) && c != 0x0652);

/// Whether [heard] was said with a haraka different from the mushaf word
/// [expected]. Both must have the same letters. When the reciter may stop
/// after the word ([pause]), its last letter is left out, as stopping
/// changes it.
bool harakatDiffer(String expected, String heard, {bool pause = false}) {
  if (!hasHarakat(heard)) return false;
  final e = _vowels(expected, _mushafVowels);
  final h = _vowels(heard, _heardVowels);
  if (e == null || h == null || e.length != h.length) return false;
  final end = pause ? e.length - 1 : e.length;
  for (var i = 0; i < end; i++) {
    if (e[i] != null && h[i] != null && e[i] != h[i]) return true;
  }
  return false;
}
