import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hifz_strength.dart';
import '../../data/mushaf_repository.dart';
import '../../data/reading_state.dart';
import '../../l10n/strings.dart';
import '../../reminders/daily_reminder.dart';
import '../../settings/app_settings.dart';
import '../review/today_card.dart';
import '../home/home_screen.dart';
import '../khatma/khatma_screen.dart';
import '../more/more_screen.dart';
import '../mushaf/mushaf_screen.dart';
import 'navigation.dart';

/// The app's main screen: the mushaf, today's wird and khatma plans, the
/// index and the tools (with the bookmarks), switched with the bottom bar. Each tab keeps its state.
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
  void initState() {
    super.initState();
    // Sets the daily reminder again, as the phone may have dropped it.
    if (ref.read(settingsProvider).reminderOn) {
      final container = ProviderScope.containerOf(context, listen: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) syncReminder(container, S.of(context));
      });
    }
    // Once the mushaf is loaded, opens on today's wird when a review is
    // due, if chosen; only at the start, never while the app is in use.
    ProviderSubscription<AsyncValue<Mushaf>>? sub;
    sub = ref.listenManual(mushafProvider, (_, mushaf) {
      if (!mushaf.hasValue) return;
      sub?.close();
      if (ref.read(settingsProvider).openOnToday &&
          ref.read(appTabProvider) == AppTab.mushaf &&
          hasReviewDue(ref.read(pageHifzProvider), DateTime.now())) {
        ref.read(appTabProvider.notifier).select(AppTab.khatma);
      }
    }, fireImmediately: true);
  }

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
          const MoreScreen(),
        ],
      ),
      bottomNavigationBar: tab == AppTab.mushaf
          ? null
          : const AppNavigationBar(),
    );
  }
}
