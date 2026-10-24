import 'package:flutter/material.dart';

import '../../data/mushaf_models.dart';
import '../../data/page_fonts.dart';
import '../../data/quarters.dart';

/// Width of one printed line in em of the QCF page fonts.
const _lineWidthEm = 16.6;

/// Distance between two printed lines in em.
const _linePitchEm = 1.6;

const _linesPerPage = 15;

/// Ayat where a quarter of a hizb starts, except the very first one.
final _quarterStarts = rubStarts.skip(1).toSet();

/// Width of the printed text block when a page gets [width] by [height].
/// A tall screen is limited by its width, a wide one by its height.
double mushafTextWidth(double width, double height) {
  final fontSize = [
    width / _lineWidthEm,
    height / _linesPerPage / _linePitchEm,
  ].reduce((a, b) => a < b ? a : b);
  return fontSize * _lineWidthEm;
}

/// The page font palette that suits the current theme.
MushafPalette mushafPalette(BuildContext context, {bool tajweed = false}) =>
    switch ((Theme.of(context).brightness == Brightness.dark, tajweed)) {
      (false, false) => MushafPalette.light,
      (true, false) => MushafPalette.dark,
      (false, true) => MushafPalette.tajweedLight,
      (true, true) => MushafPalette.tajweedDark,
    };

/// Called with the word pressed and where it is on the screen.
typedef WordCallback = void Function(MushafWord word, Offset position);

/// Draws one mushaf page line by line, as printed in the Madinah mushaf.
class MushafPageView extends StatelessWidget {
  const MushafPageView({
    super.key,
    required this.page,
    required this.surahName,
    this.selected,
    this.selectedWord,
    this.highlights = const {},
    this.showHizbMarks = false,
    this.tajweed = false,
    this.onAyahTap,
    this.onAyahLongPress,
  });

  final MushafPage page;
  final String Function(int surah) surahName;
  final AyahRef? selected;

  /// A word to show in red, as the word open in the word card: its ayah
  /// and position.
  final (AyahRef, int)? selectedWord;

  /// Ayat colored by the reader, with their color.
  final Map<AyahRef, Color> highlights;

  /// Put ۞ over the first word of each quarter of a hizb.
  final bool showHizbMarks;

  /// Letters in the colours of tajweed.
  final bool tajweed;
  final WordCallback? onAyahTap;
  final WordCallback? onAyahLongPress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final lineHeight = box.maxHeight / _linesPerPage;
        final fontSize =
            mushafTextWidth(box.maxWidth, box.maxHeight) / _lineWidthEm;
        return Column(
          // Pages 1 and 2 have only a few lines, set in the middle.
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final line in page.lines)
              SizedBox(
                height: lineHeight,
                width: fontSize * _lineWidthEm,
                child: _line(context, line, fontSize, lineHeight),
              ),
          ],
        );
      },
    );
  }

  Widget _line(
    BuildContext context,
    MushafLine line,
    double fontSize,
    double lineHeight,
  ) {
    final colors = Theme.of(context).colorScheme;
    final palette = mushafPalette(context, tajweed: tajweed);
    return switch (line) {
      SurahNameLine(:final surah) => _SurahHeader(
        surah: surah,
        name: surahName(surah),
        fontSize: fontSize,
      ),
      BasmalaLine() => Center(
        child: Text(
          // Basmala of al-Fatiha, drawn with the page 1 font.
          'ﱁ ﱂﱃﱄ',
          style: TextStyle(
            fontFamily: PageFonts.familyFor(1, palette),
            fontSize: fontSize,
            height: 1,
            color: colors.onSurface,
          ),
        ),
      ),
      AyahLine(:final words, :final centered) => FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: fontSize * _lineWidthEm,
          child: Row(
            // Pages 1 and 2 are set in a narrow centered block.
            mainAxisAlignment: centered || page.number <= 2
                ? MainAxisAlignment.center
                : MainAxisAlignment.spaceBetween,
            children: [
              for (final w in words)
                _Word(
                  word: w,
                  family: PageFonts.familyFor(page.number, palette),
                  fontSize: fontSize,
                  selected: w.ayah == selected,
                  wordSelected: selectedWord == (w.ayah, w.position),
                  highlight: highlights[w.ayah],
                  hizbMark:
                      showHizbMarks &&
                      w.position == 1 &&
                      _quarterStarts.contains(w.ayah),
                  onTap: onAyahTap,
                  onLongPress: onAyahLongPress,
                ),
            ],
          ),
        ),
      ),
    };
  }
}

class _Word extends StatelessWidget {
  const _Word({
    required this.word,
    required this.family,
    required this.fontSize,
    required this.selected,
    this.wordSelected = false,
    this.highlight,
    this.hizbMark = false,
    this.onTap,
    this.onLongPress,
  });

  final MushafWord word;
  final String family;
  final double fontSize;
  final bool selected;
  final bool wordSelected;
  final Color? highlight;
  final bool hizbMark;
  final WordCallback? onTap;
  final WordCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: onTap == null ? null : (d) => onTap!(word, d.globalPosition),
      onLongPressStart: onLongPress == null
          ? null
          : (d) => onLongPress!(word, d.globalPosition),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: wordSelected
              ? _wordColor(dark).withValues(alpha: 0.18)
              : selected
              ? colors.primaryContainer
              // Highlighter colors are light, so tone them down at night.
              : highlight?.withValues(alpha: dark ? 0.35 : 0.8),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              word.glyph,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: family,
                fontSize: fontSize,
                height: _linePitchEm,
                // Ayah numbers bring their own colours from the font.
                color: wordSelected ? _wordColor(dark) : colors.onSurface,
              ),
            ),
            if (hizbMark)
              // Above the start of the word, in the space between lines.
              PositionedDirectional(
                top: -fontSize * 0.1,
                start: 0,
                child: Text(
                  '۞',
                  style: TextStyle(
                    fontSize: fontSize * 0.5,
                    height: 1,
                    color: colors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The colour of the word open in the word card.
Color _wordColor(bool dark) =>
    dark ? const Color(0xFFE58FA6) : const Color(0xFF8E2442);

class _SurahHeader extends StatelessWidget {
  const _SurahHeader({
    required this.surah,
    required this.name,
    required this.fontSize,
  });

  final int surah;
  final String name;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.symmetric(vertical: fontSize * 0.15),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.5),
        border: Border.all(color: colors.primary, width: 1.5),
        borderRadius: BorderRadius.circular(fontSize * 0.3),
      ),
      alignment: Alignment.center,
      child: Semantics(
        label: 'سورة $name',
        child: ExcludeSemantics(
          child: FittedBox(
            child: Text(
              // The font turns these words into the calligraphy of
              // "سورة" and the surah's name, as printed in the mushaf.
              'surah${surah.toString().padLeft(3, '0')}surah-icon',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: 'SurahNames',
                fontSize: fontSize * 2,
                height: 1,
                color: colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
