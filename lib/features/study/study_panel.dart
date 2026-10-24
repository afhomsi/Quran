import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/ayah_audio.dart';
import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/quran_models.dart';
import '../../data/quran_repository.dart';
import '../../data/study.dart';
import '../../data/tajweed.dart';
import '../../l10n/strings.dart';
import '../audio/repeat_sheet.dart';
import '../notes/notes_screen.dart';
import 'ayah_tools.dart';
import 'tajweed_view.dart';
import 'study_content.dart';
import 'word_card.dart';

/// Opens the study panel on [ayah] (and the word at [word], if given) at
/// [part]. Gives the ayah the reader ended on, so the mushaf can follow.
Future<AyahRef?> showStudyPanel(
  BuildContext context, {
  required AyahRef ayah,
  int word = 1,
  StudyPart part = StudyPart.ayah,
}) => showModalBottomSheet<AyahRef>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (_) => StudyPanel(ayah: ayah, word: word, part: part),
);

/// The study panel: what is known about the surah, the page, the ayah and
/// the word, each in its own tabs, with the ayah's tools at the bottom.
class StudyPanel extends ConsumerStatefulWidget {
  const StudyPanel({
    super.key,
    required this.ayah,
    required this.word,
    required this.part,
  });

  final AyahRef ayah;
  final int word;
  final StudyPart part;

  @override
  ConsumerState<StudyPanel> createState() => _StudyPanelState();
}

class _StudyPanelState extends ConsumerState<StudyPanel> {
  late AyahRef _ayah = widget.ayah;
  late int _word = widget.word;
  late StudyPart _part = widget.part;
  bool _full = false;

  /// The tab chosen in each part, and the book chosen in each tab.
  final _tabs = <StudyPart, StudyTab>{};
  final _books = <StudyTab, StudyBook>{};

  StudyTab get _tab => _tabs[_part] ?? StudyTab.of(_part).first;

  /// Whether the reader picks the book of the tab. On a word, the books
  /// are tried in turn instead, as each speaks of only some words.
  bool get _choosesBook => _tab.books.length > 1 && _part != StudyPart.word;

