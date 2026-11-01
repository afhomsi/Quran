import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hifz_exam.dart';
import '../../data/hifz_strength.dart';
import '../../data/khatma.dart';
import '../../data/mushaf_models.dart';
import '../../data/mutashabihat.dart';
import '../../data/mushaf_repository.dart';
import '../../data/quran_models.dart';
import '../../data/quran_repository.dart';
import '../../data/recitation_history.dart';
import '../../l10n/strings.dart';
import '../../recitation/page_recitation.dart';
import '../../reminders/daily_reminder.dart';
import '../../settings/app_settings.dart';
import '../../theme/app_theme.dart';
import '../khatma/khatma_screen.dart';
import '../recitation/recitation_mode.dart';
import '../shell/navigation.dart';
import 'hifz_map_screen.dart';

/// Recites the pages of [run] from memory in the mushaf.
Future<void> reciteReviewRun(BuildContext context, ReviewRun run) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final mode = await chooseRecitationMode(context);
  if (mode == null || !context.mounted) return;
  openMushaf(context, run.firstPage);
  await container
      .read(pageRecitationProvider.notifier)
      .startPages(run.firstPage, run.lastPage, mode: mode);
}

/// Recites [questions] one by one in the mushaf, each after the ayat
/// before it, as in the hifz exam.
Future<void> startDrill(
  BuildContext context,
  List<ExamQuestion> questions,
) async {
  if (questions.isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.of(context).reciteMorePages)));
    return;
  }
  final container = ProviderScope.containerOf(context, listen: false);
  final mushaf = container.read(mushafProvider).value;
  if (mushaf == null) return;
  final mode = await chooseRecitationMode(context);
  if (mode == null || !context.mounted) return;
  final q = questions.first;
  openMushaf(context, mushaf.pageOf(AyahRef(q.surah, q.from)));
  await container
      .read(pageRecitationProvider.notifier)
      .startExam(questions, mode: mode);
}

/// Whether there is something to review on [now], for opening the app on
/// today's wird.
bool hasReviewDue(Map<int, PageHifz> pages, DateTime now) =>
    duePageCount(pages, now) > 0;

/// "Today's wird": the pages to review today, chosen from how each page
/// was last recited, the next portion of each recitation plan, and the
/// way to the hifz map.
class TodayCard extends ConsumerWidget {
  const TodayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final mushaf = ref.watch(mushafProvider).value;
    final surahs = ref.watch(surahsProvider).value;
    final pages = ref.watch(pageHifzProvider);
    final reminderOn = ref.watch(settingsProvider.select((s) => s.reminderOn));
    final history = ref.watch(recitationHistoryProvider);
    final plans = [
      for (final p in ref.watch(khatmaPlansProvider))
        if (p.recite) p,
    ];
    if (mushaf == null || surahs == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final runs = dailyReview(pages, now);
    final chosen = runs.fold(0, (sum, r) => sum + r.pageCount);
    final more = duePageCount(pages, now) - chosen;
    final counts = strengthCounts(pages);
    final streak = recitationStreak(history, now);
    final mistakes = pendingMistakes(history);

    Widget title(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconBadge(Icons.wb_sunny_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.todayWird,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (ref.watch(reminderSchedulerProvider).supported)
                  IconButton(
                    tooltip: t.dailyReminder,
                    isSelected: reminderOn,
                    icon: const Icon(Icons.notifications_none_rounded),
                    selectedIcon: const Icon(
                      Icons.notifications_active_rounded,
                    ),
                    onPressed: () => setReminder(context, !reminderOn),
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.grid_view_rounded),
                  label: Text(t.hifzMap),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HifzMapScreen()),
                  ),
                ),
              ],
            ),
            if (streak > 0)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: Color(0xFFE8772E),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t.streakDays(streak),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFFE8772E),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (pages.isNotEmpty) ...[
              const SizedBox(height: 12),
              StrengthBar(counts),
              const SizedBox(height: 6),
              StrengthLegend(counts),
            ],
            title(t.todayReview),
            if (pages.isEmpty)
              Text(t.noReviewYet, style: theme.textTheme.bodyMedium)
            else if (runs.isEmpty)
              Text(t.reviewDone, style: theme.textTheme.bodyMedium)
            else ...[
              for (final run in runs)
                _RunTile(run: run, surahs: surahs, mushaf: mushaf),
              if (more > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    t.moreDue(more),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.mic_rounded),
                label: Text(t.startReview),
                onPressed: () => reciteReviewRun(context, runs.first),
              ),
            ],
            if (pages.isNotEmpty) ...[
              title(t.drills),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.replay_rounded),
                    label: Text(t.reciteMistakes(mistakes.length)),
                    onPressed: mistakes.isEmpty
                        ? null
                        : () => startDrill(context, mistakeQuestions(mistakes)),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.compare_arrows_rounded),
                    label: Text(t.similarAyat),
                    onPressed: () => startDrill(
                      context,
                      similarQuestions(
                        ref.read(similarAyatProvider),
                        pages.keys.toSet(),
                        mushaf.pageOf,
                        Random(),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.link_rounded),
                    label: Text(t.linkPages),
                    onPressed: () => startDrill(
                      context,
                      linkingQuestions(mushaf, pages.keys, Random()),
                    ),
                  ),
                ],
              ),
            ],
            title(t.newRecitation),
            if (plans.isEmpty)
              OutlinedButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: Text(t.makeRecitePlan),
                onPressed: () => startNewKhatma(context),
              )
            else
              for (final plan in plans)
                _PlanLine(plan: plan, mushaf: mushaf, surahs: surahs),
          ],
        ),
      ),
    );
  }
}

class _RunTile extends StatelessWidget {
  const _RunTile({
    required this.run,
    required this.surahs,
    required this.mushaf,
  });

  final ReviewRun run;
  final List<Surah> surahs;
  final Mushaf mushaf;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final colors = Theme.of(context).colorScheme;
    final surah = surahs[mushaf.page(run.firstPage).firstAyah.surah - 1];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: strengthColor(run.strength, colors),
          shape: BoxShape.circle,
        ),
      ),
      title: Text(t.surahName(surah)),
      subtitle: Text(
        '${t.pages(run.firstPage, run.lastPage)} · '
        '${t.strengthName(run.strength.index)}',
      ),
      trailing: IconButton.filledTonal(
        tooltip: t.recite,
        icon: const Icon(Icons.mic_rounded),
        onPressed: () => reciteReviewRun(context, run),
      ),
      onTap: () => openMushaf(context, run.firstPage),
    );
  }
}

class _PlanLine extends StatelessWidget {
  const _PlanLine({
    required this.plan,
    required this.mushaf,
    required this.surahs,
  });

  final KhatmaPlan plan;
  final Mushaf mushaf;
  final List<Surah> surahs;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final next = plan.nextPortion(mushaf);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(Icons.flag_rounded, color: khatmaColors[plan.color]),
      title: Text(plan.title),
      subtitle: Text(
        next == null
            ? t.recitePlanDone
            : portionLabel(t, plan.portions(mushaf)[next], mushaf, surahs),
      ),
      trailing: next == null
          ? null
          : IconButton.filledTonal(
              tooltip: t.recitePortion,
              icon: const Icon(Icons.mic_rounded),
              onPressed: () => reciteKhatmaPortion(context, plan, next),
            ),
    );
  }
}
