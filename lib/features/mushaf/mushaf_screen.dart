import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/ayah_audio.dart';
import '../../data/arabic_search.dart';
import '../../data/khatma.dart';
import '../../data/marks.dart';
import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/page_fonts.dart';
import '../../data/quran_models.dart';
import '../../data/quran_repository.dart';
import '../../data/reading_state.dart';
import '../../l10n/strings.dart';
import '../../recitation/page_recitation.dart';
import '../../settings/app_settings.dart';
import '../audio/audio_bar.dart';
import '../audio/repeat_sheet.dart';
import '../notes/notes_screen.dart';
import '../recitation/recitation_bar.dart';
import '../recitation/recitation_picker.dart';
import '../settings/settings_screen.dart';
import '../home/index_icons.dart';
import '../shell/navigation.dart';
import 'go_to_dialog.dart';
import 'mushaf_page_view.dart';

/// Swipeable 604-page mushaf. Remembers the last page read.
///
/// The top bar has a menu, night mode, a clock, a switch to plain text and
/// ayah search. Listening and reciting have their own buttons beside the
/// page number. The audio player sits under the page while it is open, and
/// the page follows the ayah being recited. Reciting the page also happens
/// here, from a bar under the page, with each recited ayah colored green or
/// red on the page.
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

  /// Show the ayat of the page as plain text instead of the printed page.
  bool _textMode = false;

  /// Whether the page navigator (thumbnails and a slider) is open.
  bool _navigator = false;

  /// Takes the arrow keys, also after coming back from another tab.
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPageChanged(_page));
  }

  @override
  void dispose() {
    _autoTurn?.cancel();
    _controller.dispose();
    _focus.dispose();
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
      if (p >= 1 && p <= mushafPageCount && p != page) {
        fonts.load(p, mushafPalette(context));
      }
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
    ref.listen(appTabProvider, (_, tab) {
      // After the tab is shown: hidden tabs cannot take focus.
      if (tab == AppTab.mushaf) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _focus.requestFocus(),
        );
      }
    });
    ref.listen(mushafJumpProvider, (_, jump) {
      if (jump == null) return;
      setState(() => _selected = jump.highlight);
      if (_controller.hasClients) _controller.jumpToPage(_indexOf(jump.page));
    });
    ref.listen(audioProvider.select((a) => a.current), (_, ayah) {
      final m = ref.read(mushafProvider).value;
      if (ayah == null || m == null || !ref.read(audioProvider).playing) {
        return;
      }
      final page = m.pageOf(ayah);
      if (page < _page || page >= _page + _step) _turnTo(page);
    });
    if (mushaf == null || surahs == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final t = S.of(context);
    final audio = ref.watch(audioProvider);
    final chrome = ref.watch(mushafChromeProvider);
    // The pages draw these, so redraw when they change.
    ref.watch(highlightsProvider);
    ref.watch(markersProvider);
    ref.watch(khatmaPlansProvider);
    final recitation = ref.watch(pageRecitationProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? null : settings.pageTheme.color;
    final vertical = settings.verticalScroll;
    final appDirection = settings.language.direction;
    final bars = <Widget>[
      if (recitation != null) const RecitationBar(),
      if (audio.visible) const AudioBar(),
      if (_navigator)
        _PageNavigator(
          page: _page,
          surahs: surahs,
          mushaf: mushaf,
          onGo: (page) => _controller.jumpToPage(_indexOf(page)),
          onClose: () => setState(() => _navigator = false),
        ),
    ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: background,
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
            focusNode: _focus,
            // The mushaf reads right to left in every app language.
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: CustomMultiChildLayout(
                delegate: _MushafLayout(
                  bottomInset: MediaQuery.viewPaddingOf(context).bottom,
                  chrome: chrome,
                ),
                children: [
                  LayoutId(
                    id: _Part.page,
                    child: SafeArea(
                      bottom: false,
                      // A tap on the page shows or hides the bars.
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            ref.read(mushafChromeProvider.notifier).toggle(),
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
                              // Vertical pages scroll freely, like a long
                              // sheet.
                              pageSnapping: !vertical,
                              // Let a mouse drag turn pages too, not only
                              // touch.
                              scrollBehavior: ScrollConfiguration.of(context)
                                  .copyWith(
                                    dragDevices: PointerDeviceKind.values
                                        .toSet(),
                                  ),
                              itemCount: _slideCount,
                              onPageChanged: (i) => _onPageChanged(_pageAt(i)),
                              itemBuilder: (context, i) {
                                final first = _pageAt(i);
                                if (!_spread) {
                                  return _slot(mushaf, surahs, first);
                                }
                                return Row(
                                  children: [
                                    Expanded(
                                      child: _slot(mushaf, surahs, first),
                                    ),
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
                    ),
                  ),
                  if (bars.isNotEmpty)
                    LayoutId(
                      id: _Part.bars,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: bars,
                      ),
                    ),
                  if (chrome)
                    LayoutId(
                      id: _Part.bottomChrome,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PageBar(
                            label: _spread && _page + 1 <= mushafPageCount
                                ? '${t.n(_page)} – ${t.n(_page + 1)}'
                                : t.n(_page),
                            onLabel: () => _showNavigator(true),
                            onPrevious: _page > 1 ? _previousPage : null,
                            onNext: _page + _step <= mushafPageCount
                                ? _nextPage
                                : null,
                            onListen: () => showRepeatSheet(
                              context,
                              from: mushaf.page(_page).firstAyah,
                              to: mushaf.page(_page).words.last.ayah,
                            ),
                            onRecite: settings.hideRecitationButton
                                ? null
                                : () => ref
                                      .read(pageRecitationProvider.notifier)
                                      .start(_page),
                          ),
                          Directionality(
                            textDirection: appDirection,
                            child: const AppNavigationBar(),
                          ),
                        ],
                      ),
                    ),
                  if (chrome)
                    LayoutId(
                      id: _Part.topChrome,
                      child: Directionality(
                        textDirection: appDirection,
                        child: _topBar(context, mushaf, surahs, background),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Opens or closes the page navigator. It opens with the bars hidden, as
  /// it takes their place under the page.
  void _showNavigator(bool open) {
    setState(() => _navigator = open);
    if (open) ref.read(mushafChromeProvider.notifier).set(false);
  }

  /// Menu, night mode, the clock, plain text and search, over the page.
  Widget _topBar(
    BuildContext context,
    Mushaf mushaf,
    List<Surah> surahs,
    Color? background,
  ) {
    final t = S.of(context);
    final settings = ref.read(settingsProvider);
    return Material(
      color: background ?? Theme.of(context).colorScheme.surface,
      elevation: 3,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              const SizedBox(width: 4),
              PopupMenuButton<VoidCallback>(
                tooltip: t.menu,
                icon: const Icon(Icons.menu),
                onSelected: (action) => action(),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: () => _goToPage(context),
                    child: ListTile(
                      leading: const Icon(Icons.numbers),
                      title: Text(t.goTo),
                    ),
                  ),
                  PopupMenuItem(
                    value: () => _showNavigator(true),
                    child: ListTile(
                      leading: const Icon(Icons.view_carousel_outlined),
                      title: Text(t.pageNavigator),
                    ),
                  ),
                  PopupMenuItem(
                    value: () => ref
                        .read(audioProvider.notifier)
                        .show(mushaf.page(_page).firstAyah),
                    child: ListTile(
                      leading: const Icon(Icons.headphones),
                      title: Text(t.listen),
                    ),
                  ),
                  if (!settings.hideRecitationButton)
                    PopupMenuItem(
                      value: () => showRecitationPicker(context, page: _page),
                      child: ListTile(
                        leading: const Icon(Icons.mic),
                        title: Text(t.recite),
                      ),
                    ),
                  if (settings.autoPageTurn)
                    PopupMenuItem(
                      value: () {
                        setState(() => _autoTurnPaused = !_autoTurnPaused);
                        _scheduleAutoTurn();
                      },
                      child: ListTile(
                        leading: Icon(
                          _autoTurnPaused ? Icons.play_arrow : Icons.pause,
                        ),
                        title: Text(
                          _autoTurnPaused ? t.resumeAutoTurn : t.pauseAutoTurn,
                        ),
                      ),
                    ),
                  PopupMenuItem(
                    value: () => openSettings(context),
                    child: ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: Text(t.settings),
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip: settings.nightMode ? t.dayMode : t.nightMode,
                icon: Icon(
                  settings.nightMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
                onPressed: () => ref
                    .read(settingsProvider.notifier)
                    .update((s) => s.copyWith(nightMode: !s.nightMode)),
              ),
              const Expanded(child: Center(child: _Clock())),
              IconButton(
                tooltip: _textMode ? t.pageView : t.textView,
                icon: Icon(
                  _textMode
                      ? Icons.auto_stories_outlined
                      : Icons.chrome_reader_mode_outlined,
                ),
                onPressed: () => setState(() => _textMode = !_textMode),
              ),
              IconButton(
                tooltip: t.searchQuran,
                icon: const Icon(Icons.search),
                onPressed: () => _search(context, mushaf, surahs),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slot(Mushaf mushaf, List<Surah> surahs, int page) {
    final settings = ref.read(settingsProvider);
    final audio = ref.read(audioProvider);
    final playing = audio.visible ? audio.current : null;
    if (_textMode) {
      return _TextPage(
        page: mushaf.page(page),
        surahs: surahs,
        selected: playing ?? _selected,
        onAyahTap: (a) => _showAyahActions(context, a, surahs),
      );
    }
    final highlights = ref.read(highlightsProvider);
    final markers = ref.read(markersProvider);
    final recitation = ref.read(pageRecitationProvider);
    return _PageSlot(
      page: mushaf.page(page),
      highlights: {
        for (final e in highlights.entries) e.key: highlightColors[e.value],
        if (recitation?.page == page)
          for (final e in recitation!.ayahStates.entries)
            e.key: e.value == AyahRecitation.mistake
                ? _mistakeColor
                : _correctColor,
      },
      bookmarks: [
        for (final kind in MarkerKind.values)
          if (markers[kind] case final a? when mushaf.pageOf(a) == page)
            (kind.color, S.of(context).markerName(kind)),
        for (final plan in ref.read(khatmaPlansProvider))
          if (plan.nextPortion(mushaf) case final i?
              when plan.portions(mushaf)[i].firstPage(mushaf) == page)
            (khatmaColors[plan.color], plan.title),
      ],
      juz: mushaf.juzOfPage(page),
      rub: mushaf.rubOfPage(page),
      surahs: surahs,
      selected: playing ?? _selected,
      showHizbMarks: settings.showHizbMarks,
      // Otherwise a tap goes to the page, which shows or hides the bars.
      onAyahTap: settings.tapOpensAyahMenu
          ? (a) => _showAyahActions(context, a, surahs)
          : null,
      onAyahLongPress: (a) => _showAyahActions(context, a, surahs),
      onSurahTap: () => openIndex(context, 0),
      onPageTap: () => _showNavigator(!_navigator),
      onJuzTap: () => openIndex(context, 1),
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
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final bookmarked = ref.watch(bookmarksProvider).contains(ayah);
          final markers = ref.watch(markersProvider);
          final highlight = ref.watch(highlightsProvider)[ayah];
          final hasNote = ref.watch(notesProvider).containsKey(ayah);
          final t = S.of(context);
          void done() => Navigator.pop(context);
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(t.ayahLabel(surahs[ayah.surah - 1], ayah.ayah)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.play_circle_outline),
                    title: Text(t.playFromHere),
                    onTap: () {
                      ref.read(audioProvider.notifier).playFrom(ayah);
                      done();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.playlist_play),
                    title: Text(t.repeatFromHere),
                    onTap: () {
                      done();
                      showRepeatSheet(this.context, from: ayah, to: ayah);
                    },
                  ),
                  for (final kind in MarkerKind.values)
                    ListTile(
                      leading: Icon(Icons.bookmark, color: kind.color),
                      title: Text(
                        markers[kind] == ayah
                            ? t.removeMarker(kind)
                            : t.setMarker(kind),
                      ),
                      onTap: () {
                        final notifier = ref.read(markersProvider.notifier);
                        markers[kind] == ayah
                            ? notifier.clear(kind)
                            : notifier.set(kind, ayah);
                        done();
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.format_color_fill),
                    title: Text(t.highlightAyah),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var c = 0; c < highlightColors.length; c++)
                            _ColorDot(
                              color: highlightColors[c],
                              tooltip: t.colorNames[c],
                              selected: highlight == c,
                              onTap: () {
                                ref
                                    .read(highlightsProvider.notifier)
                                    .set(ayah, c);
                                done();
                              },
                            ),
                          if (highlight != null)
                            IconButton(
                              tooltip: t.removeHighlight,
                              icon: const Icon(Icons.format_color_reset),
                              onPressed: () {
                                ref
                                    .read(highlightsProvider.notifier)
                                    .remove(ayah);
                                done();
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.chat_outlined),
                    title: Text(hasNote ? t.editNote : t.addNote),
                    onTap: () {
                      done();
                      editNote(this.context, ayah);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      bookmarked ? Icons.bookmark_remove : Icons.bookmark_add,
                    ),
                    title: Text(bookmarked ? t.removeBookmark : t.addBookmark),
                    onTap: () {
                      ref.read(bookmarksProvider.notifier).toggle(ayah);
                      done();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.copy),
                    title: Text(t.copyAyah),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: text));
                      done();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _search(
    BuildContext context,
    Mushaf mushaf,
    List<Surah> surahs,
  ) async {
    final ayah = await showSearch<AyahRef?>(
      context: context,
      delegate: _AyahSearch(surahs, S.of(context)),
    );
    if (ayah == null) return;
    setState(() => _selected = ayah);
    _controller.jumpToPage(_indexOf(mushaf.pageOf(ayah)));
  }
}

/// How ayat are colored while reciting the page.
final _correctColor = Colors.green.withValues(alpha: 0.3);
final _mistakeColor = Colors.red.withValues(alpha: 0.35);

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.black12,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    ),
  );
}

/// Searches the text of every ayah, ignoring diacritics.
class _AyahSearch extends SearchDelegate<AyahRef?> {
  _AyahSearch(this.surahs, this.t) : super(searchFieldLabel: t.searchQuranHint);

  final List<Surah> surahs;
  final S t;
  static const _limit = 200;

  /// Every ayah with its text ready for matching, made on first search.
  late final _index = [
    for (final s in surahs)
      for (var a = 0; a < s.ayahCount; a++)
        (AyahRef(s.number, a + 1), normalizeForSearch(s.ayahs[a])),
  ];

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: t.clearSearch,
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => const BackButton();

  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    final q = normalizeForSearch(query);
    if (q.length < 2) return const SizedBox();
    final found = <AyahRef>[];
    for (final (ayah, text) in _index) {
      if (text.contains(q)) found.add(ayah);
      if (found.length > _limit) break;
    }
    if (found.isEmpty) return Center(child: Text(t.noResults));
    final more = found.length > _limit;
    final shown = found.take(_limit).toList();
    return ListView.separated(
      itemCount: shown.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == 0) {
          return ListTile(
            dense: true,
            title: Text(t.searchResults(shown.length, more: more)),
          );
        }
        final a = shown[i - 1];
        final surah = surahs[a.surah - 1];
        return ListTile(
          title: Text(
            surah.ayahs[a.ayah - 1],
            textDirection: TextDirection.rtl,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(t.surahAyah(surah, a.ayah)),
          onTap: () => close(context, a),
        );
      },
    );
  }
}

/// The time, as in the top bar of the screenshots. Updates every minute.
class _Clock extends StatefulWidget {
  const _Clock();

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  Timer? _timer;
  var _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      final now = DateTime.now();
      if (now.minute != _now.minute) setState(() => _now = now);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    S.of(context).clock(_now.hour, _now.minute),
    style: Theme.of(context).textTheme.titleMedium,
  );
}

/// The ayat of one page as plain text, for reading in a larger font or
/// when the page font is hard to read.
class _TextPage extends StatelessWidget {
  const _TextPage({
    required this.page,
    required this.surahs,
    required this.selected,
    required this.onAyahTap,
  });

  final MushafPage page;
  final List<Surah> surahs;
  final AyahRef? selected;
  final ValueChanged<AyahRef> onAyahTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = S.of(context);
    final ayat = page.words.map((w) => w.ayah).toSet().toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final a in ayat) ...[
          if (a.ayah == 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                t.surah(surahs[a.surah - 1]),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          InkWell(
            onTap: () => onAyahTap(a),
            child: Container(
              color: a == selected ? theme.colorScheme.primaryContainer : null,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Text(
                '${surahs[a.surah - 1].ayahs[a.ayah - 1]} '
                '﴿${S(AppLanguage.ar, westernDigits: false).n(a.ayah)}﴾',
                textDirection: TextDirection.rtl,
                style: theme.textTheme.headlineSmall?.copyWith(height: 1.9),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Waits for the page font, then draws the page under its running header.
class _PageSlot extends ConsumerWidget {
  const _PageSlot({
    required this.page,
    required this.juz,
    required this.rub,
    required this.surahs,
    required this.selected,
    required this.highlights,
    required this.bookmarks,
    required this.showHizbMarks,
    required this.onAyahTap,
    required this.onAyahLongPress,
    required this.onSurahTap,
    required this.onPageTap,
    required this.onJuzTap,
  });

  final MushafPage page;
  final int juz;

  /// The quarter the page starts in, 1 to 240.
  final int rub;
  final List<Surah> surahs;
  final AyahRef? selected;
  final Map<AyahRef, Color> highlights;

  /// Markers and khatma plans that stand on this page: their color and
  /// name, drawn as ribbons in the header.
  final List<(Color, String)> bookmarks;
  final bool showHizbMarks;
  final ValueChanged<AyahRef>? onAyahTap;
  final ValueChanged<AyahRef> onAyahLongPress;
  final VoidCallback onSurahTap;
  final VoidCallback onPageTap;
  final VoidCallback onJuzTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fonts = ref.watch(pageFontsProvider);
    final t = S.of(context);
    // Header texts follow the app language, inside the right-to-left page.
    final textDirection = ref.watch(
      settingsProvider.select((s) => s.language.direction),
    );
    return FutureBuilder(
      future: fonts.ready(page.number, mushafPalette(context)),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(t.loadPageError(snapshot.error!)));
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final hizb = (rub - 1) ~/ 4 + 1;
        final surah = surahs[page.firstAyah.surah - 1];
        return LayoutBuilder(
          builder: (context, box) => Center(
            child: SizedBox(
              // Keep the header as wide as the text block, also on wide
              // screens where the page sits in the middle.
              width: mushafTextWidth(box.maxWidth - 16, box.maxHeight - 36),
              child: Column(
                children: [
                  // Running header: the surah with its number and ayah
                  // count on the right, the page number in the middle, and
                  // the juz with its eighth and hizb on the left. Each one
                  // opens where it leads.
                  SizedBox(
                    height: 36,
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: _HeaderLink(
                              text: t.surahHeader(surah),
                              textDirection: textDirection,
                              onTap: onSurahTap,
                            ),
                          ),
                        ),
                        _HeaderLink(
                          text: t.n(page.number),
                          textDirection: textDirection,
                          tooltip: t.pageNavigator,
                          onTap: onPageTap,
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              for (final (color, name) in bookmarks)
                                Tooltip(
                                  message: name,
                                  child: Icon(
                                    Icons.bookmark,
                                    color: color,
                                    size: 20,
                                  ),
                                ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: _HeaderLink(
                                  text: t.juzHeader(juz, (rub - 1) % 8 + 1),
                                  textDirection: textDirection,
                                  onTap: onJuzTap,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Tooltip(
                                message: t.hizb(hizb),
                                child: SizedBox(
                                  height: 22,
                                  child: HizbBookIcon(
                                    hizb: hizb,
                                    firstLabel: t.n(juz * 2 - 1),
                                    secondLabel: t.n(juz * 2),
                                    background: Theme.of(context)
                                        .scaffoldBackgroundColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: MushafPageView(
                      page: page,
                      surahName: (s) => surahs[s - 1].name,
                      selected: selected,
                      highlights: highlights,
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

/// A text of the running header with a dashed underline, showing that it
/// can be tapped.
class _HeaderLink extends StatelessWidget {
  const _HeaderLink({
    required this.text,
    required this.textDirection,
    required this.onTap,
    this.tooltip,
  });

  final String text;
  final TextDirection textDirection;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final link = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          text,
          textDirection: textDirection,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color,
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dashed,
            decorationColor: color,
          ),
        ),
      ),
    );
    return tooltip == null ? link : Tooltip(message: tooltip, child: link);
  }
}

/// The parts of the mushaf screen.
enum _Part { page, bars, bottomChrome, topChrome }

/// Lays the bars over the page, so that showing or hiding them does not
/// move it. The page leaves room only for the bars that stay open (the
/// player, reciting and the page navigator), which sit on the bottom tabs
/// while those are shown.
class _MushafLayout extends MultiChildLayoutDelegate {
  _MushafLayout({required this.bottomInset, required this.chrome});

  /// The system's own bar under the app.
  final double bottomInset;
  final bool chrome;

  @override
  void performLayout(Size size) {
    final loose = BoxConstraints.loose(size).copyWith(minWidth: size.width);
    var chromeHeight = 0.0;
    if (hasChild(_Part.bottomChrome)) {
      chromeHeight = layoutChild(_Part.bottomChrome, loose).height;
      positionChild(_Part.bottomChrome, Offset(0, size.height - chromeHeight));
    }
    var barsHeight = 0.0;
    if (hasChild(_Part.bars)) {
      barsHeight = layoutChild(_Part.bars, loose).height;
      final under = chrome ? chromeHeight : bottomInset;
      positionChild(_Part.bars, Offset(0, size.height - under - barsHeight));
    }
    final pageHeight = (size.height - bottomInset - barsHeight).clamp(
      0.0,
      size.height,
    );
    layoutChild(_Part.page, BoxConstraints.tight(Size(size.width, pageHeight)));
    positionChild(_Part.page, Offset.zero);
    if (hasChild(_Part.topChrome)) {
      layoutChild(_Part.topChrome, loose);
      positionChild(_Part.topChrome, Offset.zero);
    }
  }

  @override
  bool shouldRelayout(_MushafLayout old) =>
      old.bottomInset != bottomInset || old.chrome != chrome;
}

/// The surah of the page, small pictures of the pages around it and a
/// slider over all 604 pages, to move quickly through the mushaf.
class _PageNavigator extends StatefulWidget {
  const _PageNavigator({
    required this.page,
    required this.surahs,
    required this.mushaf,
    required this.onGo,
    required this.onClose,
  });

  final int page;
  final List<Surah> surahs;
  final Mushaf mushaf;
  final ValueChanged<int> onGo;
  final VoidCallback onClose;

  @override
  State<_PageNavigator> createState() => _PageNavigatorState();
}

class _PageNavigatorState extends State<_PageNavigator> {
  static const _extent = 52.0;
  final _scroll = ScrollController();

  /// The page under the slider while it is dragged.
  int? _dragged;

  int get _shown => _dragged ?? widget.page;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _center(jump: true));
  }

  @override
  void didUpdateWidget(_PageNavigator old) {
    super.didUpdateWidget(old);
    if (old.page != widget.page) _center();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls the thumbnails so the shown page is in the middle.
  void _center({bool jump = false}) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final offset =
        ((_shown - 1) * _extent - (position.viewportDimension - _extent) / 2)
            .clamp(0.0, position.maxScrollExtent);
    jump
        ? _scroll.jumpTo(offset)
        : _scroll.animateTo(
            offset,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final surah = widget.surahs[widget.mushaf.page(_shown).firstAyah.surah - 1];
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 44,
            child: Stack(
              children: [
                Center(
                  child: Text(
                    t.surahName(surah),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: IconButton(
                    tooltip: t.close,
                    icon: Icon(Icons.highlight_off, color: colors.primary),
                    onPressed: widget.onClose,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 96,
            child: ListView.builder(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              itemExtent: _extent,
              itemCount: mushafPageCount,
              itemBuilder: (context, i) => _PageThumbnail(
                label: t.n(i + 1),
                current: i + 1 == _shown,
                onTap: () => widget.onGo(i + 1),
              ),
            ),
          ),
          Row(
            children: [
              Text(t.n(1), style: theme.textTheme.labelMedium),
              Expanded(
                child: Slider(
                  value: _shown.toDouble(),
                  min: 1,
                  max: mushafPageCount.toDouble(),
                  label: t.n(_shown),
                  onChanged: (v) {
                    setState(() => _dragged = v.round());
                    _center(jump: true);
                  },
                  onChangeEnd: (v) {
                    widget.onGo(v.round());
                    setState(() => _dragged = null);
                  },
                ),
              ),
              Text(t.n(mushafPageCount), style: theme.textTheme.labelMedium),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small picture of a page, with lines for its text, and its number.
class _PageThumbnail extends StatelessWidget {
  const _PageThumbnail({
    required this.label,
    required this.current,
    required this.onTap,
  });

  final String label;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: current
                      ? colors.surfaceContainerHighest
                      : colors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: current ? colors.primary : colors.outlineVariant,
                    width: current ? 2.5 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < 6; i++)
                      Container(
                        height: 1,
                        color: current
                            ? colors.onSurfaceVariant
                            : colors.outlineVariant,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: current ? colors.primary : colors.onSurfaceVariant,
                fontWeight: current ? FontWeight.bold : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Previous and next page buttons around the page number. The previous
/// page is on the right, as in a printed mushaf. Listening is on the
/// right side and reciting on the left, so both are always at hand.
class _PageBar extends StatelessWidget {
  const _PageBar({
    required this.label,
    required this.onLabel,
    this.onPrevious,
    this.onNext,
    required this.onListen,
    this.onRecite,
  });

  /// The page number, or the two numbers of facing pages.
  final String label;

  /// Opens the page navigator.
  final VoidCallback onLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onListen;

  /// Null when the recitation button is hidden in the settings.
  final VoidCallback? onRecite;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    // Drawn over the page, on the bottom tabs.
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.headphones),
                label: Text(t.listen),
                onPressed: onListen,
              ),
            ),
          ),
          IconButton(
            tooltip: t.previousPage,
            // Chevrons mirror in right-to-left layouts, so this one points
            // right, away from the page number.
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Tooltip(
            message: t.pageNavigator,
            child: InkWell(
              onTap: onLabel,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 56, minHeight: 40),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: t.nextPage,
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: onRecite == null
                  ? null
                  : TextButton.icon(
                      icon: const Icon(Icons.mic),
                      label: Text(t.recite),
                      onPressed: onRecite,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
