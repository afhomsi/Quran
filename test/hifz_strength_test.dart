import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/app.dart';
import 'package:hifz/audio/audio_store.dart';
import 'package:hifz/audio/ayah_audio.dart';
import 'package:hifz/data/hifz_exam.dart';
import 'package:hifz/data/hifz_strength.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/mushaf_repository.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:hifz/data/recitation_history.dart';
import 'package:hifz/features/review/hifz_map_screen.dart';
import 'package:hifz/features/review/today_card.dart';
import 'package:hifz/features/shell/navigation.dart';
import 'package:hifz/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_player.dart';

final _mushaf = parseMushaf(File(mushafLayoutAssetPath).readAsStringSync());

/// A recitation of pages [first] to [last] on [date], with a mistake in
/// each of [mistakes].
RecitationRecord _recited(
  DateTime date,
  int first,
  int last, {
  List<AyahRef> mistakes = const [],
  bool complete = true,
}) => RecitationRecord(
  date: date,
  page: first,
  first: _mushaf.page(first).firstAyah,
  last: _mushaf.page(last).words.last.ayah,
  wordsDone: 10,
  wordsTotal: 10,
  complete: complete,
  mistakes: [for (final a in mistakes) MistakeRecord(a, 'x')],
);

final _day1 = DateTime(2026, 11, 1, 9);
DateTime _later(int days, [int hours = 0]) =>
    _day1.add(Duration(days: days, hours: hours));

void main() {
  drillTests();
  test('a page recited right waits longer each day it is recited', () {
    var pages = pageHifzOf([_recited(_day1, 1, 1)], _mushaf);
    expect(pages.keys, [1]);
    expect(pages[1]!.strength, PageStrength.medium);
    expect(pages[1]!.isDueOn(_day1), isFalse);
    expect(pages[1]!.isDueOn(_later(1)), isFalse);
    expect(pages[1]!.isDueOn(_later(2)), isTrue);

    // Again the same day: no stronger.
    pages = pageHifzOf([
      _recited(_day1, 1, 1),
      _recited(_later(0, 3), 1, 1),
    ], _mushaf);
    expect(pages[1]!.cleanDays, 1);

    pages = pageHifzOf([
      _recited(_day1, 1, 1),
      _recited(_later(1), 1, 1),
      _recited(_later(3), 1, 1),
    ], _mushaf);
    expect(pages[1]!.cleanDays, 3);
    expect(pages[1]!.strength, PageStrength.strong);
    // 7 days after the last recitation.
    expect(pages[1]!.isDueOn(_later(9)), isFalse);
    expect(pages[1]!.isDueOn(_later(10)), isTrue);
  });

  test('a mistake makes the page weak and due the next day', () {
    final pages = pageHifzOf([
      _recited(_day1, 2, 3),
      _recited(_later(1), 2, 3),
      _recited(_later(3), 2, 3, mistakes: [const AyahRef(2, 10)]),
    ], _mushaf);
    expect(_mushaf.pageOf(const AyahRef(2, 10)), 3);
    expect(pages[2]!.strength, PageStrength.strong);
    expect(pages[3]!.strength, PageStrength.weak);
    expect(pages[3]!.isDueOn(_later(4)), isTrue);
    expect(pages[2]!.isDueOn(_later(4)), isFalse);

    // Recited right again: medium.
    final fixed = pageHifzOf([
      _recited(_day1, 2, 3),
      _recited(_later(3), 2, 3, mistakes: [const AyahRef(2, 10)]),
      _recited(_later(4), 3, 3),
    ], _mushaf);
    expect(fixed[3]!.strength, PageStrength.medium);
  });

  test('a page left part way is not counted, unless it has a mistake', () {
    final partial = RecitationRecord(
      date: _day1,
      page: 2,
      first: const AyahRef(2, 1),
      last: _mushaf.page(3).firstAyah,
      wordsDone: 5,
      wordsTotal: 50,
      complete: false,
      mistakes: const [],
    );
    expect(pagesOf(partial, _mushaf), {2});
  });

  test('the daily review takes the weakest pages first, in runs', () {
    final pages = pageHifzOf([
      _recited(_day1, 10, 19),
      _recited(_later(1), 50, 50, mistakes: [_mushaf.page(50).firstAyah]),
    ], _mushaf);
    final review = dailyReview(pages, _later(3));
    expect(review.first, const ReviewRun(50, 50, PageStrength.weak));
    expect(review.skip(1), [const ReviewRun(10, 13, PageStrength.medium)]);
    expect(duePageCount(pages, _later(3)), 11);
    expect(review.first.until(_mushaf), _mushaf.page(51).firstAyah);
    expect(dailyReview(pages, _day1), isEmpty);
  });

  testWidgets('opens on today\'s wird when a review is due', (tester) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 2));
    final container = await _start(tester, [
      _recited(yesterday, 1, 1, mistakes: [const AyahRef(1, 5)]),
    ]);
    expect(container.read(appTabProvider), AppTab.khatma);
    expect(find.byType(TodayCard), findsOneWidget);
    expect(find.text('ابدأ المراجعة'), findsOneWidget);
    expect(find.text('سمّع أخطائي (1)'), findsOneWidget);
    expect(find.text('ربط الصفحات'), findsOneWidget);
    expect(find.text('الفاتحة'), findsOneWidget);

    await tester.tap(find.text('خريطة حفظي'));
    await tester.pumpAndSettle();
    expect(find.byType(HifzMapScreen), findsOneWidget);
    expect(find.text('ضعيف 1'), findsOneWidget);
  });

  testWidgets('opens on the mushaf when nothing is due, or not chosen', (
    tester,
  ) async {
    var container = await _start(tester, [_recited(DateTime.now(), 1, 1)]);
    expect(container.read(appTabProvider), AppTab.mushaf);

    final yesterday = DateTime.now().subtract(const Duration(days: 2));
    container = await _start(tester, [
      _recited(yesterday, 1, 1, mistakes: [const AyahRef(1, 5)]),
    ], openOnToday: false);
    expect(container.read(appTabProvider), AppTab.mushaf);
  });
}

