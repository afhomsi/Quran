import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/marks.dart';
import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/quran_models.dart';
import '../../data/quran_repository.dart';
import '../../data/reading_state.dart';
import '../shell/navigation.dart';

/// "My bookmarks": the reading, hifz and review markers, highlighted
/// ayat (filterable by color) and saved ayat.
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
    final highlights = ref.watch(highlightsProvider);
    final saved = ref.watch(bookmarksProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('علاماتي'), centerTitle: true),
      body: mushaf == null || surahs == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                for (final kind in MarkerKind.values) ...[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Chip(
                      label: Text(kind.label),
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
                      title: ayahTitle(surahs, ayah),
                      trailingText: 'الصفحة ${mushaf.pageOf(ayah)}',
                      onOpen: () => openMushaf(
                        context,
                        mushaf.pageOf(ayah),
                        highlight: ayah,
                      ),
                      onRemove: () =>
                          ref.read(markersProvider.notifier).clear(kind),
                    )
                  else
                    _EmptyRow(
                      'لم تضع ${kind.label} بعد. اضغط مطولًا على آية في '
                      'المصحف لوضعها.',
                    ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'تلوين',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    PopupMenuButton<int>(
                      tooltip: 'تصفية حسب اللون',
                      icon: Icon(
                        _colorFilter == null
                            ? Icons.filter_alt_outlined
                            : Icons.filter_alt,
                        color: _colorFilter == null
                            ? null
                            : highlightColors[_colorFilter!],
                      ),
                      onSelected: (c) =>
                          setState(() => _colorFilter = c < 0 ? null : c),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: -1,
                          child: Text('كل الألوان'),
                        ),
                        for (var c = 0; c < highlightColors.length; c++)
                          PopupMenuItem(
                            value: c,
                            child: Row(
                              children: [
                                _Swatch(highlightColors[c]),
                                const SizedBox(width: 12),
                                Text(highlightColorNames[c]),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                ..._highlightRows(mushaf, surahs, highlights),
                const SizedBox(height: 16),
                Text(
                  'آيات محفوظة',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (saved.isEmpty)
                  const _EmptyRow('لا توجد آيات محفوظة بعد.')
                else
                  for (final ayah in saved.reversed)
                    _MarkRow(
                      title: ayahTitle(surahs, ayah),
                      trailingText: 'الصفحة ${mushaf.pageOf(ayah)}',
                      onOpen: () => openMushaf(
                        context,
                        mushaf.pageOf(ayah),
                        highlight: ayah,
                      ),
                      onRemove: () =>
                          ref.read(bookmarksProvider.notifier).toggle(ayah),
                    ),
              ],
            ),
    );
  }

  List<Widget> _highlightRows(
    Mushaf mushaf,
    List<Surah> surahs,
    Map<AyahRef, int> highlights,
  ) {
    final shown = [
      for (final e in highlights.entries.toList().reversed)
        if (_colorFilter == null || e.value == _colorFilter) e,
    ];
    if (shown.isEmpty) {
      return [
        _EmptyRow(
          highlights.isEmpty
              ? 'لا توجد آيات ملونة بعد. اضغط مطولًا على آية لتلوينها.'
              : 'لا توجد آيات بهذا اللون.',
        ),
      ];
    }
    return [
      for (final e in shown)
        _MarkRow(
          title: surahs[e.key.surah - 1].name,
          subtitle: 'الصفحة ${mushaf.pageOf(e.key)} - الآية ${e.key.ayah}',
          swatch: highlightColors[e.value],
          onOpen: () =>
              openMushaf(context, mushaf.pageOf(e.key), highlight: e.key),
          onRemove: () => ref.read(highlightsProvider.notifier).remove(e.key),
        ),
    ];
  }
}

/// "البقرة : الآية 177".
String ayahTitle(List<Surah> surahs, AyahRef ayah) =>
    '${surahs[ayah.surah - 1].name} : الآية ${ayah.ayah}';

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
              Text(
                trailingText!,
                style: TextStyle(color: colors.tertiary, fontSize: 16),
              ),
            if (swatch != null) _Swatch(swatch!),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: colors.primary),
            IconButton(
              tooltip: 'حذف',
              icon: Icon(Icons.remove_circle_outline, color: colors.primary),
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
