import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/ayah_audio.dart';
import '../../data/mushaf_models.dart';
import '../../data/quran_models.dart';
import '../../data/quran_repository.dart';
import '../../data/recitation_history.dart';
import '../../l10n/strings.dart';
import '../audio/audio_bar.dart';
import '../audio/repeat_sheet.dart';

/// The reader's hifz profile: how much was recited, the ayat recited with
/// mistakes (to listen to and repeat), and every recitation check.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(recitationHistoryProvider);
    final surahs = ref.watch(surahsProvider).value;
    final audioVisible = ref.watch(audioProvider.select((a) => a.visible));
    final theme = Theme.of(context);
    final t = S.of(context);
    final sectionStyle = theme.textTheme.titleLarge?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.bold,
    );
    if (surahs == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final byAyah = mistakesByAyah(history);
    final totalMistakes = history.fold(0, (sum, r) => sum + r.mistakes.length);
    final perfect = history
        .where((r) => r.complete && r.mistakes.isEmpty)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.profileTitle),
        centerTitle: true,
        actions: [
          if (history.isNotEmpty)
            IconButton(
              tooltip: t.clearHistory,
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: () => _confirmClear(context, ref),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    _Stat(label: t.recitationsLabel, value: history.length),
                    _Stat(label: t.withoutMistakes, value: perfect),
                    _Stat(label: t.mistakesLabel, value: totalMistakes),
                  ],
                ),
                const SizedBox(height: 24),
                if (history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      t.noHistory,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                if (byAyah.isNotEmpty) ...[
                  Text(t.ayatWithMistakes, style: sectionStyle),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.playlist_play_rounded),
                    label: Text(t.listenToAll),
                    onPressed: () => showRepeatSheet(
                      context,
                      ayat: [for (final (a, _) in byAyah) a]..sort(),
                      title: t.ayatWithMistakes,
                    ),
                  ),
                  for (final (ayah, count) in byAyah)
                    _MistakeAyahTile(ayah: ayah, count: count, surahs: surahs),
                  const SizedBox(height: 24),
                ],
                if (history.isNotEmpty) ...[
                  Text(t.historyTitle, style: sectionStyle),
                  const SizedBox(height: 8),
                  for (final record in history)
                    _RecordTile(record: record, surahs: surahs),
                ],
              ],
            ),
          ),
          if (audioVisible) const SafeArea(top: false, child: AudioBar()),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final t = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(t.clearHistoryQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.clear),
          ),
        ],
      ),
    );
    if (ok ?? false) ref.read(recitationHistoryProvider.notifier).clear();
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Text(
                S.of(context).n(value),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plays [ayah] right away, with the repeats chosen last time.
void _playNow(WidgetRef ref, List<AyahRef> ayat) {
  final audio = ref.read(audioProvider);
  ref
      .read(audioProvider.notifier)
      .playList(
        ayat,
        ayahRepeats: audio.repeats,
        listRepeats: audio.listRepeats,
      );
}

class _MistakeAyahTile extends ConsumerWidget {
  const _MistakeAyahTile({
    required this.ayah,
    required this.count,
    required this.surahs,
  });

  final AyahRef ayah;
  final int count;
  final List<Surah> surahs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final surah = surahs[ayah.surah - 1];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(t.surahAyah(surah, ayah.ayah)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            surah.ayahs[ayah.ayah - 1],
            textDirection: TextDirection.rtl,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, height: 1.7),
          ),
          Text(
            t.mistakeTimes(count),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: t.play,
            icon: const Icon(Icons.play_circle_outline_rounded),
            onPressed: () => _playNow(ref, [ayah]),
          ),
          IconButton(
            tooltip: t.repeatAyat,
            icon: const Icon(Icons.repeat_rounded),
            onPressed: () => showRepeatSheet(
              context,
              ayat: [ayah],
              title: t.surahAyah(surah, ayah.ayah),
            ),
          ),
        ],
      ),
    );
  }
}

/// One recitation check, opening to its mistakes.
class _RecordTile extends ConsumerWidget {
  const _RecordTile({required this.record, required this.surahs});

  final RecitationRecord record;
  final List<Surah> surahs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final theme = Theme.of(context);
    final title = record.surah != null
        ? t.reciteSurahTitle(surahs[record.surah! - 1])
        : t.recitePageTitle(record.page ?? 1);
    final mistakeAyat = record.mistakeAyat;
    final status = record.mistakes.isEmpty
        ? t.withoutMistakes
        : t.mistakesCount(record.mistakes.length);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(
          record.mistakes.isEmpty
              ? Icons.check_circle_rounded
              : Icons.error_outline_rounded,
          color: record.mistakes.isEmpty
              ? Colors.green.shade700
              : theme.colorScheme.error,
        ),
        title: Text(title),
        subtitle: Text(
          '${t.date(record.date)} · $status'
          '${record.complete ? '' : ' · ${t.notFinished}'}',
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Text(
            t.recitedRange(
              t.surahAyah(surahs[record.first.surah - 1], record.first.ayah),
              t.surahAyah(surahs[record.last.surah - 1], record.last.ayah),
            ),
          ),
          Text(
            t.wordsDone(record.wordsDone, record.wordsTotal),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.headphones_rounded),
                label: Text(t.listenToRecited),
                onPressed: () => showRepeatSheet(
                  context,
                  from: record.first,
                  to: record.last,
                ),
              ),
              if (mistakeAyat.isNotEmpty)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.replay_rounded),
                  label: Text(t.listenToMistakes),
                  onPressed: () => showRepeatSheet(
                    context,
                    ayat: mistakeAyat,
                    title: t.listenToMistakes,
                  ),
                ),
            ],
          ),
          for (final m in record.mistakes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                Icons.warning_amber_rounded,
                color: theme.colorScheme.error,
              ),
              title: Text(m.message),
              trailing: m.ayah == null
                  ? null
                  : IconButton(
                      tooltip: t.play,
                      icon: const Icon(Icons.play_circle_outline_rounded),
                      onPressed: () => _playNow(ref, [m.ayah!]),
                    ),
            ),
        ],
      ),
    );
  }
}
