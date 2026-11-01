import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hifz_strength.dart';
import '../../data/mushaf_repository.dart';
import '../../l10n/strings.dart';
import '../shell/navigation.dart';

/// The colour of a page of [strength] on the hifz map.
Color strengthColor(PageStrength strength, ColorScheme colors) =>
    switch (strength) {
      PageStrength.strong => const Color(0xFF2E9E5B),
      PageStrength.medium => const Color(0xFFE0A526),
      PageStrength.weak => const Color(0xFFD64541),
      PageStrength.none => colors.surfaceContainerHighest,
    };

/// How many pages are of each strength, by [PageStrength.index].
List<int> strengthCounts(Map<int, PageHifz> pages) {
  final counts = List.filled(PageStrength.values.length, 0);
  for (final p in pages.values) {
    counts[p.strength.index]++;
  }
  counts[PageStrength.none.index] = mushafPageCount - pages.length;
  return counts;
}

/// A thin bar of the pages of each strength, strongest first.
class StrengthBar extends StatelessWidget {
  const StrengthBar(this.counts, {super.key});

  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final s in [
              PageStrength.strong,
              PageStrength.medium,
              PageStrength.weak,
              PageStrength.none,
            ])
              if (counts[s.index] > 0)
                Expanded(
                  flex: counts[s.index],
                  child: ColoredBox(color: strengthColor(s, colors)),
                ),
          ],
        ),
      ),
    );
  }
}

/// A key to the colours, with how many pages are of each.
class StrengthLegend extends StatelessWidget {
  const StrengthLegend(this.counts, {super.key});

  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final theme = Theme.of(context);
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final s in [
          PageStrength.strong,
          PageStrength.medium,
          PageStrength.weak,
          PageStrength.none,
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: strengthColor(s, theme.colorScheme),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                t.strengthCount(s.index, counts[s.index]),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
      ],
    );
  }
}

/// Every page of the mushaf, juz by juz, coloured by how well it is
/// known; a tap opens the page.
class HifzMapScreen extends ConsumerWidget {
  const HifzMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final mushaf = ref.watch(mushafProvider).value;
    final pages = ref.watch(pageHifzProvider);
    final theme = Theme.of(context);
    final counts = strengthCounts(pages);
    return Scaffold(
      appBar: AppBar(title: Text(t.hifzMap), centerTitle: true),
      body: mushaf == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  t.hifzMapHelp,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                StrengthBar(counts),
                const SizedBox(height: 8),
                StrengthLegend(counts),
                const SizedBox(height: 16),
                for (var juz = 1; juz <= 30; juz++) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    child: Text(
                      t.juz(juz),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (
                        var p = juz == 1 ? 1 : mushaf.juzStartPage(juz);
                        p <=
                            (juz == 30
                                ? mushafPageCount
                                : mushaf.juzStartPage(juz + 1) - 1);
                        p++
                      )
                        _PageSquare(page: p, hifz: pages[p]),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class _PageSquare extends StatelessWidget {
  const _PageSquare({required this.page, required this.hifz});

  final int page;
  final PageHifz? hifz;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final colors = Theme.of(context).colorScheme;
    final strength = hifz?.strength ?? PageStrength.none;
    final color = strengthColor(strength, colors);
    final last = hifz?.lastRecited;
    final days = last == null
        ? null
        : DateUtils.dateOnly(DateTime.now())
              .difference(DateUtils.dateOnly(last))
              .inDays;
    return Tooltip(
      message: [
        t.page(page),
        t.strengthName(strength.index),
        if (days != null) t.lastRecitedDaysAgo(days),
      ].join(' · '),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: () => openMushaf(context, page),
          child: SizedBox(
            width: 30,
            height: 30,
            child: Center(
              child: Text(
                t.n(page),
                style: TextStyle(
                  fontSize: 9,
                  color: strength == PageStrength.none
                      ? colors.onSurfaceVariant
                      : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
