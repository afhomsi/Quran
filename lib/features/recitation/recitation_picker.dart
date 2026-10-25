import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mushaf_repository.dart';
import '../../data/quran_repository.dart';
import '../../data/reading_state.dart';
import '../../l10n/strings.dart';
import '../../recitation/page_recitation.dart';
import '../shell/navigation.dart';
import 'recitation_screen.dart';

/// Opens the mushaf where reciting last stopped and goes on reciting
/// there, like "continue reading".
void resumeRecitation(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  final from = container.read(lastRecitationProvider);
  final mushaf = container.read(mushafProvider).value;
  if (from == null || mushaf == null) return;
  openMushaf(context, mushaf.pageOf(from));
  container.read(pageRecitationProvider.notifier).resume();
}

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
    final t = S.of(context);
    final resumeFrom = ref.watch(lastRecitationProvider);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: ListView(
        children: [
          if (resumeFrom != null) ...[
            ListTile(
              leading: Icon(
                Icons.play_circle_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                t.continueRecitation(
                  surahs[resumeFrom.surah - 1],
                  resumeFrom.ayah,
                ),
              ),
              onTap: () => resumeRecitation(context),
            ),
            const Divider(),
          ],
          if (page != null) ...[
            ListTile(
              leading: const Icon(Icons.menu_book_rounded),
              title: Text(t.recitePage(page!)),
              onTap: () => open(RecitationScreen.page(page!)),
            ),
            for (final s in onPage)
              ListTile(
                leading: const Icon(Icons.mic_rounded),
                title: Text(t.reciteWholeSurah(surahs[s - 1])),
                onTap: () => open(RecitationScreen.surah(s)),
              ),
            const Divider(),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              t.chooseSurahToRecite,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final s in surahs)
            ListTile(
              leading: CircleAvatar(child: Text(t.n(s.number))),
              title: Text(t.surahName(s)),
              subtitle: Text(t.ayahCount(s.ayahCount)),
              onTap: () => open(RecitationScreen.surah(s.number)),
            ),
        ],
      ),
    );
  }
}
