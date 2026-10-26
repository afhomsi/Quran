import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/recitation/harakat.dart';
import 'package:hifz/recitation/recitation_matcher.dart';
import 'package:hifz/recitation/recitation_session.dart';
import 'package:hifz/recitation/speech_listener.dart';

class _FakeListener implements SpeechListener {
  void Function(String text, bool isFinal)? _onResult;

  void say(String text) => _onResult?.call(text, true);

  @override
  Future<bool> initialize({
    required void Function(String message) onError,
    required void Function() onDone,
  }) async => true;

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
  }) async => _onResult = onResult;

  @override
  Future<void> stop() async {}
}

/// Al-Fatiha as the offline recitation model wrote it for Alafasy's
/// recitation, with harakat in modern spelling.
const fatihaWithHarakat =
    'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ '
    'الرَّحْمَنِ الرَّحِيمِ مَالِكِ يَوْمِ الدِّينِ '
    'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ '
    'صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ '
    'وَلَا الضَّالِّينَ';

List<String> words(String text) => text.split(' ');

void main() {
  final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
  final fatiha = wordsOfSurah(1, surahs.first.ayahs);

  test('a right recitation with harakat has no harakat mistakes', () {
    final r = alignRecitation(fatiha, words(fatihaWithHarakat));
    expect(r.mistakeCount, 0);
    expect(r.harakatMistakeCount, 0);
    expect(r.isComplete, isTrue);
  });

  test('a wrong haraka is found, and only in strict mode', () {
    final heard = words(fatihaWithHarakat);
    heard[4] = 'الْحَمْدَ'; // al-hamda for al-hamdu
    final r = alignRecitation(fatiha, heard);
    expect(r.mistakeCount, 0);
    expect(r.harakatMistakeCount, 1);
    final w = r.words.firstWhere((w) => w.isHarakatMistake);
    expect((w.ayah, w.wrongHarakat), (2, 'الْحَمْدَ'));

    final lenient = alignRecitation(
      fatiha,
      heard,
      mode: RecitationMode.lenient,
    );
    expect(lenient.harakatMistakeCount, 0);
  });

  test('words without harakat are not checked for them', () {
    expect(harakatDiffer('ٱلۡحَمۡدُ', 'الحمد'), isFalse);
    expect(hasHarakat('الحمد'), isFalse);
  });

  test('vowels are compared letter by letter across spellings', () {
    expect(harakatDiffer('مَٰلِكِ', 'مَالِكِ'), isFalse);
    expect(harakatDiffer('مَٰلِكِ', 'مَلِكِ'), isFalse);
    expect(harakatDiffer('مَٰلِكِ', 'مَالَكِ'), isTrue);
    expect(harakatDiffer('نَعۡبُدُ', 'نَعْبِدُ'), isTrue);
    expect(harakatDiffer('نَعۡبُدُ', 'نَعَبُدُ'), isTrue);
    // Open tanween and tanween said as meem.
    expect(harakatDiffer('هُدٗى', 'هُدًى'), isFalse);
    expect(harakatDiffer('عَظِيمٞ', 'عَظِيمٌ'), isFalse);
    expect(harakatDiffer('عَظِيمٞ', 'عَظِيمٍ'), isTrue);
    expect(harakatDiffer('أَلِيمُۢ', 'أَلِيمٌ'), isFalse);
    // A letter bare in the mushaf, merged into the next word, says nothing.
    expect(harakatDiffer('مِن', 'مِنْ'), isFalse);
  });

  test('the last letter is not checked where the reciter may stop', () {
    expect(harakatDiffer('ٱلرَّحِيمِ', 'الرَّحِيمْ'), isTrue);
    expect(harakatDiffer('ٱلرَّحِيمِ', 'الرَّحِيمْ', pause: true), isFalse);
    expect(isPauseWord('رَيۡبَۛ'), isTrue);
    final ayah = wordsOfSurah(1, surahs.first.ayahs).where((w) => w.ayah == 2);
    expect([for (final w in ayah) w.pause], [false, false, false, true]);
  });

  test('lenient mode forgives more letters and extra words', () {
    expect(wordsMatch('نعبد', 'نعيد'), isFalse);
    expect(wordsMatch('نعبد', 'نعيد', RecitationMode.lenient), isTrue);
    expect(wordsMatch('المستقيم', 'المتقم'), isFalse);
    expect(wordsMatch('المستقيم', 'المتقم', RecitationMode.lenient), isFalse);
    expect(
      wordsMatch('المستقيمين', 'المستقمن', RecitationMode.lenient),
      isTrue,
    );
    final heard = words(fatihaWithHarakat)..insert(8, 'يا');
    expect(alignRecitation(fatiha, heard).mistakeCount, 1);
    expect(
      alignRecitation(fatiha, heard, mode: RecitationMode.lenient).mistakeCount,
      0,
    );
  });

  test('harakat of the words still being said are held back', () {
    final heard = words(fatihaWithHarakat).take(6).toList();
    heard[4] = 'الْحَمْدَ';
    final r = alignRecitation(fatiha, heard, settled: false);
    expect(r.harakatMistakeCount, 0);
    expect(alignRecitation(fatiha, heard).harakatMistakeCount, 1);
  });

  testWidgets('the session tells the two kinds of mistakes apart', (
    tester,
  ) async {
    final listener = _FakeListener();
    final session = RecitationSession(
      listener: listener,
      expected: fatiha,
      surahName: (s) => surahs[s - 1].name,
    );
    await session.start();
    final heard = words(fatihaWithHarakat);
    heard[4] = 'الْحَمْدَ';
    // Ayah 4 left out.
    heard.removeRange(10, 13);
    listener.say(heard.join(' '));
    expect(session.heardHarakat, isTrue);
    expect(
      [for (final m in session.mistakes) (m.kind, m.message)],
      [
        (
          MistakeKind.harakat,
          'خطأ في الحركة في الآية 2: سمعت «الْحَمْدَ» والصواب «ٱلۡحَمۡدُ»',
        ),
        (MistakeKind.word, 'نسيت الآية 4'),
      ],
    );
    session.dispose();
  });
}
