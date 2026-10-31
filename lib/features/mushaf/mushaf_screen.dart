import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/ayah_audio.dart';
import '../../audio/heard_ayat.dart';
import '../../data/hifz_exam.dart';
import '../../data/khatma.dart';
import '../../data/marks.dart';
import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/quran_models.dart';
import '../../data/quran_repository.dart';
import '../../data/reading_state.dart';
import '../../data/tajweed.dart';
import '../../l10n/strings.dart';
import '../../recitation/auto_recitation.dart';
import '../../recitation/page_recitation.dart';
import '../hifz_exam/exam_stop.dart';
import '../hifz_exam/hifz_exam_screen.dart';
import '../../settings/app_settings.dart';
import '../audio/audio_bar.dart';
import '../audio/repeat_sheet.dart';
import '../recitation/auto_recitation_bar.dart';
import '../recitation/recitation_bar.dart';
import '../recitation/recitation_picker.dart';
import '../recitation/recitation_mode.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../home/index_icons.dart';
import '../shell/navigation.dart';
import '../study/study_content.dart';
import '../study/study_panel.dart';
import '../study/word_card.dart';
import 'go_to_dialog.dart';
import 'mushaf_page_view.dart';
import 'text_size_sheet.dart';
import '../../data/mushaf_text.dart';

