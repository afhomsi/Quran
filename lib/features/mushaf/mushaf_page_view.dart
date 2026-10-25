import 'package:flutter/material.dart';

import '../../data/mushaf_models.dart';
import '../../data/mushaf_text.dart';
import '../../data/quarters.dart';
import '../../data/tajweed.dart';

/// Width of one printed line in em of the mushaf font. Most lines of the
/// Madinah layout take 14 to 18 em; longer ones are set a little smaller.
const _lineWidthEm = 16.5;

/// Distance between two printed lines in em.
const _linePitchEm = 1.7;

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
    this.recitedWords,
    this.showHizbMarks = false,
    this.tajweed,
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

  /// When given, the page is being recited from memory: each word shows
  /// only once that many words of its ayah were recited, and the others
  /// are grey blocks. The ayah numbers always show.
  final Map<AyahRef, int>? recitedWords;

  /// Put ۞ over the first word of each quarter of a hizb.
  final bool showHizbMarks;

  /// Letters in the colours of tajweed, when given.
  final TajweedMap? tajweed;
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
    return switch (line) {
      SurahNameLine(:final surah) => _SurahHeader(
        surah: surah,
        name: surahName(surah),
        fontSize: fontSize,
      ),
      BasmalaLine() => Center(
        child: Text(
          mushafDisplayText(basmalaText),
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: mushafFont,
            fontSize: fontSize,
            height: 1,
            color: colors.onSurface,
          ),
        ),
      ),
      // A line as wide as the text block, or as its words if they need
      // more, then shrunk to fit.
      AyahLine(:final words, :final centered) => FittedBox(
        fit: BoxFit.scaleDown,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: fontSize * _lineWidthEm),
          child: IntrinsicWidth(
            child: Row(
              // Pages 1 and 2 are set in a narrow centered block.
              mainAxisAlignment: centered || page.number <= 2
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              spacing: fontSize * 0.15,
              children: [
                for (final w in words)
                  _Word(
                    word: w,
                    tajweed: w.isAyahEnd
                        ? const []
                        : tajweed?.spansOf(w.ayah)[w.position - 1],
                    fontSize: fontSize,
                    selected: w.ayah == selected,
                    wordSelected: selectedWord == (w.ayah, w.position),
                    highlight: highlights[w.ayah],
                    hidden:
                        recitedWords != null &&
                        !w.isAyahEnd &&
                        (recitedWords![w.ayah] ?? 0) < w.position,
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
      ),
    };
  }
}

class _Word extends StatelessWidget {
  const _Word({
    required this.word,
    required this.tajweed,
    required this.fontSize,
    required this.selected,
    this.wordSelected = false,
    this.highlight,
    this.hidden = false,
    this.hizbMark = false,
    this.onTap,
    this.onLongPress,
  });

  final MushafWord word;

  /// The letters to colour by the rules of tajweed, if they are shown.
  final List<TajweedSpan>? tajweed;
  final double fontSize;
  final bool selected;
  final bool wordSelected;
  final Color? highlight;

  /// Not recited yet, or recited wrongly, so drawn as a block of the
  /// word's size: grey, or in the ayah's highlight colour.
  final bool hidden;
  final bool hizbMark;
  final WordCallback? onTap;
  final WordCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (hidden) {
      return Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: fontSize * 0.3),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // An ayah recited wrongly shows its colour, red.
                  color:
                      highlight?.withValues(alpha: dark ? 0.35 : 0.5) ??
                      colors.onSurface.withValues(alpha: dark ? 0.16 : 0.1),
                  borderRadius: BorderRadius.circular(fontSize * 0.25),
                ),
              ),
            ),
          ),
          // Keeps the word's size, so the lines stay as printed.
          Opacity(
            opacity: 0,
            child: Text(
              _display(word.text),
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: mushafFont,
                fontSize: fontSize,
                height: _linePitchEm,
              ),
            ),
          ),
        ],
      );
    }
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
            Text.rich(
              word.isAyahEnd
                  ? TextSpan(
                      text: ayahEndMark(word.ayah.ayah),
                      style: TextStyle(color: colors.primary),
                    )
                  : TextSpan(
                      children: wordSelected
                          ? [TextSpan(text: _display(word.text))]
                          : _tajweedSpans(word.text, tajweed, dark),
                    ),
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: mushafFont,
                fontSize: fontSize,
                height: _linePitchEm,
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

/// [text] as the mushaf font draws it, without the ۞ that the page shows
/// apart.
String _display(String text) => mushafDisplayText(text.replaceAll('۞', ''));

/// [text] with each letter in the colour of its tajweed rule; a letter
/// that takes two rules shows the first of [TajweedRule.values].
List<TextSpan> _tajweedSpans(String text, List<TajweedSpan>? spans, bool dark) {
  if (spans == null || spans.isEmpty) return [TextSpan(text: _display(text))];
  final rules = List<TajweedRule?>.filled(text.length, null);
  for (final s in spans) {
    for (var i = s.start; i < s.end; i++) {
      if (rules[i] == null || s.rule.index < rules[i]!.index) rules[i] = s.rule;
    }
  }
  final out = <TextSpan>[];
  var start = 0;
  for (var i = 1; i <= text.length; i++) {
    if (i < text.length && rules[i] == rules[start]) continue;
    final rule = rules[start];
    out.add(
      TextSpan(
        text: _display(text.substring(start, i)),
        style: rule == null ? null : TextStyle(color: rule.color(dark)),
      ),
    );
    start = i;
  }
  return out;
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
              'سُورَةُ $name',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: mushafFont,
                fontSize: fontSize * 1.1,
                height: 1.4,
                color: colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