Future<ProviderContainer> _start(
  WidgetTester tester,
  List<RecitationRecord> history, {
  bool openOnToday = true,
}) async {
  SharedPreferences.setMockInitialValues({
    recitationHistoryKey: jsonEncode([for (final r in history) r.toJson()]),
    settingsKey: jsonEncode(
      const AppSettings().copyWith(openOnToday: openOnToday).toJson(),
    ),
  });
  final prefs = await SharedPreferences.getInstance();
  final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
  tester.view.physicalSize = const Size(1080, 2316);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        mushafProvider.overrideWith((ref) async => _mushaf),
        surahsProvider.overrideWith((ref) async => surahs),
        ayahPlayerProvider.overrideWithValue(FakePlayer()),
        audioStoreProvider.overrideWithValue(AudioStore.none()),
        screenWakeProvider.overrideWithValue((on) async {}),
      ],
      child: const HifzApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

void drillTests() {
  test('a mistake stays until the ayah is recited right', () {
    final wrong = _recited(_day1, 2, 3, mistakes: [const AyahRef(2, 10)]);
    expect(pendingMistakes([wrong]), [const AyahRef(2, 10)]);
    // A recitation that did not reach it leaves it.
    expect(pendingMistakes([wrong, _recited(_later(1), 1, 1)]), [
      const AyahRef(2, 10),
    ]);
    expect(pendingMistakes([wrong, _recited(_later(1), 3, 3)]), isEmpty);
    expect(
      pendingMistakes([
        wrong,
        _recited(_later(1), 3, 3, mistakes: [const AyahRef(2, 10)]),
      ]),
      [const AyahRef(2, 10)],
    );
    expect(mistakeQuestions([const AyahRef(2, 10)]), [
      const ExamQuestion(2, 10, 10),
    ]);
  });

  test('counts the days in a row with a recitation', () {
    final now = _later(5, 3);
    expect(recitationStreak([], now), 0);
    expect(
      recitationStreak([
        _recited(_later(5), 1, 1),
        _recited(_later(4), 1, 1),
        _recited(_later(4, 2), 1, 1),
        _recited(_later(3), 1, 1),
        _recited(_later(1), 1, 1),
      ], now),
      3,
    );
    // Not yet today: counts up to yesterday.
    expect(recitationStreak([_recited(_later(4), 1, 1)], now), 1);
    expect(recitationStreak([_recited(_later(3), 1, 1)], now), 0);
  });

  test('page linking asks the last ayah of a page and the next', () {
    final questions = linkingQuestions(_mushaf, [2, 49, 604], Random(1));
    // Page 49 ends Al-Baqarah; 604 is the last page.
    expect(questions, hasLength(1));
    final q = questions.single;
    expect(q.surah, 2);
    expect(AyahRef(2, q.from), _mushaf.page(2).words.last.ayah);
    expect(AyahRef(2, q.to), _mushaf.page(3).firstAyah);
  });
}
