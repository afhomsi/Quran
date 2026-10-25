import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/audio/audio_downloads.dart';
import 'package:hifz/audio/audio_store.dart';
import 'package:hifz/audio/ayah_audio.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/mushaf_repository.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:hifz/features/audio/downloads_screen.dart';
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
  final alafasy = reciters[0];

  late Directory root;
  late AudioStore store;
  late FakePlayer player;
  late ProviderContainer container;
  late List<Uri> asked;
  var online = true;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    root = await Directory.systemTemp.createTemp('audio');
    store = AudioStore(root: root);
    player = FakePlayer();
    asked = [];
    online = true;
    final client = MockClient((request) async {
      asked.add(request.url);
      if (!online) throw const SocketException('offline');
      if (request.url.host == 'mp3quran.net') {
        final surah = int.parse(request.url.queryParameters['surah']!);
        return http.Response(_timings(surahs[surah - 1].ayahCount), 200);
      }
      return http.Response.bytes(utf8.encode('mp3 ${request.url.path}'), 200);
    });
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ayahPlayerProvider.overrideWithValue(player),
        audioStoreProvider.overrideWithValue(store),
        audioDownloadClientProvider.overrideWithValue(() => client),
        ayahTimingsProvider.overrideWithValue(
          AyahTimings(client: client, store: store),
        ),
        mushafProvider.overrideWith((ref) async => mushaf),
        surahsProvider.overrideWith((ref) async => surahs),
      ],
    );
    await container.read(mushafProvider.future);
    await container.read(surahsProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await root.delete(recursive: true);
  });

  AudioController audio() => container.read(audioProvider.notifier);
  AudioDownloads downloads() => container.read(audioDownloadsProvider.notifier);

  /// Waits until nothing is waiting to download.
  Future<void> downloaded() async {
    for (var i = 0; i < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      if (container.read(audioDownloadsProvider).queue.isEmpty) return;
    }
    fail('Downloads did not finish');
  }

  test('a downloaded surah keeps each ayah and the basmala', () async {
    downloads().download(0, [112]);
    await downloaded();
    expect(await store.files(alafasy), {
      '001001.mp3',
      '112001.mp3',
      '112002.mp3',
      '112003.mp3',
      '112004.mp3',
    });
    expect(
      await File('${root.path}/Alafasy_128kbps/112002.mp3').readAsString(),
      'mp3 /data/Alafasy_128kbps/112002.mp3',
    );
    final kept = await container.read(keptAudioProvider(0).future);
    expect(surahProgress(alafasy, surahs[111], kept), 1);
    expect(surahProgress(alafasy, surahs[110], kept), 0);
  });

  test('a downloaded surah plays from the phone, without internet', () async {
    downloads().download(0, [112]);
    await downloaded();
    online = false;
    await audio().playFrom(const AyahRef(112, 1));
    player.finish();
    await pumpEventQueue();
    expect(container.read(audioProvider).failed, isFalse);
    expect(player.played, [
      Uri.file('${root.path}/Alafasy_128kbps/001001.mp3').toString(),
      Uri.file('${root.path}/Alafasy_128kbps/112001.mp3').toString(),
    ]);
    // A surah that was not downloaded still plays over the internet.
    await audio().playFrom(const AyahRef(113, 2));
    expect(
      player.played.last,
      endsWith(
        'everyayah.com/data/'
        'Alafasy_128kbps/113002.mp3',
      ),
    );
  });

  test('a whole-surah reciter plays a downloaded surah, cut into ayat, '
      'without internet', () async {
    downloads().download(saber, [1, 112]);
    await downloaded();
    expect(await store.files(reciters[saber]), {
      '001.mp3',
      '001.json',
      '112.mp3',
      '112.json',
    });
    asked.clear();
    online = false;
    audio().setReciter(saber);
    await audio().playFrom(const AyahRef(112, 2));
    expect(container.read(audioProvider).failed, isFalse);
    expect(
      player.played.single,
      Uri.file('${root.path}/saber-abdulhakam_r1/112.mp3').toString(),
    );
    expect(player.clips, ['2000-3000']);
    expect(asked, isEmpty);
  });

  test('offline, downloading stops and says so', () async {
    online = false;
    downloads().download(0, [112, 113]);
    await downloaded();
    final state = container.read(audioDownloadsProvider);
    expect(state.failed, isTrue);
    expect(state.queue, isEmpty);
    expect(await store.files(alafasy), isEmpty);
  });

  test('deleting a surah keeps the basmala other surahs need', () async {
    downloads().download(0, [112, 113]);
    await downloaded();
    await downloads().delete(0, 112);
    final kept = await store.files(alafasy);
    expect(kept, contains('001001.mp3'));
    expect(kept.where((n) => n.startsWith('112')), isEmpty);
    expect(surahProgress(alafasy, surahs[112], kept), 1);
    await downloads().delete(0);
    expect(await store.files(alafasy), isEmpty);
  });

  testWidgets('the downloads screen downloads a surah', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DownloadsScreen(reciter: 0)),
      ),
    );
    await tester.runAsync(() => pumpEventQueue());
    await tester.pump();
    expect(find.text('مشاري العفاسي'), findsOneWidget);
    expect(find.byKey(const ValueKey('download-all')), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('download-surah-1')));
      await downloaded();
      await container.read(keptAudioProvider(0).future);
    });
    await tester.pump();
    expect(find.byKey(const ValueKey('delete-surah-1')), findsOneWidget);
    expect(find.textContaining('محمّل 1 من 114 سورة'), findsOneWidget);
  });
}
