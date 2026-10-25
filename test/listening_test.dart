import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/audio/ayah_audio.dart';
import 'package:hifz/audio/heard_ayat.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/mushaf_repository.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_player.dart';

/// A player that can fail, as when the phone is offline.
class _FlakyPlayer extends FakePlayer {
  bool offline = false;
  var paused = 0;
  var resumed = 0;
  var stopped = 0;
  final speeds = <double>[];

  @override
  Future<void> play(
    String url, {
    double speed = 1,
    Duration? start,
    Duration? end,
  }) async {
    if (offline) throw const SocketException('offline');
    speeds.add(speed);
    await super.play(url, speed: speed, start: start, end: end);
  }

  @override
  Future<void> pause() async => paused++;

  @override
  Future<void> resume() async => resumed++;

  @override
  Future<void> stop() async => stopped++;
}

void main() {
  final mushaf = parseMushaf(File(mushafLayoutAssetPath).readAsStringSync());
  final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());

  late _FlakyPlayer player;
  late SharedPreferences prefs;

  Future<ProviderContainer> open([Map<String, Object> saved = const {}]) async {
    SharedPreferences.setMockInitialValues(saved);
    prefs = await SharedPreferences.getInstance();
    player = _FlakyPlayer();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ayahPlayerProvider.overrideWithValue(player),
        mushafProvider.overrideWith((ref) async => mushaf),
        surahsProvider.overrideWith((ref) async => surahs),
      ],
    );
    addTearDown(container.dispose);
    await container.read(mushafProvider.future);
    await container.read(surahsProvider.future);
    return container;
  }

  Future<void> finish() async {
    player.finish();
    await pumpEventQueue();
  }

  String last(List<String> urls) => urls.last.substring(urls.last.length - 10);

  test('pauses and resumes the same ayah', () async {
    final c = await open();
    final audio = c.read(audioProvider.notifier);
    await audio.playFrom(const AyahRef(36, 1));
    await audio.togglePlay();
    expect(c.read(audioProvider).playing, isFalse);
    expect(player.paused, 1);
    await audio.togglePlay();
    expect(c.read(audioProvider).playing, isTrue);
    expect(player.resumed, 1);
    expect(c.read(audioProvider).current, const AyahRef(36, 1));
    // Nothing was loaded again.
    expect(player.played, hasLength(1));
  });

  test(
    'a recording that cannot be played says so and can be tried again',
    () async {
      final c = await open();
      final audio = c.read(audioProvider.notifier);
      player.offline = true;
      await audio.playFrom(const AyahRef(2, 255));
      var state = c.read(audioProvider);
      expect(state.failed, isTrue);
      expect(state.playing, isFalse);
      expect(state.loading, isFalse);
      expect(state.current, const AyahRef(2, 255));

      player.offline = false;
      await audio.togglePlay();
      state = c.read(audioProvider);
      expect(state.failed, isFalse);
      expect(state.playing, isTrue);
      expect(last(player.played), '002255.mp3');
    },
  );

  test('a finished ayah does not move on while paused', () async {
    final c = await open();
    final audio = c.read(audioProvider.notifier);
    await audio.playFrom(const AyahRef(1, 3));
    await audio.togglePlay();
    await finish();
    expect(c.read(audioProvider).current, const AyahRef(1, 3));
    expect(player.played, hasLength(1));
  });

  test('loops one ayah until it is stopped', () async {
    final c = await open();
    final audio = c.read(audioProvider.notifier);
    audio.cycleLoop();
    expect(c.read(audioProvider).loop, AudioLoop.ayah);
    await audio.playFrom(const AyahRef(112, 2));
    for (var i = 0; i < 5; i++) {
      await finish();
    }
    expect(player.played, hasLength(6));
    expect(player.played.toSet(), {reciters[0].url(const AyahRef(112, 2))});
    await audio.close();
    await finish();
    expect(player.played, hasLength(6));
    expect(player.stopped, 1);
  });

  test('loops a surah back to its start, with the basmala', () async {
    final c = await open();
    final audio = c.read(audioProvider.notifier);
    audio
      ..cycleLoop()
      ..cycleLoop()
      ..cycleLoop();
    expect(c.read(audioProvider).loop, AudioLoop.surah);
    await audio.playFrom(const AyahRef(112, 4));
    await finish();
    expect(c.read(audioProvider).current, const AyahRef(112, 1));
    await finish();
    expect(player.played.map((u) => u.substring(u.length - 10)), [
      '112004.mp3',
      '001001.mp3', // the basmala
      '112001.mp3',
    ]);
  });

  test('the loop goes back to none after surah', () async {
    final c = await open();
    final audio = c.read(audioProvider.notifier);
    for (var i = 0; i < AudioLoop.values.length; i++) {
      audio.cycleLoop();
    }
    expect(c.read(audioProvider).loop, AudioLoop.none);
  });

  test('stops at the end of the Quran and plays it again on play', () async {
    final c = await open();
    final audio = c.read(audioProvider.notifier);
    await audio.playFrom(const AyahRef(114, 6));
    await finish();
    expect(c.read(audioProvider).playing, isFalse);
    await audio.next();
    expect(c.read(audioProvider).current, const AyahRef(114, 6));
    await audio.togglePlay();
    expect(c.read(audioProvider).playing, isTrue);
    expect(player.played, hasLength(2));
  });

  test('previous stops at the first ayah of the Quran', () async {
    final c = await open();
    final audio = c.read(audioProvider.notifier);
    await audio.playFrom(const AyahRef(1, 1));
    await audio.previous();
    expect(c.read(audioProvider).current, const AyahRef(1, 1));
    expect(player.played, hasLength(1));
  });

  test(
    'changing the reciter while playing restarts the ayah with the new reciter',
    () async {
      final c = await open();
      final audio = c.read(audioProvider.notifier);
      await audio.playFrom(const AyahRef(18, 10));
      audio.setReciter(1);
      await pumpEventQueue();
      expect(player.played.last, reciters[1].url(const AyahRef(18, 10)));
      expect(player.played.last, contains('Husary'));
    },
  );

  test('changing the reciter while paused waits for play', () async {
    final c = await open();
    final audio = c.read(audioProvider.notifier);
    await audio.playFrom(const AyahRef(18, 10));
    await audio.togglePlay();
    audio.setReciter(2);
    await pumpEventQueue();
    expect(player.played, hasLength(1));
  });

  test('plays at the chosen speed, also the next ayah', () async {
    final c = await open();
    final audio = c.read(audioProvider.notifier);
    await audio.setSpeed(0.75);
    await audio.playFrom(const AyahRef(1, 2));
    await finish();
    expect(player.speeds, [0.75, 0.75]);
  });

  test('the reciter, repeats, speed and loop are kept for next time', () async {
    var c = await open();
    final audio = c.read(audioProvider.notifier);
    audio
      ..setReciter(3)
      ..setRepeats(4)
      ..cycleLoop();
    await audio.setSpeed(1.25);

    final saved = {for (final k in prefs.getKeys()) k: prefs.get(k)!};
    c = await open(saved);
    final state = c.read(audioProvider);
    expect(state.reciter, 3);
    expect(state.repeats, 4);
    expect(state.speed, 1.25);
    expect(state.loop, AudioLoop.ayah);
    // What is playing is not kept: the bar starts hidden.
    expect(state.visible, isFalse);
    expect(state.current, isNull);
  });

  test('damaged player choices fall back to the defaults', () async {
    final c = await open({'audio_settings': '{"reciter": "x"'});
    final state = c.read(audioProvider);
    expect(state.reciter, 0);
    expect(state.repeats, 1);
    expect(state.speed, 1);
    expect(state.loop, AudioLoop.none);
  });

  test('showing the bar keeps what is playing', () async {
    final c = await open();
    final audio = c.read(audioProvider.notifier);
    audio.show(const AyahRef(5, 3));
    expect(c.read(audioProvider).current, const AyahRef(5, 3));
    expect(c.read(audioProvider).visible, isTrue);
    expect(player.played, isEmpty);
    await audio.playFrom(const AyahRef(5, 4));
    audio.show(const AyahRef(7, 1));
    expect(c.read(audioProvider).current, const AyahRef(5, 4));
  });

  test('the heard ayat follow a range played with repeats', () async {
    final c = await open();
    c.listen(heardAyatProvider, (_, _) {});
    final audio = c.read(audioProvider.notifier);
    await audio.playRange(
      const AyahRef(103, 1),
      const AyahRef(103, 3),
      ayahRepeats: 2,
      listRepeats: 1,
    );
    expect(c.read(heardAyatProvider), {const AyahRef(103, 1)});
    for (var i = 0; i < 3; i++) {
      await finish();
    }
    expect(c.read(heardAyatProvider), {
      const AyahRef(103, 1),
      const AyahRef(103, 2),
    });
  });

  test('every reciter has a recording of every ayah address', () {
    for (final r in reciters) {
      if (r.timed) {
        expect(r.folder, matches(RegExp(r'^[a-z0-9-]+/r[0-9]+$')));
        expect(
          r.url(const AyahRef(2, 7)),
          'https://cdn.mp3quran.net/audio/${r.folder}/002.mp3',
        );
        continue;
      }
      expect(r.folder, matches(RegExp(r'^[A-Za-z0-9_.-]+$')));
      expect(
        r.url(const AyahRef(2, 7)),
        'https://everyayah.com/data/${r.folder}/002007.mp3',
      );
    }
    // No reciter is listed twice.
    expect(reciters.map((r) => r.folder).toSet(), hasLength(reciters.length));
  });
}
