import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/quran_models.dart';
import 'package:hifz/recitation/arabic_normalizer.dart';
import 'package:hifz/recitation/speech_listener.dart';
import 'package:hifz/recitation/speech_pieces.dart';

/// The Quran in plain spelling, without harakat, as Google's recognizer
/// writes it: the Tanzil "simple clean" text (see fixtures/README.md).
class PlainQuran {
  PlainQuran(List<Surah> surahs) {
    final ayat = (jsonDecode(
      utf8.decode(
        gzip.decode(
          File('test/fixtures/tanzil_simple_clean.json.gz').readAsBytesSync(),
        ),
      ),
    ) as List).cast<String>();
    var k = 0;
    for (final s in surahs) {
      _ayat.add([
        for (var a = 0; a < s.ayahs.length; a++)
          [
            // Pause marks are not said.
            for (final w in ayat[k++].split(RegExp(r'[\s ]+')))
              if (normalizeWord(w).isNotEmpty) w,
          ],
      ]);
    }
  }

  final _ayat = <List<List<String>>>[];

  List<String> ayah(AyahRef a) => _ayat[a.surah - 1][a.ayah - 1];

  int ayahCount(int surah) => _ayat[surah - 1].length;
}

/// A word the reciter says, as a recognizer writes it, and the ayah it is
/// in; the basmala before a surah is in its ayah 0.
class SpokenWord {
  const SpokenWord(this.text, this.ayah);

  final String text;
  final AyahRef ayah;
}

/// What a reciter says reciting [count] ayat from word [position] of
/// [from] on, going on into the next surahs with their basmala.
List<SpokenWord> recitationOf(
  PlainQuran quran,
  AyahRef from,
  int count, {
  int position = 1,
  bool istiadha = false,
}) {
  final words = <SpokenWord>[
    if (istiadha)
      for (final w in 'أعوذ بالله من الشيطان الرجيم'.split(' '))
        SpokenWord(w, AyahRef(from.surah, 0)),
  ];
  var a = from;
  for (var n = 0; n < count; n++) {
    if (a.ayah == 1 && a.surah != 1 && a.surah != 9) {
      for (final w in 'بسم الله الرحمن الرحيم'.split(' ')) {
        words.add(SpokenWord(w, AyahRef(a.surah, 0)));
      }
    }
    final ayah = quran.ayah(a);
    for (final w in ayah.skip(n == 0 ? position - 1 : 0)) {
      words.add(SpokenWord(w, a));
    }
    if (a.ayah < quran.ayahCount(a.surah)) {
      a = AyahRef(a.surah, a.ayah + 1);
    } else if (a.surah < 114) {
      a = AyahRef(a.surah + 1, 1);
    } else {
      break;
    }
  }
  return words;
}

/// One result of a recognizer: the text of its listening session so far.
class RecognizerEvent {
  const RecognizerEvent(this.at, this.text, this.isFinal, this.spoken);

  /// When it comes, in milliseconds from the start.
  final int at;
  final String text;
  final bool isFinal;

  /// How many of the words were said by then.
  final int spoken;
}

/// The words a simulated recognizer got wrong or lost on purpose, so a
/// test knows how many mistakes to expect.
class Noise {
  int dropped = 0;
  int wrong = 0;
  int get total => dropped + wrong;
}

bool _startsAyah(List<SpokenWord> words, int i) =>
    i > 0 && words[i].ayah != words[i - 1].ayah;

/// How fast the reciter recites: a word every 230–330 ms, and short
/// breaths between ayat.
int _wordTime(Random rnd) => 230 + rnd.nextInt(100);
int _breath(Random rnd) =>
    rnd.nextDouble() < 0.75 ? 120 + rnd.nextInt(300) : 550 + rnd.nextInt(500);

/// Google's recognizer on Android as heard in the app: plain spelling and
/// no harakat, partial results word by word (sometimes two at once, the
/// last word first half written), a word long heard now and then written
/// another way and then back, the text starting over after a breath
/// within one listening session and losing the first words said then,
/// and now and then the session ending, losing the words said until it
/// listens again. [drop] and [wrong] are how often a word is lost or
/// heard as another word.
List<RecognizerEvent> googleEvents(
  List<SpokenWord> words,
  Random rnd, {
  double drop = 0,
  double wrong = 0,
  Noise? noise,
}) {
  final events = <RecognizerEvent>[];
  var t = 0;
  var segment = <String>[];
  var lose = 0;
  var held = false;
  void emit(List<String> text, int spoken, {bool isFinal = false}) =>
      events.add(RecognizerEvent(t, text.join(' '), isFinal, spoken));

  for (var i = 0; i < words.length; i++) {
    t += _wordTime(rnd);
    if (_startsAyah(words, i)) {
      final breath = _breath(rnd);
      if (held) {
        // A word held back comes before the pause.
        emit(segment, i);
        held = false;
      }
      t += breath;
      final r = rnd.nextDouble();
      if (r < 0.1 && segment.isNotEmpty) {
        // The listening session ends; it starts again 300 ms later.
        emit(segment, i, isFinal: true);
        segment = [];
        t += 350;
        lose = rnd.nextInt(2);
      } else if (r < 0.45 && breath > 250 && segment.isNotEmpty) {
        // Starts over within the session.
        segment = [];
        final l = rnd.nextDouble();
        lose = l < 0.55 ? 0 : (l < 0.85 ? 1 : 2);
      }
    }
    if (lose > 0) {
      lose--;
      continue;
    }
    var word = words[i].text;
    if (rnd.nextDouble() < drop) {
      noise?.dropped++;
      continue;
    }
    if (rnd.nextDouble() < wrong) {
      noise?.wrong++;
      word = _otherWord(words, word, rnd);
    }
    var cut = false;
    if (word.length >= 4 && rnd.nextDouble() < 0.15) {
      emit([...segment, word.substring(0, word.length - 2)], i);
      t += 60;
      cut = true;
    }
    segment.add(word);
    if (!held && !cut && rnd.nextDouble() < 0.2) {
      held = true;
      continue;
    }
    held = false;
    if (segment.length > 6 && rnd.nextDouble() < 0.05) {
      // One of the last words, as the recognizer hears more of the phrase.
      final k = segment.length - 2 - rnd.nextInt(min(8, segment.length - 2));
      final changed = [...segment]..[k] = 'و${segment[k]}';
      emit(changed, i + 1);
      t += 40;
    }
    emit(segment, i + 1);
  }
  t += 600;
  if (segment.isNotEmpty) emit(segment, words.length, isFinal: true);
  return events;
}

