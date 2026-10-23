import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/quran_repository.dart';
import '../../data/reading_state.dart';
import '../mushaf/mushaf_screen.dart';
import '../recitation/recitation_screen.dart';
import 'index_view.dart';

/// Index of the mushaf (see [IndexView]), plus "continue reading".
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mushaf = ref.watch(mushafProvider);
    final surahs = ref.watch(surahsProvider);
    final lastPage = ref.watch(lastPageProvider);

    return DefaultTabController(
      length: indexTabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المصحف'),
          actions: [
            IconButton(
              tooltip: 'تسميع الفاتحة',
              icon: const Icon(Icons.mic),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RecitationScreen(surahNumber: 1),
                ),
              ),
            ),
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
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final t in indexTabs) Tab(text: t)],
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
          (AsyncData(value: final m), AsyncData(value: final s)) => IndexView(
            mushaf: m,
            surahs: s,
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
