import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hifz_exam.dart';
import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/quran_models.dart';
import '../../data/quran_repository.dart';
import '../../l10n/strings.dart';
import '../../recitation/page_recitation.dart';
import '../recitation/recitation_mode.dart';
import '../shell/navigation.dart';

/// Hifz exam: the reciter picks a surah longer than a page, and the app
/// picks a few groups of its ayat at random, about a tenth of the surah.
/// Each is recited in the mushaf from memory, after the ayat before it,
/// and a popup says to stop at its end and goes on to the next; see
/// [PageRecitationController.startExam].
class HifzExamScreen extends ConsumerStatefulWidget {
  const HifzExamScreen({super.key, this.random});

  /// For tests; a fresh [Random] otherwise, so each exam asks other ayat.
  final Random? random;

  @override
  ConsumerState<HifzExamScreen> createState() => _HifzExamScreenState();
}

class _HifzExamScreenState extends ConsumerState<HifzExamScreen> {
  late final _random = widget.random ?? Random();

  /// The surahs the exam is given for, once the mushaf is loaded.
  List<int>? _allowed;

  @override
  Widget build(BuildContext context) {
    final surahs = ref.watch(surahsProvider).value;
    final mushaf = ref.watch(mushafProvider).value;
    if (mushaf != null) {
      _allowed ??= [
        for (var s = 1; s <= ayahCounts.length; s++)
          if (examAllowed(mushaf, s)) s,
      ];
    }
    final t = S.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.hifzExam)),
      body: surahs == null || _allowed == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(t.hifzExamHelp, style: theme.textTheme.bodyLarge),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    t.hifzExamLongOnly,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final s in _allowed!)
                  ListTile(
                    leading: CircleAvatar(child: Text(t.n(s))),
                    title: Text(t.surahName(surahs[s - 1])),
                    subtitle: Text(t.ayahCount(surahs[s - 1].ayahCount)),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () => _start(surahs[s - 1], mushaf!),
                  ),
              ],
            ),
    );
  }

  /// Opens the mushaf at the first question and recites the exam there.
  Future<void> _start(Surah surah, Mushaf mushaf) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final mode = await chooseRecitationMode(context);
    if (mode == null || !mounted) return;
    final exam = pickExam(surah.number, surah.ayahCount, _random);
    final q = exam.first;
    openMushaf(context, mushaf.pageOf(AyahRef(q.surah, q.from)));
    await container
        .read(pageRecitationProvider.notifier)
        .startExam(exam, mode: mode);
  }
}
