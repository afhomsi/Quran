import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/audio/ayah_audio.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/mushaf_repository.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePlayer implements AyahPlayer {
  final played = <String>[];
  final _completed = StreamController<void>.broadcast(sync: true);

  void finish() => _completed.add(null);

  @override
  Future<void> play(String url, {double speed = 1}) async => played.add(url);

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Stream<void> get completed => _completed.stream;

  @override
  void dispose() {}
}

void main() {
  final mushaf = parseMushaf(File(mushafLayoutAssetPath).readAsStringSync());
  final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());

  late FakePlayer player;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    player = FakePlayer();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ayahPlayerProvider.overrideWithValue(player),
        mushafProvider.overrideWith((ref) async => mushaf),
        surahsProvider.overrideWith((ref) async => surahs),
      ],
    );
    await container.read(mushafProvider.future);
    await container.read(surahsProvider.future);
  });

  AudioController audio() => container.read(audioProvider.notifier);
  AyahRef? current() => container.read(audioProvider).current;

  test('plays on to the next ayah and the next surah', () async {
    await audio().playFrom(const AyahRef(1, 7));
    expect(
      player.played.single,
      'https://everyayah.com/data/Alafasy_128kbps/001007.mp3',
    );
    player.finish();
    await pumpEventQueue();
    expect(current(), const AyahRef(2, 1));
    expect(container.read(audioProvider).playing, isTrue);
  });

  test('repeats each ayah and loops the page', () async {
    audio().setRepeats(2);
    audio().cycleLoop(); // ayah
    audio().cycleLoop(); // page
    expect(container.read(audioProvider).loop, AudioLoop.page);
    // Page 1 is al-Fatiha, ayat 1 to 7.
    await audio().playFrom(const AyahRef(1, 7));
    player.finish();
    await pumpEventQueue();
    expect(current(), const AyahRef(1, 7));
    player.finish();
    await pumpEventQueue();
    expect(current(), const AyahRef(1, 1));
    expect(player.played, hasLength(3));
  });

  test('next, previous and stop at the end', () async {
    await audio().playFrom(const AyahRef(2, 1));
    await audio().previous();
    expect(current(), const AyahRef(1, 7));
    await audio().next();
    expect(current(), const AyahRef(2, 1));

    await audio().playFrom(const AyahRef(114, 6));
    player.finish();
    await pumpEventQueue();
    expect(current(), const AyahRef(114, 6));
    expect(container.read(audioProvider).playing, isFalse);

    await audio().close();
    expect(container.read(audioProvider).visible, isFalse);
  });
}
