import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/ayah_audio.dart';
import '../../data/quran_repository.dart';

String _loopLabel(AudioLoop loop) => switch (loop) {
  AudioLoop.none => 'بدون تكرار',
  AudioLoop.ayah => 'تكرار الآية',
  AudioLoop.page => 'تكرار الصفحة',
  AudioLoop.surah => 'تكرار السورة',
};

/// Player controls under the mushaf page: options, loop, previous ayah,
/// play or pause, next ayah and close.
class AudioBar extends ConsumerWidget {
  const AudioBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    final controller = ref.read(audioProvider.notifier);
    final surahs = ref.watch(surahsProvider).value;
    final colors = Theme.of(context).colorScheme;
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
          if (current != null && surahs != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                audio.error ??
                    '${reciters[audio.reciter].name} · '
                        '${surahs[current.surah - 1].name} ${current.ayah}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: audio.error == null ? null : colors.error,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: 'إغلاق المشغل',
                icon: Icon(Icons.cancel, color: colors.primary),
                onPressed: controller.close,
              ),
              IconButton(
                tooltip: 'الآية التالية',
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
                      tooltip: audio.playing ? 'إيقاف مؤقت' : 'تشغيل',
                      iconSize: 32,
                      icon: Icon(
                        audio.playing ? Icons.pause : Icons.play_arrow,
                        color: colors.primary,
                      ),
                      onPressed: controller.togglePlay,
                    ),
              IconButton(
                tooltip: 'الآية السابقة',
                icon: Icon(Icons.fast_rewind, color: colors.primary),
                onPressed: controller.previous,
              ),
              IconButton(
                tooltip: _loopLabel(audio.loop),
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
                        content: Text(_loopLabel(ref.read(audioProvider).loop)),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                },
              ),
              IconButton(
                tooltip: 'خيارات التلاوة',
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
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('القارئ', style: theme.textTheme.titleMedium),
            RadioGroup<int>(
              groupValue: audio.reciter,
              onChanged: (r) => controller.setReciter(r ?? audio.reciter),
              child: Column(
                children: [
                  for (var r = 0; r < reciters.length; r++)
                    RadioListTile(
                      value: r,
                      title: Text(reciters[r].name),
                      dense: true,
                    ),
                ],
              ),
            ),
            const Divider(),
            Text(
              'تكرار كل آية: ${audio.repeats} '
              '${audio.repeats == 1 ? 'مرة' : 'مرات'}',
              style: theme.textTheme.titleMedium,
            ),
            Slider(
              value: audio.repeats.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '${audio.repeats}',
              onChanged: (v) => controller.setRepeats(v.round()),
            ),
            Text('عند انتهاء التلاوة', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<AudioLoop>(
              showSelectedIcon: false,
              segments: [
                for (final l in AudioLoop.values)
                  ButtonSegment(
                    value: l,
                    label: Text(switch (l) {
                      AudioLoop.none => 'أكمل',
                      AudioLoop.ayah => 'الآية',
                      AudioLoop.page => 'الصفحة',
                      AudioLoop.surah => 'السورة',
                    }),
                  ),
              ],
              selected: {audio.loop},
              onSelectionChanged: (s) {
                while (ref.read(audioProvider).loop != s.first) {
                  controller.cycleLoop();
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              'سرعة التلاوة: ${audio.speed}×',
              style: theme.textTheme.titleMedium,
            ),
            Slider(
              value: audio.speed,
              min: 0.5,
              max: 1.5,
              divisions: 4,
              label: '${audio.speed}×',
              onChanged: controller.setSpeed,
            ),
            Text(
              'التلاوات من موقع everyayah.com وتحتاج اتصالًا بالإنترنت.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
