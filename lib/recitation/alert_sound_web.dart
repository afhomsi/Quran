import 'package:web/web.dart' as web;

web.AudioContext? _context;

/// Browsers have no system alert sound, so play a short tone.
void playMistakeAlert() {
  try {
    final ctx = _context ??= web.AudioContext();
    final tone = ctx.createOscillator();
    final volume = ctx.createGain();
    tone.frequency.value = 660;
    volume.gain.value = 0.2;
    tone.connect(volume);
    volume.connect(ctx.destination);
    tone.start();
    tone.stop(ctx.currentTime + 0.3);
  } catch (_) {
    // No audio output; the mistake is still shown on screen.
  }
}
