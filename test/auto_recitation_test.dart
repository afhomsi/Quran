import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/app.dart';
import 'package:hifz/audio/audio_store.dart';
import 'package:hifz/audio/ayah_audio.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/mushaf_repository.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:hifz/features/mushaf/mushaf_page_view.dart';
import 'package:hifz/features/mushaf/mushaf_screen.dart';
import 'package:hifz/recitation/alert_sound.dart';
import 'package:hifz/recitation/auto_recitation.dart';
import 'package:hifz/recitation/page_recitation.dart';
import 'package:hifz/recitation/quran_finder.dart';
import 'package:hifz/recitation/speech_listener.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_listener.dart';
import 'fake_player.dart';

final _surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
final _mushaf = parseMushaf(File(mushafLayoutAssetPath).readAsStringSync());

List<String> _words(String text) => text.split(' ');

/// The words of an ayah from word [from] on (counted from 1).
List<String> _ayah(int surah, int ayah, [int from = 1]) =>
    _surahs[surah - 1].ayahs[ayah - 1].split(' ').sublist(from - 1);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeListener listener, {
  Widget? child,
}) async {
  SharedPreferences.setMockInitialValues({
    'settings': '{"askRecitationMode":false}',
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        mushafProvider.overrideWith((ref) async => _mushaf),
        surahsProvider.overrideWith((ref) async => _surahs),
        speechListenerProvider.overrideWithValue(listener),
        mistakeAlertProvider.overrideWithValue(() {}),
        ayahPlayerProvider.overrideWithValue(FakePlayer()),
        audioStoreProvider.overrideWithValue(AudioStore.none()),
      ],
      child:
          child ??
          const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: MushafScreen(initialPage: 1),
            ),
          ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(child == null ? MushafScreen : HifzApp)),
  );
}

