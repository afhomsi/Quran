import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/arabic_search.dart';
import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/page_fonts.dart';
import '../../data/quarters.dart';
import '../../data/quran_models.dart';
import '../../l10n/strings.dart';
import 'home_screen.dart';
import '../mushaf/mushaf_page_view.dart' show mushafPalette;
import 'index_icons.dart';

/// The index, one tab per entry of [S.indexTabs]: surahs, juz cards that
/// open onto their pages, every page as a book, and the quarters with their
/// opening words. Tapping an entry opens the mushaf there.
class IndexView extends StatelessWidget {
  const IndexView({
    super.key,
    required this.mushaf,
    required this.surahs,
    this.currentPage,
  });

  final Mushaf mushaf;
  final List<Surah> surahs;

  /// The page last read, whose juz starts open.
  final int? currentPage;

  @override
  Widget build(BuildContext context) => TabBarView(
    children: [
      _SurahTab(mushaf: mushaf, surahs: surahs),
      _JuzTab(mushaf: mushaf, surahs: surahs, currentPage: currentPage),
      _PageTab(mushaf: mushaf, surahs: surahs),
      _RubTab(mushaf: mushaf, surahs: surahs),
    ],
  );
}

/// A surah's names to search in: Arabic and in Latin letters.
List<String> _surahTexts(Surah s) => [s.name, s.transliteration];

/// A rounded search box at the top of a tab, with the tab's name as hint.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final t = S.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: colors.surface,
          // Balances the icon on the other side, so the text stays centered.
          prefixIcon: const SizedBox(width: 48),
          suffixIcon: controller.text.isEmpty
              ? Icon(Icons.search, color: colors.primary)
              : IconButton(
                  tooltip: t.clearSearch,
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onChanged();
                  },
                ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: colors.primary),
          ),
        ),
      ),
    );
  }
}

/// State for a tab with its own search box.
mixin _Searchable<T extends StatefulWidget> on State<T> {
  final search = TextEditingController();

  String get query => search.text;

  Widget searchField(String hint) => _SearchField(
    controller: search,
    hint: hint,
    onChanged: () => setState(() {}),
  );

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) =>
      Center(child: Text(S.of(context).noResults));
}

// --- Surahs -------------------------------------------------------------

class _SurahTab extends StatefulWidget {
  const _SurahTab({required this.mushaf, required this.surahs});

  final Mushaf mushaf;
  final List<Surah> surahs;

  @override
  State<_SurahTab> createState() => _SurahTabState();
}

