import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/strings.dart';
import '../../recitation/page_recitation.dart';
import '../../recitation/session_record.dart';
import '../audio/repeat_sheet.dart';

/// Reciting controls under the mushaf page, like the audio player: close,
/// start over, the microphone and listening to the ayat recited wrongly.
/// The page itself shows each ayah in green or red as it is recited.
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
      status = result.mistakeCount == 0
          ? t.perfectRecitation
          : t.finishedWithMistakes(result.mistakeCount);
    } else if (session.isListening) {
      status = t.listening(done, total);
    } else {
      status = t.pressMicToRecite;
    }
    final mistakeAyat = mistakeAyatOf(session);
    final message =
        session.error ??
        (session.mistakes.isEmpty ? null : session.mistakes.last.message);

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
          Text(
            '${t.recitePageTitle(recitation.page)} · $status',
            style: textTheme.labelMedium,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                message,
                key: ValueKey(session.mistakes.length),
                style: textTheme.bodyMedium?.copyWith(color: colors.error),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: t.closeRecitation,
                icon: Icon(Icons.cancel, color: colors.primary),
                onPressed: controller.close,
              ),
              IconButton(
                tooltip: t.restartRecitation,
                icon: Icon(Icons.restart_alt, color: colors.primary),
                onPressed: controller.restart,
              ),
              IconButton.filled(
                tooltip: session.isListening ? t.stop : t.startRecitation,
                iconSize: 30,
                icon: Icon(session.isListening ? Icons.stop : Icons.mic),
                onPressed: controller.toggleListening,
              ),
              IconButton(
                tooltip: t.listenToMistakes,
                icon: Icon(
                  Icons.replay,
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