void main() {
  group('the place recited is found in the whole Quran', () {
    final finder = QuranFinder(_surahs);

    test('from the first words of an ayah, as the recognizer writes them', () {
      final found = finder.find(_words('تبارك الذي بيده الملك وهو على'))!;
      expect(found.ayah, const AyahRef(67, 1));
      expect(found.position, 1);
      expect(found.heardStart, 0);
    });

    test('part way through an ayah', () {
      // Al-Kahf 18:10 from its sixth word.
      final found = finder.find(_ayah(18, 10, 6))!;
      expect(found.ayah, const AyahRef(18, 10));
      expect(found.position, 6);
    });

    test('waits while the words are in more than one place', () {
      // Ali 'Imran 3:2 is the start of Ayat al-Kursi as well.
      expect(finder.find(_words('الله لا إله إلا هو الحي القيوم')), isNull);
      final found = finder.find(
        _words('الله لا إله إلا هو الحي القيوم لا تأخذه سنة ولا نوم'),
      )!;
      expect(found.ayah, const AyahRef(2, 255));
      expect(found.position, 1);
    });

    test('a repeated ayah is placed by the ayah after it', () {
      expect(finder.find(_ayah(55, 13)), isNull);
      final found = finder.find([..._ayah(55, 13), ..._ayah(55, 14)])!;
      expect(found.ayah, const AyahRef(55, 13));
    });

    test('too few words are not enough', () {
      expect(finder.find(_words('الحمد لله')), isNull);
      expect(finder.find(const []), isNull);
    });

    test('the isti\'adha and basmala before a surah belong to it', () {
      final found = finder.find(
        _words(
          'أعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم '
          'تبارك الذي بيده الملك وهو على كل شيء قدير',
        ),
      )!;
      expect(found.ayah, const AyahRef(67, 1));
      expect(found.heardStart, 0);

      final fatiha = finder.find(
        _words('بسم الله الرحمن الرحيم الحمد لله رب العالمين الرحمن الرحيم'),
      )!;
      expect(fatiha.ayah, const AyahRef(1, 1));
      expect(fatiha.heardStart, 0);
    });

    test('the basmala before an ayah part way through a surah is left out', () {
      final found = finder.find([
        ..._words('بسم الله الرحمن الرحيم'),
        ..._ayah(36, 12),
      ])!;
      expect(found.ayah, const AyahRef(36, 12));
      expect(found.heardStart, 4);
    });

    test('words said before reciting are left out', () {
      final found = finder.find([..._words('السلام عليكم'), ..._ayah(36, 12)])!;
      expect(found.ayah, const AyahRef(36, 12));
      expect(found.position, 1);
      expect(found.heardStart, 2);
    });

    test('a word the recognizer missed does not lose the place', () {
      final words = _ayah(18, 10)..removeAt(3);
      final found = finder.find(words)!;
      expect(found.ayah, const AyahRef(18, 10));
      expect(found.position, 1);
    });
  });

  group('reciting from anywhere', () {
    testWidgets('finds the place, opens its page and follows on', (
      tester,
    ) async {
      final listener = FakeListener();
      final container = await _pump(tester, listener);
      await container.read(autoRecitationProvider.notifier).start();
      await tester.pumpAndSettle();
      expect(listener.listening, isTrue);
      expect(
        find.text('ابدأ القراءة من أي موضع… أبحث عن موضعك في القرآن'),
        findsOneWidget,
      );

      // Ayat al-Kursi, part of it heard so far.
      final kursi = _ayah(2, 255);
      listener.say(kursi.take(4).join(' '));
      await tester.pumpAndSettle();
      expect(container.read(pageRecitationProvider), isNull);

      listener.say(kursi.take(12).join(' '));
      await tester.pumpAndSettle();
      expect(container.read(autoRecitationProvider), isNull);
      final recitation = container.read(pageRecitationProvider)!;
      expect(recitation.from, const AyahRef(2, 255));
      expect(recitation.startWord, 0);
      expect(recitation.session.isListening, isTrue);
      // The words heard while searching are compared too.
      expect(recitation.session.mistakes, isEmpty);
      expect(recitation.currentWord, (const AyahRef(2, 255), 13));
      // The page of Ayat al-Kursi opens.
      final page = _mushaf.pageOf(const AyahRef(2, 255));
      expect(
        tester.widget<MushafPageView>(find.byType(MushafPageView)).page.number,
        page,
      );

      // The same listening goes on to the end of the ayah and the next.
      listener.say([...kursi, ..._ayah(2, 256)].join(' '));
      await tester.pumpAndSettle();
      final now = container.read(pageRecitationProvider)!;
      expect(now.session.mistakes, isEmpty);
      expect(now.ayahStates[const AyahRef(2, 255)], AyahRecitation.correct);
      expect(now.ayahStates[const AyahRef(2, 256)], AyahRecitation.correct);
      await tester.tap(find.byTooltip('إغلاق التسميع'));
      await tester.pumpAndSettle();
    });

    testWidgets('part way through an ayah, the words before it show', (
      tester,
    ) async {
      final listener = FakeListener();
      final container = await _pump(tester, listener);
      await container.read(autoRecitationProvider.notifier).start();
      await tester.pumpAndSettle();

      // Al-Kahf 18:10 from its sixth word, after a basmala.
      final words = ['بسم الله الرحمن الرحيم', ..._ayah(18, 10, 6)];
      listener.say(words.join(' '));
      await tester.pumpAndSettle();
      final recitation = container.read(pageRecitationProvider)!;
      expect(recitation.from, const AyahRef(18, 10));
      expect(recitation.startWord, 5);
      expect(recitation.session.mistakes, isEmpty);
      expect(
        recitation.ayahStates[const AyahRef(18, 10)],
        AyahRecitation.correct,
      );
      // Coloured by their own place in the ayah.
      expect(
        recitation.wordStates.keys.where((k) => k.$1 == const AyahRef(18, 10)),
        everyElement(
          isA<(AyahRef, int)>().having((k) => k.$2, 'position', greaterThan(5)),
        ),
      );
      expect(
        recitation.recitedWords[const AyahRef(18, 10)],
        PageRecitation.allWords,
      );
      await tester.tap(find.byTooltip('إغلاق التسميع'));
      await tester.pumpAndSettle();
    });

    testWidgets('a place found after a pause takes the words before it', (
      tester,
    ) async {
      final listener = FakeListener();
      final container = await _pump(tester, listener);
      await container.read(autoRecitationProvider.notifier).start();
      await tester.pumpAndSettle();

      // Too few words to tell, then the recognizer ends its session.
      final ayah = _ayah(36, 12);
      listener.say(ayah.take(3).join(' '), isFinal: true);
      await tester.pump(const Duration(milliseconds: 400));
      expect(container.read(pageRecitationProvider), isNull);
      expect(listener.listening, isTrue);

      listener.say(ayah.skip(3).take(5).join(' '));
      await tester.pumpAndSettle();
      final recitation = container.read(pageRecitationProvider)!;
      expect(recitation.from, const AyahRef(36, 12));
      expect(recitation.startWord, 0);
      expect(recitation.session.mistakes, isEmpty);
      expect(recitation.currentWord, (const AyahRef(36, 12), 9));
      await tester.tap(find.byTooltip('إغلاق التسميع'));
      await tester.pumpAndSettle();
    });

    testWidgets('starts from the recitation picker', (tester) async {
      final listener = FakeListener();
      await _pump(tester, listener, child: const HifzApp());
      await tester.tap(find.text('الفهرس'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تسميع'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تسميع تلقائي: اقرأ من أي موضع'));
      await tester.pumpAndSettle();
      expect(
        find.text('ابدأ القراءة من أي موضع… أبحث عن موضعك في القرآن'),
        findsOneWidget,
      );
      expect(listener.listening, isTrue);
      await tester.tap(find.byTooltip('إغلاق التسميع'));
      await tester.pumpAndSettle();
      expect(listener.listening, isFalse);
    });
  });
}
