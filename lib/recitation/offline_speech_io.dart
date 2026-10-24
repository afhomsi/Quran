import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'speech_listener.dart';

/// Where the model files are published, by .github/workflows/speech-model.yml.
const _release =
    'https://github.com/afhomsi/Quran/releases/download/speech-model-v1';

/// Tarteel's Whisper base, fine-tuned on Quran recitation.
const _model = 'quran-base';

/// The model's files and their approximate sizes, for showing progress.
const _files = {
  '$_model-encoder.int8.onnx': 29104812,
  '$_model-decoder.int8.onnx': 130659024,
  '$_model-tokens.txt': 816730,
  'silero_vad.onnx': 643854,
};

/// Written last, so a download cut half way is not taken as installed.
const _doneMarker = '.complete';

const _sampleRate = 16000;

/// The download size, for telling the user before they start.
int get offlineModelSizeMb =>
    (_files.values.fold(0, (a, b) => a + b) / 1000000).round();

bool get offlineSpeechSupported => Platform.isAndroid || Platform.isIOS;

Future<Directory> _modelDir() async {
  final base = await getApplicationSupportDirectory();
  return Directory('${base.path}/speech-model-v1/$_model');
}

Future<bool> isOfflineModelInstalled() async {
  if (!offlineSpeechSupported) return false;
  final dir = await _modelDir();
  return File('${dir.path}/$_doneMarker').exists();
}

/// Downloads the model, reporting bytes received so far out of the total.
Future<void> downloadOfflineModel(
  void Function(int received, int total) onProgress,
) async {
  final dir = await _modelDir();
  await dir.create(recursive: true);
  final sizes = Map.of(_files);
  var done = 0;
  int total() => sizes.values.fold(0, (a, b) => a + b);
  final client = HttpClient();
  try {
    for (final name in _files.keys) {
      final file = File('${dir.path}/$name');
      if (await file.exists()) {
        sizes[name] = await file.length();
        done += sizes[name]!;
        onProgress(done, total());
        continue;
      }
      final request = await client.getUrl(Uri.parse('$_release/$name'));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode} for $name');
      }
      if (response.contentLength > 0) sizes[name] = response.contentLength;
      final part = File('${file.path}.part');
      final sink = part.openWrite();
      var got = 0;
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          got += chunk.length;
          onProgress(done + got, total());
        }
      } finally {
        await sink.close();
      }
      if (response.contentLength > 0 && got != response.contentLength) {
        await part.delete();
        throw const HttpException('انقطع التحميل قبل أن يكتمل');
      }
      await part.rename(file.path);
      done += got;
    }
    await File('${dir.path}/$_doneMarker').writeAsString('ok');
  } finally {
    client.close();
  }
}

Future<void> deleteOfflineModel() async {
  final dir = await _modelDir();
  if (await dir.exists()) await dir.delete(recursive: true);
}

DisposableSpeechListener createOfflineSpeechListener() =>
    OfflineSpeechListener();

/// Recognizes recitation on the device.
///
/// The microphone runs for as long as the reciter recites. A voice activity
/// detector cuts the audio at each pause (usually the end of an ayah), and
/// each piece is transcribed by Whisper in a background isolate and
/// reported as a final result. While a long piece is still being recited,
/// what has been said so far is transcribed every few seconds as a partial
/// result, so mistakes show up without waiting for the pause.
class OfflineSpeechListener implements DisposableSpeechListener {
  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _mic;
  Future<void>? _starting;
  ReceivePort? _inbox;
  SendPort? _toWorker;
  Timer? _idle;

  void Function(String text, bool isFinal)? _onResult;
  void Function(String message) _onError = (_) {};
  void Function() _onDone = () {};

  /// Results that arrived between two listening sessions.
  final _pending = <(String, bool)>[];

  @override
  Future<bool> initialize({
    required void Function(String message) onError,
    required void Function() onDone,
  }) async {
    _onError = onError;
    _onDone = onDone;
    return _recorder.hasPermission();
  }

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    _idle?.cancel();
    _onResult = onResult;
    while (_pending.isNotEmpty && _onResult != null) {
      final (text, isFinal) = _pending.removeAt(0);
      _deliver(text, isFinal);
    }
    await (_starting ??= _startWorker());
    if (_mic != null) return;
    final audio = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      ),
    );
    _mic = audio.listen(
      (bytes) => _toWorker?.send(_toSamples(bytes)),
      onError: (Object e) => _onError('error_audio $e'),
      onDone: () {
        _mic = null;
        _onDone();
      },
    );
  }

  @override
  Future<void> stop() async {
    _onResult = null;
    _pending.clear();
    final mic = _mic;
    _mic = null;
    await mic?.cancel();
    if (await _recorder.isRecording()) await _recorder.stop();
    _toWorker?.send('reset');
    // The model holds a lot of memory; let it go if not used again soon.
    _idle?.cancel();
    _idle = Timer(const Duration(minutes: 2), _stopWorker);
  }

  @override
  Future<void> dispose() async {
    await stop();
    _idle?.cancel();
    _stopWorker();
    await _recorder.dispose();
  }

  /// Passes a result to the current session. A final result ends the
  /// session, so anything after it waits for the next one.
  void _deliver(String text, bool isFinal) {
    final onResult = _onResult;
    if (onResult == null) {
      if (_pending.isNotEmpty && !_pending.last.$2) _pending.removeLast();
      _pending.add((text, isFinal));
      return;
    }
    if (isFinal) _onResult = null;
    onResult(text, isFinal);
  }

  Future<void> _startWorker() async {
    final dir = await _modelDir();
    final inbox = ReceivePort();
    final ready = Completer<void>();
    inbox.listen((message) {
      switch (message) {
        case SendPort port:
          _toWorker = port;
        case 'ready':
          ready.complete();
        case ['error', String error]:
          if (!ready.isCompleted) {
            ready.completeError(error);
          } else {
            _onError(error);
          }
        case [String text, bool isFinal]:
          _deliver(text, isFinal);
      }
    });
    _inbox = inbox;
    await Isolate.spawn(_worker, (inbox.sendPort, dir.path));
    try {
      await ready.future;
    } catch (_) {
      _stopWorker();
      rethrow;
    }
  }

  void _stopWorker() {
    _toWorker?.send('close');
    _toWorker = null;
    _inbox?.close();
    _inbox = null;
    _starting = null;
  }
}

