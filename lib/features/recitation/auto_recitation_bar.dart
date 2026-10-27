import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/strings.dart';
import '../../recitation/auto_recitation.dart';
import 'offline_model_tile.dart';

/// Shown under the mushaf page while the app looks for where the reciter
/// is; once found, the recitation bar takes its place on that page.
class AutoRecitationBar extends ConsumerWidget {
  const AutoRecitationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auto = ref.watch(autoRecitationProvider);
    if (auto == null) return const SizedBox();
    final controller = ref.read(autoRecitationProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final t = S.of(context);
    final String status;
    if (!auto.listening) {
      status = t.autoRecitePaused;
    } else if (auto.heard.split(' ').length >= 6) {
      status = t.autoReciteKeepGoing;
    } else {
      status = t.autoReciteSearching;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
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
            status,
            style: textTheme.labelLarge,
            textAlign: TextAlign.center,
          ),
          if (auto.error case final error?)
            Text(
              error,
              style: textTheme.bodyMedium?.copyWith(color: colors.error),
              textAlign: TextAlign.center,
            )
          else if (auto.heard.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                auto.heard,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const OfflineModelTile(onlyToDownload: true),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: t.closeRecitation,
                icon: Icon(Icons.cancel_rounded, color: colors.primary),
                onPressed: controller.close,
              ),
              IconButton.filled(
                tooltip: auto.listening ? t.stop : t.startRecitation,
                iconSize: 30,
                icon: Icon(
                  auto.listening ? Icons.stop_rounded : Icons.mic_rounded,
                ),
                onPressed: controller.toggleListening,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