/// Swipeable 604-page mushaf. Remembers the last page read.
///
/// The top bar has a menu, night mode, a clock, a switch to plain text and
/// ayah search. Beside the page number, one button recites the page; its
/// long press or arrow offers listening and the hifz exam. The audio player sits under the page while it is open, and
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

  /// The word open in the word card, if any.
  WordSelection? _word;

  /// The text size while two fingers pinch the page, saved when they lift.
  double? _pinchScale;
  final _pointers = <int, Offset>{};
  double? _pinchStartSpan;
  double _pinchStartScale = 1;

  /// When dragging past the end of an enlarged page last turned it.
  DateTime _lastOverscrollTurn = DateTime(0);

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

  double get _textScale =>
      _pinchScale ?? ref.read(settingsProvider).mushafTextScale;

  /// How far apart the two fingers on the page are.
  double get _pointerSpan {
    final [a, b] = _pointers.values.take(2).toList();
    return (a - b).distance;
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      _pinchStartSpan = _pointerSpan;
      _pinchStartScale = _textScale;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    final start = _pinchStartSpan;
    if (_pointers.length != 2 || start == null || start < 1) return;
    final scale = (_pinchStartScale * _pointerSpan / start).clamp(
      minMushafTextScale,
      maxMushafTextScale,
    );
    // In tenths, as the size slider sets it, so the page redraws less.
    final rounded = (scale * 10).round() / 10;
    if (rounded != _textScale) setState(() => _pinchScale = rounded);
  }

  void _onPointerEnd(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length >= 2) return;
    _pinchStartSpan = null;
    final scale = _pinchScale;
    if (scale == null) return;
    ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(mushafTextScale: scale));
    setState(() => _pinchScale = null);
  }

  /// Pages scrolled up and down turn when an enlarged page, which scrolls
  /// by itself, is dragged on past its end.
  bool _onOverscroll(OverscrollNotification n) {
    final now = DateTime.now();
    if (n.depth == 0 ||
        n.dragDetails == null ||
        n.metrics.axis != Axis.vertical ||
        now.difference(_lastOverscrollTurn) < const Duration(seconds: 1)) {
      return false;
    }
    _lastOverscrollTurn = now;
    if (n.overscroll > 0) {
      _nextPage();
    } else if (n.overscroll < 0) {
      _previousPage();
    }
    return false;
  }

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
    _scheduleAutoTurn();
  }

  /// Turns the page after the chosen time, if automatic turning is on.
  void _scheduleAutoTurn() {
    _autoTurn?.cancel();
    final settings = ref.read(settingsProvider);
    // While reciting, the pages turn with the reciter only.
    if (!settings.autoPageTurn ||
        _autoTurnPaused ||
        ref.read(pageRecitationProvider) != null ||
        ref.read(autoRecitationProvider) != null) {
      return;
    }
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
    ref.listen(
      pageRecitationProvider.select((r) => r != null),
      (_, _) => _scheduleAutoTurn(),
    );
    ref.listen(
      autoRecitationProvider.select((r) => r != null),
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
    // The pages turn with the reciter, as they do when listening, once
    // the page shown is recited to its end.
    ref.listen(pageRecitationProvider.select((r) => r?.settledWord), (_, _) {
      final m = ref.read(mushafProvider).value;
      final recitation = ref.read(pageRecitationProvider);
      if (recitation == null || m == null) return;
      final page = recitation.pageToShow(m);
      if (page >= _page && page < _page + _step) return;
      // A recitation found far away, by reciting from anywhere, opens
      // there at once.
      if ((page - _page).abs() > 2 * _step && _controller.hasClients) {
        _controller.jumpToPage(_indexOf(page));
      } else {
        _turnTo(page);
      }
    });
    // The mistakes report, once the recitation is finished and stopped
    // listening, or once the reciter stops after going on from surah to
    // surah.
    ref.listen(
      pageRecitationProvider.select(
        (r) =>
            r != null &&
                !r.session.isListening &&
                (r.session.result.isComplete || r.wentOn)
            ? r.session
            : null,
      ),
      (_, session) {
        if (session == null) return;
        // In the hifz exam, a popup says to stop and goes on to the next
        // question instead.
        if (ref.read(pageRecitationProvider)?.exam != null) {
          showExamStop(context, ref);
        } else {
          showMistakesReport(context, session);
        }
      },
    );
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
    ref.watch(heardAyatProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? null : settings.pageTheme.color;
    final vertical = settings.verticalScroll;
    final appDirection = settings.language.direction;
    final bars = <Widget>[
      if (recitation != null) const RecitationBar(),
      if (ref.watch(autoRecitationProvider) != null) const AutoRecitationBar(),
      if (audio.visible) const AudioBar(),
      if (ref.watch(pageNavigatorProvider))
        _PageNavigator(
          page: _page,
          surahs: surahs,
          mushaf: mushaf,
          onGo: (page) => _controller.jumpToPage(_indexOf(page)),
          onClose: () => _showNavigator(false),
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
              child: _withWordCard(
                CustomMultiChildLayout(
                  delegate: _MushafLayout(
                    bottomInset: MediaQuery.viewPaddingOf(context).bottom,
                    chrome: chrome,
                  ),
                  children: [
                    LayoutId(
                      id: _Part.page,
                      child: SafeArea(
                        bottom: false,
                        // Two fingers spread or pinched size the text.
                        child: Listener(
                          onPointerDown: _onPointerDown,
                          onPointerMove: _onPointerMove,
                          onPointerUp: _onPointerEnd,
                          onPointerCancel: _onPointerEnd,
                          // A tap on the page shows or hides the bars.
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => ref
                                .read(mushafChromeProvider.notifier)
                                .toggle(),
                            child: LayoutBuilder(
                              builder: (context, box) {
                                _useSpread(
                                  settings.twoPagesInLandscape &&
                                      box.maxWidth > box.maxHeight,
                                );
                                final pages = PageView.builder(
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
                                  scrollBehavior:
                                      ScrollConfiguration.of(context).copyWith(
                                        dragDevices: PointerDeviceKind.values
                                            .toSet(),
                                      ),
                                  itemCount: _slideCount,
                                  onPageChanged: (i) =>
                                      _onPageChanged(_pageAt(i)),
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
                                return vertical
                                    ? NotificationListener<
                                        OverscrollNotification
                                      >(
                                        onNotification: _onOverscroll,
                                        child: pages,
                                      )
                                    : pages;
                              },
                            ),
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
                                  : _recite,
                              onExam: _exam,
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
      ),
    );
  }

  /// [page] with the word card over it while a word is open. A tap
  /// outside the card closes it.
  Widget _withWordCard(Widget page) {
    final word = _word;
    if (word == null) return page;
    final size = MediaQuery.sizeOf(context);
    final below = word.anchor.dy < size.height / 2;
    return Stack(
      children: [
        page,
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _word = null),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: below ? word.anchor.dy + 36 : null,
          bottom: below ? null : size.height - word.anchor.dy + 36,
          child: Directionality(
            textDirection: ref.watch(
              settingsProvider.select((s) => s.language.direction),
            ),
            child: WordCard(
              key: ValueKey(word),
              ayah: word.ayah,
              position: word.position,
              onClose: () => setState(() => _word = null),
              onMore: () => _openStudy(
                word.ayah,
                word: word.position,
                part: StudyPart.word,
              ),
              onTafsir: () => _openStudy(word.ayah),
            ),
          ),
        ),
      ],
    );
  }

  /// Starts a hifz exam on the surah of the open page, or on the first
  /// surah on it long enough for one; otherwise lets the reciter choose a
  /// surah.
  Future<void> _exam() async {
    final mushaf = ref.read(mushafProvider).value;
    if (mushaf == null) return;
    final page = mushaf.page(_page);
    final surah = {
      page.firstAyah.surah,
      for (final line in page.lines.whereType<SurahNameLine>()) line.surah,
    }.where((s) => examAllowed(mushaf, s)).firstOrNull;
    if (surah == null) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const HifzExamScreen()));
      return;
    }
    final mode = await chooseRecitationMode(context);
    if (mode == null || !mounted) return;
    await ref
        .read(pageRecitationProvider.notifier)
        .startExam(
          pickExam(surah, ayahCounts[surah - 1], Random()),
          mode: mode,
        );
  }

  /// Recites the open page from its top. When a surah starts part way
  /// down the page, first asks whether to start there instead, so a new
  /// surah can be recited without the end of the one before it.
  Future<void> _recite() async {
    final controller = ref.read(pageRecitationProvider.notifier);
    final mushaf = ref.read(mushafProvider).value;
    final surahs = ref.read(surahsProvider).value;
    if (mushaf == null || surahs == null) return;
    final page = mushaf.page(_page);
    final starts = [
      for (final line in page.lines.whereType<SurahNameLine>())
        if (AyahRef(line.surah, 1) != page.firstAyah) AyahRef(line.surah, 1),
    ];
    if (controller.isListeningTo(_page)) return controller.start(_page);
    if (starts.isEmpty) {
      final mode = await chooseRecitationMode(context);
      if (mode == null || !mounted) return;
      return controller.start(_page, mode: mode);
    }
    final t = S.of(context);
    final from = await showModalBottomSheet<AyahRef>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.reciteFromWhere, style: TextTheme.of(context).titleMedium),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.vertical_align_top_rounded),
              title: Text(t.reciteFromPageStart),
              onTap: () => Navigator.pop(context, page.firstAyah),
            ),
            for (final a in starts)
              ListTile(
                leading: const Icon(Icons.menu_book_rounded),
                title: Text(t.reciteFromSurah(surahs[a.surah - 1])),
                onTap: () => Navigator.pop(context, a),
              ),
          ],
        ),
      ),
    );
    if (from == null || !mounted) return;
    final mode = await chooseRecitationMode(context);
    if (mode == null || !mounted) return;
    await controller.start(
      _page,
      from: from == page.firstAyah ? null : from,
      mode: mode,
    );
  }

  /// Opens or closes the page navigator. It opens with the bars hidden, as
  /// it takes their place under the page.
  void _showNavigator(bool open) {
    ref.read(pageNavigatorProvider.notifier).set(open);
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
    final colors = Theme.of(context).colorScheme;
    // A floating rounded bar, with the page showing around it.
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
        child: Material(
          color: colors.surfaceContainerLowest,
          elevation: 2,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(18),
          child: IconTheme.merge(
            data: IconThemeData(color: colors.primary),
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  PopupMenuButton<VoidCallback>(
                    tooltip: t.menu,
                    icon: const Icon(Icons.segment_rounded),
                    onSelected: (action) => action(),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: () => _goToPage(context),
                        child: ListTile(
                          leading: const Icon(Icons.numbers_rounded),
                          title: Text(t.goTo),
                        ),
                      ),
                      PopupMenuItem(
                        value: () => _showNavigator(true),
                        child: ListTile(
                          leading: const Icon(Icons.view_carousel_rounded),
                          title: Text(t.pageNavigator),
                        ),
                      ),
                      PopupMenuItem(
                        value: () => ref
                            .read(audioProvider.notifier)
                            .show(mushaf.page(_page).firstAyah),
                        child: ListTile(
                          leading: const Icon(Icons.headphones_rounded),
                          title: Text(t.listen),
                        ),
                      ),
                      if (!settings.hideRecitationButton)
                        PopupMenuItem(
                          value: () =>
                              showRecitationPicker(context, page: _page),
                          child: ListTile(
                            leading: const Icon(Icons.mic_rounded),
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
                              _autoTurnPaused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                            ),
                            title: Text(
                              _autoTurnPaused
                                  ? t.resumeAutoTurn
                                  : t.pauseAutoTurn,
                            ),
                          ),
                        ),
                      PopupMenuItem(
                        value: () => showTextSizeSheet(context),
                        child: ListTile(
                          leading: const Icon(Icons.format_size_rounded),
                          title: Text(t.textSize),
                        ),
                      ),
                      PopupMenuItem(
                        value: () => openSettings(context),
                        child: ListTile(
                          leading: const Icon(Icons.settings_rounded),
                          title: Text(t.settings),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: settings.nightMode ? t.dayMode : t.nightMode,
                    icon: Icon(
                      settings.nightMode
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
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
                          ? Icons.auto_stories_rounded
                          : Icons.chrome_reader_mode_rounded,
                    ),
                    onPressed: () => setState(() => _textMode = !_textMode),
                  ),
                  IconButton(
                    tooltip: t.searchQuran,
                    icon: const Icon(Icons.search_rounded),
                    onPressed: () => _search(context, mushaf, surahs),
                  ),
                  const SizedBox(width: 4),
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
    final audio = ref.read(audioProvider);
    final playing = audio.visible ? audio.current : null;
    if (_textMode) {
      return _TextPage(
        page: mushaf.page(page),
        surahs: surahs,
        selected: playing ?? _selected,
        textScale: _textScale,
        onAyahTap: (a) => _openStudy(a),
      );
    }
    final highlights = ref.read(highlightsProvider);
    final markers = ref.read(markersProvider);
    final recitation = ref.read(pageRecitationProvider);
    return _PageSlot(
      page: mushaf.page(page),
      highlights: {
        for (final e in highlights.entries) e.key: highlightColors[e.value],
      },
      // Each word recited shows green, or red when said wrong, while the
      // ayat show; hidden, they show plain as recited, and a word said
      // wrong stays hidden instead.
      wordColors: {
        if (recitation?.covers(page) == true && !recitation!.hideText)
          for (final e in recitation.wordStates.entries)
            e.key: switch (e.value) {
              AyahRecitation.mistake => _mistakeColor,
              AyahRecitation.harakat => _harakatColor,
              AyahRecitation.correct => _correctColor,
            },
      },
      // Listening, also after reciting, shows the ayat as the reciter
      // reaches them, or all of them when that is turned off.
      recitedWords: audio.visible
          ? settings.hideWhileListening
                ? {
                    for (final a in ref.read(heardAyatProvider))
                      a: PageRecitation.allWords,
                  }
                : null
          : recitation?.covers(page) == true && recitation!.hideText
          ? {
              // Going on from where reciting stopped, the ayat before it
              // were recited already.
              if (recitation.from case final from?)
                for (final w in mushaf.page(page).words)
                  if (w.ayah < from) w.ayah: PageRecitation.allWords,
              ...recitation.recitedWords,
            }
          : null,
      wrongWords: !audio.visible && recitation?.covers(page) == true
          ? recitation!.wrongWords
          : const {},
      harakatWords: recitation?.covers(page) == true && !recitation!.hideText
          ? recitation.harakatWords
          : const {},
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
      selectedWord: switch (_word) {
        final w? => (w.ayah, w.position),
        null => null,
      },
      showHizbMarks: settings.showHizbMarks,
      textScale: _textScale,
      // Otherwise a tap goes to the page, which shows or hides the bars.
      onAyahTap: settings.tapOpensAyahMenu ? _openWord : null,
      onAyahLongPress: _openWord,
      onSurahTap: () => openIndex(context, 0),
      onPageTap: () => _showNavigator(!ref.read(pageNavigatorProvider)),
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

  /// Opens the word card on [word], pressed at [position] on the screen.
  void _openWord(MushafWord word, Offset position) {
    if (word.isAyahEnd) {
      _openStudy(word.ayah);
      return;
    }
    setState(() {
      _selected = null;
      _word = (ayah: word.ayah, position: word.position, anchor: position);
    });
  }

  /// Opens the study panel, then shows the page of the ayah it ended on.
  Future<void> _openStudy(
    AyahRef ayah, {
    int word = 1,
    StudyPart part = StudyPart.ayah,
  }) async {
    setState(() => _word = null);
    final end = await showStudyPanel(
      context,
      ayah: ayah,
      word: word,
      part: part,
    );
    final mushaf = ref.read(mushafProvider).value;
    if (end == null || mushaf == null || !mounted) return;
    final page = mushaf.pageOf(end);
    if (page < _page || page >= _page + _step) {
      _controller.jumpToPage(_indexOf(page));
    }
  }

  Future<void> _search(
    BuildContext context,
    Mushaf mushaf,
    List<Surah> surahs,
  ) async {
    final ayah = await Navigator.of(context).push<AyahRef>(
      MaterialPageRoute(builder: (_) => const QuranSearchScreen()),
    );
    if (ayah == null) return;
    setState(() => _selected = ayah);
    _controller.jumpToPage(_indexOf(mushaf.pageOf(ayah)));
  }
}

/// How words are colored while reciting the page.
final _correctColor = Colors.green.withValues(alpha: 0.3);
final _mistakeColor = Colors.red.withValues(alpha: 0.35);
// Pale, so the words said with a wrong haraka stand out on it in orange.
const _harakatColor = Color(0xFFFFDDB0);

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
    required this.textScale,
    required this.onAyahTap,
  });

  final MushafPage page;
  final List<Surah> surahs;
  final AyahRef? selected;
  final double textScale;
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
                '${mushafDisplayText(surahs[a.surah - 1].ayahs[a.ayah - 1])} '
                '${ayahEndMark(a.ayah)}',
                textDirection: TextDirection.rtl,
                style: quranTextStyle(
                  theme.textTheme.headlineSmall?.copyWith(
                    height: 1.9,
                    fontSize:
                        (theme.textTheme.headlineSmall?.fontSize ?? 24) *
                        textScale,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Draws the page under its running header.
class _PageSlot extends ConsumerWidget {
  const _PageSlot({
    required this.page,
    required this.juz,
    required this.rub,
    required this.surahs,
    required this.selected,
    required this.selectedWord,
    required this.highlights,
    this.wordColors = const {},
    this.recitedWords,
    this.wrongWords = const {},
    this.harakatWords = const {},
    required this.bookmarks,
    required this.showHizbMarks,
    required this.textScale,
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
  final Map<(AyahRef, int), Color> wordColors;
  final Map<AyahRef, int>? recitedWords;
  final Set<(AyahRef, int)> wrongWords;
  final Set<(AyahRef, int)> harakatWords;

  /// Markers and khatma plans that stand on this page: their color and
  /// name, drawn as ribbons in the header.
  final List<(Color, String)> bookmarks;
  final bool showHizbMarks;
  final double textScale;
  final (AyahRef, int)? selectedWord;
  final WordCallback? onAyahTap;
  final WordCallback onAyahLongPress;
  final VoidCallback onSurahTap;
  final VoidCallback onPageTap;
  final VoidCallback onJuzTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    // Header texts follow the app language, inside the right-to-left page.
    final textDirection = ref.watch(
      settingsProvider.select((s) => s.language.direction),
    );
    final tajweed = ref.watch(settingsProvider.select((s) => s.tajweedColors))
        ? ref.watch(tajweedProvider).value
        : null;
    final jalala = ref.watch(
      settingsProvider.select((s) => s.jalalaColors ? s.jalalaColor : null),
    );
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
                                Icons.bookmark_rounded,
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
                  selectedWord: selectedWord,
                  highlights: highlights,
                  wordColors: wordColors,
                  recitedWords: recitedWords,
                  wrongWords: wrongWords,
                  harakatWords: harakatWords,
                  showHizbMarks: showHizbMarks,
                  textScale: textScale,
                  tajweed: tajweed,
                  jalala: jalala,
                  onAyahTap: onAyahTap,
                  onAyahLongPress: onAyahLongPress,
                ),
              ),
            ],
          ),
        ),
      ),
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
                    icon: Icon(
                      Icons.highlight_off_rounded,
                      color: colors.primary,
                    ),
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
    required this.onExam,
  });

  /// The page number, or the two numbers of facing pages.
  final String label;

  /// Opens the page navigator.
  final VoidCallback onLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onListen;

  /// Null when the recitation button is hidden in the settings; then
  /// the button listens instead, and there is no exam.
  final VoidCallback? onRecite;
  final VoidCallback onExam;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    // Drawn over the page, on the bottom tabs.
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: colors.surfaceContainerLowest,
        elevation: 2,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              // One button: a tap recites, the main thing the app is for;
              // a long press, or its arrow, offers listening and the exam.
              // The page buttons sit at the other end.
              // On a narrow phone it shrinks rather than overflow.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: onRecite == null
                      ? _ActionButton(
                          icon: Icons.headphones_rounded,
                          label: t.listen,
                          onPressed: onListen,
                        )
                      : _ReciteButton(
                          onRecite: onRecite!,
                          onListen: onListen,
                          onExam: onExam,
                        ),
                ),
              ),
              IconButton(
                tooltip: t.previousPage,
                visualDensity: VisualDensity.compact,
                // Chevrons mirror in right-to-left layouts, so this one points
                // right, away from the page number.
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: onPrevious,
              ),
              Tooltip(
                message: t.pageNavigator,
                child: InkWell(
                  onTap: onLabel,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 40,
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: t.nextPage,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A pill button of the page bar.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.onLongPress,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      visualDensity: VisualDensity.compact,
      shape: const StadiumBorder(),
    ),
    icon: Icon(icon, size: 20),
    label: Text(label),
    onPressed: onPressed,
    onLongPress: onLongPress,
  );
}