  StudyRequest get _request => (
    tab: _tab,
    // Both books of qira'at are shown together until one is chosen.
    book: _choosesBook && _tab != StudyTab.qiraat
        ? _books[_tab] ?? _tab.books.first
        : _books[_tab],
    ayah: _ayah,
    word: _word,
  );

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final colors = Theme.of(context).colorScheme;
    final surahs = ref.watch(surahsProvider).value;
    final mushaf = ref.watch(mushafProvider).value;
    if (surahs == null || mushaf == null) return const SizedBox();
    final height = MediaQuery.sizeOf(context).height;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _ayah);
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, _full ? 0 : height * 0.12, 12, 8),
        child: Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                child: _Segments(
                  labels: [
                    t.surahSciences,
                    t.studyPage,
                    t.studyAyah,
                    t.studyWord,
                  ],
                  selected: _part.index,
                  onSelected: (i) =>
                      setState(() => _part = StudyPart.values[i]),
                ),
              ),
              _TabStrip(
                labels: [for (final tab in StudyTab.of(_part)) tab.label(t)],
                selected: StudyTab.of(_part).indexOf(_tab),
                onSelected: (i) =>
                    setState(() => _tabs[_part] = StudyTab.of(_part)[i]),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  key: ValueKey(_request),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  children: [
                    if (_choosesBook) _bookChips(t),
                    ..._header(context, surahs),
                    if (_tab == StudyTab.stats)
                      _Stats(
                        rows: surahStats(t, surahs[_ayah.surah - 1], mushaf),
                      )
                    else
                      StudyContentView(request: _request),
                  ],
                ),
              ),
              _toolbar(t, surahs, mushaf),
              _actions(t, surahs, mushaf),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bookChips(S t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final book in _tab.books)
          ChoiceChip(
            label: Text(t.bookName(book)),
            selected: _request.book == book,
            showCheckmark: false,
            onSelected: (_) => setState(() => _books[_tab] = book),
          ),
      ],
    ),
  );

  /// The ayah above its tafsir, and the word above what is said on it.
  List<Widget> _header(BuildContext context, List<Surah> surahs) {
    if (_part == StudyPart.surah || _part == StudyPart.page) return const [];
    final surah = surahs[_ayah.surah - 1];
    final words = ayahWords(surah.ayahs[_ayah.ayah - 1]);
    final quranColor = studyQuranColor(context);
    final colors = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: 20,
      height: 1.9,
      color: _part == StudyPart.word ? colors.onSurface : quranColor,
    );
    final t = S.of(context);
    return [
      Text.rich(
        TextSpan(
          style: style,
          children: [
            const TextSpan(text: '﴿'),
            for (final (i, w) in words.indexed) ...[
              TextSpan(
                text: w,
                style: _part == StudyPart.word && i == _word - 1
                    ? TextStyle(color: quranColor)
                    : null,
              ),
              if (i < words.length - 1) const TextSpan(text: ' '),
            ],
            const TextSpan(text: '﴾ '),
            TextSpan(
              text: '[${t.surahName(surah)} – ${t.n(_ayah.ayah)}]',
              style: TextStyle(fontSize: 15, color: colors.tertiary),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
      ),
      if (_part == StudyPart.word)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            wordAt(surah.ayahs[_ayah.ayah - 1], _word),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 34, color: colors.primary),
          ),
        )
      else
        const SizedBox(height: 16),
    ];
  }

  Widget _toolbar(S t, List<Surah> surahs, Mushaf mushaf) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: _full ? t.shrink : t.expand,
            icon: Icon(
              _full
                  ? Icons.close_fullscreen_rounded
                  : Icons.open_in_full_rounded,
            ),
            onPressed: () => setState(() => _full = !_full),
          ),
          const Spacer(),
          IconButton(
            tooltip: t.previous,
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => _step(-1, surahs, mushaf),
          ),
          IconButton(
            tooltip: t.next,
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => _step(1, surahs, mushaf),
          ),
          const Spacer(),
          IconButton(
            tooltip: t.share,
            icon: const Icon(Icons.share_rounded),
            onPressed: () => _share(t, surahs, mushaf),
          ),
          IconButton(
            tooltip: t.close,
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context, _ayah),
          ),
        ],
      ),
    );
  }

  /// Moves to the next or previous surah, page, ayah or word, following
  /// the part shown. In a right-to-left layout the arrows swap sides, so
  /// "next" stays the one pointing forward in reading.
  void _step(int by, List<Surah> surahs, Mushaf mushaf) {
    AyahRef? ayahAfter(AyahRef a) {
      if (by > 0) {
        if (a.ayah < surahs[a.surah - 1].ayahCount) {
          return AyahRef(a.surah, a.ayah + 1);
        }
        return a.surah < 114 ? AyahRef(a.surah + 1, 1) : null;
      }
      if (a.ayah > 1) return AyahRef(a.surah, a.ayah - 1);
      return a.surah > 1
          ? AyahRef(a.surah - 1, surahs[a.surah - 2].ayahCount)
          : null;
    }

    setState(() {
      switch (_part) {
        case StudyPart.surah:
          final s = _ayah.surah + by;
          if (s >= 1 && s <= 114) _ayah = AyahRef(s, 1);
        case StudyPart.page:
          final p = mushaf.pageOf(_ayah) + by;
          if (p >= 1 && p <= mushafPageCount) _ayah = mushaf.page(p).firstAyah;
        case StudyPart.ayah:
          _ayah = ayahAfter(_ayah) ?? _ayah;
        case StudyPart.word:
          final count = ayahWords(surahs[_ayah.surah - 1].ayahs[_ayah.ayah - 1])
              .length;
          final w = _word + by;
          if (w >= 1 && w <= count) {
            _word = w;
          } else if (ayahAfter(_ayah) case final next?) {
            _ayah = next;
            _word = by > 0
                ? 1
                : ayahWords(surahs[next.surah - 1].ayahs[next.ayah - 1]).length;
          }
      }
      if (_part != StudyPart.word) _word = 1;
    });
  }

  Future<void> _share(S t, List<Surah> surahs, Mushaf mushaf) async {
    final surah = surahs[_ayah.surah - 1];
    final ayahText = surah.ayahs[_ayah.ayah - 1];
    final word = _part == StudyPart.word ? _word : null;
    final String body;
    if (_tab == StudyTab.stats) {
      body = [
        for (final (label, value) in surahStats(t, surah, mushaf))
          '$label: $value',
      ].join('\n');
    } else if (_tab.isTajweed) {
      final map = await ref.read(tajweedProvider.future);
      body = tajweedText(t, map, _ayah, word, ayahText);
    } else {
      final sections = await ref.read(studyContentProvider(_request).future);
      body = sections.join('\n\n');
    }
    final title = switch (_part) {
      StudyPart.surah => t.surahName(surah),
      StudyPart.page => '${t.pageWord} ${t.n(mushaf.pageOf(_ayah))}',
      StudyPart.ayah =>
        '﴿$ayahText﴾ [${t.surahName(surah)} – ${t.n(_ayah.ayah)}]',
      StudyPart.word =>
        '${wordAt(ayahText, _word)}\n'
            '[${t.surahName(surah)} – ${t.n(_ayah.ayah)}]',
    };
    final book = _request.book ?? _tab.books.firstOrNull;
    if (!mounted) return;
    showShareSheet(
      context,
      ShareContent(
        title: title,
        label: _tab.label(t),
        body: body,
        source: book == null ? null : t.source(book),
        quranTitle: _part == StudyPart.ayah || _part == StudyPart.word,
      ),
    );
  }

  /// The ayah's tools: listen, listen settings, place markers, a note and
  /// a color. The surah and the page only listen.
  Widget _actions(S t, List<Surah> surahs, Mushaf mushaf) {
    final colors = Theme.of(context).colorScheme;
    final surah = surahs[_ayah.surah - 1];
    final page = mushaf.page(mushaf.pageOf(_ayah));
    final (from, to) = switch (_part) {
      StudyPart.surah => (
        AyahRef(surah.number, 1),
        AyahRef(surah.number, surah.ayahCount),
      ),
      StudyPart.page => (page.firstAyah, page.words.last.ayah),
      _ => (_ayah, _ayah),
    };
    final onAyah = _part == StudyPart.ayah || _part == StudyPart.word;
    final word = wordAt(surah.ayahs[_ayah.ayah - 1], _word);
    Widget item(IconData icon, String label, [VoidCallback? onTap]) =>
        _BarItem(icon: icon, label: label, onTap: onTap);
    return Material(
      color: colors.primary,
      child: SafeArea(
        top: false,
        child: IconTheme(
          data: IconThemeData(color: colors.onPrimary),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: colors.onPrimary),
            child: Row(
              children: [
                item(Icons.play_arrow_rounded, t.listen, () {
                  ref.read(audioProvider.notifier).playFrom(from);
                }),
                item(Icons.tune_rounded, t.settings, () {
                  showRepeatSheet(context, from: from, to: to);
                }),
                if (_part != StudyPart.surah)
                  Expanded(
                    child: MarkerMenuButton(
                      ayah: onAyah ? _ayah : page.firstAyah,
                      child: _BarLabel(
                        icon: Icons.bookmarks_rounded,
                        label: t.bookmarkAction,
                      ),
                    ),
                  ),
                if (onAyah) ...[
                  item(Icons.chat_bubble_outline_rounded, t.comment, () {
                    editNote(
                      context,
                      _ayah,
                      word: _part == StudyPart.word ? word : null,
                    );
                  }),
                  item(Icons.format_color_fill_rounded, t.colorAction, () {
                    showColorSheet(context, _ayah);
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: _BarLabel(icon: icon, label: label),
    ),
  );
}

class _BarLabel extends StatelessWidget {
  const _BarLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 26),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}

/// The four parts, as a segmented bar with the chosen one raised.
class _Segments extends StatelessWidget {
  const _Segments({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final (i, label) in labels.indexed)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == selected ? colors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: i == selected
                        ? const [
                            BoxShadow(blurRadius: 2, color: Colors.black12),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: i == selected ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The tabs of a part, scrolling sideways, the chosen one underlined.
class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final (i, label) in labels.indexed)
            InkWell(
              onTap: () => onSelected(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: i == selected
                          ? colors.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    color: colors.primary,
                    fontWeight: i == selected ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final (label, value) in rows)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(child: Text(label)),
                Text(
                  value,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
