import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/arabic_search.dart';
import '../../data/khatma.dart';
import '../../data/mushaf_repository.dart';
import '../../data/quran_models.dart';
import '../../data/quran_repository.dart';
import '../../l10n/strings.dart';
import '../shell/navigation.dart';

IconData khatmaTypeIcon(KhatmaType type) => switch (type) {
  KhatmaType.salaf => Icons.menu_book_outlined,
  KhatmaType.ramadan => Icons.nightlight_outlined,
  KhatmaType.dailyWird => Icons.event_repeat_outlined,
  KhatmaType.custom => Icons.bookmarks_outlined,
};

/// "My khatmas": the user's plans to read the whole Quran, each with a
/// colored bookmark that shows where the plan stands in the mushaf.
class KhatmaScreen extends ConsumerWidget {
  const KhatmaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(khatmaPlansProvider);
    final mushaf = ref.watch(mushafProvider).value;
    final surahs = ref.watch(surahsProvider).value;
    final t = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.myKhatmas),
        centerTitle: true,
        actions: [
          IconButton.filled(
            tooltip: t.newKhatma,
            icon: const Icon(Icons.add),
            onPressed: () => startNewKhatma(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: mushaf == null || surahs == null
          ? const Center(child: CircularProgressIndicator())
          : plans.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_stories_outlined, size: 64),
                    const SizedBox(height: 16),
                    Text(t.noKhatma, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(t.newKhatma),
                      onPressed: () => startNewKhatma(context),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final p in plans)
                  _PlanCard(plan: p, mushaf: mushaf, surahs: surahs),
              ],
            ),
    );
  }
}

/// Asks for the kind of plan, then its bookmark color and title.
Future<void> startNewKhatma(BuildContext context) async {
  final type = await showModalBottomSheet<KhatmaType>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _TypePicker(),
  );
  if (type == null || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PlanForm(type: type),
  );
}

class _TypePicker extends StatefulWidget {
  const _TypePicker();

  @override
  State<_TypePicker> createState() => _TypePickerState();
}

class _TypePickerState extends State<_TypePicker> {
  var _type = KhatmaType.salaf;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final t = S.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.chooseKhatmaType,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: t.close,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final type in KhatmaType.values)
              Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: type == _type
                        ? colors.primary
                        : colors.outlineVariant,
                    width: type == _type ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Icon(
                    khatmaTypeIcon(type),
                    size: 36,
                    color: colors.primary,
                  ),
                  title: Text(
                    t.khatmaTitle(type),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(t.khatmaSubtitle(type)),
                  onTap: () => setState(() => _type = type),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: () => Navigator.pop(context, _type),
              child: Text(t.next),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanForm extends ConsumerStatefulWidget {
  const _PlanForm({required this.type});

  final KhatmaType type;

  @override
  ConsumerState<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends ConsumerState<_PlanForm> {
  TextEditingController? _title;
  final _days = TextEditingController(text: '30');
  var _color = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final now = DateTime.now();
    _title ??= TextEditingController(
      text: S
          .of(context)
          .defaultPlanTitle(
            '${now.year}-${'${now.month}'.padLeft(2, '0')}-'
            '${'${now.day}'.padLeft(2, '0')}',
          ),
    );
  }

  @override
  void dispose() {
    _title?.dispose();
    _days.dispose();
    super.dispose();
  }

  int? get _customDays {
    // Arabic, Urdu and Bengali digits count too, as typed on their keyboards.
    final n = int.tryParse(normalizeForSearch(_days.text));
    return n != null && n >= 1 && n <= mushafPageCount ? n : null;
  }

  bool get _valid =>
      _title!.text.trim().isNotEmpty &&
      (widget.type != KhatmaType.custom || _customDays != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = S.of(context);
    final labelStyle = theme.textTheme.titleMedium;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.createPlan, style: theme.textTheme.headlineSmall),
                      Text(
                        '[${t.khatmaTitle(widget.type)}]',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: const Color(0xFFD9822B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: t.close,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(t.planBookmark, style: labelStyle),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var c = 0; c < khatmaColors.length; c++)
                  Tooltip(
                    message: t.bookmarkColor(c + 1),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: khatmaColors[c].withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: c == _color
                                ? khatmaColors[c]
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.bookmark,
                          color: khatmaColors[c],
                          size: 30,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(t.planTitle, style: labelStyle),
            TextField(
              controller: _title,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                suffixIcon: IconButton(
                  tooltip: t.clear,
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(_title!.clear),
                ),
              ),
            ),
            if (widget.type == KhatmaType.custom) ...[
              const SizedBox(height: 24),
              Text(t.khatmaDays, style: labelStyle),
              TextField(
                controller: _days,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  helperText: _customDays == null
                      ? t.daysRange
                      : t.pagesPerDay(
                          (mushafPageCount / _customDays!).toStringAsFixed(1),
                        ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _valid ? _create : null,
              child: Text(t.createPlan),
            ),
          ],
        ),
      ),
    );
  }

  void _create() {
    ref
        .read(khatmaPlansProvider.notifier)
        .add(
          type: widget.type,
          title: _title!.text.trim(),
          color: _color,
          customDays: _customDays ?? 30,
        );
    Navigator.pop(context);
  }
}

