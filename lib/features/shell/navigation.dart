import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mushaf_models.dart';

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