/// The page bar's one action button: a tap recites the page; a long
/// press, or the arrow beside it, opens a small menu above it to listen
/// or to take the hifz exam. The arrow is always there, so the menu can
/// be found without knowing about the long press.
class _ReciteButton extends StatefulWidget {
  const _ReciteButton({
    required this.onRecite,
    required this.onListen,
    required this.onExam,
  });

  final VoidCallback onRecite;
  final VoidCallback onListen;
  final VoidCallback onExam;

  @override
  State<_ReciteButton> createState() => _ReciteButtonState();
}

class _ReciteButtonState extends State<_ReciteButton> {
  static const _menuHeight = 2 * 48.0 + 16;

  final _menu = MenuController();

  void _open() {
    HapticFeedback.selectionClick();
    _menu.open();
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    return MenuAnchor(
      controller: _menu,
      // Opens upwards, over the page, since the bar is at the bottom:
      // the menu's two items and padding stand above the button's top.
      alignmentOffset: const Offset(0, -_menuHeight - 8),
      style: MenuStyle(
        alignment: AlignmentDirectional.topStart,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.headphones_rounded),
          onPressed: widget.onListen,
          child: Text(t.listen),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.quiz_rounded),
          onPressed: widget.onExam,
          child: Text(t.exam),
        ),
      ],
      builder: (context, controller, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            icon: Icons.mic_rounded,
            label: t.recite,
            onPressed: widget.onRecite,
            onLongPress: _open,
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            tooltip: t.reciteMore,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              controller.isOpen
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
            ),
            onPressed: () => controller.isOpen ? controller.close() : _open(),
          ),
        ],
      ),
    );
  }
}
