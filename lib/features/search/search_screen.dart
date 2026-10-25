import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mushaf_models.dart';
import '../../data/mushaf_text.dart';
import '../../data/quran_search.dart';
import '../../l10n/strings.dart';

/// Searches the Quran by its words or by their meaning. Closes with the
/// ayah the user picked.
class QuranSearchScreen extends ConsumerStatefulWidget {
  const QuranSearchScreen({super.key});

  @override
  ConsumerState<QuranSearchScreen> createState() => _QuranSearchScreenState();
}

class _QuranSearchScreenState extends ConsumerState<QuranSearchScreen> {
  /// The options stay as the user left them, until the app closes.
  static var _lastOptions = const SearchOptions();

  final _input = TextEditingController();
  Timer? _debounce;
  var _query = '';
  var _options = _lastOptions;

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    super.dispose();
  }

  void _typed(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = text);
    });
    // Show or hide the clear button at once.
    setState(() {});
  }

  /// The last search made and what it found. Typing redraws the screen
  /// at once, for the clear button, and must not search all the ayat again
  /// on every letter before the pause.
  (QuranSearchIndex, String, SearchOptions)? _searched;
  var _hits = const <SearchHit>[];

  List<SearchHit> _search(QuranSearchIndex index) {
    final key = (index, _query, _options);
    if (key != _searched) {
      _searched = key;
      _hits = index.search(_query, _options);
    }
    return _hits;
  }

  void _setOptions(SearchOptions options) =>
      setState(() => _options = _lastOptions = options);

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final index = ref.watch(quranSearchProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.searchQuran)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: _SearchBox(
              controller: _input,
              hint: t.searchModeHint(_options.mode),
              onChanged: _typed,
              onClear: () {
                _input.clear();
                _typed('');
              },
            ),
          ),
          _OptionsBar(options: _options, onChanged: _setOptions),
          const Divider(height: 1),
          Expanded(
            child: index.when(
              loading: () => _Message(t.searchLoading, busy: true),
              error: (e, _) => _Message('$e'),
              data: (index) => _Results(
                index: index,
                hits: _search(index),
                empty: SearchQuery(_query, _options).isEmpty,
                help: _options.mode == SearchMode.meaning
                    ? t.searchMeaningHelp
                    : t.searchOptionsHelp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded box to type in, with a clear button once there is text.
class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        prefixIcon: Icon(Icons.search_rounded, color: colors.primary),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: S.of(context).clearSearch,
                icon: const Icon(Icons.close_rounded),
                onPressed: onClear,
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

/// Where to search, and the options, all in sight under the search box.
class _OptionsBar extends StatelessWidget {
  const _OptionsBar({required this.options, required this.onChanged});

  final SearchOptions options;
  final ValueChanged<SearchOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final text = options.mode == SearchMode.text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<SearchMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: SearchMode.text,
                icon: const Icon(Icons.format_quote_rounded),
                label: Text(t.searchMode(SearchMode.text)),
              ),
              ButtonSegment(
                value: SearchMode.meaning,
                icon: const Icon(Icons.lightbulb_outline_rounded),
                label: Text(t.searchMode(SearchMode.meaning)),
              ),
            ],
            selected: {options.mode},
            onSelectionChanged: (s) =>
                onChanged(options.copyWith(mode: s.single)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                avatar: const Icon(Icons.crop_free_rounded, size: 18),
                label: Text(t.searchWholeWord),
                selected: options.wholeWord,
                showCheckmark: false,
                onSelected: (v) => onChanged(options.copyWith(wholeWord: v)),
              ),
              FilterChip(
                avatar: const Icon(Icons.scatter_plot_rounded, size: 18),
                label: Text(t.searchAnyOrder),
                selected: options.anyOrder,
                showCheckmark: false,
                onSelected: (v) => onChanged(options.copyWith(anyOrder: v)),
              ),
              if (text)
                FilterChip(
                  avatar: const Icon(Icons.menu_book_rounded, size: 18),
                  label: Text(t.searchWithTafsir),
                  selected: options.withTafsir,
                  showCheckmark: false,
                  onSelected: (v) => onChanged(options.copyWith(withTafsir: v)),
                ),
              if (options.changed)
                ActionChip(
                  avatar: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: Text(t.searchResetOptions),
                  onPressed: () => onChanged(options.reset()),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.busy = false, this.icon});

  final String text;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy) const CircularProgressIndicator(),
            if (icon != null) Icon(icon, size: 48, color: colors.primary),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.index,
    required this.hits,
    required this.empty,
    required this.help,
  });

  final QuranSearchIndex index;
  final List<SearchHit> hits;
  final bool empty;
  final String help;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    if (empty) return _Message(help, icon: Icons.manage_search_rounded);
    if (hits.isEmpty) {
      return _Message(t.noResults, icon: Icons.search_off_rounded);
    }
    final colors = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: hits.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  t.searchCount(hits.length),
                  style: TextStyle(color: colors.onSecondaryContainer),
                ),
              ),
            ),
          );
        }
        return _HitCard(index: index, hit: hits[i - 1]);
      },
    );
  }
}

