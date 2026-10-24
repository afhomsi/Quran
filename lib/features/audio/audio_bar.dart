import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/ayah_audio.dart';
import '../../data/quran_repository.dart';
import '../../l10n/strings.dart';
import 'repeat_sheet.dart';

/// Compact player controls under the mushaf page: close, next ayah, play
/// or pause, previous ayah, loop and more options. Repeating a group of
/// ayat is in the options. A line above the buttons shows only an error
/// or the round of a repeated group.
class AudioBar extends ConsumerWidget {
  const AudioBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    final controller = ref.read(audioProvider.notifier);
    final surahs = ref.watch(surahsProvider).value;
    final colors = Theme.of(context).colorScheme;
    final t = S.of(context);
    final current = audio.current;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (current != null &&
              surahs != null &&
              (audio.failed || audio.playlist != null))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                audio.failed
                    ? t.audioError
                    : '${t.reciterName(reciters[audio.reciter])} · '
                          '${t.surahName(surahs[current.surah - 1])} '
                          '${t.n(current.ayah)}'
                          '${audio.playlist == null ? '' : ' · ${t.playlistRound(audio.pass, audio.listRepeats)}'}',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: audio.failed ? colors.error : null),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: t.closePlayer,
                icon: Icon(Icons.cancel, color: colors.primary),
                onPressed: controller.close,
              ),
              IconButton(
                tooltip: t.nextAyah,
                icon: Icon(Icons.fast_forward, color: colors.primary),
                onPressed: controller.next,
              ),
              audio.loading && audio.playing
                  ? const SizedBox(
                      width: 48,
                      height: 48,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  : IconButton(
                      tooltip: audio.playing ? t.pause : t.play,
                      iconSize: 32,
                      icon: Icon(
                        audio.playing ? Icons.pause : Icons.play_arrow,
                        color: colors.primary,
                      ),
                      onPressed: controller.togglePlay,
                    ),
              IconButton(
                tooltip: t.previousAyah,
                icon: Icon(Icons.fast_rewind, color: colors.primary),
                onPressed: controller.previous,
              ),
              IconButton(
                tooltip: t.loopLabel(audio.loop),
                isSelected: audio.loop != AudioLoop.none,
                icon: Icon(
                  audio.loop == AudioLoop.ayah
                      ? Icons.repeat_one
                      : Icons.all_inclusive,
                  color: audio.loop == AudioLoop.none
                      ? colors.onSurfaceVariant
                      : colors.primary,
                ),
                onPressed: () {
                  controller.cycleLoop();
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          t.loopLabel(ref.read(audioProvider).loop),
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                },
              ),
              IconButton(
                tooltip: t.audioOptions,
                icon: Icon(Icons.more_horiz, color: colors.primary),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  builder: (_) => const _AudioOptions(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AudioOptions extends ConsumerWidget {
  const _AudioOptions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    final controller = ref.read(audioProvider.notifier);
    final theme = Theme.of(context);
    final t = S.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.playlist_play,
                color: audio.playlist == null
                    ? null
                    : theme.colorScheme.primary,
              ),
              title: Text(t.repeatAyat),
              onTap: () {
                // This sheet closes, so open the next one from the app.
                final navigator = Navigator.of(context)..pop();
                showRepeatSheet(
                  navigator.context,
                  from: audio.playlist?.first ?? audio.current,
                  to: audio.playlist?.last ?? audio.current,
                );
              },
            ),
            const Divider(),
            Text(t.reciter, style: theme.textTheme.titleMedium),
            RadioGroup<int>(
              groupValue: audio.reciter,
              onChanged: (r) => controller.setReciter(r ?? audio.reciter),
              child: Column(
                children: [
                  for (var r = 0; r < reciters.length; r++)
                    RadioListTile(
                      value: r,
                      title: Text(t.reciterName(reciters[r])),
                      dense: true,
                    ),
                ],
              ),
            ),
            const Divider(),
            Text(
              t.repeatEachAyah(audio.repeats),
              style: theme.textTheme.titleMedium,
            ),
            Slider(
              value: audio.repeats.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              label: '${audio.repeats}',
              onChanged: (v) => controller.setRepeats(v.round()),
            ),
            Text(t.whenFinished, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<AudioLoop>(
              showSelectedIcon: false,
              segments: [
                for (final l in AudioLoop.values)
                  ButtonSegment(value: l, label: Text(t.loopShort(l))),
              ],
              selected: {audio.loop},
              onSelectionChanged: (s) {
                while (ref.read(audioProvider).loop != s.first) {
                  controller.cycleLoop();
                }
              },
            ),
            const SizedBox(height: 16),
            Text(t.speed(audio.speed), style: theme.textTheme.titleMedium),
            Slider(
              value: audio.speed,
              min: 0.5,
              max: 1.5,
              divisions: 4,
              label: '${audio.speed}×',
              onChanged: controller.setSpeed,
            ),
            Text(t.audioSource, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
