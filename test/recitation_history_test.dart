import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/audio/ayah_audio.dart';
import 'package:hifz/data/backup.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:hifz/data/recitation_history.dart';
import 'package:hifz/features/profile/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_player.dart';

RecitationRecord _record(List<MistakeRecord> mistakes) => RecitationRecord(
  date: DateTime(2026, 10, 24, 9, 30),
  surah: 1,
  first: const AyahRef(1, 1),
  last: const AyahRef(1, 7),
  wordsDone: 29,
  wordsTotal: 29,
  complete: true,
  mistakes: mistakes,
);

void main() {
  test('keeps recitations, newest first, and counts mistakes', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    final history = container.read(recitationHistoryProvider.notifier);
    history.add(_record(const [MistakeRecord(AyahRef(1, 5), 'a')]));
    history.add(
      _record(const [
        MistakeRecord(AyahRef(1, 5), 'b'),
        MistakeRecord(AyahRef(1, 2), 'c'),
        MistakeRecord(null, 'd'),
      ]),
    );

    final reloaded = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    ).read(recitationHistoryProvider);
    expect(reloaded, hasLength(2));
    expect(reloaded.first.mistakes, hasLength(3));
    expect(reloaded.first.mistakeAyat, const [AyahRef(1, 2), AyahRef(1, 5)]);
    expect(mistakesByAyah(reloaded), [
      (const AyahRef(1, 5), 2),
      (const AyahRef(1, 2), 1),
    ]);

    expect(exportBackup(prefs), contains('recitation_history'));
  });

  testWidgets('the profile lists mistakes and plays them with repeats', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
    final player = FakePlayer();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        surahsProvider.overrideWith((ref) async => surahs),
        ayahPlayerProvider.overrideWithValue(player),
      ],
    );
    container
        .read(recitationHistoryProvider.notifier)
        .add(
          _record(const [
            MistakeRecord(AyahRef(1, 5), 'نسيت كلمة'),
            MistakeRecord(AyahRef(1, 3), 'خطأ'),
          ]),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('سجل التسميع'), findsOneWidget);
    expect(find.text('الفاتحة : الآية 5'), findsOneWidget);

    await tester.tap(find.text('استمع لها كلها مع التكرار'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add).last); // the group twice
    await tester.pump();
    await tester.tap(find.text('ابدأ الاستماع'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      player.finish();
      // The player goes on to the next ayah after its own event.
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(player.played.map((u) => u.substring(u.length - 10)), [
      '001003.mp3',
      '001005.mp3',
      '001003.mp3',
      '001005.mp3',
    ]);
    await container.read(audioProvider.notifier).close();
    await tester.pumpAndSettle();
  });
}
