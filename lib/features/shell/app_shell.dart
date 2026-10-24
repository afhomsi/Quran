import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/reading_state.dart';
import '../../l10n/strings.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../home/home_screen.dart';
import '../khatma/khatma_screen.dart';
import '../more/more_screen.dart';
import '../mushaf/mushaf_screen.dart';
import 'navigation.dart';

/// The app's main screen: the mushaf, khatma plans, index, bookmarks and
/// more, switched with the bottom bar. Each tab keeps its state.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// The mushaf opens where the reader left off.
  late final int _startPage = ref.read(lastPageProvider) ?? 1;

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(appTabProvider);
    final t = S.of(context);
    return Scaffold(
      body: IndexedStack(
        index: tab.index,
        children: [
          MushafScreen(initialPage: _startPage),
          const KhatmaScreen(),
          const HomeScreen(),
          const BookmarksScreen(),
          const MoreScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab.index,
        onDestinationSelected: (i) =>
            ref.read(appTabProvider.notifier).select(AppTab.values[i]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.auto_stories_outlined),
            selectedIcon: const Icon(Icons.auto_stories),
            label: t.mushaf,
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: t.tabKhatma,
          ),
          NavigationDestination(
            icon: const Icon(Icons.toc_outlined),
            selectedIcon: const Icon(Icons.toc),
            label: t.tabIndex,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bookmarks_outlined),
            selectedIcon: const Icon(Icons.bookmarks),
            label: t.tabBookmarks,
          ),
          NavigationDestination(
            icon: const Icon(Icons.more_horiz),
            selectedIcon: const Icon(Icons.more_horiz),
            label: t.tabMore,
          ),
        ],
      ),
    );
  }
}
