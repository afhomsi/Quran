import 'package:flutter/material.dart';

import '../../data/mushaf_models.dart';
import '../../data/page_fonts.dart';

/// Width of one printed line in em of the QCF page fonts.
const _lineWidthEm = 16.6;

/// Distance between two printed lines in em.
const _linePitchEm = 1.6;

const _linesPerPage = 15;

/// Draws one mushaf page line by line, as printed in the Madinah mushaf.
class MushafPageView extends StatelessWidget {
  const MushafPageView({
    super.key,
    required this.page,
    required this.surahName,
    this.selected,
    this.onAyahTap,
    this.onAyahLongPress,
  });

  final MushafPage page;
  final String Function(int surah) surahName;
  final AyahRef? selected;
  final ValueChanged<AyahRef>? onAyahTap;
  final ValueChanged<AyahRef>? onAyahLongPress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final lineHeight = box.maxHeight / _linesPerPage;
        final fontSize = [
          box.maxWidth / _lineWidthEm,
          lineHeight / _linePitchEm,
        ].reduce((a, b) => a < b ? a : b);
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
    return switch (line) {
      SurahNameLine(:final surah) => _SurahHeader(
        name: surahName(surah),
        fontSize: fontSize,
      ),
      BasmalaLine() => Center(
        child: Text(
          // Basmala of al-Fatiha, drawn with the page 1 font.
          'ﱁ ﱂﱃﱄ',
          style: TextStyle(
            fontFamily: PageFonts.familyFor(1),
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
                  family: PageFonts.familyFor(page.number),
                  fontSize: fontSize,
                  selected: w.ayah == selected,
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
    this.onTap,
    this.onLongPress,
  });

  final MushafWord word;
  final String family;
  final double fontSize;
  final bool selected;
  final ValueChanged<AyahRef>? onTap;
  final ValueChanged<AyahRef>? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null ? null : () => onTap!(word.ayah),
      onLongPress: onLongPress == null ? null : () => onLongPress!(word.ayah),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? colors.primaryContainer : null,
        ),
        child: Text(
          word.glyph,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: family,
            fontSize: fontSize,
            height: _linePitchEm,
            color: word.isAyahEnd ? colors.primary : colors.onSurface,
          ),
        ),
      ),
    );
  }
}

class _SurahHeader extends StatelessWidget {
  const _SurahHeader({required this.name, required this.fontSize});

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
      child: Text(
        'سورة $name',
        style: TextStyle(
          fontSize: fontSize * 0.8,
          fontWeight: FontWeight.bold,
          color: colors.onPrimaryContainer,
        ),
      ),
    );
  }
}
