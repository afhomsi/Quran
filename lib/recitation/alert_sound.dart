/// A short sound or vibration that tells the reciter a mistake was made.
library;

export 'alert_sound_device.dart'
    if (dart.library.js_interop) 'alert_sound_web.dart';
