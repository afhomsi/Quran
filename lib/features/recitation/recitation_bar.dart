import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/quran_repository.dart';
import '../../l10n/strings.dart';
import '../../recitation/page_recitation.dart';
import '../../recitation/session_record.dart';
import '../audio/repeat_sheet.dart';
import '../hifz_exam/exam_stop.dart';
import '../../recitation/recitation_matcher.dart';
import '../../recitation/recitation_session.dart';
import 'offline_model_tile.dart';
import 'recitation_mode.dart';

/// Reciting controls under the mushaf page, like the audio player: close,
/// start over, the microphone and listening to the ayat recited wrongly.
/// The page itself hides the words not recited yet and shows each word in
/// green or red as it is recited; the «show ayat» button shows the whole page.
class RecitationBar extends ConsumerWidget {
  const RecitationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recitation = ref.watch(pageRecitationProvider);
    if (recitation == null) return const SizedBox();
    final controller = ref.read(pageRecitationProvider.notifier);
    final session = recitation.session;
    final result = session.result;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final t = S.of(context);

    final total = result.words.where((w) => !w.word.optional).length;
    final done = result.words
        .take(result.progress)
        .where((w) => !w.word.optional)
        .length;
    final String status;
    if (result.isComplete) {
      status = finishedStatus(t, result);
    } else if (session.isListening) {
      status = t.listening(done, total);
    } else {
      status = t.pressMicToRecite;
    }
    // Over several pages, the surah being recited.
    final surahs = ref.watch(surahsProvider).value;
    final title = recitation.lastPage > recitation.page && surahs != null
        ? t.reciteSurahTitle(surahs[recitation.currentWord.$1.surah - 1])
        : t.recitePageTitle(recitation.page);
    final mistakeAyat = mistakeAyatOf(session);
    final message =
        session.error ??
        (session.mistakes.isEmpty ? null : session.mistakes.last.message);
    final harakatMessage =
        session.error == null &&
        session.mistakes.isNotEmpty &&
        session.mistakes.last.kind == MistakeKind.harakat;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (recitation.exam != null) ExamPrompt(recitation: recitation),
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    if (recitation.exam == null) title,
                    session.mode == RecitationMode.lenient
                        ? t.lenientShort
                        : t.strictShort,
                    status,
                  ].join(' · '),
                  style: textTheme.labelMedium,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Shows the word the reciter is stuck on, one more each press.
              if (recitation.hideText && !result.isComplete)
                Tooltip(
                  message: t.hintTooltip,
                  child: TextButton.icon(
                    icon: const Icon(Icons.lightbulb_rounded),
                    label: Text(t.hint),
                    onPressed: controller.hint,
                  ),
                ),
            ],
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                message,
                key: ValueKey(session.mistakes.length),
                style: textTheme.bodyMedium?.copyWith(
                  color: harakatMessage ? Colors.orange.shade800 : colors.error,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const ExamNextButton(),
          const OfflineModelTile(onlyToDownload: true),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: t.closeRecitation,
                icon: Icon(Icons.cancel_rounded, color: colors.primary),
                onPressed: controller.close,
              ),
              FilledButton.tonalIcon(
                icon: Icon(
                  recitation.hideText
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
                label: Text(recitation.hideText ? t.showAyat : t.hideAyat),
                onPressed: controller.toggleHideText,
              ),
              IconButton(
                tooltip: t.mistakesReport,
                icon: Icon(Icons.assignment_rounded, color: colors.primary),
                onPressed: () => showMistakesReport(context, session),
              ),
              IconButton(
                tooltip: t.restartRecitation,
                icon: Icon(Icons.restart_alt_rounded, color: colors.primary),
                onPressed: controller.restart,
              ),
              IconButton.filled(
                tooltip: session.isListening ? t.stop : t.startRecitation,
                iconSize: 30,
                icon: Icon(
                  session.isListening ? Icons.stop_rounded : Icons.mic_rounded,
                ),
                onPressed: controller.toggleListening,
              ),
              IconButton(
                tooltip: t.listenToMistakes,
                icon: Icon(
                  Icons.replay_rounded,
                  color: mistakeAyat.isEmpty ? null : colors.error,
                ),
                onPressed: mistakeAyat.isEmpty
                    ? null
                    : () async {
                        if (session.isListening) {
                          await controller.toggleListening();
                        }
                        if (!context.mounted) return;
                        await showRepeatSheet(
                          context,
                          ayat: mistakeAyat,
                          title: t.listenToMistakes,
                        );
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