Float32List _toSamples(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final samples = Float32List(bytes.length ~/ 2);
  for (var i = 0; i < samples.length; i++) {
    samples[i] = data.getInt16(i * 2, Endian.little) / 32768;
  }
  return samples;
}

/// Seconds of new speech between two partial transcriptions.
const _partialEvery = 2.5;

/// Audio kept from just before the detector notices speech, so the first
/// letters are not cut off.
const _lead = 0.5;

/// Runs the detector and Whisper away from the UI thread.
void _worker((SendPort, String) args) {
  final (out, dir) = args;
  final inbox = ReceivePort();
  out.send(inbox.sendPort);

  final sherpa.VoiceActivityDetector vad;
  final sherpa.OfflineRecognizer recognizer;
  try {
    sherpa.initBindings();
    vad = sherpa.VoiceActivityDetector(
      config: sherpa.VadModelConfig(
        sileroVad: sherpa.SileroVadModelConfig(
          model: '$dir/silero_vad.onnx',
          minSilenceDuration: 0.5,
          maxSpeechDuration: 15,
        ),
        sampleRate: _sampleRate,
        debug: false,
      ),
      bufferSizeInSeconds: 30,
    );
    recognizer = sherpa.OfflineRecognizer(
      sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          whisper: sherpa.OfflineWhisperModelConfig(
            encoder: '$dir/$_model-encoder.int8.onnx',
            decoder: '$dir/$_model-decoder.int8.onnx',
            language: 'ar',
            task: 'transcribe',
          ),
          tokens: '$dir/$_model-tokens.txt',
          modelType: 'whisper',
          numThreads: 2,
          debug: false,
        ),
      ),
    );
  } catch (e) {
    out.send(['error', 'تعذر تشغيل نموذج التلاوة: $e']);
    inbox.close();
    return;
  }
  out.send('ready');

  final window = vad.config.sileroVad.windowSize;
  var leftover = Float32List(0);
  // The speech being recited, from shortly before the detector noticed it.
  final speech = <Float32List>[];
  var speechLength = 0;
  var lastPartial = 0;
  final recent = <Float32List>[];
  final leadWindows = (_lead * _sampleRate / window).ceil();

  String transcribe(Float32List samples) {
    final stream = recognizer.createStream();
    try {
      stream.acceptWaveform(samples: samples, sampleRate: _sampleRate);
      recognizer.decode(stream);
      return recognizer.getResult(stream).text.trim();
    } finally {
      stream.free();
    }
  }

  void clearSpeech() {
    speech.clear();
    speechLength = 0;
    lastPartial = 0;
  }

  void accept(Float32List samples) {
    final all = Float32List(leftover.length + samples.length)
      ..setAll(0, leftover)
      ..setAll(leftover.length, samples);
    var start = 0;
    for (; start + window <= all.length; start += window) {
      final chunk = Float32List.sublistView(all, start, start + window);
      vad.acceptWaveform(chunk);
      recent.add(chunk);
      if (recent.length > leadWindows) recent.removeAt(0);
      if (vad.isDetected()) {
        if (speech.isEmpty) {
          speech.addAll(recent);
          speechLength = recent.length * window;
        } else {
          speech.add(chunk);
          speechLength += window;
        }
      } else if (vad.isEmpty()) {
        clearSpeech();
      }
      while (!vad.isEmpty()) {
        final segment = vad.front();
        vad.pop();
        out.send([transcribe(segment.samples), true]);
        clearSpeech();
      }
    }
    leftover = Float32List.fromList(all.sublist(start));

    if (speechLength - lastPartial >= _partialEvery * _sampleRate) {
      lastPartial = speechLength;
      final joined = Float32List(speechLength);
      var at = 0;
      for (final s in speech) {
        joined.setAll(at, s);
        at += s.length;
      }
      final text = transcribe(joined);
      if (text.isNotEmpty) out.send([text, false]);
    }
  }

  inbox.listen((message) {
    try {
      switch (message) {
        case Float32List samples:
          accept(samples);
        case 'reset':
          vad.reset();
          leftover = Float32List(0);
          recent.clear();
          clearSpeech();
        case 'close':
          inbox.close();
          vad.free();
          recognizer.free();
      }
    } catch (e) {
      out.send(['error', 'خطأ في نموذج التلاوة: $e']);
    }
  });
}
