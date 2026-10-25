import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_downloads.dart';
import '../../audio/ayah_audio.dart';
import '../../data/quran_repository.dart';
import '../../l10n/strings.dart';
import '../../theme/app_theme.dart';

void openDownloads(BuildContext context, int reciter) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => DownloadsScreen(reciter: reciter)));

/// Downloads a reciter's surahs, or the whole Quran, to the phone, so they
/// play without internet, and removes them again.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key, required this.reciter});

  /// Index in [reciters].
  final int reciter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final r = reciters[reciter];
    final surahs = ref.watch(surahsProvider).value;
    final kept = ref.watch(keptAudioProvider(reciter)).value ?? const {};
    final size = ref.watch(keptAudioSizeProvider(reciter)).value ?? 0;
    final downloads = ref.watch(audioDownloadsProvider);
    final controller = ref.read(audioDownloadsProvider.notifier);
    if (surahs == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t.offlineAudio)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final complete = surahs.where((s) => surahProgress(r, s, kept) == 1).length;
    final busy = downloads.queue.any((d) => d.reciter == reciter);

    return Scaffold(
      appBar: AppBar(title: Text(t.offlineAudio), centerTitle: true),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: surahs.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t.reciterName(r),
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.downloadedSummary(complete, surahs.length, size),
                      key: const ValueKey('downloaded-summary'),
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.offlineAudioNote,
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    if (downloads.failed) ...[
                      const SizedBox(height: 8),
                      Text(
                        t.downloadFailed,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (busy)
                      OutlinedButton.icon(
                        key: const ValueKey('stop-downloads'),
                        icon: const Icon(Icons.stop_rounded),
                        label: Text(t.stopDownloads),
                        onPressed: () => controller.cancel(reciter),
                      )
                    else if (complete < surahs.length)
                      FilledButton.icon(
                        key: const ValueKey('download-all'),
                        icon: const Icon(Icons.download_rounded),
                        label: Text(t.downloadWholeQuran),
                        onPressed: () => controller.download(reciter, [
                          for (final s in surahs)
                            if (surahProgress(r, s, kept) < 1) s.number,
                        ]),
                      ),
                    if (kept.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        key: const ValueKey('delete-all'),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(t.deleteDownloads),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.error,
                        ),
                        onPressed: () async {
                          if (await _confirm(context, t.deleteDownloadsAsk)) {
                            await controller.delete(reciter);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          final surah = surahs[i - 1];
          final s = surah.number;
          final progress = surahProgress(r, surah, kept);
          final active = downloads.active == (reciter: reciter, surah: s);
          final waiting = downloads.waiting(reciter, s);
          final Widget trailing;
          if (active) {
            trailing = IconButton(
              tooltip: t.cancel,
              onPressed: () => controller.cancel(reciter, s),
              icon: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: downloads.progress,
                    strokeWidth: 3,
                  ),
                  const Icon(Icons.close_rounded, size: 18),
                ],
              ),
            );
          } else if (waiting) {
            trailing = IconButton(
              tooltip: t.cancel,
              onPressed: () => controller.cancel(reciter, s),
              icon: const Icon(Icons.schedule_rounded),
            );
          } else if (progress == 1) {
            trailing = IconButton(
              key: ValueKey('delete-surah-$s'),
              tooltip: t.deleteDownloads,
              onPressed: () => controller.delete(reciter, s),
              icon: Icon(Icons.delete_outline_rounded, color: colors.error),
            );
          } else {
            trailing = IconButton(
              key: ValueKey('download-surah-$s'),
              tooltip: t.download,
              onPressed: () => controller.download(reciter, [s]),
              icon: Icon(Icons.download_rounded, color: colors.primary),
            );
          }
          return ListTile(
            key: ValueKey('surah-download-$s'),
            leading: IconBadge(
              progress == 1
                  ? Icons.download_done_rounded
                  : Icons.cloud_outlined,
              color: progress == 1 ? colors.primary : colors.outline,
              size: 38,
            ),
            title: Text('${t.n(s)}. ${t.surahName(surah)}'),
            subtitle: progress > 0 && progress < 1 && !active
                ? Text(t.partlyDownloaded((progress * 100).floor()))
                : progress == 1
                ? Text(t.downloaded)
                : null,
            trailing: trailing,
          );
        },
      ),
    );
  }

  Future<bool> _confirm(BuildContext context, String question) async {
    final t = S.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(question),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(t.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(t.deleteDownloads),
              ),
            ],
          ),
        ) ??
        false;
  }
}