String portionLabel(S t, KhatmaPortion p, Mushaf m, List<Surah> surahs) {
  final pages = t.pages(p.firstPage(m), p.lastPage(m));
  return p.prayer == null
      ? '$pages · ${t.fromAyah(surahs[p.from.surah - 1], p.from.ayah)}'
      : '${t.afterPrayer(p.prayer!)} · $pages';
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({
    required this.plan,
    required this.mushaf,
    required this.surahs,
  });

  final KhatmaPlan plan;
  final Mushaf mushaf;
  final List<Surah> surahs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = S.of(context);
    final portions = plan.portions(mushaf);
    final next = plan.nextPortion(mushaf);
    final day = plan.dayOn(DateTime.now()).clamp(1, plan.days);
    final color = khatmaColors[plan.color];
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => KhatmaPlanScreen(planId: plan.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bookmark, color: color, size: 32),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan.title, style: theme.textTheme.titleMedium),
                        Text(
                          t.khatmaTitle(plan.type),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(t.dayOf(day, plan.days)),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: plan.done.length / portions.length,
                color: color,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 4),
              Text(
                t.doneOf(plan.done.length, portions.length),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (next == null)
                Text(
                  t.khatmaComplete,
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                )
              else ...[
                Text(
                  t.nextPortion(portions[next].day),
                  style: theme.textTheme.labelLarge,
                ),
                Text(portionLabel(t, portions[next], mushaf, surahs)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.menu_book),
                      label: Text(t.readPortion),
                      onPressed: () => openMushaf(
                        context,
                        portions[next].firstPage(mushaf),
                        highlight: portions[next].from,
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.check),
                      label: Text(t.markRead),
                      onPressed: () => ref
                          .read(khatmaPlansProvider.notifier)
                          .setRead(plan.id, next),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Every portion of one plan, to tick off or open in the mushaf.
class KhatmaPlanScreen extends ConsumerWidget {
  const KhatmaPlanScreen({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref
        .watch(khatmaPlansProvider)
        .where((p) => p.id == planId)
        .firstOrNull;
    final mushaf = ref.watch(mushafProvider).value;
    final surahs = ref.watch(surahsProvider).value;
    final t = S.of(context);
    if (plan == null || mushaf == null || surahs == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final portions = plan.portions(mushaf);
    final today = plan.dayOn(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: Text(plan.title),
        actions: [
          IconButton(
            tooltip: t.deleteKhatma,
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(t.deleteKhatmaQuestion),
                  content: Text(t.deleteKhatmaExplain(plan.title)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(t.cancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(t.delete),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                Navigator.pop(context);
                ref.read(khatmaPlansProvider.notifier).remove(plan.id);
              }
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: portions.length,
        itemBuilder: (context, i) {
          final p = portions[i];
          return CheckboxListTile(
            value: plan.done.contains(i),
            onChanged: (v) => ref
                .read(khatmaPlansProvider.notifier)
                .setRead(plan.id, i, read: v ?? false),
            title: Text(
              p.day == today ? '${t.day(p.day)} (${t.today})' : t.day(p.day),
              style: TextStyle(
                fontWeight: p.day == today ? FontWeight.bold : null,
              ),
            ),
            subtitle: Text(portionLabel(t, p, mushaf, surahs)),
            secondary: IconButton(
              tooltip: t.openInMushaf,
              icon: Icon(Icons.menu_book, color: khatmaColors[plan.color]),
              onPressed: () =>
                  openMushaf(context, p.firstPage(mushaf), highlight: p.from),
            ),
          );
        },
      ),
    );
  }
}
