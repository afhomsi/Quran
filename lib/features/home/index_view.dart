import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/arabic_search.dart';
import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/quarters.dart';
import '../../data/quran_models.dart';
import '../../data/reading_state.dart';
import '../../l10n/strings.dart';
import 'home_screen.dart';

/// Searchable index: one list per entry of [S.indexTabs], filtered by the
/// search box. Tapping an entry opens the mushaf at its page.
class IndexView extends StatefulWidget {
  const IndexView({super.key, required this.mushaf, required this.surahs});

  final Mushaf mushaf;
  final List<Surah> surahs;

  @override
  State<IndexView> createState() => _IndexViewState();
}

class _IndexViewState extends State<IndexView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text;
    final m = widget.mushaf;
    final s = widget.surahs;
    final t = S.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: t.searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: t.clearSearch,
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(_search.clear),
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            children: [
              _surahs(t, m, s, query),
              _juz(t, m, s, query),
              _quarters(t, m, s, query),
              _pages(t, m, s, query),
              _BookmarkList(mushaf: m, surahs: s, query: query),
            ],
          ),
        ),
      ],
    );
  }

  Widget _surahs(S t, Mushaf m, List<Surah> surahs, String query) =>
      _EntryList([
        for (final s in surahs)
          if (searchMatches(
            query,
            numbers: [s.number],
            texts: [s.name, s.transliteration],
          ))
            _Entry(
              number: s.number,
              title: t.surahName(s),
              subtitle:
                  '${s.isMeccan ? t.meccan : t.medinan} · '
                  '${t.ayahCount(s.ayahCount)}',
              page: m.surahStartPage(s.number),
            ),
      ]);

  Widget _juz(S t, Mushaf m, List<Surah> surahs, String query) => _EntryList([
    for (var j = 1; j <= juzStarts.length; j++)
      if (searchMatches(
        query,
        numbers: [j],
        texts: _surahTexts(surahs[juzStarts[j - 1].surah - 1]),
      ))
        _Entry(
          number: j,
          title: t.juz(j),
          subtitle: _ayahLabel(t, surahs, juzStarts[j - 1]),
          page: m.juzStartPage(j),
        ),
  ]);

  Widget _quarters(S t, Mushaf m, List<Surah> surahs, String query) =>
      _EntryList([
        for (var r = 1; r <= rubStarts.length; r++)
          if (searchMatches(
            query,
            numbers: [(r - 1) ~/ 4 + 1],
            texts: _surahTexts(surahs[rubStarts[r - 1].surah - 1]),
          ))
            _Entry(
              number: (r - 1) ~/ 4 + 1,
              title: t.rubTitle(r),
              subtitle: _ayahLabel(t, surahs, rubStarts[r - 1], withText: true),
              page: m.rubStartPage(r),
            ),
      ]);

  Widget _pages(S t, Mushaf m, List<Surah> surahs, String query) => _EntryList([
    for (final p in m.pages)
      if (searchMatches(
        query,
        numbers: [p.number],
        texts: _surahTexts(surahs[p.firstAyah.surah - 1]),
      ))
        _Entry(
          number: p.number,
          title: t.page(p.number),
          subtitle:
              '${_ayahLabel(t, surahs, p.firstAyah)} · '
              '${t.juz(m.juzOfPage(p.number))}',
          page: p.number,
        ),
  ]);
}

/// A surah's names to search in: Arabic and in Latin letters.
List<String> _surahTexts(Surah s) => [s.name, s.transliteration];

String _ayahLabel(S t, List<Surah> surahs, AyahRef a, {bool withText = false}) {
  final surah = surahs[a.surah - 1];
  final label = t.ayahLabel(surah, a.ayah);
  if (!withText) return label;
  final words = surah.ayahs[a.ayah - 1].split(' ');
  final start = words.take(4).join(' ');
  return '$label\n${words.length > 4 ? '$start…' : start}';
}

class _Entry {
  const _Entry({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  final int number;
  final String title;
  final String subtitle;
  final int page;
}

class _EntryList extends StatelessWidget {
  const _EntryList(this.entries);

  final List<_Entry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const _NoResults();
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = entries[i];
        final t = S.of(context);
        return ListTile(
          leading: CircleAvatar(child: Text(t.n(e.number))),
          title: Text(e.title),
          subtitle: Text(e.subtitle),
          trailing: Text(t.n(e.page)),
          onTap: () => openMushaf(context, e.page),
        );
      },
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) =>
      Center(child: Text(S.of(context).noResults));
}

class _BookmarkList extends ConsumerWidget {
  const _BookmarkList({
    required this.mushaf,
    required this.surahs,
    required this.query,
  });

  final Mushaf mushaf;
  final List<Surah> surahs;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(bookmarksProvider);
    final t = S.of(context);
    if (all.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t.noBookmarks, textAlign: TextAlign.center),
        ),
      );
    }
    final bookmarks = [
      for (final b in all.reversed)
        if (searchMatches(
          query,
          numbers: [mushaf.pageOf(b)],
          texts: _surahTexts(surahs[b.surah - 1]),
        ))
          b,
    ];
    if (bookmarks.isEmpty) return const _NoResults();
    return ListView.separated(
      itemCount: bookmarks.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final b = bookmarks[i];
        final page = mushaf.pageOf(b);
        return ListTile(
          leading: const Icon(Icons.bookmark),
          title: Text(t.ayahLabel(surahs[b.surah - 1], b.ayah)),
          trailing: Text(t.n(page)),
          onTap: () => openMushaf(context, page, highlight: b),
          onLongPress: () => ref.read(bookmarksProvider.notifier).toggle(b),
        );
      },
    );
  }
}
