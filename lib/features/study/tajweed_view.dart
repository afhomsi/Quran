import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mushaf_models.dart';
import '../../data/quran_repository.dart';
import '../../data/study.dart';
import '../../data/tajweed.dart';
import '../../l10n/strings.dart';
import '../../settings/app_settings.dart';
import '../../data/mushaf_text.dart';

/// The tajweed rules of an ayah, or of one word in it when [word] is given:
/// each rule in its colour, what it means and the words it is on. The rules
/// come from the colours of the mushaf's own tajweed fonts.
class TajweedView extends ConsumerWidget {
  const TajweedView({
    super.key,
    required this.ayah,
    this.word,
    this.compact = false,
  });

  final AyahRef ayah;
  final int? word;

  /// In the word card: the rules only, without the switch.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final map = ref.watch(tajweedProvider).value;
    final surahs = ref.watch(surahsProvider).value;
    if (map == null || surahs == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final words = ayahWords(surahs[ayah.surah - 1].ayahs[ayah.ayah - 1]);
    final onWords = map.ofAyah(ayah);
    if (word != null) onWords.removeWhere((position, _) => position != word);
    final rules = [
      for (final r in TajweedRule.values)
        if (onWords.values.any((s) => s.contains(r))) r,
    ];
    final tajweedOn = ref.watch(
      settingsProvider.select((s) => s.tajweedColors),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.brush_rounded),
            title: Text(t.tajweedOnPage),
            value: tajweedOn,
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .update((s) => s.copyWith(tajweedColors: v)),
          ),
        if (rules.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              t.noTajweedHere,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        for (final rule in rules)
          Container(
            margin: EdgeInsets.only(bottom: compact ? 6 : 10),
            padding: EdgeInsets.all(compact ? 8 : 12),
            decoration: BoxDecoration(
              color: rule.color(dark).withValues(alpha: 0.08),
              border: BorderDirectional(
                start: BorderSide(color: rule.color(dark), width: 4),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.tajweedName(rule),
                  style: TextStyle(
                    color: rule.color(dark),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(t.tajweedHelp(rule), style: const TextStyle(height: 1.6)),
                if (word == null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    textDirection: TextDirection.rtl,
                    children: [
                      for (final e in onWords.entries)
                        if (e.value.contains(rule) && e.key <= words.length)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              mushafDisplayText(words[e.key - 1]),
                              textDirection: TextDirection.rtl,
                              style: quranTextStyle(
                                TextStyle(
                                  fontSize: 19,
                                  color: rule.color(dark),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Every rule's colour and name, as a plain-text list for sharing.
String tajweedText(S t, TajweedMap map, AyahRef ayah, int? word, String text) {
  final words = ayahWords(text);
  final onWords = map.ofAyah(ayah);
  if (word != null) onWords.removeWhere((position, _) => position != word);
  return [
    for (final rule in TajweedRule.values)
      if (onWords.values.any((s) => s.contains(rule)))
        [
          '${t.tajweedName(rule)}: ${t.tajweedHelp(rule)}',
          if (word == null)
            [
              for (final e in onWords.entries)
                if (e.value.contains(rule) && e.key <= words.length)
                  words[e.key - 1],
            ].join('، '),
        ].join('\n'),
  ].join('\n\n');
}
