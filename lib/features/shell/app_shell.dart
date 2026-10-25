import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/reading_state.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../home/home_screen.dart';
import '../khatma/khatma_screen.dart';
import '../more/more_screen.dart';
import '../mushaf/mushaf_screen.dart';
import 'navigation.dart';

/// The app's main screen: the mushaf, khatma plans, index, bookmarks and
/// more, switched with the bottom bar. Each tab keeps its state.
///
/// The mushaf draws the bottom bar over its page, and hides it with a tap.
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
      bottomNavigationBar: tab == AppTab.mushaf
          ? null
          : const AppNavigationBar(),
    );
  }
}
