/// Speech recognition on the device, with a Quran-tuned Whisper model that
/// is downloaded once and then works without internet.
library;

export 'offline_speech_stub.dart'
    if (dart.library.ffi) 'offline_speech_io.dart';
