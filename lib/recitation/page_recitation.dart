import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/ayah_audio.dart';
import '../data/mushaf_models.dart';
import '../data/mushaf_repository.dart';
import '../data/quran_models.dart';
import '../data/quran_repository.dart';
import '../data/recitation_history.dart';
import 'alert_sound.dart';
import 'recitation_matcher.dart';
import 'recitation_session.dart';
import 'session_record.dart';
import 'speech_listener.dart';

/// How each ayah of a page was recited so far.
enum AyahRecitation { correct, mistake }

/// Reciting the page open in the mushaf, from a bar under the page.
class PageRecitation {
  const PageRecitation(
    this.page,
    this.session,
    this.version, {
    this.hideText = true,
  });

  final int page;
  final RecitationSession session;

  /// Changes whenever the session does, so listeners redraw.
  final int version;

  /// Hifz is recited from memory, so the words of the page are hidden and
  /// show one by one as they are recited.
  final bool hideText;

  PageRecitation copyWith({int? version, bool? hideText}) => PageRecitation(
    page,
    session,
    version ?? this.version,
    hideText: hideText ?? this.hideText,
  );

  /// How many words of each ayah were recited so far, right or wrong. An
  /// ayah recited to its end shows all its words, whatever the count, so
  /// a word printed apart on the page does not stay hidden.
  Map<AyahRef, int> get recitedWords {
    final counts = <AyahRef, int>{};
    final unfinished = <AyahRef>{};
    for (final w in session.result.words) {
      if (w.word.kind != WordKind.ayah) continue;
      final ayah = AyahRef(w.surah, w.ayah);
      if (w.status == WordStatus.pending) {
        unfinished.add(ayah);
      } else {
        counts[ayah] = (counts[ayah] ?? 0) + 1;
      }
    }
    return {
      for (final e in counts.entries)
        e.key: unfinished.contains(e.key) ? e.value : allWords,
    };
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
List<ExpectedWord> wordsOfPage(MushafPage page, List<Surah> surahs) {
  final seen = <AyahRef>{};
  return wordsToRecite([
    for (final w in page.words)
      if (seen.add(w.ayah))
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
    ref.onDispose(() => _session?.dispose());
    return null;
  }

  /// Opens the bar for [page] and starts listening.
  Future<void> start(int page) async {
    final mushaf = ref.read(mushafProvider).value;
    final surahs = ref.read(surahsProvider).value;
    if (mushaf == null || surahs == null) return;
    if (state?.page != page) {
      close();
      final session = RecitationSession(
        listener: ref.read(speechListenerProvider),
        expected: wordsOfPage(mushaf.page(page), surahs),
        surahName: (s) => surahs[s - 1].name,
      )..onMistake = (_) => ref.read(mistakeAlertProvider)();
      session.addListener(() => _changed(session));
      _saved = false;
      _session = session;
      state = PageRecitation(page, session, 0);
    }
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
    final current = state;
    if (current == null || current.session != session) return;
    if (session.result.isComplete) _save();
    state = current.copyWith(version: current.version + 1);
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
