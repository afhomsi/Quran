import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_downloads.dart';
import '../../audio/ayah_audio.dart';
import '../../data/mushaf_models.dart';
import '../../data/quran_repository.dart';
import '../../l10n/strings.dart';
import '../../theme/app_theme.dart';
import 'downloads_screen.dart';

void openReciters(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RecitersScreen()));

/// Every reciter the app can play. Tapping one chooses them; the play
/// button beside them lets the user hear them first.
class RecitersScreen extends ConsumerWidget {
  const RecitersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    final controller = ref.read(audioProvider.notifier);
    final t = S.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final canDownload = ref.watch(audioStoreProvider).supported;

    return Scaffold(
      appBar: AppBar(title: Text(t.reciters), centerTitle: true),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: reciters.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.wifi_rounded, size: 18, color: colors.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.recitersNote,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          }
          final r = i - 1;
          final reciter = reciters[r];
          final chosen = r == audio.reciter;
          final playing = chosen && audio.playing;
          return Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: chosen
                  ? BorderSide(color: colors.primary, width: 1.5)
                  : BorderSide.none,
            ),
            child: ListTile(
              key: ValueKey('reciter-$r'),
              contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
              leading: IconBadge(
                chosen ? Icons.check_rounded : Icons.record_voice_over_rounded,
                color: chosen ? colors.primary : colors.secondary,
                size: 42,
              ),
              title: Text(
                t.reciterName(reciter),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: chosen ? FontWeight.bold : null,
                ),
              ),
              subtitle: _Subtitle(reciter: r),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canDownload)
                    IconButton(
                      key: ValueKey('download-reciter-$r'),
                      tooltip: t.offlineAudio,
                      icon: Icon(
                        Icons.download_for_offline_rounded,
                        color: colors.secondary,
                        size: 30,
                      ),
                      onPressed: () => openDownloads(context, r),
                    ),
                  IconButton(
                    tooltip: playing ? t.pause : t.listenToReciter,
                    icon: Icon(
                      playing
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: colors.primary,
                      size: 36,
                    ),
                    onPressed: () {
                      if (playing) {
                        controller.togglePlay();
                        return;
                      }
                      // Choosing another reciter while playing starts them.
                      if (!chosen) controller.setReciter(r);
                      if (!ref.read(audioProvider).playing) {
                        controller.playFrom(
                          audio.current ?? const AyahRef(1, 1),
                        );
                      }
                    },
                  ),
                ],
              ),
              onTap: () => controller.setReciter(r),
            ),
          );
        },
      ),
    );
  }
}

/// How the reciter's recordings come, and how many surahs are downloaded.
class _Subtitle extends ConsumerWidget {
  const _Subtitle({required this.reciter});

  final int reciter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final theme = Theme.of(context);
    final r = reciters[reciter];
    final kept = ref.watch(keptAudioProvider(reciter)).value ?? const {};
    final surahs = ref.watch(surahsProvider).value ?? const [];
    final count = kept.isEmpty
        ? 0
        : surahs.where((s) => surahProgress(r, s, kept) == 1).length;
    return Text(
      [
        r.timed ? t.reciterTimed : t.reciterByAyah,
        if (count > 0) t.surahsDownloaded(count),
      ].join(' · '),
      style: theme.textTheme.bodySmall,
    );
  }
}
