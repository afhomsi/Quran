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
}

/// One word of the Madinah mushaf, drawn with its page's QCF font.
class MushafWord {
  const MushafWord({
    required this.ayah,
    required this.position,
    required this.glyph,
    required this.isAyahEnd,
  });

  final AyahRef ayah;

  /// 1-based position of the word in its ayah. The ayah-number marker is
  /// the last position.
  final int position;
  final String glyph;
  final bool isAyahEnd;
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
