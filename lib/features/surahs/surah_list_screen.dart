import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/quran_repository.dart';
import '../reader/surah_reader_screen.dart';

class SurahListScreen extends ConsumerWidget {
  const SurahListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surahs = ref.watch(surahsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('السور')),
      body: surahs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('تعذر تحميل المصحف\n$e')),
        data: (list) => ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final s = list[i];
            return ListTile(
              leading: CircleAvatar(child: Text('${s.number}')),
              title: Text(s.name),
              subtitle: Text(
                '${s.isMeccan ? 'مكية' : 'مدنية'} · ${s.ayahCount} آية',
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SurahReaderScreen(surah: s)),
              ),
            );
          },
        ),
      ),
    );
  }
}
