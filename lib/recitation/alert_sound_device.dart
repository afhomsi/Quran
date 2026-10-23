import 'package:flutter/services.dart';

void playMistakeAlert() {
  HapticFeedback.vibrate();
  SystemSound.play(SystemSoundType.alert);
}
