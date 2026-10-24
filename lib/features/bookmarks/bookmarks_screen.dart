import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/marks.dart';
import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/quran_models.dart';
import '../../data/quran_repository.dart';
import '../../data/reading_state.dart';
import '../../l10n/strings.dart';
import '../shell/navigation.dart';

/// "My marks": the reading, hifz and review markers, highlighted ayat
/// (filterable by color) and saved ayat.
class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  /// Index in [highlightColors] to show, or null for every color.
  int? _colorFilter;

  @override
  Widget build(BuildContext context) {
    final mushaf = ref.watch(mushafProvider).value;
    final surahs = ref.watch(surahsProvider).value;
    final markers = ref.watch(markersProvider);
    final saved = ref.watch(bookmarksProvider);
    final theme = Theme.of(context);
    final t = S.of(context);
    final sectionStyle = theme.textTheme.titleLarge?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.bold,
    );

    void open(AyahRef ayah) =>
        openMushaf(context, mushaf!.pageOf(ayah), highlight: ayah);

    return Scaffold(
      appBar: AppBar(title: Text(t.tabBookmarks), centerTitle: true),
      body: mushaf == null || surahs == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                for (final kind in MarkerKind.values) ...[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Chip(
                      label: Text(t.markerName(kind)),
                      labelStyle: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                      backgroundColor: kind.color,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                    ),
                  ),
                  if (markers[kind] case final ayah?)
                    _MarkRow(
                      title: t.surahAyah(surahs[ayah.surah - 1], ayah.ayah),
                      trailingText: t.page(mushaf.pageOf(ayah)),
                      onOpen: () => open(ayah),
                      onRemove: () =>
                          ref.read(markersProvider.notifier).clear(kind),
                    )
                  else
                    _EmptyRow(t.noMarker(kind)),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    const SizedBox(width: 48),
                    Expanded(
                      child: Text(
                        t.highlights,
                        textAlign: TextAlign.center,
                        style: sectionStyle,
                      ),
                    ),
                    PopupMenuButton<int>(
                      tooltip: t.filterByColor,
                      icon: Icon(
                        _colorFilter == null
                            ? Icons.filter_alt_outlined
                            : Icons.filter_alt_rounded,
                        color: _colorFilter == null
                            ? null
                            : highlightColors[_colorFilter!],
                      ),
                      onSelected: (c) =>
                          setState(() => _colorFilter = c < 0 ? null : c),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: -1, child: Text(t.allColors)),
                        for (var c = 0; c < highlightColors.length; c++)
                          PopupMenuItem(
                            value: c,
                            child: Row(
                              children: [
                                _Swatch(highlightColors[c]),
                                const SizedBox(width: 12),
                                Text(t.colorNames[c]),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                ..._highlightRows(t, mushaf, surahs, open),
                const SizedBox(height: 16),
                Text(
                  t.savedAyat,
                  textAlign: TextAlign.center,
                  style: sectionStyle,
                ),
                if (saved.isEmpty)
                  _EmptyRow(t.noSavedAyat)
                else
                  for (final ayah in saved.reversed)
                    _MarkRow(
                      title: t.surahAyah(surahs[ayah.surah - 1], ayah.ayah),
                      trailingText: t.page(mushaf.pageOf(ayah)),
                      onOpen: () => open(ayah),
                      onRemove: () =>
                          ref.read(bookmarksProvider.notifier).toggle(ayah),
                    ),
              ],
            ),
    );
  }

  List<Widget> _highlightRows(
    S t,
    Mushaf mushaf,
    List<Surah> surahs,
    void Function(AyahRef) open,
  ) {
    final highlights = ref.watch(highlightsProvider);
    final shown = [
      for (final e in highlights.entries.toList().reversed)
        if (_colorFilter == null || e.value == _colorFilter) e,
    ];
    if (shown.isEmpty) {
      return [
        _EmptyRow(highlights.isEmpty ? t.noHighlights : t.noHighlightsInColor),
      ];
    }
    return [
      for (final e in shown)
        _MarkRow(
          title: t.surahName(surahs[e.key.surah - 1]),
          subtitle: t.pageAndAyah(mushaf.pageOf(e.key), e.key.ayah),
          swatch: highlightColors[e.value],
          onOpen: () => open(e.key),
          onRemove: () => ref.read(highlightsProvider.notifier).remove(e.key),
        ),
    ];
  }
}

class _MarkRow extends StatelessWidget {
  const _MarkRow({
    required this.title,
    this.subtitle,
    this.trailingText,
    this.swatch,
    required this.onOpen,
    required this.onRemove,
  });

  final String title;
  final String? subtitle;
  final String? trailingText;
  final Color? swatch;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.only(start: 20, end: 8),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        onTap: onOpen,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingText != null)
              Text(trailingText!, style: TextStyle(color: colors.tertiary)),
            if (swatch != null) _Swatch(swatch!),
            const SizedBox(width: 8),
            // Mirrors in right-to-left, so it points left, at the page.
            Icon(Icons.chevron_right_rounded, color: colors.primary),
            IconButton(
              tooltip: S.of(context).delete,
              icon: Icon(
                Icons.remove_circle_outline_rounded,
                color: colors.primary,
              ),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    child: Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}
