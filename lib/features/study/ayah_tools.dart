import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/marks.dart';
import '../../data/mushaf_models.dart';
import '../../data/reading_state.dart';
import '../../l10n/strings.dart';

/// A short message floating over the bottom of the screen, as after
/// adding a bookmark.
void showToast(BuildContext context, String message) {
  final colors = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onTertiaryContainer, fontSize: 16),
        ),
        backgroundColor: colors.tertiaryContainer,
        behavior: SnackBarBehavior.floating,
        shape: const StadiumBorder(),
        margin: const EdgeInsets.symmetric(horizontal: 48, vertical: 96),
        duration: const Duration(seconds: 2),
      ),
    );
}

/// Adds [ayah] to the saved ayat, or takes it out, and says which.
void toggleBookmark(BuildContext context, WidgetRef ref, AyahRef ayah) {
  final t = S.of(context);
  final had = ref.read(bookmarksProvider).contains(ayah);
  ref.read(bookmarksProvider.notifier).toggle(ayah);
  showToast(context, had ? t.bookmarkRemoved : t.bookmarkAdded);
}

/// Lets the reader color [ayah] with one of the highlighter colors, or
/// take its color away.
Future<void> showColorSheet(BuildContext context, AyahRef ayah) =>
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => _ColorSheet(ayah: ayah),
    );

class _ColorSheet extends ConsumerStatefulWidget {
  const _ColorSheet({required this.ayah});

  final AyahRef ayah;

  @override
  ConsumerState<_ColorSheet> createState() => _ColorSheetState();
}

class _ColorSheetState extends ConsumerState<_ColorSheet> {
  late int? _color = ref.read(highlightsProvider)[widget.ayah];

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final colors = Theme.of(context).colorScheme;
    final had = ref.watch(highlightsProvider).containsKey(widget.ayah);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IconButton(
                tooltip: t.close,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              runSpacing: 18,
              children: [
                for (var c = 0; c < highlightColors.length; c++)
                  Tooltip(
                    message: t.colorNames[c],
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: highlightColors[c],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == c
                                ? colors.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FilledButton(
                  onPressed: _color == null
                      ? null
                      : () {
                          ref
                              .read(highlightsProvider.notifier)
                              .set(widget.ayah, _color!);
                          Navigator.pop(context);
                        },
                  child: Text(t.colorAction),
                ),
                TextButton(
                  onPressed: had
                      ? () {
                          ref
                              .read(highlightsProvider.notifier)
                              .remove(widget.ayah);
                          Navigator.pop(context);
                        }
                      : null,
                  child: Text(t.removeColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A button that opens the three place markers (reading, hifz, review) to
/// put one of them on [ayah], or take it away.
class MarkerMenuButton extends ConsumerWidget {
  const MarkerMenuButton({super.key, required this.ayah, required this.child});

  final AyahRef ayah;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final markers = ref.watch(markersProvider);
    return PopupMenuButton<MarkerKind>(
      tooltip: t.bookmarkAction,
      onSelected: (kind) {
        final notifier = ref.read(markersProvider.notifier);
        markers[kind] == ayah ? notifier.clear(kind) : notifier.set(kind, ayah);
      },
      itemBuilder: (context) => [
        for (final kind in MarkerKind.values)
          PopupMenuItem(
            value: kind,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                markers[kind] == ayah ? Icons.bookmark_remove : Icons.bookmark,
                color: kind.color,
              ),
              title: Text(
                markers[kind] == ayah
                    ? t.removeMarker(kind)
                    : t.markerName(kind),
              ),
            ),
          ),
      ],
      child: child,
    );
  }
}

/// Shares or copies [text], the content being shown.
Future<void> showShareSheet(BuildContext context, String text) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final t = S.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.shareCurrent,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        SharePlus.instance.share(ShareParams(text: text));
                      },
                      child: Text(t.shareAsText),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: text));
                        showToast(context, t.copied);
                        Navigator.pop(context);
                      },
                      child: Text(t.copyText),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
