import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/strings.dart';
import '../../settings/app_settings.dart';

/// One press of the smaller or larger buttons.
const _step = 0.1;

/// Opens a sheet under the page to make the mushaf text smaller or larger.
Future<void> showTextSizeSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            S.of(context).textSize,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const MushafTextSizeControl(),
          Text(
            S.of(context).textSizeHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  ),
);

/// Smaller and larger buttons around a slider of the mushaf text size, as
/// a percentage of the size that fits the printed page.
class MushafTextSizeControl extends ConsumerWidget {
  const MushafTextSizeControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final scale = ref.watch(settingsProvider.select((s) => s.mushafTextScale));
    void set(double v) => ref
        .read(settingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            // Kept to tenths, so 1 can be found again.
            mushafTextScale: ((v * 10).round() / 10).clamp(
              minMushafTextScale,
              maxMushafTextScale,
            ),
          ),
        );
    final percent = '${t.n((scale * 100).round())}%';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: t.smallerText,
              icon: const Icon(Icons.text_decrease_rounded),
              onPressed: scale > minMushafTextScale + 0.01
                  ? () => set(scale - _step)
                  : null,
            ),
            Expanded(
              child: Slider(
                value: scale,
                min: minMushafTextScale,
                max: maxMushafTextScale,
                divisions: ((maxMushafTextScale - minMushafTextScale) / _step)
                    .round(),
                label: percent,
                onChanged: set,
              ),
            ),
            IconButton(
              tooltip: t.largerText,
              icon: const Icon(Icons.text_increase_rounded),
              onPressed: scale < maxMushafTextScale - 0.01
                  ? () => set(scale + _step)
                  : null,
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(percent, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(width: 12),
            TextButton(
              onPressed: (scale - 1).abs() < 0.01 ? null : () => set(1),
              child: Text(t.defaultTextSize),
            ),
          ],
        ),
      ],
    );
  }
}
