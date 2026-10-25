import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mushaf_repository.dart';
import '../../data/quran_repository.dart';
import '../../data/reading_state.dart';
import '../../l10n/strings.dart';
import '../../settings/app_settings.dart';
import '../settings/settings_screen.dart';
import '../../data/mushaf_models.dart';
import '../search/search_screen.dart';
import '../shell/navigation.dart';
import '../recitation/recitation_picker.dart';
import 'index_view.dart';

export '../shell/navigation.dart' show openMushaf;

/// The index tab: the mushaf's index (see [IndexView]), plus "continue
/// reading" and "continue reciting".
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mushaf = ref.watch(mushafProvider);
    final surahs = ref.watch(surahsProvider);
    final lastPage = ref.watch(lastPageProvider);
    final resumeFrom = ref.watch(lastRecitationProvider);
    final hideRecite = ref.watch(
      settingsProvider.select((s) => s.hideRecitationButton),
    );
    final s = S.of(context);

    return DefaultTabController(
      length: s.indexTabs.length,
      // Shows the tab the mushaf's running header asks for.
      child: Consumer(
        builder: (context, ref, child) {
          ref.listen(indexTabProvider, (_, request) {
            if (request != null) {
              DefaultTabController.of(context).animateTo(request.tab);
            }
          });
          return child!;
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(s.tabIndex),
            centerTitle: true,
            actions: [
              if (!hideRecite)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.mic_rounded),
                  label: Text(s.recite),
                  onPressed: () => showRecitationPicker(context),
                ),
              IconButton(
                tooltip: s.searchQuran,
                icon: const Icon(Icons.search_rounded),
                onPressed: () async {
                  final ayah = await Navigator.of(context).push<AyahRef>(
                    MaterialPageRoute(
                      builder: (_) => const QuranSearchScreen(),
                    ),
                  );
                  final m = mushaf.value;
                  if (ayah != null && m != null && context.mounted) {
                    openMushaf(context, m.pageOf(ayah), highlight: ayah);
                  }
                },
              ),
              IconButton(
                tooltip: s.settings,
                icon: const Icon(Icons.settings_rounded),
                onPressed: () => openSettings(context),
              ),
            ],
            bottom: TabBar(
              labelStyle: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              unselectedLabelStyle: Theme.of(context).textTheme.titleMedium,
              tabs: [for (final t in s.indexTabs) Tab(text: t)],
            ),
          ),
          // Continue reading, and continue reciting below it.
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 12,
            children: [
              if (resumeFrom != null && !hideRecite)
                if (surahs.value case final all?)
                  FloatingActionButton.extended(
                    heroTag: 'continueRecitation',
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .secondaryContainer,
                    foregroundColor: Theme.of(context)
                        .colorScheme
                        .onSecondaryContainer,
                    onPressed: () => resumeRecitation(context),
                    icon: const Icon(Icons.mic_rounded),
                    label: Text(
                      s.continueRecitation(
                        all[resumeFrom.surah - 1],
                        resumeFrom.ayah,
                      ),
                    ),
                  ),
              if (lastPage != null)
                FloatingActionButton.extended(
                  heroTag: 'continueReading',
                  onPressed: () => openMushaf(context, lastPage),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: Text(s.continueReading(lastPage)),
                ),
            ],
          ),
          body: switch ((mushaf, surahs)) {
            (AsyncData(value: final m), AsyncData(value: final all)) =>
              IndexView(mushaf: m, surahs: all, currentPage: lastPage),
            (AsyncError(:final error), _) || (_, AsyncError(:final error)) =>
              Center(child: Text(s.loadMushafError(error))),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}
