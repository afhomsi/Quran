/// A reference to one ayah, e.g. `AyahRef(2, 255)`.
class AyahRef implements Comparable<AyahRef> {
  const AyahRef(this.surah, this.ayah);

  final int surah;
  final int ayah;

  @override
  int compareTo(AyahRef other) =>
      surah != other.surah ? surah - other.surah : ayah - other.ayah;

  bool operator <(AyahRef other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      other is AyahRef && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => Object.hash(surah, ayah);

  @override
  String toString() => '$surah:$ayah';

  static AyahRef parse(String s) {
    final parts = s.split(':');
    return AyahRef(int.parse(parts[0]), int.parse(parts[1]));
  }

  /// Whether this ayah is in the mushaf.
  bool get isValid =>
      surah >= 1 &&
      surah <= ayahCounts.length &&
      ayah >= 1 &&
      ayah <= ayahCounts[surah - 1];

  /// [s] as an ayah of the mushaf, such as `'2:255'`, or null when it is
  /// not one, as in damaged or edited saved data.
  static AyahRef? tryParse(Object? s) {
    if (s is! String) return null;
    final m = _pattern.firstMatch(s);
    if (m == null) return null;
    final ref = AyahRef(int.parse(m[1]!), int.parse(m[2]!));
    return ref.isValid ? ref : null;
  }

  /// Like [parse], but throws a [FormatException] for an ayah that is not
  /// in the mushaf, so saved data pointing at one is not trusted.
  static AyahRef parseValid(Object? s) =>
      tryParse(s) ?? (throw FormatException('Not an ayah', s));

  static final _pattern = RegExp(r'^(\d{1,3}):(\d{1,3})$');
}

/// How many ayat each surah has in the Hafs mushaf, 6236 in all.
const ayahCounts = [
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, //
  128, 111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, //
  30, 73, 54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, //
  18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, //
  12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, //
  36, 25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, //
  11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6,
];

/// One word of the Madinah mushaf.
class MushafWord {
  const MushafWord({
    required this.ayah,
    required this.position,
    required this.text,
  });

  final AyahRef ayah;

  /// 1-based position of the word in its ayah. The ayah-number marker is
  /// the last position.
  final int position;

  /// The word in the Uthmani text, as `ayahWords` gives it; empty for the
  /// ayah-number marker.
  final String text;

  bool get isAyahEnd => text.isEmpty;
}

sealed class MushafLine {
  const MushafLine();
}

class SurahNameLine extends MushafLine {
  const SurahNameLine(this.surah);
  final int surah;
}

class BasmalaLine extends MushafLine {
  const BasmalaLine(this.surah);
  final int surah;
}

class AyahLine extends MushafLine {
  const AyahLine({required this.words, required this.centered});
  final List<MushafWord> words;
  final bool centered;
}

class MushafPage {
  const MushafPage({required this.number, required this.lines});

  final int number;
  final List<MushafLine> lines;

  Iterable<MushafWord> get words =>
      lines.whereType<AyahLine>().expand((l) => l.words);

  AyahRef get firstAyah => words.first.ayah;
}
