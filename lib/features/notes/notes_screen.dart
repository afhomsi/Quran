import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/marks.dart';
import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/quran_repository.dart';
import '../../l10n/strings.dart';
import '../shell/navigation.dart';

/// "My notes": what the user wrote on ayat, newest first.
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider).entries.toList().reversed.toList();
    final surahs = ref.watch(surahsProvider).value;
    final mushaf = ref.watch(mushafProvider).value;
    final t = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.myNotes)),
      body: surahs == null || mushaf == null
          ? const Center(child: CircularProgressIndicator())
          : notes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(t.noNotes, textAlign: TextAlign.center),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: notes.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final MapEntry(key: ayah, value: note) = notes[i];
                final page = mushaf.pageOf(ayah);
                return ListTile(
                  title: Text(
                    t.ayahOnPage(surahs[ayah.surah - 1], ayah.ayah, page),
                  ),
                  subtitle: Text(note),
                  onTap: () => editNote(context, ayah),
                  trailing: IconButton(
                    tooltip: t.openInMushaf,
                    icon: const Icon(Icons.menu_book),
                    onPressed: () => openMushaf(context, page, highlight: ayah),
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
  Widget build(BuildContext context) {
    final t = S.of(context);
    return AlertDialog(
      title: Text(t.noteOnAyah),
      content: TextField(
        controller: _text,
        autofocus: true,
        minLines: 3,
        maxLines: 8,
        decoration: InputDecoration(
          hintText: t.noteHint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        if (widget.initial.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(t.delete),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _text.text),
          child: Text(t.save),
        ),
      ],
    );
  }
}
