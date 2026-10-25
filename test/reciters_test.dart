import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/audio/audio_store.dart';
import 'package:hifz/audio/ayah_audio.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/mushaf_repository.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:hifz/features/audio/reciters_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_player.dart';

/// mp3quran.net's answer for a surah: ayah N from N seconds to N + 1.
String _timings(int ayat) => jsonEncode([
  for (var a = 1; a <= ayat; a++)
    {'ayah': a, 'start_time': a * 1000, 'end_time': (a + 1) * 1000},
]);

void main() {
  final mushaf = parseMushaf(File(mushafLayoutAssetPath).readAsStringSync());
  final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
  final saber = reciters.indexWhere((r) => r.timingRead == 39);

  late FakePlayer player;
  late ProviderContainer container;
  late List<Uri> asked;
  var online = true;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    player = FakePlayer();
    asked = [];
    online = true;
    final client = MockClient((request) async {
      asked.add(request.url);
      if (!online) throw const SocketException('offline');
      final surah = int.parse(request.url.queryParameters['surah']!);
      return http.Response(_timings(surahs[surah - 1].ayahCount), 200);
    });
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ayahPlayerProvider.overrideWithValue(player),
        audioStoreProvider.overrideWithValue(AudioStore.none()),
        ayahTimingsProvider.overrideWithValue(AyahTimings(client: client)),
        mushafProvider.overrideWith((ref) async => mushaf),
        surahsProvider.overrideWith((ref) async => surahs),
      ],
    );
    await container.read(mushafProvider.future);
    await container.read(surahsProvider.future);
  });

  AudioController audio() => container.read(audioProvider.notifier);

  Future<void> finish() async {
    player.finish();
    await pumpEventQueue();
  }

  test('the reciters in the reference app are all listed once', () {
    final names = reciters.map((r) => r.name).toSet();
    expect(names, hasLength(reciters.length));
    for (final name in [
      'ماهر المعيقلي',
      'محمد أيوب',
      'ياسر الدوسري',
      'علي الحذيفي',
      'صابر عبد الحكم',
      'محمود علي البنا',
      'محمود الحصري - المجوّد',
      'سعد الغامدي',
      'علي جابر',
      'مصطفى إسماعيل',
      'بندر بليلة',
      'فارس عباد',
      'خالد القحطاني',
      'خالد المهنا',
    ]) {
      expect(names, contains(name));
    }
    // The first reciters keep their places, as the choice is saved by place.
    expect(reciters.first.folder, 'Alafasy_128kbps');
    expect(reciters[13].folder, 'Fares_Abbad_64kbps');
  });

  test('reads the ayah times and leaves out what is not an ayah', () {
    final spans = parseAyahTimings(
      jsonEncode([
        {'ayah': 0, 'start_time': 0, 'end_time': 4000},
        {'ayah': 1, 'start_time': 4460, 'end_time': 10380},
        {'ayah': 2, 'start_time': 10380.4, 'end_time': 17440},
        {'ayah': 3, 'start_time': 900, 'end_time': 900},
        {'ayah': '4', 'start_time': 1, 'end_time': 2},
        'nothing',
      ]),
    );
    expect(spans.keys, [1, 2]);
    expect(spans[1]!.start, const Duration(milliseconds: 4460));
    expect(spans[2]!.start, const Duration(milliseconds: 10380));
    expect(spans[2]!.end, const Duration(milliseconds: 17440));
  });

  test('a whole-surah reciter plays a range of ayat, cut from the surah, '
      'each ayah and the range repeated', () async {
    audio().setReciter(saber);
    await audio().playRange(
      const AyahRef(112, 2),
      const AyahRef(112, 3),
      ayahRepeats: 2,
      listRepeats: 2,
    );
    for (var i = 0; i < 8; i++) {
      await finish();
    }
    expect(player.played.toSet(), {
      'https://cdn.mp3quran.net/audio/saber-abdulhakam/r1/112.mp3',
    });
    expect(player.clips, [
      for (var pass = 0; pass < 2; pass++) ...[
        '2000-3000',
        '2000-3000',
        '3000-4000',
        '3000-4000',
      ],
    ]);
    expect(container.read(audioProvider).playing, isFalse);
    // Each surah's times are fetched once.
    expect(asked, hasLength(1));
    expect(asked.single.host, 'mp3quran.net');
    expect(asked.single.queryParameters, {'surah': '112', 'read': '39'});
  });

  test('a whole-surah reciter starts a surah with the basmala of '
      'al-Fatiha', () async {
    audio().setReciter(saber);
    await audio().playFrom(const AyahRef(114, 1));
    await finish();
    expect(player.played, [
      'https://cdn.mp3quran.net/audio/saber-abdulhakam/r1/001.mp3',
      'https://cdn.mp3quran.net/audio/saber-abdulhakam/r1/114.mp3',
    ]);
    expect(player.clips, ['1000-2000', '1000-2000']);
  });

  test('without the ayah times it says so, and tries again', () async {
    audio().setReciter(saber);
    online = false;
    await audio().playFrom(const AyahRef(103, 2));
    expect(container.read(audioProvider).failed, isTrue);
    expect(player.played, isEmpty);
    online = true;
    await audio().togglePlay();
    expect(container.read(audioProvider).failed, isFalse);
    expect(player.clips, ['2000-3000']);
  });

  test('an ayah-by-ayah reciter plays whole files', () async {
    await audio().playFrom(const AyahRef(103, 2));
    expect(player.played.single, endsWith('/103002.mp3'));
    expect(player.clips, ['']);
    expect(asked, isEmpty);
  });

  testWidgets('the reciters list chooses a reciter and plays them', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RecitersScreen()),
      ),
    );
    expect(find.text('مشاري العفاسي'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('بندر بليلة'), 300);
    await tester.ensureVisible(find.text('بندر بليلة'));
    await tester.pump();
    final bandar = reciters.indexWhere((r) => r.timingRead == 217);
    await tester.tap(find.text('بندر بليلة'));
    await tester.pump();
    expect(container.read(audioProvider).reciter, bandar);
    expect(
      find.descendant(
        of: find.byKey(ValueKey('reciter-$bandar')),
        matching: find.text('سورة كاملة مقسّمة على الآيات'),
      ),
      findsOneWidget,
    );
    await tester.runAsync(() async {
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey('reciter-$bandar')),
          matching: find.byIcon(Icons.play_circle_fill_rounded),
        ),
      );
      await pumpEventQueue();
    });
    await tester.pump();
    expect(player.played, [
      'https://cdn.mp3quran.net/audio/bandar-baleela/r1/001.mp3',
    ]);
    expect(find.byIcon(Icons.pause_circle_filled_rounded), findsOneWidget);
  });
}
