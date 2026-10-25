import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/strings.dart';
import '../../recitation/offline_model.dart';
import '../../recitation/offline_speech.dart';
import '../../theme/app_theme.dart';

/// Offers the offline recitation model, shows its download, or says it is
/// in use. Shows nothing where the model cannot run (the web).
class OfflineModelTile extends ConsumerWidget {
  const OfflineModelTile({super.key, this.onlyToDownload = false});

  /// Shows only the offer and the download, not the model in use, for
  /// places with little room such as the reciting bar.
  final bool onlyToDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(offlineModelProvider);
    final notifier = ref.read(offlineModelProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final t = S.of(context);
    switch (model.status) {
      case OfflineModelStatus.unsupported || OfflineModelStatus.checking:
        return const SizedBox.shrink();
      case OfflineModelStatus.ready when onlyToDownload:
        return const SizedBox.shrink();
      case OfflineModelStatus.ready:
        return ListTile(
          leading: IconBadge(Icons.offline_bolt_rounded),
          title: Text(t.offlineRecitation),
          subtitle: Text(t.offlineRecitationReady),
          trailing: IconButton(
            tooltip: t.delete,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final yes = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  content: Text(t.deleteOfflineModelAsk),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(t.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(t.delete),
                    ),
                  ],
                ),
              );
              if (yes == true) await notifier.delete();
            },
          ),
        );
      case OfflineModelStatus.downloading:
        final progress = model.progress;
        return ListTile(
          dense: onlyToDownload,
          leading: IconBadge(Icons.downloading_rounded),
          title: Text(t.offlineRecitation),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.offlineRecitationDownloading(((progress ?? 0) * 100).floor()),
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: progress),
            ],
          ),
        );
      case OfflineModelStatus.missing:
        return ListTile(
          dense: onlyToDownload,
          contentPadding: onlyToDownload ? EdgeInsets.zero : null,
          leading: IconBadge(Icons.download_for_offline_rounded),
          title: Text(t.offlineRecitation),
          subtitle: Text(
            model.failed
                ? t.offlineRecitationFailed
                : t.offlineRecitationNote(offlineModelBytes),
            style: model.failed ? TextStyle(color: colors.error) : null,
          ),
          trailing: FilledButton(
            onPressed: notifier.download,
            child: Text(t.download),
          ),
        );
    }
  }
}
