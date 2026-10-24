import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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
                icon: const Icon(Icons.close_rounded),
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
                markers[kind] == ayah
                    ? Icons.bookmark_remove_rounded
                    : Icons.bookmark_rounded,
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

/// What the study panel shares: the ayah (or surah or page) it is on, the
/// tab, the text shown and the book it comes from.
class ShareContent {
  const ShareContent({
    required this.title,
    required this.label,
    required this.body,
    this.source,
    this.quranTitle = false,
  });

  final String title;
  final String label;
  final String body;
  final String? source;

  /// [title] is Quran text, drawn in the Quran's colour.
  final bool quranTitle;

  String get text => [title, label, body, ?source].join('\n\n');
}

/// Shares [content] as text, an image or a PDF, or copies it.
Future<void> showShareSheet(BuildContext context, ShareContent content) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final t = S.of(context);
        final navigator = Navigator.of(context);
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
                        navigator.pop();
                        SharePlus.instance.share(
                          ShareParams(text: content.text),
                        );
                      },
                      child: Text(t.shareAsText),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        navigator.pop();
                        navigator.push(
                          MaterialPageRoute<void>(
                            fullscreenDialog: true,
                            builder: (_) => SharePreview(content: content),
                          ),
                        );
                      },
                      child: Text('${t.shareAsImage} / PDF'),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: content.text));
                        showToast(context, t.copied);
                        navigator.pop();
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

/// Shows [content] as a card, as it will look, and shares it as a PNG
/// image or as a one-page PDF of that image.
class SharePreview extends StatefulWidget {
  const SharePreview({super.key, required this.content});

  final ShareContent content;

  @override
  State<SharePreview> createState() => _SharePreviewState();
}

class _SharePreviewState extends State<SharePreview> {
  final _card = GlobalKey();
  bool _busy = false;

  /// Long tafsir is cut, so the picture stays readable.
  static const _maxBody = 2500;

  Future<Uint8List> _png() async {
    final boundary =
        _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  Future<void> _share({required bool pdf}) async {
    setState(() => _busy = true);
    try {
      final png = await _png();
      final XFile file;
      if (pdf) {
        final image = pw.MemoryImage(png);
        final doc = pw.Document()
          ..addPage(
            pw.Page(
              pageFormat: PdfPageFormat(
                PdfPageFormat.a4.width,
                PdfPageFormat.a4.width * image.height! / image.width!,
              ),
              margin: pw.EdgeInsets.zero,
              build: (_) => pw.Image(image, fit: pw.BoxFit.contain),
            ),
          );
        file = XFile.fromData(
          await doc.save(),
          mimeType: 'application/pdf',
          name: 'ayah.pdf',
        );
      } else {
        file = XFile.fromData(png, mimeType: 'image/png', name: 'ayah.png');
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          fileNameOverrides: [pdf ? 'ayah.pdf' : 'ayah.png'],
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final c = widget.content;
    final body = c.body.length > _maxBody
        ? '${c.body.substring(0, _maxBody)}…'
        : c.body;
    return Scaffold(
      appBar: AppBar(title: Text(t.sharePreview)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: RepaintBoundary(
          key: _card,
          child: ShareCard(
            title: c.title,
            label: c.label,
            body: body,
            source: c.source,
            quranTitle: c.quranTitle,
            footer: t.appName,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.image_rounded),
                  label: Text(t.shareAsImage),
                  onPressed: _busy ? null : () => _share(pdf: false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: Text(t.shareAsPdf),
                  onPressed: _busy ? null : () => _share(pdf: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The picture that is shared: on a page-coloured card, the ayah or
/// title, the tab, the text and its source, and the app's name.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.title,
    required this.label,
    required this.body,
    required this.footer,
    this.source,
    this.quranTitle = false,
  });

  final String title;
  final String label;
  final String body;
  final String? source;
  final String footer;
  final bool quranTitle;

  @override
  Widget build(BuildContext context) {
    const paper = Color(0xFFFFF8EC);
    const ink = Color(0xFF2B2B2B);
    const green = Color(0xFF55692F);
    const quran = Color(0xFF8E2442);
    return Container(
      decoration: BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: green, width: 2),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 21,
              height: 1.9,
              color: quranTitle ? quran : ink,
              fontWeight: quranTitle ? null : FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.justify,
            textDirection: _isLatin(body)
                ? TextDirection.ltr
                : TextDirection.rtl,
            style: const TextStyle(fontSize: 17, height: 1.8, color: ink),
          ),
          if (source != null) ...[
            const SizedBox(height: 12),
            Text(source!, style: const TextStyle(fontSize: 13, color: green)),
          ],
          const Divider(color: green),
          Text(
            footer,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: green),
          ),
        ],
      ),
    );
  }
}

/// Whether [text] starts in Latin letters, e.g. the English translation.
bool _isLatin(String text) {
  final first = RegExp(r'[A-Za-z\u0600-\u06FF]').firstMatch(text)?[0];
  return first != null && RegExp('[A-Za-z]').hasMatch(first);
}
