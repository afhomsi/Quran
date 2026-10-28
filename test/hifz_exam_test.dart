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
import 'package:hifz/features/hifz_exam/hifz_exam_screen.dart';
import 'package:hifz/features/recitation/recitation_mode.dart';
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
        var last = 0;
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

  testWidgets('recites each group in turn and gives the score', (tester) async {
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
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: HifzExamScreen(random: Random(7)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('الفاتحة'), findsNothing);
    await tester.tap(find.text('البقرة'));
    await tester.pumpAndSettle();

    final exam = pickExam(2, 286, Random(7));
    expect(find.text('سورة البقرة: 10 أسئلة، 29 آية'), findsOneWidget);
    expect(
      find.text(
        'سمّع الآيات من ${(exam[0].from)} إلى ${(exam[0].to)} من سورة البقرة',
      ),
      findsOneWidget,
    );

    Future<void> recite(ExamQuestion q, {String? wrongEnd}) async {
      await tester.tap(find.text('ابدأ التسميع'));
      await tester.pumpAndSettle();
      final words = [
        for (var a = q.from; a <= q.to; a++) _surahs[1].ayahs[a - 1],
      ].join(' ').split(' ');
      if (wrongEnd != null) words[words.length - 1] = wrongEnd;
      listener.say(words.join(' '), isFinal: true);
      await tester.pumpAndSettle();
      // Reciting to the end stops listening.
      expect(find.text('إيقاف'), findsNothing);
      // The report opens at the end; close it.
      Navigator.of(tester.element(find.byType(MistakesReport))).pop();
      await tester.pumpAndSettle();
    }

    // The first question, recited right, then on to the second.
    await tester.tap(find.text('السؤال 1 من 10'));
    await tester.pumpAndSettle();
    expect(
      find.text('اختبار: البقرة ${(exam[0].from)}–${(exam[0].to)}'),
      findsOneWidget,
    );
    await recite(exam[0]);
    await tester.tap(find.text('السؤال التالي'));
    await tester.pumpAndSettle();
    expect(
      find.text('اختبار: البقرة ${(exam[1].from)}–${(exam[1].to)}'),
      findsOneWidget,
    );
    // The second with a wrong last word, then back to the exam.
    await recite(exam[1], wrongEnd: 'الناس');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('بلا أخطاء'), findsOneWidget);
    expect(find.text('1 خطأ'), findsOneWidget);
    expect(find.text('لم تُسمَّع بعد'), findsWidgets);
    expect(find.text('السؤال 3 من 10'), findsOneWidget);
  });
}
