import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/ayah_audio.dart';
import '../data/mushaf_models.dart';
import '../data/mushaf_repository.dart';
import '../data/quran_models.dart';
import '../data/quran_repository.dart';
import '../data/reading_state.dart';
import '../data/recitation_history.dart';
import 'alert_sound.dart';
import 'recitation_matcher.dart';
import 'recitation_session.dart';
import 'session_record.dart';
import 'speech_listener.dart';

/// How each ayah of a page was recited so far.
enum AyahRecitation { correct, mistake }

/// Reciting in place in the mushaf, from a bar under the page: from the
/// page open when it started on to the end of the surah, so a surah longer
/// than a page is recited without stopping and the pages turn with it.
class PageRecitation {
  const PageRecitation(
    this.page,
    this.session,
    this.version, {
    int? lastPage,
    this.from,
    this.hideText = true,
  }) : lastPage = lastPage ?? page;

  /// The page the recitation started on.
  final int page;

  /// The ayah it started from when going on from where reciting last
  /// stopped; the ayat before it on [page] are not recited and show.
  final AyahRef? from;

  /// The page where the recited surah ends.
  final int lastPage;
  final RecitationSession session;

  /// Whether [p] is one of the pages being recited.
  bool covers(int p) => p >= page && p <= lastPage;

  /// The word the reciter is at, as its ayah and position in the ayah:
  /// the next one to recite, or the last one once all is recited.
  (AyahRef, int) get currentWord {
    final words = session.result.words;
    var k = session.result.end;
    while (k < words.length && words[k].word.kind != WordKind.ayah) {
      k++;
    }
    if (k >= words.length) {
      k = words.lastIndexWhere((w) => w.word.kind == WordKind.ayah);
    }
    final w = words[k];
    var position = 1;
    while (k - position >= 0 &&
        words[k - position].word.kind == WordKind.ayah &&
        words[k - position].ayah == w.ayah &&
        words[k - position].surah == w.surah) {
      position++;
    }
    return (AyahRef(w.surah, w.ayah), position);
  }

  /// Changes whenever the session does, so listeners redraw.
  final int version;

  /// Hifz is recited from memory, so the words of the page are hidden and
  /// show one by one as they are recited.
  final bool hideText;

  PageRecitation copyWith({int? version, bool? hideText}) => PageRecitation(
    page,
    session,
    version ?? this.version,
    lastPage: lastPage,
    from: from,
    hideText: hideText ?? this.hideText,
  );

  /// How many words of each ayah show while the text is hidden: those up
  /// to the last one recited, except the [wrongWords]. An ayah recited to
  /// its end shows all its words, whatever the count, so a word printed
  /// apart on the page does not stay hidden.
  Map<AyahRef, int> get recitedWords {
    final counts = <AyahRef, int>{};
    final unfinished = <AyahRef>{};
    _forEachAyahWord((ayah, position, w) {
      if (w.status == WordStatus.pending) {
        unfinished.add(ayah);
      } else {
        counts[ayah] = position;
      }
    });
    return {
      for (final e in counts.entries)
        e.key: unfinished.contains(e.key) ? e.value : allWords,
    };
  }

  /// The words said wrong or left out, as their ayah and position: they
  /// stay hidden until recited again correctly, while the rest of their
  /// ayah shows and the reciting goes on.
  Set<(AyahRef, int)> get wrongWords {
    final wrong = <(AyahRef, int)>{};
    _forEachAyahWord((ayah, position, w) {
      if (w.status == WordStatus.wrong || w.status == WordStatus.skipped) {
        wrong.add((ayah, position));
      }
    });
    return wrong;
  }

  /// Calls [f] with each word of the ayat, its ayah and its position.
  void _forEachAyahWord(void Function(AyahRef, int, WordResult) f) {
    AyahRef? last;
    var position = 0;
    for (final w in session.result.words) {
      if (w.word.kind != WordKind.ayah) continue;
      final ayah = AyahRef(w.surah, w.ayah);
      position = ayah == last ? position + 1 : 1;
      last = ayah;
      f(ayah, position, w);
    }
  }

  /// The count of an ayah recited to its end in [recitedWords].
  static const allWords = 1 << 30;

  /// The ayat reached so far: wrong if any of their words was, else right.
  Map<AyahRef, AyahRecitation> get ayahStates {
    final states = <AyahRef, AyahRecitation>{};
    for (final w in session.result.words) {
      if (w.word.kind != WordKind.ayah) continue;
      final ayah = AyahRef(w.surah, w.ayah);
      if (w.isMistake) {
        states[ayah] = AyahRecitation.mistake;
      } else if (w.status == WordStatus.correct) {
        states.putIfAbsent(ayah, () => AyahRecitation.correct);
      }
    }
    // An ayah counts as right only once all of it was recited.
    for (final w in session.result.words) {
      if (w.word.kind == WordKind.ayah && w.status == WordStatus.pending) {
        final ayah = AyahRef(w.surah, w.ayah);
        if (states[ayah] == AyahRecitation.correct) states.remove(ayah);
      }
    }
    return states;
  }
}

/// The words to recite for the ayat on [page], in order.
List<ExpectedWord> wordsOfPage(MushafPage page, List<Surah> surahs) =>
    wordsOfPages([page], surahs);

