import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/page_fonts.dart';
import '../../data/quran_models.dart';
import '../../data/quran_repository.dart';
import '../../data/reading_state.dart';
import '../../l10n/strings.dart';
import '../../settings/app_settings.dart';
import '../recitation/recitation_picker.dart';
import '../settings/settings_screen.dart';
import 'go_to_dialog.dart';
import 'mushaf_page_view.dart';

/// Swipeable 604-page mushaf. Remembers the last page read.
///
/// Follows the settings: two facing pages on a wide screen, vertical
/// scrolling, automatic page turning, the page color and the ayah menu on
/// a single tap.
class MushafScreen extends ConsumerStatefulWidget {
  const MushafScreen({super.key, required this.initialPage, this.highlight});

  final int initialPage;

  /// Ayah to highlight on open, e.g. when coming from a bookmark.
  final AyahRef? highlight;

  @override
  ConsumerState<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends ConsumerState<MushafScreen> {
  /// Whether each slide shows two facing pages instead of one.
  bool _spread = false;
  late PageController _controller = PageController(
    initialPage: _indexOf(widget.initialPage),
  );

  /// The page shown, or the right-hand page of the two facing pages.
  late int _page = widget.initialPage;
  late AyahRef? _selected = widget.highlight;

  Timer? _autoTurn;
  bool _autoTurnPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPageChanged(_page));
  }

  @override
  void dispose() {
    _autoTurn?.cancel();
    _controller.dispose();
    super.dispose();
  }

  int get _step => _spread ? 2 : 1;

  int get _slideCount => _spread ? (mushafPageCount + 1) ~/ 2 : mushafPageCount;

  /// The slide that shows [page].
  int _indexOf(int page) => _spread ? (page - 1) ~/ 2 : page - 1;

  /// The first page on slide [index].
  int _pageAt(int index) => _spread ? index * 2 + 1 : index + 1;

  /// Switches between one and two pages per slide, staying on the same page.
  void _useSpread(bool spread) {
    if (spread == _spread) return;
    final old = _controller;
    _spread = spread;
    _page = _pageAt(_indexOf(_page));
    _controller = PageController(initialPage: _indexOf(_page));
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void _onPageChanged(int page) {
    setState(() => _page = page);
    ref.read(lastPageProvider.notifier).set(page);
    final fonts = ref.read(pageFontsProvider);
    for (var p = page - _step; p < page + 2 * _step; p++) {
      if (p >= 1 && p <= mushafPageCount && p != page) fonts.load(p);
    }
    _scheduleAutoTurn();
  }

  /// Turns the page after the chosen time, if automatic turning is on.
  void _scheduleAutoTurn() {
    _autoTurn?.cancel();
    final settings = ref.read(settingsProvider);
    if (!settings.autoPageTurn || _autoTurnPaused) return;
    _autoTurn = Timer(Duration(seconds: settings.autoPageSeconds), _nextPage);
  }

  @override
  Widget build(BuildContext context) {
    final mushaf = ref.watch(mushafProvider).value;
    final surahs = ref.watch(surahsProvider).value;
    final settings = ref.watch(settingsProvider);
    ref.listen(
      settingsProvider.select((s) => (s.autoPageTurn, s.autoPageSeconds)),
      (_, _) => _scheduleAutoTurn(),
    );
    if (mushaf == null || surahs == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final t = S.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? null : settings.pageTheme.color;
    final vertical = settings.verticalScroll;
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        actions: [
          if (settings.autoPageTurn)
            IconButton(
              tooltip: _autoTurnPaused ? t.resumeAutoTurn : t.pauseAutoTurn,
              icon: Icon(_autoTurnPaused ? Icons.play_arrow : Icons.pause),
              onPressed: () {
                setState(() => _autoTurnPaused = !_autoTurnPaused);
                _scheduleAutoTurn();
              },
            ),
          IconButton(
            tooltip: t.goTo,
            icon: const Icon(Icons.numbers),
            onPressed: () => _goToPage(context),
          ),
          IconButton(
            tooltip: t.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => openSettings(context),
          ),
          if (!settings.hideRecitationButton)
            FilledButton.tonalIcon(
              icon: const Icon(Icons.mic),
              label: Text(t.recite),
              onPressed: () => showRecitationPicker(context, page: _page),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: CallbackShortcuts(
        // Pages turn right to left, so the left arrow goes forward.
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): _nextPage,
          const SingleActivator(LogicalKeyboardKey.arrowRight): _previousPage,
          const SingleActivator(LogicalKeyboardKey.arrowDown): _nextPage,
          const SingleActivator(LogicalKeyboardKey.arrowUp): _previousPage,
        },
        child: Focus(
          autofocus: true,
          child: SafeArea(
            // The mushaf reads right to left in every app language.
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        _useSpread(
                          settings.twoPagesInLandscape &&
                              box.maxWidth > box.maxHeight,
                        );
                        return PageView.builder(
                          key: ValueKey((_spread, vertical)),
                          controller: _controller,
                          scrollDirection: vertical
                              ? Axis.vertical
                              : Axis.horizontal,
                          // Vertical pages scroll freely, like a long sheet.
                          pageSnapping: !vertical,
                          // Let a mouse drag turn pages too, not only touch.
                          scrollBehavior: ScrollConfiguration.of(context)
                              .copyWith(
                                dragDevices: PointerDeviceKind.values.toSet(),
                              ),
                          itemCount: _slideCount,
                          onPageChanged: (i) => _onPageChanged(_pageAt(i)),
                          itemBuilder: (context, i) {
                            final first = _pageAt(i);
                            if (!_spread) return _slot(mushaf, surahs, first);
                            return Row(
                              children: [
                                Expanded(child: _slot(mushaf, surahs, first)),
                                const VerticalDivider(width: 1),
                                Expanded(
                                  child: first + 1 <= mushafPageCount
                                      ? _slot(mushaf, surahs, first + 1)
                                      : const SizedBox(),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                  _PageBar(
                    label: _spread && _page + 1 <= mushafPageCount
                        ? '${t.n(_page)} – ${t.n(_page + 1)}'
                        : t.n(_page),
                    onPrevious: _page > 1 ? _previousPage : null,
                    onNext: _page + _step <= mushafPageCount ? _nextPage : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _slot(Mushaf mushaf, List<Surah> surahs, int page) {
    final settings = ref.read(settingsProvider);
    return _PageSlot(
      page: mushaf.page(page),
      juz: mushaf.juzOfPage(page),
      hizb: mushaf.hizbOfPage(page),
      surahs: surahs,
      selected: _selected,
      showHizbMarks: settings.showHizbMarks,
      onAyahTap: settings.tapOpensAyahMenu
          ? (a) => _showAyahActions(context, a, surahs)
          : (a) => setState(() => _selected = _selected == a ? null : a),
      onAyahLongPress: (a) => _showAyahActions(context, a, surahs),
    );
  }

  void _nextPage() => _turnTo(_page + _step);

  void _previousPage() => _turnTo(_page - _step);

  void _turnTo(int page) {
    if (page < 1 || page > mushafPageCount || !_controller.hasClients) return;
    _controller.animateToPage(
      _indexOf(page),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _goToPage(BuildContext context) async {
    final target = await showGoToDialog(context);
    if (target == null) return;
    setState(() => _selected = target.ayah ?? _selected);
    _controller.jumpToPage(_indexOf(target.page));
  }

  void _showAyahActions(
    BuildContext context,
    AyahRef ayah,
    List<Surah> surahs,
  ) {
    setState(() => _selected = ayah);
    final text = surahs[ayah.surah - 1].ayahs[ayah.ayah - 1];
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final bookmarked = ref.watch(bookmarksProvider).contains(ayah);
          final t = S.of(context);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(t.ayahLabel(surahs[ayah.surah - 1], ayah.ayah)),
                ),
                ListTile(
                  leading: Icon(
                    bookmarked ? Icons.bookmark_remove : Icons.bookmark_add,
                  ),
                  title: Text(bookmarked ? t.removeBookmark : t.addBookmark),
                  onTap: () {
                    ref.read(bookmarksProvider.notifier).toggle(ayah);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: Text(t.copyAyah),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: text));
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Waits for the page font, then draws the page with its page number.
class _PageSlot extends ConsumerWidget {
  const _PageSlot({
    required this.page,
    required this.juz,
    required this.hizb,
    required this.surahs,
    required this.selected,
    required this.showHizbMarks,
    required this.onAyahTap,
    required this.onAyahLongPress,
  });

  final MushafPage page;
  final int juz;
  final int hizb;
  final List<Surah> surahs;
  final AyahRef? selected;
  final bool showHizbMarks;
  final ValueChanged<AyahRef> onAyahTap;
  final ValueChanged<AyahRef> onAyahLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fonts = ref.watch(pageFontsProvider);
    final t = S.of(context);
    // Header texts follow the app language, inside the right-to-left page.
    final textDirection = ref.watch(
      settingsProvider.select((s) => s.language.direction),
    );
    return FutureBuilder(
      future: fonts.ready(page.number),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(t.loadPageError(snapshot.error!)));
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final style = Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary);
        return LayoutBuilder(
          builder: (context, box) => Center(
            child: SizedBox(
              // Keep the header as wide as the text block, also on wide
              // screens where the page sits in the middle.
              width: mushafTextWidth(box.maxWidth - 16, box.maxHeight - 36),
              child: Column(
                children: [
                  // Running header, as printed: surah on the right, juz and
                  // hizb on the left.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            t.surah(surahs[page.firstAyah.surah - 1]),
                            textDirection: textDirection,
                            style: style,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            t.juzAndHizb(juz, hizb),
                            textDirection: textDirection,
                            style: style,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 8),
                  Expanded(
                    child: MushafPageView(
                      page: page,
                      surahName: (s) => surahs[s - 1].name,
                      selected: selected,
                      showHizbMarks: showHizbMarks,
                      onAyahTap: onAyahTap,
                      onAyahLongPress: onAyahLongPress,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Previous and next page buttons around the page number. The previous
/// page is on the right, as in a printed mushaf.
class _PageBar extends StatelessWidget {
  const _PageBar({required this.label, this.onPrevious, this.onNext});

  /// The page number, or the two numbers of facing pages.
  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: t.previousPage,
          // Chevrons mirror in right-to-left layouts, so this one points
          // right, away from the page number.
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 56),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: t.nextPage,
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    );
  }
}
