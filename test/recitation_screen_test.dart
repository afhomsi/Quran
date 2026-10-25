import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/audio/audio_store.dart';
import 'package:hifz/audio/ayah_audio.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:hifz/data/recitation_history.dart';
import 'package:hifz/features/recitation/recitation_screen.dart';
import 'package:hifz/recitation/alert_sound.dart';
import 'package:hifz/recitation/speech_listener.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_listener.dart';
import 'fake_player.dart';

void main() {
  testWidgets('alerts on a mistake while reciting Al-Fatiha', (tester) async {
    final listener = FakeListener();
    final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
    final alamin = surahs.first.ayahs[1].split(' ').last;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final player = FakePlayer();
    var alerts = 0;
    final container = ProviderContainer(
      overrides: [
        surahsProvider.overrideWith((ref) async => surahs),
        speechListenerProvider.overrideWithValue(listener),
        sharedPreferencesProvider.overrideWithValue(prefs),
        ayahPlayerProvider.overrideWithValue(player),
        audioStoreProvider.overrideWithValue(AudioStore.none()),
        mistakeAlertProvider.overrideWithValue(() => alerts++),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: RecitationScreen.surah(1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('تسميع سورة الفاتحة'), findsOneWidget);

    await tester.tap(find.text('ابدأ التسميع'));
    await tester.pumpAndSettle();
    expect(listener.listening, isTrue);
    expect(find.text('إيقاف'), findsOneWidget);

    listener.say('بسم الله الرحمن الرحيم الحمد لله رب الناس');
    await tester.pump();
    expect(find.textContaining('خطأ'), findsNothing);

    listener.say('بسم الله الرحمن الرحيم الحمد لله رب الناس', isFinal: true);
    await tester.pump();
    expect(
      find.text('خطأ في الآية 2: سمعت «الناس» والصواب «$alamin»'),
      findsOneWidget,
    );
    expect(find.text('سمعت: الناس'), findsOneWidget);
    expect(alerts, 1);

    // After stopping, the ayah recited wrongly can be played and repeated.
    await tester.tap(find.text('إيقاف'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('استمع للآيات التي أخطأت فيها'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابدأ الاستماع'));
    await tester.pumpAndSettle();
    expect(player.played.single, endsWith('/001002.mp3'));
    await container.read(audioProvider.notifier).close();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('إعادة التسميع'));
    await tester.pumpAndSettle();
    expect(find.textContaining('خطأ'), findsNothing);
    expect(find.text('ابدأ التسميع'), findsOneWidget);

    // Starting over keeps the first try, with its mistake, in the history.
    final history = container.read(recitationHistoryProvider);
    expect(history, hasLength(1));
    expect(history.single.surah, 1);
    expect(history.single.mistakeAyat, [const AyahRef(1, 2)]);
  });
}