/// The words to recite for the ayat on [pages], in order, starting from
/// the ayah [from] when given.
List<ExpectedWord> wordsOfPages(
  Iterable<MushafPage> pages,
  List<Surah> surahs, {
  AyahRef? from,
}) {
  final seen = <AyahRef>{};
  return wordsToRecite([
    for (final w in pages.expand((p) => p.words))
      if ((from == null || !(w.ayah < from)) && seen.add(w.ayah))
        (
          w.ayah.surah,
          w.ayah.ayah,
          surahs[w.ayah.surah - 1].ayahs[w.ayah.ayah - 1],
        ),
  ]);
}

/// Starts, follows and ends reciting a mushaf page in place. Each
/// recitation is kept in the history when it ends or starts over.
class PageRecitationController extends Notifier<PageRecitation?> {
  bool _saved = false;

  /// The session being recited, also for disposing it with the provider.
  RecitationSession? _session;

  @override
  PageRecitation? build() {
    ref.onDispose(() {
      // Disposing may still report the last words; nothing redraws now.
      final session = _session;
      _session = null;
      session?.dispose();
    });
    // Listening to the reciter stops the microphone, so it does not take
    // the recording for the reader's voice.
    ref.listen(audioProvider.select((a) => a.playing), (_, playing) {
      final session = _session;
      if (playing && session != null && session.isListening) session.stop();
    });
    return null;
  }

  /// Opens the bar for [page] and starts listening from the top of the
  /// page, or from the ayah [from] on it, on to the end of the surah the
  /// page ends in. Each start recites anew, so a recitation that ended or
  /// stopped earlier does not take the new one for words after its end.
  /// While the page is being listened to, only stops listening.
  Future<void> start(int page, {AyahRef? from}) async {
    final session = state?.covers(page) == true ? state!.session : null;
    if (session != null && session.isListening) return session.stop();
    await _start(page, from: from);
  }

  /// Goes on reciting from where reciting last stopped.
  Future<void> resume() async {
    final mushaf = ref.read(mushafProvider).value;
    final from = ref.read(lastRecitationProvider);
    if (mushaf == null || from == null) return;
    await _start(mushaf.pageOf(from), from: from);
  }

  Future<void> _start(int page, {AyahRef? from}) async {
    final mushaf = ref.read(mushafProvider).value;
    final surahs = ref.read(surahsProvider).value;
    if (mushaf == null || surahs == null) return;
    close();
    final surah = mushaf.page(page).words.last.ayah.surah;
    final lastPage = mushaf.pageOf(
      AyahRef(surah, surahs[surah - 1].ayahs.length),
    );
    final session = RecitationSession(
      listener: ref.read(speechListenerProvider),
      expected: wordsOfPages(
        [for (var p = page; p <= lastPage; p++) mushaf.page(p)],
        surahs,
        from: from,
      ),
      surahName: (s) => surahs[s - 1].name,
    )..onMistake = (_) => ref.read(mistakeAlertProvider)();
    session.addListener(() => _changed(session));
    _saved = false;
    _session = session;
    state = PageRecitation(page, session, 0, lastPage: lastPage, from: from);
    await toggleListening();
  }

  /// Hides the words not recited yet, or shows the whole page.
  void toggleHideText() {
    final current = state;
    if (current == null) return;
    state = current.copyWith(hideText: !current.hideText);
  }

  /// Starts or stops listening. The recitation audio is paused first, so
  /// the microphone does not hear it.
  Future<void> toggleListening() async {
    final session = state?.session;
    if (session == null) return;
    if (session.isListening) return session.stop();
    if (ref.read(audioProvider).playing) {
      await ref.read(audioProvider.notifier).togglePlay();
    }
    await session.start();
  }

  /// Keeps the try so far and recites the page again from the start.
  Future<void> restart() async {
    final current = state;
    if (current == null) return;
    _save();
    await current.session.reset();
    _saved = false;
  }

  /// Stops listening, keeps the recitation and closes the bar.
  void close() {
    final current = state;
    if (current == null) return;
    _save();
    state = null;
    _session = null;
    current.session.dispose();
  }

  void _changed(RecitationSession session) {
    if (session != _session) return;
    final current = state;
    if (current == null || current.session != session) return;
    if (session.result.isComplete) _save();
    _keepPlace(current);
    state = current.copyWith(version: current.version + 1);
  }

  /// Remembers where to go on reciting from: the next ayah, or the next
  /// surah once this one is recited to its end.
  void _keepPlace(PageRecitation current) {
    final result = current.session.result;
    if (result.progress == 0) return;
    final AyahRef? next;
    if (result.isComplete) {
      final surah = current.currentWord.$1.surah;
      next = surah < 114 ? AyahRef(surah + 1, 1) : null;
    } else {
      next = current.currentWord.$1;
    }
    ref.read(lastRecitationProvider.notifier).set(next);
  }

  void _save() {
    final current = state;
    if (_saved || current == null) return;
    final record = recordOf(current.session, page: current.page);
    if (record == null) return;
    _saved = true;
    ref.read(recitationHistoryProvider.notifier).add(record);
  }
}

final pageRecitationProvider =
    NotifierProvider<PageRecitationController, PageRecitation?>(
      PageRecitationController.new,
    );
