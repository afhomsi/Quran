import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hifz_exam.dart';
import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/quran_models.dart';
import '../../data/quran_repository.dart';
import '../../l10n/strings.dart';
import '../../recitation/recitation_matcher.dart';
import '../recitation/recitation_mode.dart';
import '../recitation/recitation_screen.dart';
import '../shell/navigation.dart';

/// Hifz exam: the reciter picks a surah longer than a page, and the app
/// picks a few groups of its ayat at random, about a tenth of the surah,
/// to recite from memory one after the other. Each is checked like any
/// recitation, and the exam ends with what to review.
class HifzExamScreen extends ConsumerStatefulWidget {
  const HifzExamScreen({super.key, this.random});

  /// For tests; a fresh [Random] otherwise.
  final Random? random;

  @override
  ConsumerState<HifzExamScreen> createState() => _HifzExamScreenState();
}

class _HifzExamScreenState extends ConsumerState<HifzExamScreen> {
  late final _random = widget.random ?? Random();

  /// The surahs the exam is given for, once the mushaf is loaded.
  List<int>? _allowed;

  /// The exam in progress, or null while choosing a surah.
  List<ExamQuestion>? _questions;
  var _mode = RecitationMode.strict;

  /// How each question was recited, by its index.
  final _results = <int, RecitationResult>{};

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
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).hifzExam)),
      body: surahs == null || _allowed == null
          ? const Center(child: CircularProgressIndicator())
          : switch (_questions) {
              null => _chooseSurah(surahs),
              final q => _exam(surahs, mushaf!, q),
            },
    );
  }

  Widget _chooseSurah(List<Surah> surahs) {
    final t = S.of(context);
    final theme = Theme.of(context);
    return ListView(
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
            onTap: () => _start(surahs[s - 1]),
          ),
      ],
    );
  }

  Future<void> _start(Surah surah) async {
    final mode = await chooseRecitationMode(context);
    if (mode == null || !mounted) return;
    setState(() {
      _mode = mode;
      _questions = pickExam(surah.number, surah.ayahCount, _random);
      _results.clear();
    });
  }

  /// Recites question [index], then goes on to the next one not recited
  /// yet when the reciter presses «next question».
  Future<void> _recite(List<Surah> surahs, int index) async {
    final questions = _questions!;
    final q = questions[index];
    final surah = surahs[q.surah - 1];
    final t = S.of(context);
    final next = _nextUnrecited(after: index);
    final goOn = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecitationScreen.range(
          q.surah,
          q.from,
          q.to,
          mode: _mode,
          title: t.examRangeTitle(surah, q.from, q.to),
          doneLabel: next == null ? t.examResults : t.nextQuestion,
          onComplete: (result) {
            if (mounted && identical(questions, _questions)) {
              setState(() => _results[index] = result);
            }
          },
        ),
      ),
    );
    if (goOn == true && next != null && mounted) {
      await _recite(surahs, next);
    }
  }

  /// The first question after [after], or else before it, not recited yet.
  int? _nextUnrecited({required int after}) {
    final count = _questions!.length;
    for (var i = 1; i < count; i++) {
      final k = (after + i) % count;
      if (!_results.containsKey(k)) return k;
    }
    return null;
  }

  Widget _exam(List<Surah> surahs, Mushaf mushaf, List<ExamQuestion> qs) {
    final t = S.of(context);
    final theme = Theme.of(context);
    final surah = surahs[qs.first.surah - 1];
    final done = _results.length == qs.length;
    final right = _results.values.where((r) => r.mistakeCount == 0).length;
    final first = _results.containsKey(0) ? _nextUnrecited(after: 0) : 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          t.examSummary(
            surah,
            qs.length,
            qs.fold(0, (sum, q) => sum + q.ayahCount),
          ),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: _results.length / qs.length),
        const SizedBox(height: 8),
        if (!done && first != null)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.mic_rounded),
            label: Text(t.questionOf(first + 1, qs.length)),
            onPressed: () => _recite(surahs, first),
          ),
        if (done) ...[
          Icon(
            right == qs.length
                ? Icons.emoji_events_rounded
                : Icons.school_rounded,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          Text(
            t.score(right, qs.length),
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (right < qs.length) ...[
            const SizedBox(height: 8),
            Text(t.reviewThese, style: theme.textTheme.titleMedium),
            for (var i = 0; i < qs.length; i++)
              if (_results[i]!.mistakeCount > 0)
                ListTile(
                  leading: const Icon(Icons.replay_rounded),
                  title: Text(t.examRangeTitle(surah, qs[i].from, qs[i].to)),
                  trailing: Text(
                    t.n(mushaf.pageOf(AyahRef(qs[i].surah, qs[i].from))),
                  ),
                  onTap: () => openMushaf(
                    context,
                    mushaf.pageOf(AyahRef(qs[i].surah, qs[i].from)),
                    highlight: AyahRef(qs[i].surah, qs[i].from),
                  ),
                ),
          ],
        ],
        const SizedBox(height: 8),
        for (var i = 0; i < qs.length; i++)
          _QuestionCard(
            number: i + 1,
            text: t.reciteRange(surah, qs[i].from, qs[i].to),
            result: _results[i],
            onRecite: () => _recite(surahs, i),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.shuffle_rounded),
                label: Text(t.newTest),
                onPressed: () => setState(() {
                  _questions = pickExam(surah.number, surah.ayahCount, _random);
                  _results.clear();
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.list_rounded),
                label: Text(t.chooseSurahToRecite),
                onPressed: () => setState(() {
                  _questions = null;
                  _results.clear();
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.number,
    required this.text,
    required this.result,
    required this.onRecite,
  });

  final int number;
  final String text;
  final RecitationResult? result;
  final VoidCallback onRecite;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final result = this.result;
    final mistakes = result?.mistakeCount ?? 0;
    final (IconData icon, Color color, String status) = switch (result) {
      null => (
        Icons.radio_button_unchecked_rounded,
        scheme.outline,
        t.notRecitedYet,
      ),
      _ when mistakes == 0 => (
        Icons.check_circle_rounded,
        Colors.green.shade700,
        t.noMistakes,
      ),
      _ => (Icons.cancel_rounded, scheme.error, t.examMistakes(mistakes)),
    };
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(t.n(number))),
        title: Text(text),
        subtitle: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(status, style: TextStyle(color: color)),
            ),
          ],
        ),
        trailing: TextButton(
          onPressed: onRecite,
          child: Text(result == null ? t.examRecite : t.reciteAgain),
        ),
      ),
    );
  }
}
