import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/ayah_audio.dart';
import '../data/hifz_exam.dart';
import '../data/khatma.dart';
import '../data/mushaf_models.dart';
import '../data/mushaf_repository.dart';
import '../data/quran_models.dart';
import '../data/quran_repository.dart';
import '../data/reading_state.dart';
import '../data/recitation_history.dart';
import 'alert_sound.dart';
import 'handover_listener.dart';
import 'quran_finder.dart';
import 'recitation_matcher.dart';
import 'recitation_session.dart';
import 'session_record.dart';
import 'speech_listener.dart';

/// How each ayah of a page was recited so far: a mistake is a wrong or
/// missing word, a harakat mistake only wrong harakat.
enum AyahRecitation { correct, harakat, mistake }

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
    this.until,
    this.portion,
    this.hideText = true,
    this.wentOn = false,
    this.startWord = 0,
    this.exam,
  }) : lastPage = lastPage ?? page;

  /// The hifz exam this recites a question of, if any.
  final ExamRun? exam;

  /// The words of the ayah [from] before the one the reciter started at,
  /// when reciting started part way through it: they show, and are not
  /// recited.
  final int startWord;

  /// Whether the reciter went on past the end of the surah into the next.
  final bool wentOn;

  /// The page the recitation started on.
  final int page;

  /// The ayah it started from when going on from where reciting last
  /// stopped; the ayat before it on [page] are not recited and show.
  final AyahRef? from;

  /// The ayah the recitation stops before, for a portion of a recitation
  /// plan; null to go on to the end of the surah.
  final AyahRef? until;

  /// The recitation plan and the index of its portion being recited, so
  /// the portion is ticked off once recited to its end.
  final (String, int)? portion;

  /// The page where the recited surah, or plan portion, ends.
  final int lastPage;
  final RecitationSession session;

  /// Whether [p] is one of the pages being recited.
  bool covers(int p) => p >= page && p <= lastPage;

  /// The word the reciter is at, as its ayah and position in the ayah:
  /// the next one to recite, or the last one once all is recited.
  (AyahRef, int) get currentWord => _wordAt(session.result);

  /// The word the settled recitation is at; see
  /// [RecitationSession.settledResult].
  (AyahRef, int) get settledWord => _wordAt(session.settledResult);

  /// The word the page follows while reciting: the [settledWord], or
  /// while the text is hidden the first word that stops showing the ayat
  /// (see [stopIndex]) when it comes before it, so the page stays where
  /// the mistake is to be put right.
  (AyahRef, int) get followedWord {
    if (hideText) {
      final settled = session.settledResult;
      final stop = _firstStop(settled.words);
      if (stop != null && stop < settled.end) {
        return _positionOf(settled.words, stop);
      }
    }
    return settledWord;
  }

  (AyahRef, int) _wordAt(RecitationResult result) {
    final words = result.words;
    var k = result.end;
    while (k < words.length && words[k].word.kind != WordKind.ayah) {
      k++;
    }
    if (k >= words.length) {
      k = words.lastIndexWhere((w) => w.word.kind == WordKind.ayah);
    }
    return _positionOf(words, k);
  }

  /// The ayah and position in it of word [k] of [words].
  (AyahRef, int) _positionOf(List<WordResult> words, int k) {
    final w = words[k];
    var position = 1;
    while (k - position >= 0 &&
        words[k - position].word.kind == WordKind.ayah &&
        words[k - position].ayah == w.ayah &&
        words[k - position].surah == w.surah) {
      position++;
    }
    final ayah = AyahRef(w.surah, w.ayah);
    return (ayah, ayah == from ? startWord + position : position);
  }

  /// The page to show while reciting: the one with the next word to
  /// recite. It follows only the settled words, so the page turns once
  /// the page shown is recited to its end, and not when the recognizer
  /// guesses words ahead of the reciter and then takes them back.
  int pageToShow(Mushaf mushaf) {
    final (ayah, position) = followedWord;
    var p = mushaf.pageOf(ayah);
    // An ayah may go on over the next page.
    while (p < lastPage &&
        !mushaf
            .page(p)
            .words
            .any((w) => w.ayah == ayah && w.position >= position)) {
      p++;
    }
    return p.clamp(page, lastPage);
  }

  /// Changes whenever the session does, so listeners redraw.
  final int version;

  /// Hifz is recited from memory, so the words of the page are hidden and
  /// show one by one as they are recited.
  final bool hideText;

  PageRecitation copyWith({
    int? version,
    bool? hideText,
    int? lastPage,
    bool? wentOn,
    ExamRun? exam,
  }) => PageRecitation(
    page,
    session,
    version ?? this.version,
    lastPage: lastPage ?? this.lastPage,
    from: from,
    until: until,
    portion: portion,
    hideText: hideText ?? this.hideText,
    wentOn: wentOn ?? this.wentOn,
    startWord: startWord,
    exam: exam ?? this.exam,
  );

  /// How many words of each ayah show while the text is hidden: those up
  /// to the last one recited, stopping before the first word said wrong,
  /// left out or with a wrong haraka (see [stopIndex]) until it is
  /// recited again correctly. An ayah recited to its end shows all its
  /// words, whatever the count, so a word printed apart on the page does
  /// not stay hidden.
  Map<AyahRef, int> get recitedWords {
    final counts = <AyahRef, int>{
      if (from case final from? when startWord > 0) from: startWord,
    };
    final unfinished = <AyahRef>{};
    final hints = session.hints;
    final stop = stopIndex;
    _forEachAyahWord((ayah, position, w, i) {
      if (stop != null && i >= stop) {
        unfinished.add(ayah);
        return;
      }
      if (w.status == WordStatus.pending) unfinished.add(ayah);
      // A word shown by a hint shows like one recited.
      if (w.status != WordStatus.pending || hints.contains(i)) {
        counts[ayah] = position;
      }
    });
    return {
      for (final e in counts.entries)
        e.key: unfinished.contains(e.key) ? e.value : allWords,
    };
  }

  /// The first word said wrong, left out or with a wrong haraka and not
  /// shown by a hint, as its index in the session's words: while the text
  /// is hidden, no word from it on shows until it is recited again right.
  int? get stopIndex => _firstStop(session.result.words);

  int? _firstStop(List<WordResult> words) {
    final hints = session.hints;
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.word.kind == WordKind.ayah &&
          (w.status == WordStatus.wrong ||
              w.status == WordStatus.skipped ||
              w.isHarakatMistake) &&
          !hints.contains(i)) {
        return i;
      }
    }
    return null;
  }

  /// The words said with a wrong haraka, as their ayah and position:
  /// they show in orange.
  Set<(AyahRef, int)> get harakatWords {
    final words = <(AyahRef, int)>{};
    _forEachAyahWord((ayah, position, w, _) {
      if (w.isHarakatMistake) words.add((ayah, position));
    });
    return words;
  }

  /// The words said wrong or left out, as their ayah and position: they
  /// stay hidden until recited again correctly, while the rest of their
  /// ayah shows and the reciting goes on, or until shown by a hint.
  Set<(AyahRef, int)> get wrongWords {
    final wrong = <(AyahRef, int)>{};
    final hints = session.hints;
    _forEachAyahWord((ayah, position, w, i) {
      if ((w.status == WordStatus.wrong || w.status == WordStatus.skipped) &&
          !hints.contains(i)) {
        wrong.add((ayah, position));
      }
    });
    return wrong;
  }

  /// Calls [f] with each word of the ayat, its ayah, its position and
  /// its index in the session's words.
  void _forEachAyahWord(void Function(AyahRef, int, WordResult, int) f) {
    AyahRef? last;
    var position = 0;
    final words = session.result.words;
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.word.kind != WordKind.ayah) continue;
      final ayah = AyahRef(w.surah, w.ayah);
      position = ayah == last
          ? position + 1
          : ayah == from
          ? startWord + 1
          : 1;
      last = ayah;
      f(ayah, position, w, i);
    }
  }

  /// The count of an ayah recited to its end in [recitedWords].
  static const allWords = 1 << 30;

  /// The words recited so far, as their ayah and position: right, wrong
  /// or left out, or said with a wrong haraka. Each word is coloured by
  /// its own state, so a mistake does not colour its whole ayah.
  Map<(AyahRef, int), AyahRecitation> get wordStates {
    final states = <(AyahRef, int), AyahRecitation>{};
    _forEachAyahWord((ayah, position, w, _) {
      if (w.isMistake) {
        states[(ayah, position)] = AyahRecitation.mistake;
      } else if (w.isHarakatMistake) {
        states[(ayah, position)] = AyahRecitation.harakat;
      } else if (w.status == WordStatus.correct) {
        states[(ayah, position)] = AyahRecitation.correct;
      }
    });
    return states;
  }

  /// The ayat reached so far: wrong if any of their words was, else right.
  Map<AyahRef, AyahRecitation> get ayahStates {
    final states = <AyahRef, AyahRecitation>{};
    for (final w in session.result.words) {
      if (w.word.kind != WordKind.ayah) continue;
      final ayah = AyahRef(w.surah, w.ayah);
      if (w.isMistake) {
        states[ayah] = AyahRecitation.mistake;
      } else if (w.isHarakatMistake) {
        if (states[ayah] != AyahRecitation.mistake) {
          states[ayah] = AyahRecitation.harakat;
        }
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
/// the ayah [from] and stopping before the ayah [until] when given.
List<ExpectedWord> wordsOfPages(
  Iterable<MushafPage> pages,
  List<Surah> surahs, {
  AyahRef? from,
  AyahRef? until,
}) {
  final seen = <AyahRef>{};
  return wordsToRecite([
    for (final w in pages.expand((p) => p.words))
      if ((from == null || !(w.ayah < from)) &&
          (until == null || w.ayah < until) &&
          seen.add(w.ayah))
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

  /// Whether to look for the place recited while nothing recited fits
  /// the page; see [_moveToPlaceRecited].
  bool _findPlace = false;

  /// Where the recitation ends now that it went on into a next surah.
  int? _lastPage;

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
    // Once the offline model is downloaded, a page waiting to be recited
    // is opened again to recite with it.
    ref.listen(speechListenerProvider, (_, _) {
      final current = state;
      if (current == null || current.session.isListening) return;
      _start(
        current.page,
        from: current.from,
        until: current.until,
        portion: current.portion,
        mode: current.session.mode,
        listen: false,
        restart: true,
        startWord: current.startWord,
        exam: current.exam,
      );
    });
    return null;
  }

  /// Opens the bar for [page] and starts listening from the top of the
  /// page, or from the ayah [from] on it, on to the end of the surah the
  /// page ends in. Each start recites anew, so a recitation that ended or
  /// stopped earlier does not take the new one for words after its end.
  /// While the page is being listened to, only stops listening.
  ///
  /// [mode] is how strictly to check the recitation.
  Future<void> start(
    int page, {
    AyahRef? from,
    RecitationMode mode = RecitationMode.strict,
  }) async {
    final session = state?.covers(page) == true ? state!.session : null;
    if (session != null && session.isListening) return session.stop();
    await _start(page, from: from, mode: mode, restart: true, findPlace: true);
  }

  /// Recites portion [index] of the recitation plan [plan], from its
  /// first ayah to its last, and ticks it off once recited to its end.
  Future<void> startPortion(
    KhatmaPlan plan,
    int index, {
    RecitationMode mode = RecitationMode.strict,
  }) async {
    final mushaf = ref.read(mushafProvider).value;
    if (mushaf == null) return;
    final portion = plan.portions(mushaf)[index];
    final page = portion.firstPage(mushaf);
    await _start(
      page,
      from: portion.from == mushaf.page(page).firstAyah ? null : portion.from,
      until: portion.until,
      portion: (plan.id, index),
      mode: mode,
      restart: true,
    );
  }

  /// Whether starting on [page] only stops listening to it.
  bool isListeningTo(int page) =>
      state?.covers(page) == true && state!.session.isListening;

  /// Recites from word [position] of [ayah] on, where the reciter was
  /// found reciting; [listener] is the one that heard them, still
  /// listening, so the words said so far are compared too.
  Future<void> startAt(
    AyahRef ayah, {
    int position = 1,
    RecitationMode mode = RecitationMode.strict,
    SpeechListener? listener,
  }) async {
    final mushaf = ref.read(mushafProvider).value;
    if (mushaf == null) return;
    await _start(
      mushaf.pageOf(ayah),
      from: ayah,
      startWord: position - 1,
      mode: mode,
      listener: listener,
      restart: true,
    );
  }

  /// Starts the hifz [exam]: each question is recited in the mushaf from
  /// its first ayah, with the ayat before it showing, and stops at its
  /// end; see [nextQuestion].
  Future<void> startExam(
    List<ExamQuestion> exam, {
    RecitationMode mode = RecitationMode.strict,
  }) => _startQuestion(ExamRun(exam), mode);

  /// Goes on to the next question of the exam.
  Future<void> nextQuestion() async {
    final current = state;
    final exam = current?.exam;
    if (current == null || exam == null || exam.isLast) return;
    await _startQuestion(exam.next(), current.session.mode);
  }

  Future<void> _startQuestion(ExamRun exam, RecitationMode mode) async {
    final mushaf = ref.read(mushafProvider).value;
    if (mushaf == null) return;
    final q = exam.current;
    final from = AyahRef(q.surah, q.from);
    await _start(
      mushaf.pageOf(from),
      from: from,
      until: q.to < ayahCounts[q.surah - 1]
          ? AyahRef(q.surah, q.to + 1)
          : AyahRef(q.surah + 1, 1),
      mode: mode,
      restart: true,
      exam: exam,
    );
  }

  /// Goes on reciting from where reciting last stopped.
  Future<void> resume({RecitationMode mode = RecitationMode.strict}) async {
    final mushaf = ref.read(mushafProvider).value;
    final from = ref.read(lastRecitationProvider);
    if (mushaf == null || from == null) return;
    await _start(
      mushaf.pageOf(from),
      from: from,
      mode: mode,
      restart: true,
      findPlace: true,
    );
  }

  Future<void> _start(
    int page, {
    AyahRef? from,
    AyahRef? until,
    (String, int)? portion,
    RecitationMode mode = RecitationMode.strict,
    bool listen = true,
    bool restart = false,
    int startWord = 0,
    SpeechListener? listener,
    ExamRun? exam,
    bool findPlace = false,
  }) async {
    final mushaf = ref.read(mushafProvider).value;
    final surahs = ref.read(surahsProvider).value;
    if (mushaf == null || surahs == null) return;
    if (restart || from != null || state?.covers(page) != true) {
      close();
      final int lastPage;
      if (portion != null || until != null) {
        lastPage = KhatmaPortion(
          day: 0,
          from: from ?? mushaf.page(page).firstAyah,
          until: until,
        ).lastPage(mushaf);
      } else {
        final surah = mushaf.page(page).words.last.ayah.surah;
        lastPage = mushaf.pageOf(
          AyahRef(surah, surahs[surah - 1].ayahs.length),
        );
      }
      var expected = wordsOfPages(
        [for (var p = page; p <= lastPage; p++) mushaf.page(p)],
        surahs,
        from: from,
        until: until,
      );
      if (from != null && startWord > 0) {
        expected = _withoutStart(expected, from, startWord);
      }
      // Reciting another place than the page open moves the recitation
      // there, so the listener is one that can be handed over.
      if (findPlace) {
        listener = HandoverListener(
          listener ?? ref.read(speechListenerProvider),
        );
        ref.read(quranFinderProvider);
      }
      _findPlace = findPlace;
      final session = RecitationSession(
        listener: listener ?? ref.read(speechListenerProvider),
        expected: expected,
        surahName: (s) => surahs[s - 1].name,
        mode: mode,
      );
      session.onMistake = (_) {
        // Words not on this page at all may be another place recited,
        // where the recitation is about to move.
        if (_findPlace && _rightWords(session) == 0) return;
        ref.read(mistakeAlertProvider)();
      };
      // Reciting on past the end of the surah goes on into the next one,
      // as in juz 'Amma, where a page holds several short surahs.
      List<ExpectedWord> nextSurah() {
        final surah = session.expected.last.surah;
        // An-Nas is the last; nothing to go on to after it.
        if (surah + 1 == 114) session.onFinished = null;
        final ayahs = surahs[surah].ayahs;
        _lastPage = mushaf.pageOf(AyahRef(surah + 1, ayahs.length));
        return [
          for (final w in wordsOfSurah(surah + 1, ayahs))
            if (w.kind != WordKind.istiadha) w,
        ];
      }

      if (until == null && session.expected.last.surah < 114) {
        session.onFinished = nextSurah;
      }
      session.addListener(() => _changed(session));
      _saved = false;
      _lastPage = null;
      _session = session;
      state = PageRecitation(
        page,
        session,
        0,
        lastPage: lastPage,
        from: from,
        until: until,
        portion: portion,
        startWord: startWord,
        exam: exam,
      );
    }
    if (listen) await toggleListening();
  }

  /// [words] without the first [count] words of the ayah [from], and its
  /// basmala, for reciting from part way through it.
  static List<ExpectedWord> _withoutStart(
    List<ExpectedWord> words,
    AyahRef from,
    int count,
  ) {
    var left = count;
    return [
      for (final w in words)
        if (w.surah != from.surah ||
            !(w.kind == WordKind.basmala ||
                (w.kind == WordKind.ayah && w.ayah == from.ayah && left-- > 0)))
          w,
    ];
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

  /// Shows the word the reciter is stuck on: the word the ayat stop
  /// showing at, if any, else see [RecitationSession.hint].
  void hint() {
    final current = state;
    if (current == null) return;
    current.session.hint(at: current.hideText ? current.stopIndex : null);
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
    final exam = current.exam;
    if (exam != null) {
      final answered = session.result.isComplete && !session.isListening;
      state = current.copyWith(
        version: current.version + 1,
        exam: answered && !exam.answered
            ? exam.answer(session.result.mistakeCount)
            : null,
      );
      if (answered) _save();
      return;
    }
    if (_findPlace && _moveToPlaceRecited(session)) return;
    // Done once it stops listening: it may still go on into the next surah.
    if (session.result.isComplete && !session.isListening) {
      _save();
      if (current.portion case (final plan, final index)
          when ref
              .read(khatmaPlansProvider)
              .any((p) => p.id == plan && !p.done.contains(index))) {
        ref.read(khatmaPlansProvider.notifier).setRead(plan, index);
      }
    }
    _keepPlace(current);
    state = current.copyWith(
      version: current.version + 1,
      lastPage: _lastPage,
      wentOn: _lastPage != null,
    );
  }

  static int _rightWords(RecitationSession session) => session.result.words
      .where(
        (w) => w.word.kind == WordKind.ayah && w.status == WordStatus.correct,
      )
      .length;

  /// How far after the word the reciter is at a place found is still
  /// the place being recited.
  static const _nearWords = 60;

  /// Words recited right before the page counts as the place recited.
  static const _rightToStay = 3;

  /// When what the reciter says is not on the page open but is found
  /// elsewhere in the Quran, as when another surah is recited, starts the
  /// recitation there with the same listening, so the mushaf goes there.
  /// Returns whether it moved.
  bool _moveToPlaceRecited(RecitationSession session) {
    if (_rightWords(session) >= _rightToStay) {
      _findPlace = false;
      return false;
    }
    final listener = session.listener;
    final finder = ref.read(quranFinderProvider).value;
    if (listener is! HandoverListener || finder == null) return false;
    final found = finder.find(listener.heard);
    if (found == null) return false;
    // Near where the reciter is expected, the recitation follows by itself.
    final at = session.expected.indexWhere(
      (w) => w.surah == found.ayah.surah && w.ayah == found.ayah.ayah,
    );
    if (at >= 0 && at <= session.result.end + _nearWords) return false;
    _findPlace = false;
    // What was heard belongs to the place found, not to this page.
    _saved = true;
    listener.handOverFrom(found.heardStart);
    final mode = session.mode;
    // Not while the session is still telling its listeners.
    Future.microtask(
      () => startAt(
        found.ayah,
        position: found.position,
        mode: mode,
        listener: listener,
      ),
    );
    return true;
  }

  /// Remembers where to go on reciting from: the next ayah, or the next
  /// surah once this one is recited to its end.
  void _keepPlace(PageRecitation current) {
    final result = current.session.result;
    if (result.progress == 0) return;
    final AyahRef? next;
    if (result.isComplete && current.portion != null) {
      next = current.until;
    } else if (result.isComplete) {
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
