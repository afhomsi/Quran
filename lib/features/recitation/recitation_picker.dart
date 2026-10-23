import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mushaf_repository.dart';
import '../../data/quran_repository.dart';
import 'recitation_screen.dart';

/// Asks what to recite and opens the recitation screen.
///
/// From a mushaf [page], the page itself and its surahs come first.
Future<void> showRecitationPicker(BuildContext context, {int? page}) async {
  final screen = await showModalBottomSheet<Widget>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RecitationPicker(page: page),
  );
  if (screen != null && context.mounted) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _RecitationPicker extends ConsumerWidget {
  const _RecitationPicker({this.page});

  final int? page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surahs = ref.watch(surahsProvider).value;
    final mushaf = ref.watch(mushafProvider).value;
    if (surahs == null || mushaf == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final onPage = page == null
        ? const <int>[]
        : mushaf.page(page!).words.map((w) => w.ayah.surah).toSet().toList();

    void open(Widget screen) => Navigator.of(context).pop(screen);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: ListView(
        children: [
          if (page != null) ...[
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: Text('تسميع هذه الصفحة ($page)'),
              onTap: () => open(RecitationScreen.page(page!)),
            ),
            for (final s in onPage)
              ListTile(
                leading: const Icon(Icons.mic),
                title: Text('تسميع سورة ${surahs[s - 1].name} كاملة'),
                onTap: () => open(RecitationScreen.surah(s)),
              ),
            const Divider(),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'اختر سورة للتسميع',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final s in surahs)
            ListTile(
              leading: CircleAvatar(child: Text('${s.number}')),
              title: Text(s.name),
              subtitle: Text('${s.ayahCount} آية'),
              onTap: () => open(RecitationScreen.surah(s.number)),
            ),
        ],
      ),
    );
  }
}
