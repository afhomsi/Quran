import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/arabic_search.dart';
import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/quarters.dart';
import '../../data/quran_models.dart';
import '../../data/reading_state.dart';
import 'home_screen.dart';

/// The tabs of the index, in order. [IndexView] shows one list per tab.
const indexTabs = ['السور', 'الأجزاء', 'الأرباع', 'الصفحات', 'العلامات'];

/// Searchable index: one list per entry of [indexTabs], filtered by the
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'ابحث باسم السورة أو بالرقم',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
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
              _surahs(m, s, query),
              _juz(m, s, query),
              _quarters(m, s, query),
              _pages(m, s, query),
              _BookmarkList(mushaf: m, surahs: s, query: query),
            ],
          ),
        ),
      ],
    );
  }

  Widget _surahs(Mushaf m, List<Surah> surahs, String query) => _EntryList([
    for (final s in surahs)
      if (searchMatches(query, numbers: [s.number], texts: [s.name]))
        _Entry(
          number: s.number,
          title: s.name,
          subtitle: '${s.isMeccan ? 'مكية' : 'مدنية'} · ${s.ayahCount} آية',
          page: m.surahStartPage(s.number),
        ),
  ]);

  Widget _juz(Mushaf m, List<Surah> surahs, String query) => _EntryList([
    for (var j = 1; j <= juzStarts.length; j++)
      if (searchMatches(
        query,
        numbers: [j],
        texts: [surahs[juzStarts[j - 1].surah - 1].name],
      ))
        _Entry(
          number: j,
          title: 'الجزء $j',
          subtitle: _ayahLabel(surahs, juzStarts[j - 1]),
          page: m.juzStartPage(j),
        ),
  ]);

  Widget _quarters(Mushaf m, List<Surah> surahs, String query) => _EntryList([
    for (var r = 1; r <= rubStarts.length; r++)
      if (searchMatches(
        query,
        numbers: [(r - 1) ~/ 4 + 1],
        texts: [surahs[rubStarts[r - 1].surah - 1].name],
      ))
        _Entry(
          number: (r - 1) ~/ 4 + 1,
          title: rubTitle(r),
          subtitle: _ayahLabel(surahs, rubStarts[r - 1], withText: true),
          page: m.rubStartPage(r),
        ),
  ]);

  Widget _pages(Mushaf m, List<Surah> surahs, String query) => _EntryList([
    for (final p in m.pages)
      if (searchMatches(
        query,
        numbers: [p.number],
        texts: [surahs[p.firstAyah.surah - 1].name],
      ))
        _Entry(
          number: p.number,
          title: 'الصفحة ${p.number}',
          subtitle:
              '${_ayahLabel(surahs, p.firstAyah)} · '
              'الجزء ${m.juzOfPage(p.number)}',
          page: p.number,
        ),
  ]);
}

/// "الحزب 3", "ربع الحزب 3", "نصف الحزب 3" or "ثلاثة أرباع الحزب 3".
String rubTitle(int rub) {
  final hizb = (rub - 1) ~/ 4 + 1;
  const parts = ['', 'ربع ', 'نصف ', 'ثلاثة أرباع '];
  return '${parts[(rub - 1) % 4]}الحزب $hizb';
}

String _ayahLabel(List<Surah> surahs, AyahRef a, {bool withText = false}) {
  final surah = surahs[a.surah - 1];
  final label = '${surah.name} · آية ${a.ayah}';
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
        return ListTile(
          leading: CircleAvatar(child: Text('${e.number}')),
          title: Text(e.title),
          subtitle: Text(e.subtitle),
          trailing: Text('${e.page}'),
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
      const Center(child: Text('لا توجد نتائج'));
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
    if (all.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد علامات بعد.\nاضغط مطولًا على أي آية في المصحف لإضافة علامة.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final bookmarks = [
      for (final b in all.reversed)
        if (searchMatches(
          query,
          numbers: [mushaf.pageOf(b)],
          texts: [surahs[b.surah - 1].name],
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
          title: Text('${surahs[b.surah - 1].name} · آية ${b.ayah}'),
          trailing: Text('$page'),
          onTap: () => openMushaf(context, page, highlight: b),
          onLongPress: () => ref.read(bookmarksProvider.notifier).toggle(b),
        );
      },
    );
  }
}
