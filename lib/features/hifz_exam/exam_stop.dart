import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hifz_exam.dart';
import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/quran_repository.dart';
import '../../l10n/strings.dart';
import '../../recitation/page_recitation.dart';

/// How long the «stop» popup waits before going on to the next question.
const examNextDelay = Duration(seconds: 5);

/// Tells the reciter to stop once a question of the hifz exam is recited
/// to its end, and goes on to the next one after [examNextDelay], or shows
/// the result after the last.
Future<void> showExamStop(BuildContext context, WidgetRef ref) async {
  final recitation = ref.read(pageRecitationProvider);
  final exam = recitation?.exam;
  if (recitation == null || exam == null || !exam.answered) return;
  final controller = ref.read(pageRecitationProvider.notifier);
  if (exam.isLast) {
    final again = await showDialog<bool>(
      context: context,
      builder: (_) => _ExamResult(exam: exam),
    );
    if (again == true) {
      final q = exam.current;
      await controller.startExam(
        pickExam(q.surah, ayahCounts[q.surah - 1], Random()),
        mode: recitation.session.mode,
      );
    } else if (again == false) {
      controller.close();
    }
    return;
  }
  final next = await showDialog<bool>(
    context: context,
    builder: (_) => _ExamStop(exam: exam),
  );
  if (next == true) {
    await controller.nextQuestion();
  } else if (next == false) {
    controller.close();
  }
}

class _ExamStop extends ConsumerStatefulWidget {
  const _ExamStop({required this.exam});

  final ExamRun exam;

  @override
  ConsumerState<_ExamStop> createState() => _ExamStopState();
}

class _ExamStopState extends ConsumerState<_ExamStop> {
  late int _left = examNextDelay.inSeconds;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left <= 1) {
        _timer.cancel();
        Navigator.of(context).pop(true);
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final theme = Theme.of(context);
    final surahs = ref.watch(surahsProvider).value;
    final exam = widget.exam;
    final mistakes = exam.mistakes[exam.index]!;
    final next = exam.questions[exam.index + 1];
    return AlertDialog(
      icon: Icon(
        Icons.back_hand_rounded,
        size: 40,
        color: theme.colorScheme.primary,
      ),
      title: Text(t.examStop),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            mistakes == 0 ? t.noMistakes : t.examMistakes(mistakes),
            style: theme.textTheme.titleMedium?.copyWith(
              color: mistakes == 0
                  ? Colors.green.shade700
                  : theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          if (surahs != null)
            Text(
              '${t.questionOf(exam.index + 2, exam.questions.length)}: '
              '${t.reciteRange(surahs[next.surah - 1], next.from, next.to)}',
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 8),
          Text(
            t.examNextIn(_left),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.closeExam),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.reviewMistakes),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(t.nextQuestion),
        ),
      ],
    );
  }
}

class _ExamResult extends ConsumerWidget {
  const _ExamResult({required this.exam});

  final ExamRun exam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final theme = Theme.of(context);
    final surahs = ref.watch(surahsProvider).value;
    final mushaf = ref.watch(mushafProvider).value;
    final total = exam.questions.length;
    return AlertDialog(
      icon: Icon(
        exam.right == total ? Icons.emoji_events_rounded : Icons.school_rounded,
        size: 48,
        color: theme.colorScheme.primary,
      ),
      title: Text(t.examDone),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.score(exam.right, total),
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (exam.right < total && surahs != null && mushaf != null) ...[
              const SizedBox(height: 12),
              Text(t.reviewThese, style: theme.textTheme.titleSmall),
              for (var i = 0; i < total; i++)
                if (exam.mistakes[i] != 0)
                  Text(
                    '• ${t.examRangeTitle(surahs[exam.questions[i].surah - 1], exam.questions[i].from, exam.questions[i].to)}'
                    ' (${exam.mistakes[i] == null ? t.notRecited : t.examMistakes(exam.mistakes[i]!)})'
                    ' · ${t.n(mushaf.pageOf(AyahRef(exam.questions[i].surah, exam.questions[i].from)))}',
                  ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.closeExam),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.shuffle_rounded),
          onPressed: () => Navigator.of(context).pop(true),
          label: Text(t.newTest),
        ),
      ],
    );
  }
}

/// What the recitation bar shows during a question of the exam: which
/// question, the ayat to recite and, when they start a page, the end of
/// the ayah before them, as the page does not show it.
class ExamPrompt extends ConsumerWidget {
  const ExamPrompt({super.key, required this.recitation});

  final PageRecitation recitation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exam = recitation.exam!;
    final surahs = ref.watch(surahsProvider).value;
    final mushaf = ref.watch(mushafProvider).value;
    if (surahs == null || mushaf == null) return const SizedBox();
    final t = S.of(context);
    final theme = Theme.of(context);
    final q = exam.current;
    final from = AyahRef(q.surah, q.from);
    final startsPage = mushaf.page(mushaf.pageOf(from)).firstAyah == from;
    final before = surahs[q.surah - 1].ayahs[q.from - 2].split(' ');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${t.hifzExam} · ${t.questionOf(exam.index + 1, exam.questions.length)}',
          style: theme.textTheme.labelMedium,
          textAlign: TextAlign.center,
        ),
        Text(
          t.reciteRange(surahs[q.surah - 1], q.from, q.to),
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        if (startsPage)
          Text(
            t.examCue(before.skip(max(0, before.length - 5)).join(' ')),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

/// Shows the stop popup again, or the next question, once the popup was
/// put away to look over the mistakes.
class ExamNextButton extends ConsumerWidget {
  const ExamNextButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exam = ref.watch(pageRecitationProvider)?.exam;
    if (exam == null || !exam.answered) return const SizedBox();
    final t = S.of(context);
    return FilledButton.icon(
      icon: const Icon(Icons.arrow_back_rounded),
      label: Text(exam.isLast ? t.examResults : t.nextQuestion),
      onPressed: exam.isLast
          ? () => showExamStop(context, ref)
          : ref.read(pageRecitationProvider.notifier).nextQuestion,
    );
  }
}
