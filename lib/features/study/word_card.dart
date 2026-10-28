import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/ayah_audio.dart';
import '../../data/mushaf_models.dart';
import '../../data/quran_repository.dart';
import '../../data/reading_state.dart';
import '../../data/study.dart';
import '../../l10n/strings.dart';
import '../notes/notes_screen.dart';
import 'ayah_tools.dart';
import 'study_content.dart';
import 'tajweed_view.dart';
import '../../data/mushaf_text.dart';

/// The word the reader pressed on the page: its ayah, its position in the
/// ayah, and where on the screen it is.
typedef WordSelection = ({AyahRef ayah, int position, Offset anchor});

/// What the word card shows; the reader's last choice is kept.
class WordCardTabNotifier extends Notifier<StudyTab> {
  @override
  StudyTab build() => StudyTab.wordMeaning;

  void set(StudyTab tab) => state = tab;
}

final wordCardTabProvider = NotifierProvider<WordCardTabNotifier, StudyTab>(
  WordCardTabNotifier.new,
);

/// A card over the page about one word: its meaning, qira'at, morphology,
/// i'rab or translation, with buttons to listen, read the ayah's tafsir,
/// bookmark, color, write a note or open the study panel.
class WordCard extends ConsumerWidget {
  const WordCard({
    super.key,
    required this.ayah,
    required this.position,
    required this.onMore,
    required this.onTafsir,
    required this.onClose,
  });

  final AyahRef ayah;
  final int position;

  /// Opens the study panel on this word.
  final VoidCallback onMore;

  /// Opens the study panel on the tafsir of this word's ayah.
  final VoidCallback onTafsir;

  /// Closes the card, e.g. once listening starts, to reach the player.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tab = ref.watch(wordCardTabProvider);
    final surahs = ref.watch(surahsProvider).value;
    final word = surahs == null
        ? ''
        : wordAt(surahs[ayah.surah - 1].ayahs[ayah.ayah - 1], position);
    return Material(
      elevation: 6,
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: colors.surfaceContainerHighest,
              foregroundColor: colors.onSurface,
            ),
            onPressed: () => _chooseTab(context, ref),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tab.label(t)),
                const Icon(Icons.arrow_drop_down_rounded),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.3,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: StudyContentView(
                request: (tab: tab, book: null, ayah: ayah, word: position),
                lead: word,
                compact: true,
              ),
            ),
          ),
          ColoredBox(
            color: colors.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _Action(
                    icon: Icons.play_arrow_rounded,
                    label: t.listen,
                    onTap: () {
                      ref.read(audioProvider.notifier).playFrom(ayah);
                      onClose();
                    },
                  ),
                  _Action(
                    icon: Icons.menu_book_rounded,
                    label: t.tafsir,
                    onTap: onTafsir,
                  ),
                  _Action(
                    icon: ref.watch(bookmarksProvider).contains(ayah)
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    label: t.bookmarkAction,
                    onTap: () => toggleBookmark(context, ref, ayah),
                  ),
                  _Action(
                    icon: Icons.format_color_fill_rounded,
                    label: t.colorAction,
                    onTap: () => showColorSheet(context, ayah),
                  ),
                  _Action(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: t.comments,
                    onTap: () => editNote(context, ayah, word: word),
                  ),
                  _Action(
                    icon: Icons.more_horiz_rounded,
                    label: t.studyMore,
                    onTap: onMore,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseTab(BuildContext context, WidgetRef ref) async {
    final tab = await showContentChooser(
      context,
      StudyTab.of(StudyPart.word),
      ref.read(wordCardTabProvider),
    );
    if (tab != null) ref.read(wordCardTabProvider.notifier).set(tab);
  }
}

/// "Choose the content": the tabs as chips in a bottom sheet.
Future<StudyTab?> showContentChooser(
  BuildContext context,
  List<StudyTab> tabs,
  StudyTab current,
) => showModalBottomSheet<StudyTab>(
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
              t.chooseContent,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final tab in tabs)
                  ChoiceChip(
                    label: Text(tab.label(t)),
                    selected: tab == current,
                    onSelected: (_) => Navigator.pop(context, tab),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  },
);

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shows the sections of [request] once they are loaded, with a way to try
/// again when they cannot be.
///
/// [lead], e.g. the word, is set before the first section in the Quran's
/// colour. [compact] keeps it to running text, as in the word card.
class StudyContentView extends ConsumerWidget {
  const StudyContentView({
    super.key,
    required this.request,
    this.lead,
    this.compact = false,
  });

  final StudyRequest request;
  final String? lead;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge!.copyWith(
      fontSize: compact ? 18 : 19,
      height: 1.8,
    );
    final quranColor = studyQuranColor(context);
    if (request.tab.isTajweed) {
      return TajweedView(
        ayah: request.ayah,
        word: request.tab == StudyTab.wordTajweed ? request.word : null,
        compact: compact,
      );
    }
    final content = ref.watch(studyContentProvider(request));
    final book = request.book ?? request.tab.books.firstOrNull;
    return switch (content) {
      AsyncData(:final value) when value.isEmpty => Text(
        book == null
            ? t.noWordMeaning
            : request.tab.part == StudyPart.word
            ? t.noWordEntry(book)
            : t.noAyahEntry(book),
        textAlign: TextAlign.center,
        style: body.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      AsyncData(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, s) in value.indexed)
            Padding(
              padding: EdgeInsets.only(bottom: compact ? 4 : 16),
              child: Text.rich(
                TextSpan(
                  children: [
                    if (i == 0 && lead != null && lead!.isNotEmpty)
                      TextSpan(
                        text: '${mushafDisplayText(lead!)}: ',
                        style: quranTextStyle(TextStyle(color: quranColor)),
                      ),
                    if (s.heading != null)
                      TextSpan(
                        text: '${s.heading} ',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ..._quranSpans(s.text, quranColor),
                  ],
                ),
                style: body,
                textAlign: compact ? TextAlign.start : TextAlign.justify,
                textDirection: book == StudyBook.english
                    ? TextDirection.ltr
                    : TextDirection.rtl,
              ),
            ),
          // The book is named under its text, as its licence asks.
          if (!compact && book != null)
            Text(
              t.source(book),
              style: theme.textTheme.bodySmall!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      AsyncError() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t.studyLoadError, textAlign: TextAlign.center, style: body),
          TextButton.icon(
            icon: const Icon(Icons.refresh_rounded),
            label: Text(t.retry),
            onPressed: () => ref.invalidate(studyContentProvider(request)),
          ),
        ],
      ),
      _ => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

/// The colour that Quran words take inside study texts.
Color studyQuranColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFE58FA6)
    : const Color(0xFF8E2442);

final _quote = RegExp('﴿[^﴾]*﴾|{[^}]*}');

/// [text] with the Quran it quotes, in ﴿ ﴾ or { }, in [color].
List<TextSpan> _quranSpans(String text, Color color) {
  final spans = <TextSpan>[];
  var start = 0;
  for (final m in _quote.allMatches(text)) {
    if (m.start > start) {
      spans.add(TextSpan(text: text.substring(start, m.start)));
    }
    spans.add(
      TextSpan(
        text: m[0],
        style: TextStyle(color: color),
      ),
    );
    start = m.end;
  }
  if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
  return spans;
}
