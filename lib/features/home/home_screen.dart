import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/quran_models.dart';
import '../../data/quran_repository.dart';
import '../../data/reading_state.dart';
import '../mushaf/mushaf_screen.dart';

/// Index of the mushaf: surahs, juz and bookmarks, plus "continue reading".
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mushaf = ref.watch(mushafProvider);
    final surahs = ref.watch(surahsProvider);
    final lastPage = ref.watch(lastPageProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المصحف'),
          actions: [
            IconButton(
              tooltip: 'انتقال إلى صفحة',
              icon: const Icon(Icons.numbers),
              onPressed: () async {
                final page = await showDialog<int>(
                  context: context,
                  builder: (_) => const GoToPageDialog(),
                );
                if (page != null && context.mounted) openMushaf(context, page);
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'السور'),
              Tab(text: 'الأجزاء'),
              Tab(text: 'العلامات'),
            ],
          ),
        ),
        floatingActionButton: lastPage == null
            ? null
            : FloatingActionButton.extended(
                onPressed: () => openMushaf(context, lastPage),
                icon: const Icon(Icons.menu_book),
                label: Text('متابعة القراءة · صفحة $lastPage'),
              ),
        body: switch ((mushaf, surahs)) {
          (AsyncData(value: final m), AsyncData(value: final s)) => TabBarView(
            children: [
              _SurahList(mushaf: m, surahs: s),
              _JuzList(mushaf: m, surahs: s),
              _BookmarkList(mushaf: m, surahs: s),
            ],
          ),
          (AsyncError(:final error), _) || (_, AsyncError(:final error)) =>
            Center(child: Text('تعذر تحميل المصحف\n$error')),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

void openMushaf(BuildContext context, int page, {AyahRef? highlight}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => MushafScreen(initialPage: page, highlight: highlight),
    ),
  );
}

class _SurahList extends StatelessWidget {
  const _SurahList({required this.mushaf, required this.surahs});

  final Mushaf mushaf;
  final List<Surah> surahs;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: surahs.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final s = surahs[i];
        final page = mushaf.surahStartPage(s.number);
        return ListTile(
          leading: CircleAvatar(child: Text('${s.number}')),
          title: Text(s.name),
          subtitle: Text(
            '${s.isMeccan ? 'مكية' : 'مدنية'} · ${s.ayahCount} آية',
          ),
          trailing: Text('$page'),
          onTap: () => openMushaf(context, page),
        );
      },
    );
  }
}

class _JuzList extends StatelessWidget {
  const _JuzList({required this.mushaf, required this.surahs});

  final Mushaf mushaf;
  final List<Surah> surahs;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: juzStarts.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final start = juzStarts[i];
        final page = mushaf.juzStartPage(i + 1);
        return ListTile(
          leading: CircleAvatar(child: Text('${i + 1}')),
          title: Text('الجزء ${i + 1}'),
          subtitle: Text('${surahs[start.surah - 1].name} · آية ${start.ayah}'),
          trailing: Text('$page'),
          onTap: () => openMushaf(context, page),
        );
      },
    );
  }
}

class _BookmarkList extends ConsumerWidget {
  const _BookmarkList({required this.mushaf, required this.surahs});

  final Mushaf mushaf;
  final List<Surah> surahs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksProvider);
    if (bookmarks.isEmpty) {
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
    return ListView.separated(
      itemCount: bookmarks.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final b = bookmarks[bookmarks.length - 1 - i];
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
