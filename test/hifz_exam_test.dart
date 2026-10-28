import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/audio/audio_store.dart';
import 'package:hifz/audio/ayah_audio.dart';
import 'package:hifz/data/hifz_exam.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/mushaf_repository.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:hifz/features/hifz_exam/exam_stop.dart';
import 'package:hifz/features/mushaf/mushaf_screen.dart';
import 'package:hifz/recitation/page_recitation.dart';
import 'package:hifz/recitation/recitation_matcher.dart';
import 'package:hifz/recitation/alert_sound.dart';
import 'package:hifz/recitation/speech_listener.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_listener.dart';
import 'fake_player.dart';

final _mushaf = parseMushaf(File(mushafLayoutAssetPath).readAsStringSync());
final _surahs = parseSurahs(File(quranAssetPath).readAsStringSync());

void main() {
  test('only surahs longer than a page are examined', () {
    for (final (surah, allowed) in [
      (1, false), // Al-Fatiha
      (2, true), // Al-Baqarah
      (67, true), // Al-Mulk, two pages and more
      (93, false), // Ad-Duha
      (112, false), // Al-Ikhlas
      (114, false), // An-Nas
    ]) {
      expect(examAllowed(_mushaf, surah), allowed, reason: 'surah $surah');
    }
    // A surah over two pages but shorter than one in all is left out.
    for (var s = 1; s <= 114; s++) {
      final pages =
          _mushaf.pageOf(AyahRef(s, ayahCounts[s - 1])) -
          _mushaf.surahStartPage(s) +
          1;
      if (examAllowed(_mushaf, s)) expect(pages, greaterThan(1));
    }
  });

  test('about a tenth of the surah, in short groups that do not overlap', () {
    for (var seed = 0; seed < 50; seed++) {
      for (var s = 1; s <= 114; s++) {
        if (!examAllowed(_mushaf, s)) continue;
        final count = ayahCounts[s - 1];
        final exam = pickExam(s, count, Random(seed));
        final total = exam.fold(0, (sum, q) => sum + q.ayahCount);
        expect(total, max(2, (count * 0.1).round()), reason: 'surah $s');
        var last = 1; // Never the first ayah: one shows before.

        for (final q in exam) {
          expect(q.surah, s);
          expect(q.from, greaterThan(last), reason: '$exam');
          expect(q.to, lessThanOrEqualTo(count));
          expect(q.ayahCount, inInclusiveRange(1, 4), reason: '$exam');
          last = q.to;
        }
      }
    }
    // Al-Baqarah: 29 of its 286 ayat, in ten groups.
    final baqarah = pickExam(2, 286, Random(3));
    expect(baqarah, hasLength(10));
    expect(baqarah.fold(0, (sum, q) => sum + q.ayahCount), 29);
  });

  testWidgets('recites each question in the mushaf, stops and goes on', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'settings': '{"askRecitationMode":false}',
    });
    final prefs = await SharedPreferences.getInstance();
    final listener = FakeListener();
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
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: MushafScreen(initialPage: 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MushafScreen)),
    );
    final controller = container.read(pageRecitationProvider.notifier);
    String ayat(int from, int to) =>
        [for (var a = from; a <= to; a++) _surahs[1].ayahs[a - 1]].join(' ');

    await controller.startExam(const [
      ExamQuestion(2, 6, 7),
      ExamQuestion(2, 30, 31),
      ExamQuestion(2, 40, 41),
    ]);
    await tester.pumpAndSettle();
    var recitation = container.read(pageRecitationProvider)!;
    expect(recitation.from, const AyahRef(2, 6));
    expect(recitation.until, const AyahRef(2, 8));
    expect(listener.listening, isTrue);
    // Only ayat 6 and 7 are recited; the ayat before them show.
    expect(
      {
        for (final w in recitation.session.expected)
          if (w.kind == WordKind.ayah) w.ayah,
      },
      {6, 7},
    );
    expect(find.text('سمّع الآيات من 6 إلى 7 من سورة البقرة'), findsOneWidget);
    expect(find.textContaining('السؤال 1 من 3'), findsOneWidget);

    // Recited to the end: stop, and on to the next one.
    listener.say(ayat(6, 7), isFinal: true);
    await tester.pump();
    await tester.pump();
    expect(find.text('توقف'), findsOneWidget);
    expect(find.text('بلا أخطاء'), findsOneWidget);
    expect(
      find.text('السؤال 2 من 3: سمّع الآيات من 30 إلى 31 من سورة البقرة'),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('السؤال التالي'),
      ),
    );
    await tester.pumpAndSettle();
    recitation = container.read(pageRecitationProvider)!;
    expect(recitation.from, const AyahRef(2, 30));
    expect(recitation.exam!.index, 1);
    expect(listener.listening, isTrue);

    // A mistake; the popup goes on by itself after a few seconds.
    final words = ayat(30, 31).split(' ');
    words[words.length - 1] = 'الناس';
    listener.say(words.join(' '), isFinal: true);
    await tester.pump();
    await tester.pump();
    expect(find.text('1 خطأ'), findsOneWidget);
    await tester.pump(examNextDelay);
    await tester.pumpAndSettle();
    expect(find.text('توقف'), findsNothing);
    expect(container.read(pageRecitationProvider)!.from, const AyahRef(2, 40));

    // The last one ends with the result.
    listener.say(ayat(40, 41), isFinal: true);
    await tester.pump();
    await tester.pump();
    expect(find.text('انتهى الاختبار'), findsOneWidget);
    expect(find.text('النتيجة: 2 من 3'), findsOneWidget);
    expect(find.textContaining('البقرة 30–31 (1 خطأ)'), findsOneWidget);

    // A new exam asks other ayat of the same surah.
    await tester.tap(find.text('اختبار جديد'));
    await tester.pumpAndSettle();
    recitation = container.read(pageRecitationProvider)!;
    expect(recitation.exam!.index, 0);
    expect(recitation.exam!.questions, hasLength(10));
    await tester.tap(find.byTooltip('إغلاق التسميع'));
    await tester.pumpAndSettle();
  });
}
