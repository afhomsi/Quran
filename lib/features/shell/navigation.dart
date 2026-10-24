import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mushaf_models.dart';
import '../../l10n/strings.dart';

/// The tabs of the bottom bar, in order.
enum AppTab { mushaf, khatma, quranIndex, bookmarks, more }

/// The tab shown in the bottom bar.
class AppTabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.mushaf;

  void select(AppTab tab) => state = tab;
}

final appTabProvider = NotifierProvider<AppTabNotifier, AppTab>(
  AppTabNotifier.new,
);

/// Whether the mushaf shows its bars (the top bar, the page buttons and the
/// bottom tabs) over the page. A tap on the page shows or hides them, so
/// the page can be read on its own.
class MushafChromeNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;

  void set(bool shown) => state = shown;
}

final mushafChromeProvider = NotifierProvider<MushafChromeNotifier, bool>(
  MushafChromeNotifier.new,
);

/// Whether the mushaf's page navigator (thumbnails and a slider) is open.
class PageNavigatorNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool open) => state = open;
}

final pageNavigatorProvider = NotifierProvider<PageNavigatorNotifier, bool>(
  PageNavigatorNotifier.new,
);

/// A request to show one tab of the index (0 surah, 1 juz, 2 page,
/// 3 quarter). Each request is a new object, so the same tab can be asked
/// for twice.
class IndexTabRequest {
  IndexTabRequest(this.tab);

  final int tab;
}

class IndexTabNotifier extends Notifier<IndexTabRequest?> {
  @override
  IndexTabRequest? build() => null;

  void show(int tab) => state = IndexTabRequest(tab);
}

final indexTabProvider = NotifierProvider<IndexTabNotifier, IndexTabRequest?>(
  IndexTabNotifier.new,
);

/// Opens the index on [tab], e.g. from the running header of the mushaf.
void openIndex(BuildContext context, int tab) {
  final container = ProviderScope.containerOf(context, listen: false);
  container.read(indexTabProvider.notifier).show(tab);
  container.read(appTabProvider.notifier).select(AppTab.quranIndex);
}

/// The bottom tabs. The mushaf draws them over the page itself, so that
/// hiding them does not move the page.
class AppNavigationBar extends ConsumerWidget {
  const AppNavigationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(appTabProvider);
    final t = S.of(context);
    return NavigationBar(
      selectedIndex: tab.index,
      onDestinationSelected: (i) {
        // Tapping the mushaf tab while reading opens the page navigator,
        // as its small arrow shows.
        if (tab == AppTab.mushaf && AppTab.values[i] == AppTab.mushaf) {
          ref.read(pageNavigatorProvider.notifier).set(true);
          ref.read(mushafChromeProvider.notifier).set(false);
          return;
        }
        ref.read(appTabProvider.notifier).select(AppTab.values[i]);
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.import_contacts_rounded),
          selectedIcon: Badge(
            label: const Icon(Icons.keyboard_arrow_up_rounded, size: 12),
            padding: EdgeInsets.zero,
            backgroundColor: Theme.of(context).colorScheme.secondary,
            textColor: Theme.of(context).colorScheme.onSecondary,
            child: const Icon(Icons.import_contacts_rounded),
          ),
          label: t.tabRead,
        ),
        NavigationDestination(
          icon: const Icon(Icons.event_note_outlined),
          selectedIcon: const Icon(Icons.event_note_rounded),
          label: t.tabKhatma,
        ),
        NavigationDestination(
          icon: const Icon(Icons.format_list_numbered_rtl_rounded),
          label: t.tabIndex,
        ),
        NavigationDestination(
          icon: const Icon(Icons.bookmark_border_rounded),
          selectedIcon: const Icon(Icons.bookmark_rounded),
          label: t.tabBookmarks,
        ),
        NavigationDestination(
          icon: const Icon(Icons.grid_view_rounded),
          label: t.tabMore,
        ),
      ],
    );
  }
}

/// A request to show [page] in the mushaf tab, optionally highlighting an
/// ayah. Each request is a new object, so asking for the same page twice
/// still jumps there.
class MushafJump {
  MushafJump(this.page, {this.highlight});

  final int page;
  final AyahRef? highlight;
}

class MushafJumpNotifier extends Notifier<MushafJump?> {
  @override
  MushafJump? build() => null;

  void jump(int page, {AyahRef? highlight}) =>
      state = MushafJump(page, highlight: highlight);
}

final mushafJumpProvider = NotifierProvider<MushafJumpNotifier, MushafJump?>(
  MushafJumpNotifier.new,
);

/// Shows [page] in the mushaf tab, closing any screens opened on top of
/// the tabs.
void openMushaf(BuildContext context, int page, {AyahRef? highlight}) {
  final container = ProviderScope.containerOf(context, listen: false);
  container.read(mushafJumpProvider.notifier).jump(page, highlight: highlight);
  container.read(appTabProvider.notifier).select(AppTab.mushaf);
  Navigator.of(context).popUntil((route) => route.isFirst);
}
