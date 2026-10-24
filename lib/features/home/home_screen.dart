import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/quran_repository.dart';
import '../../data/reading_state.dart';
import '../../l10n/strings.dart';
import '../../settings/app_settings.dart';
import '../settings/settings_screen.dart';
import '../mushaf/go_to_dialog.dart';
import '../mushaf/mushaf_screen.dart';
import '../recitation/recitation_picker.dart';
import 'index_view.dart';

/// Index of the mushaf (see [IndexView]), plus "continue reading".
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mushaf = ref.watch(mushafProvider);
    final surahs = ref.watch(surahsProvider);
    final lastPage = ref.watch(lastPageProvider);
    final hideRecite = ref.watch(
      settingsProvider.select((s) => s.hideRecitationButton),
    );
    final s = S.of(context);

    return DefaultTabController(
      length: s.indexTabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.mushaf),
          actions: [
            if (!hideRecite)
              FilledButton.tonalIcon(
                icon: const Icon(Icons.mic),
                label: Text(s.recite),
                onPressed: () => showRecitationPicker(context),
              ),
            IconButton(
              tooltip: s.goTo,
              icon: const Icon(Icons.numbers),
              onPressed: () async {
                final target = await showGoToDialog(context);
                if (target != null && context.mounted) {
                  openMushaf(context, target.page, highlight: target.ayah);
                }
              },
            ),
            IconButton(
              tooltip: s.settings,
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => openSettings(context),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final t in s.indexTabs) Tab(text: t)],
          ),
        ),
        floatingActionButton: lastPage == null
            ? null
            : FloatingActionButton.extended(
                onPressed: () => openMushaf(context, lastPage),
                icon: const Icon(Icons.menu_book),
                label: Text(s.continueReading(lastPage)),
              ),
        body: switch ((mushaf, surahs)) {
          (AsyncData(value: final m), AsyncData(value: final all)) => IndexView(
            mushaf: m,
            surahs: all,
          ),
          (AsyncError(:final error), _) || (_, AsyncError(:final error)) =>
            Center(child: Text(s.loadMushafError(error))),
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
