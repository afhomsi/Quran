import 'dart:async';

import 'package:hifz/audio/ayah_audio.dart';

/// Records what would be played; [finish] ends the current recording.
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
