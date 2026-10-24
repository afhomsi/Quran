import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/marks.dart';
import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/quran_repository.dart';
import '../shell/navigation.dart';

/// "My notes": what the user wrote on ayat, newest first.
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    final surahs = ref.watch(surahsProvider).value;
    final mushaf = ref.watch(mushafProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('تعليقاتي')),
      body: surahs == null || mushaf == null
          ? const Center(child: CircularProgressIndicator())
          : notes.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'لا توجد تعليقات بعد.\nاضغط مطولًا على آية في المصحف '
                  'واختر "إضافة تعليق".',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: notes.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = notes.entries.toList().reversed.elementAt(i);
                final page = mushaf.pageOf(e.key);
                return ListTile(
                  title: Text(
                    '${surahs[e.key.surah - 1].name} · الآية ${e.key.ayah} '
                    '· الصفحة $page',
                  ),
                  subtitle: Text(e.value),
                  onTap: () => editNote(context, e.key),
                  trailing: IconButton(
                    tooltip: 'افتح في المصحف',
                    icon: const Icon(Icons.menu_book),
                    onPressed: () =>
                        openMushaf(context, page, highlight: e.key),
                  ),
                );
              },
            ),
    );
  }
}

/// Lets the user write, change or delete their note on [ayah].
Future<void> editNote(BuildContext context, AyahRef ayah) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final old = container.read(notesProvider)[ayah] ?? '';
  final text = await showDialog<String>(
    context: context,
    builder: (_) => _NoteDialog(initial: old),
  );
  if (text != null) container.read(notesProvider.notifier).set(ayah, text);
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.initial});

  final String initial;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('تعليق على الآية'),
    content: TextField(
      controller: _text,
      autofocus: true,
      minLines: 3,
      maxLines: 8,
      decoration: const InputDecoration(
        hintText: 'اكتب تعليقك أو فائدة عن الآية',
        border: OutlineInputBorder(),
      ),
    ),
    actions: [
      if (widget.initial.isNotEmpty)
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: const Text('حذف'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _text.text),
        child: const Text('حفظ'),
      ),
    ],
  );
}
