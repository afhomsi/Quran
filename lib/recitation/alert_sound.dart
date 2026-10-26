/// A short vibration that tells the reciter a mistake was made.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Vibrates on phones. There is no sound: it held the reciter up, and the
/// mistake is shown on screen anyway.
Future<void> playMistakeAlert() async {
  await HapticFeedback.vibrate();
}

/// What to do when a mistake is heard. Tests swap it for a counter.
final mistakeAlertProvider = Provider<void Function()>(
  (ref) => playMistakeAlert,
);