class _SurahTabState extends State<_SurahTab> with _Searchable {
  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final colors = Theme.of(context).colorScheme;
    final found = [
      for (final s in widget.surahs)
        if (searchMatches(query, numbers: [s.number], texts: _surahTexts(s))) s,
    ];
    return Column(
      children: [
        searchField(t.indexTabs[0]),
        Expanded(
          child: found.isEmpty
              ? const _NoResults()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: found.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, i) {
                    final s = found[i];
                    final page = widget.mushaf.surahStartPage(s.number);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colors.primaryContainer,
                        child: Text(t.n(s.number)),
                      ),
                      title: Text(t.surahName(s)),
                      subtitle: Text(
                        '${s.isMeccan ? t.meccan : t.medinan} · '
                        '${t.ayahCount(s.ayahCount)}',
                      ),
                      trailing: Text(t.page(page)),
                      onTap: () => openMushaf(context, page),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// --- Juz ----------------------------------------------------------------

/// The pages of [juz]: from its first page up to where the next juz
/// starts. A few juz start in the middle of a page, such as the 7th in
/// al-Ma'ida; that page then belongs to both.
List<int> _pagesOfJuz(Mushaf m, int juz) {
  final first = m.juzStartPage(juz);
  var last = mushafPageCount;
  if (juz < juzStarts.length) {
    final next = m.juzStartPage(juz + 1);
    last = m.page(next).firstAyah == juzStarts[juz] ? next - 1 : next;
  }
  return [for (var p = first; p <= last; p++) p];
}

class _JuzTab extends StatefulWidget {
  const _JuzTab({required this.mushaf, required this.surahs, this.currentPage});

  final Mushaf mushaf;
  final List<Surah> surahs;
  final int? currentPage;

  @override
  State<_JuzTab> createState() => _JuzTabState();
}

class _JuzTabState extends State<_JuzTab> with _Searchable {
  late final Set<int> _open = {
    widget.mushaf.juzOfPage(widget.currentPage ?? 1),
  };

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final m = widget.mushaf;
    final found = [
      for (var j = 1; j <= juzStarts.length; j++)
        if (searchMatches(
          query,
          numbers: [j],
          texts: _surahTexts(widget.surahs[juzStarts[j - 1].surah - 1]),
        ))
          j,
    ];
    return Column(
      children: [
        searchField(t.indexTabs[1]),
        Expanded(
          child: found.isEmpty
              ? const _NoResults()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: found.length,
                  itemBuilder: (context, i) {
                    final j = found[i];
                    return _JuzCard(
                      juz: j,
                      pages: _pagesOfJuz(m, j),
                      open: _open.contains(j),
                      onToggle: () => setState(() {
                        if (!_open.remove(j)) _open.add(j);
                      }),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _JuzCard extends StatelessWidget {
  const _JuzCard({
    required this.juz,
    required this.pages,
    required this.open,
    required this.onToggle,
  });

  final int juz;
  final List<int> pages;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Material(
            color: colors.surfaceContainerHigh,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onToggle,
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    const SizedBox(width: 48),
                    Expanded(
                      child: Text(
                        t.juzCard(juz),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    PopupMenuButton<void>(
                      icon: Icon(Icons.more_horiz, color: colors.primary),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          onTap: () => openMushaf(context, pages.first),
                          child: Text(t.openJuzStart),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(12),
              decoration: ShapeDecoration(
                color: colors.surfaceContainer,
                shape: shape,
              ),
              child: _BookGrid(
                pages: pages,
                columns: 4,
                background: colors.surfaceContainer,
              ),
            ),
        ],
      ),
    );
  }
}

// --- Pages --------------------------------------------------------------

/// Books for [pages], in rows from the start side; tapping one opens it.
class _BookGrid extends StatelessWidget {
  const _BookGrid({
    required this.pages,
    required this.columns,
    required this.background,
    this.scrollable = false,
    this.iconWidth,
  });

  final List<int> pages;
  final int columns;
  final Color background;
  final bool scrollable;

  /// Fixed width of each book; when null a book fills its cell.
  final double? iconWidth;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    return GridView.builder(
      shrinkWrap: !scrollable,
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
      padding: scrollable
          ? const EdgeInsets.fromLTRB(16, 8, 16, 16)
          : EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: iconWidth == null ? 1.4 : 2.1,
      ),
      itemCount: pages.length,
      itemBuilder: (context, i) {
        final p = pages[i];
        final book = PageBookIcon(
          page: p,
          label: t.n(p),
          background: background,
        );
        return Semantics(
          button: true,
          label: t.page(p),
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => openMushaf(context, p),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: iconWidth == null
                    ? book
                    : SizedBox(width: iconWidth, child: book),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PageTab extends StatefulWidget {
  const _PageTab({required this.mushaf, required this.surahs});

  final Mushaf mushaf;
  final List<Surah> surahs;

  @override
  State<_PageTab> createState() => _PageTabState();
}

class _PageTabState extends State<_PageTab> with _Searchable {
  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final found = [
      for (final p in widget.mushaf.pages)
        if (searchMatches(
          query,
          numbers: [p.number],
          texts: _surahTexts(widget.surahs[p.firstAyah.surah - 1]),
        ))
          p.number,
    ];
    return Column(
      children: [
        searchField(t.indexTabs[2]),
        Expanded(
          child: found.isEmpty
              ? const _NoResults()
              : _BookGrid(
                  pages: found,
                  columns: 3,
                  background: Theme.of(context).colorScheme.surface,
                  scrollable: true,
                  iconWidth: 64,
                ),
        ),
      ],
    );
  }
}

// --- Quarters -----------------------------------------------------------

/// Quarters grouped by juz, eight to a card, each with the opening words
/// of its first ayah in the mushaf's own script.
class _RubTab extends StatelessWidget {
  const _RubTab({required this.mushaf, required this.surahs});

  final Mushaf mushaf;
  final List<Surah> surahs;

  static const _perJuz = 8;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final colors = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      itemCount: rubStarts.length ~/ _perJuz,
      itemBuilder: (context, i) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.juz(i + 1),
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (var k = 0; k < _perJuz; k++) ...[
                if (k > 0) const Divider(height: 1),
                _RubEntry(
                  rub: i * _perJuz + k + 1,
                  mushaf: mushaf,
                  surahs: surahs,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RubEntry extends StatelessWidget {
  const _RubEntry({
    required this.rub,
    required this.mushaf,
    required this.surahs,
  });

  final int rub;
  final Mushaf mushaf;
  final List<Surah> surahs;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final start = rubStarts[rub - 1];
    final surah = surahs[start.surah - 1];
    final page = mushaf.rubStartPage(rub);
    return Semantics(
      button: true,
      label: t.rubTitle(rub),
      child: InkWell(
        onTap: () => openMushaf(context, page, highlight: start),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              RubIcon(rub: rub, hizbLabel: t.n((rub - 1) ~/ 4 + 1)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OpeningWords(mushaf: mushaf, surah: surah, ayah: start),
                    const SizedBox(height: 2),
                    Text(
                      t.ayahAndPage(surah, start.ayah, page),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The first words of [ayah], drawn with the mushaf page fonts. Until the
/// fonts are loaded, shows the same words in plain text.
class _OpeningWords extends ConsumerStatefulWidget {
  const _OpeningWords({
    required this.mushaf,
    required this.surah,
    required this.ayah,
  });

  final Mushaf mushaf;
  final Surah surah;
  final AyahRef ayah;

  static const maxWords = 5;

  @override
  ConsumerState<_OpeningWords> createState() => _OpeningWordsState();
}

class _OpeningWordsState extends ConsumerState<_OpeningWords> {
  /// Each word with the page it is printed on; an ayah can run on to the
  /// next page, which has its own font.
  late final List<(int, MushafWord)> _words = _openingWords();
  final _fonts = <MushafPalette, Future<void>>{};

  /// The page fonts for the words, in the colours of the current theme.
  Future<void> _fontsIn(MushafPalette palette) =>
      _fonts[palette] ??= Future.wait([
        for (final p in {for (final (p, _) in _words) p})
          ref.read(pageFontsProvider).load(p, palette),
      ]);

  List<(int, MushafWord)> _openingWords() {
    final words = <(int, MushafWord)>[];
    final m = widget.mushaf;
    for (var p = m.pageOf(widget.ayah); p <= mushafPageCount; p++) {
      for (final w in m.page(p).words) {
        if (w.ayah != widget.ayah) continue;
        if (w.isAyahEnd || words.length == _OpeningWords.maxWords) {
          return words;
        }
        words.add((p, w));
      }
    }
    return words;
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final palette = mushafPalette(context);
    // One line, as long as the opening words are; shrunk if too wide.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: FutureBuilder(
        future: _fontsIn(palette),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done ||
              snapshot.hasError) {
            final words = widget.surah.ayahs[widget.ayah.ayah - 1].split(' ');
            return Text(
              words.take(_words.length).join(' '),
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 20, height: 1.7, color: color),
            );
          }
          return Text.rich(
            TextSpan(
              children: [
                for (final (p, w) in _words)
                  TextSpan(
                    text: '${w.glyph} ',
                    style: TextStyle(
                      fontFamily: PageFonts.familyFor(p, palette),
                    ),
                  ),
              ],
            ),
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 24, height: 1.6, color: color),
          );
        },
      ),
    );
  }
}
