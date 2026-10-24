import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/data/khatma.dart';
import 'package:hifz/data/marks.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:hifz/data/recitation_history.dart';
import 'package:hifz/data/self_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container() async {
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('keeps one reading, hifz and review marker each', () async {
    final first = await _container();
    final markers = first.read(markersProvider.notifier);
    markers.set(MarkerKind.reading, const AyahRef(2, 177));
    markers.set(MarkerKind.hifz, const AyahRef(2, 164));
    markers.set(MarkerKind.reading, const AyahRef(2, 200));
    markers.set(MarkerKind.review, const AyahRef(2, 62));
    markers.clear(MarkerKind.review);

    final second = await _container();
    expect(second.read(markersProvider), {
      MarkerKind.reading: const AyahRef(2, 200),
      MarkerKind.hifz: const AyahRef(2, 164),
    });
  });

  test('damaged saved data is skipped instead of stopping the app', () async {
    SharedPreferences.setMockInitialValues({
      'markers': '["not", "a", "map"]',
      'highlights': '{"2:255": "yellow"}',
      'notes': 'not json',
      'khatma_plans': '{"id": 1}',
      'recitation_history': '[{"date": 5}]',
    });
    final c = await _container();
    expect(c.read(markersProvider), isEmpty);
    expect(c.read(highlightsProvider), isEmpty);
    expect(c.read(notesProvider), isEmpty);
    expect(c.read(khatmaPlansProvider), isEmpty);
    expect(c.read(recitationHistoryProvider), isEmpty);
  });

  test('highlights and notes are kept, newest last', () async {
    final first = await _container();
    final highlights = first.read(highlightsProvider.notifier);
    highlights.set(const AyahRef(2, 13), 0);
    highlights.set(const AyahRef(2, 40), 2);
    highlights.set(const AyahRef(2, 13), 1);
    first.read(notesProvider.notifier)
      ..set(const AyahRef(1, 1), '  فائدة  ')
      ..set(const AyahRef(1, 2), 'x')
      ..set(const AyahRef(1, 2), ' ');

    final second = await _container();
    expect(second.read(highlightsProvider).entries.map((e) => e.value), [2, 1]);
    expect(second.read(notesProvider), {const AyahRef(1, 1): 'فائدة'});
  });

  test('self-test picks ayat inside the scope', () {
    final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
    final kahf = ayahsBetween(
      surahs,
      const AyahRef(18, 1),
      const AyahRef(19, 1),
    );
    expect(kahf, hasLength(110));
    final juz30 = ayahsBetween(surahs, const AyahRef(78, 1), null);
    expect(juz30.last, const AyahRef(114, 6));

    final picked = pickQuestions(kahf, SelfTestMode.nextAyah, 200, Random(1));
    expect(picked, hasLength(109));
    expect(picked, isNot(contains(const AyahRef(18, 110))));
    expect(picked.toSet(), hasLength(109));

    expect(promptWordCount('قل هو الله أحد'), 2);
    expect(promptWordCount('طه'), 1);
  });
}