/// A word that is not [word], from the recitation.
String _otherWord(List<SpokenWord> words, String word, Random rnd) {
  while (true) {
    final other = words[rnd.nextInt(words.length)].text;
    if (normalizeWord(other) != normalizeWord(word) && other.length > 2) {
      return other;
    }
  }
}

/// The offline model (Whisper with a voice detector) as heard in the
/// app: the audio is cut at each pause of half a second or more, or after
/// 20 s of speech without one, which may cut a word in two; each piece is
/// transcribed and passed on by [SpeechPieces], as the app does, and
/// while it is recited all of it but its last word is transcribed every
/// 2.5 s of speech, sometimes with words guessed ahead of the reciter.
/// Results come in order and none is lost.
List<RecognizerEvent> offlineEvents(List<SpokenWord> words, Random rnd) {
  final events = <RecognizerEvent>[];
  var t = 0;
  var spoken = 0;
  final pieces = SpeechPieces(
    (text, isFinal) => events.add(RecognizerEvent(t, text, isFinal, spoken)),
  );
  var segment = <String>[];
  var speech = 0;
  var lastPartial = 0;
  for (var i = 0; i < words.length; i++) {
    if (_startsAyah(words, i)) {
      final breath = _breath(rnd);
      t += breath;
      if (breath >= 500 && segment.isNotEmpty) {
        // The detector cuts here; transcribing takes a little.
        t += 500 + 400;
        spoken = i;
        pieces.piece(segment.join(' '), cut: false);
        segment = [];
        speech = 0;
        lastPartial = 0;
      }
    }
    final time = _wordTime(rnd);
    if (speech + time > 20000 && words[i].text.length >= 4) {
      // Cut after 20 s of speech, in the middle of this word.
      final w = words[i].text;
      final half = w.length ~/ 2;
      t += time ~/ 2 + 400;
      spoken = i;
      pieces.piece([...segment, w.substring(0, half)].join(' '), cut: true);
      t += time - time ~/ 2 - 400;
      segment = [w.substring(half)];
      speech = time - time ~/ 2;
      lastPartial = 0;
      continue;
    }
    t += time;
    speech += time;
    segment.add(words[i].text);
    if (speech - lastPartial >= 2500) {
      lastPartial = speech;
      final text = segment.take(segment.length - 1).toList();
      if (rnd.nextDouble() < 0.15) {
        // Guesses a few words ahead, then takes them back.
        final ahead = 1 + rnd.nextInt(3);
        for (var k = i; k < words.length && k <= i + ahead; k++) {
          text.add(words[k].text);
        }
      }
      t += 300;
      spoken = i + 1;
      pieces.partial(text.join(' '));
      t -= 300;
    }
  }
  t += 600 + 400;
  spoken = words.length;
  if (segment.isNotEmpty) pieces.piece(segment.join(' '), cut: false);
  // Transcribing takes time; results still come in the order heard.
  events.sort((a, b) => a.at.compareTo(b.at));
  return events;
}

/// Plays a simulated recognizer's results to the app.
class SimulatedListener implements SpeechListener, SlowResults {
  SimulatedListener({required this.keepsResults});

  /// The offline model sends results every few seconds.
  @override
  Duration get quietDelay =>
      keepsResults ? const Duration(seconds: 4) : quickQuietDelay;

  /// Whether results that come between two listening sessions wait for
  /// the next one, as with the offline model; Google's are lost.
  final bool keepsResults;

  void Function(String text, bool isFinal)? _onResult;
  void Function()? _onDone;
  final _waiting = <(String, bool)>[];
  bool listening = false;

  /// Results lost because nothing was listening.
  int lost = 0;

  void say(String text, bool isFinal) {
    final onResult = _onResult;
    if (!listening || onResult == null) {
      if (keepsResults) {
        _waiting.add((text, isFinal));
      } else {
        lost++;
      }
      return;
    }
    if (isFinal) {
      listening = false;
      _onResult = null;
    }
    onResult(text, isFinal);
    if (isFinal) _onDone?.call();
  }

  @override
  Future<bool> initialize({
    required void Function(String message) onError,
    required void Function() onDone,
  }) async {
    _onDone = onDone;
    return true;
  }

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    _onResult = onResult;
    listening = true;
    while (_waiting.isNotEmpty && listening) {
      final (text, isFinal) = _waiting.removeAt(0);
      say(text, isFinal);
    }
  }

  @override
  Future<void> stop() async {
    if (!listening) return;
    listening = false;
    _onResult = null;
    _onDone?.call();
  }
}
