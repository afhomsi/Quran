import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/data/khatma.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/mushaf_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final mushaf = parseMushaf(File(mushafLayoutAssetPath).readAsStringSync());

  KhatmaPlan plan(KhatmaType type, {int days = 30}) => KhatmaPlan(
    id: '1',
    title: 't',
    type: type,
    color: 0,
    days: KhatmaPlan.daysFor(type, customDays: days),
    created: DateTime(2026, 10, 24),
  );

  /// The portions cover all 604 pages in order, without gaps.
  void expectWholeQuran(List<KhatmaPortion> portions) {
    expect(portions.first.firstPage(mushaf), 1);
    expect(portions.last.lastPage(mushaf), 604);
    expect(portions.last.until, isNull);
    for (var i = 1; i < portions.length; i++) {
      expect(portions[i].from, portions[i - 1].until);
    }
  }

  test('hizb of the Salaf is 7 manzils', () {
    final p = plan(KhatmaType.salaf);
    final portions = p.portions(mushaf);
    expect(p.days, 7);
    expect(portions, hasLength(7));
    expect(portions[1].from, const AyahRef(5, 1));
    expect(portions[6].from, const AyahRef(50, 1));
    expect(portions[6].day, 7);
    expectWholeQuran(portions);
  });

  test('Ramadan khatma is one juz a day', () {
    final portions = plan(KhatmaType.ramadan).portions(mushaf);
    expect(portions, hasLength(30));
    expect(portions[29].firstPage(mushaf), 582);
    expect(portions[0].lastPage(mushaf), 21);
    expectWholeQuran(portions);
  });

  test('daily wird is two pages after each prayer', () {
    final p = plan(KhatmaType.dailyWird);
    final portions = p.portions(mushaf);
    expect(portions, hasLength(302));
    expect(portions[0].prayer, 0);
    expect(portions[0].firstPage(mushaf), 1);
    expect(portions[0].lastPage(mushaf), 2);
    expect(portions[4].prayer, 4);
    expect(portions[5].day, 2);
    expect(portions.last.day, p.days);
    expectWholeQuran(portions);
  });

  test('custom khatma splits the pages over the chosen days', () {
    final portions = plan(KhatmaType.custom, days: 20).portions(mushaf);
    expect(portions, hasLength(20));
    for (final p in portions) {
      final pages = p.lastPage(mushaf) - p.firstPage(mushaf) + 1;
      expect(pages, inInclusiveRange(30, 32));
    }
    expectWholeQuran(portions);
  });

  test('a recitation plan keeps its kind when saved', () {
    final p = KhatmaPlan.fromJson(
      KhatmaPlan(
        id: '1',
        title: 't',
        type: KhatmaType.ramadan,
        color: 0,
        days: 30,
        created: DateTime(2026, 10, 27),
        recite: true,
      ).toJson(),
    );
    expect(p.recite, isTrue);
    expect(p.copyWith(done: {0}).recite, isTrue);
    expect(
      KhatmaPlan.fromJson(plan(KhatmaType.salaf).toJson()).recite,
      isFalse,
    );
  });

  test('plans are saved, ticked off and removed', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer container() => ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );

    final first = container();
    final notifier = first.read(khatmaPlansProvider.notifier);
    final p = notifier.add(
      type: KhatmaType.salaf,
      title: 'ختمتي',
      color: 2,
      now: DateTime(2026, 10, 24),
    );
    notifier.setRead(p.id, 0);
    notifier.setRead(p.id, 1);
    notifier.setRead(p.id, 0, read: false);

    final again = container().read(khatmaPlansProvider).single;
    expect(again.title, 'ختمتي');
    expect(again.color, 2);
    expect(again.done, {1});
    expect(again.nextPortion(mushaf), 0);
    expect(again.dayOn(DateTime(2026, 10, 26, 23)), 3);

    container().read(khatmaPlansProvider.notifier).remove(p.id);
    expect(container().read(khatmaPlansProvider), isEmpty);
  });
}
