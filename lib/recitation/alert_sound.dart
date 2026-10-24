/// A short sound and vibration that tells the reciter a mistake was made.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

const mistakeSoundAsset = 'assets/sounds/mistake.mp3';

AudioPlayer? _player;

/// Plays two falling tones, chosen to stand out from a recitation, and
/// vibrates on phones. Android has no system alert sound to use instead.
Future<void> playMistakeAlert() async {
  HapticFeedback.vibrate();
  try {
    final player = _player ??= AudioPlayer();
    await player.stop();
    await player.setAsset(mistakeSoundAsset);
    // play() only returns once the sound ends, so don't wait for it.
    unawaited(player.play());
  } catch (_) {
    // No audio output; the mistake is still shown on screen.
  }
}

/// What to do when a mistake is heard. Tests swap it for a counter.
final mistakeAlertProvider = Provider<void Function()>(
  (ref) => playMistakeAlert,
);