/// One ayah found: where it is, its text, and the matches marked.
class _HitCard extends StatelessWidget {
  const _HitCard({required this.index, required this.hit});

  final QuranSearchIndex index;
  final SearchHit hit;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final colors = Theme.of(context).colorScheme;
    final surah = index.surahs[hit.ayah.surah - 1];
    final ayahText = mushafDisplayText(surah.ayahs[hit.ayah.ayah - 1]);
    final inAyah = hit.source == HitSource.ayah;
    final mark = colors.tertiaryContainer;
    final ayahStyle = TextStyle(
      fontFamily: mushafFont,
      fontSize: 22,
      height: 1.9,
      color: colors.onSurface,
    );
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pop<AyahRef>(hit.ayah),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: colors.primaryContainer,
                    child: Text(
                      t.n(hit.ayah.ayah),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.surah(surah),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text.rich(
                inAyah
                    ? _marked(ayahText, hit.ranges, ayahStyle, mark)
                    : TextSpan(text: ayahText, style: ayahStyle),
                textDirection: TextDirection.rtl,
                maxLines: inAyah ? null : 2,
                overflow: inAyah ? null : TextOverflow.ellipsis,
              ),
              if (!inAyah) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            hit.source == HitSource.tafsir
                                ? Icons.menu_book_rounded
                                : Icons.translate_rounded,
                            size: 16,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t.hitSource(hit.source),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: colors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _Snippet(hit: hit, mark: mark),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The part of a tafsir or translation around its first match.
class _Snippet extends StatelessWidget {
  const _Snippet({required this.hit, required this.mark});

  final SearchHit hit;
  final Color mark;

  @override
  Widget build(BuildContext context) {
    final (text, ranges) = snippet(hit.text, hit.ranges);
    final english = hit.source == HitSource.translation;
    return Text.rich(
      _marked(
        text,
        ranges,
        TextStyle(
          fontSize: 15,
          height: 1.7,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        mark,
      ),
      textDirection: english ? TextDirection.ltr : TextDirection.rtl,
    );
  }
}

/// [text] with [ranges] on a background of [mark].
TextSpan _marked(
  String text,
  List<(int, int)> ranges,
  TextStyle style,
  Color mark,
) {
  final spans = <TextSpan>[];
  var at = 0;
  for (final (a, b) in ranges) {
    if (a < at) continue;
    if (a > at) spans.add(TextSpan(text: text.substring(at, a)));
    spans.add(
      TextSpan(
        text: text.substring(a, b),
        style: TextStyle(backgroundColor: mark),
      ),
    );
    at = b;
  }
  if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
  return TextSpan(style: style, children: spans);
}

/// About [before] characters before the first of [ranges] and [after]
/// after it, cut at spaces, with the ranges moved to match.
(String, List<(int, int)>) snippet(
  String text,
  List<(int, int)> ranges, {
  int before = 70,
  int after = 160,
}) {
  if (ranges.isEmpty) return (text, ranges);
  var start = ranges.first.$1 - before;
  var end = ranges.first.$2 + after;
  if (start <= 0) {
    start = 0;
  } else {
    final space = text.indexOf(' ', start);
    start = space < 0 || space >= ranges.first.$1 ? start : space + 1;
  }
  if (end >= text.length) {
    end = text.length;
  } else {
    final space = text.lastIndexOf(' ', end);
    end = space <= ranges.first.$2 ? end : space;
  }
  final lead = start > 0 ? '… ' : '';
  final shift = lead.length - start;
  return (
    '$lead${text.substring(start, end)}${end < text.length ? ' …' : ''}',
    [
      for (final (a, b) in ranges)
        if (a >= start && b <= end) (a + shift, b + shift),
    ],
  );
}
