import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/mushaf_models.dart';
import '../data/quran_models.dart';
import '../data/quran_repository.dart';
import 'audio_store.dart';
import 'ayah_audio.dart';

/// One file to download for a surah: what it is called on the phone and
/// where it comes from.
typedef AudioFile = ({String name, Uri url});

/// The files that let [surah] of [reciter] play without internet: each
/// ayah's recording, with the basmala that is played before the first ayah,
/// or the whole-surah recording with its ayah times.
List<AudioFile> surahFiles(Reciter reciter, Surah surah) {
  final s = surah.number;
  if (reciter.timed) {
    final ayah = AyahRef(s, 1);
    return [
      (name: reciter.fileName(ayah), url: Uri.parse(reciter.url(ayah))),
      (name: reciter.timingsFile(s), url: reciter.timingsUrl(s)),
    ];
  }
  return [
    // The basmala is al-Fatiha's first ayah.
    if (s != 1 && s != 9)
      (
        name: reciter.fileName(const AyahRef(1, 1)),
        url: Uri.parse(reciter.url(const AyahRef(1, 1))),
      ),
    for (var a = 1; a <= surah.ayahCount; a++)
      (
        name: reciter.fileName(AyahRef(s, a)),
        url: Uri.parse(reciter.url(AyahRef(s, a))),
      ),
  ];
}

/// How much of [surah] of [reciter] is on the phone, from 0 to 1, given the
/// names of the files kept for the reciter.
double surahProgress(Reciter reciter, Surah surah, Set<String> kept) {
  final files = surahFiles(reciter, surah).map((f) => f.name).toList();
  // The basmala is shared by every surah, so alone it is no progress.
  final basmala = reciter.fileName(const AyahRef(1, 1));
  final own = surah.number == 1 || reciter.timed
      ? files
      : files.where((f) => f != basmala).toList();
  final done = own.where(kept.contains).length / own.length;
  if (done == 1 && !files.every(kept.contains)) {
    return (own.length - 0.5) / own.length;
  }
  return done;
}

/// The names of the files kept for each reciter, by their place in
/// [reciters].
final keptAudioProvider = FutureProvider.family<Set<String>, int>(
  (ref, reciter) => ref.watch(audioStoreProvider).files(reciters[reciter]),
);

/// Bytes taken by the recordings kept for a reciter.
final keptAudioSizeProvider = FutureProvider.family<int, int>((ref, reciter) {
  // Measured again whenever the files change.
  ref.watch(keptAudioProvider(reciter));
  return ref.watch(audioStoreProvider).size(reciters[reciter]);
});

/// Sent with every download. Some recitation sites refuse requests that
/// name no browser or player, as Dart's own default does.
const audioUserAgent =
    'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36';

/// Makes the connection downloads are fetched over; swapped in tests.
final audioDownloadClientProvider = Provider<http.Client Function()>(
  (ref) => http.Client.new,
);

/// A surah of a reciter, waiting or being downloaded.
typedef SurahDownload = ({int reciter, int surah});

class DownloadsState {
  const DownloadsState({
    this.queue = const [],
    this.done = 0,
    this.total = 0,
    this.error,
  });

  /// The surahs still to download; the first one is downloading now.
  final List<SurahDownload> queue;

  /// Files of the first surah in [queue] downloaded so far, of [total].
  final int done;
  final int total;

  /// Why the last download stopped, when a file could not be fetched,
  /// usually because the device is offline; shown to help find the cause.
  final String? error;

  bool get failed => error != null;

  SurahDownload? get active => queue.isEmpty ? null : queue.first;

  /// How far the first surah in [queue] has got, from 0 to 1.
  double get progress => total == 0 ? 0 : done / total;

  bool waiting(int reciter, int surah) =>
      queue.contains((reciter: reciter, surah: surah));
}

/// Downloads surahs, one after another, so they play without internet.
class AudioDownloads extends Notifier<DownloadsState> {
  /// Files fetched at the same time.
  static const _parallel = 4;

  /// Times a file is tried before downloading stops.
  static const _tries = 3;

  http.Client? _client;
  var _running = false;

  /// Counts the times downloads were stopped, so a stopped download does
  /// not carry on.
  var _stops = 0;

  @override
  DownloadsState build() {
    ref.onDispose(() {
      _stops++;
      _client?.close();
    });
    return const DownloadsState();
  }

  /// Adds [surahs] of [reciter] to the downloads, leaving out the ones
  /// already waiting.
  void download(int reciter, Iterable<int> surahs) {
    final queue = [...state.queue];
    for (final s in surahs) {
      final item = (reciter: reciter, surah: s);
      if (!queue.contains(item)) queue.add(item);
    }
    state = DownloadsState(queue: queue, done: state.done, total: state.total);
    if (!_running) unawaited(_run());
  }

  /// Stops downloading [surah] of [reciter], or all of the reciter's
  /// surahs when [surah] is null. What was downloaded is kept.
  void cancel(int reciter, [int? surah]) {
    final active = state.active;
    final queue = state.queue
        .where(
          (d) => d.reciter != reciter || (surah != null && d.surah != surah),
        )
        .toList();
    final stopsActive = active != null && !queue.contains(active);
    if (stopsActive) {
      _stops++;
      _client?.close();
      _client = null;
      _running = false;
    }
    state = DownloadsState(
      queue: queue,
      done: stopsActive ? 0 : state.done,
      total: stopsActive ? 0 : state.total,
    );
    if (stopsActive) {
      ref.invalidate(keptAudioProvider(reciter));
      if (queue.isNotEmpty) unawaited(_run());
    }
  }

  /// Removes the downloaded [surah] of [reciter] from the phone, or every
  /// surah of the reciter when [surah] is null.
  Future<void> delete(int reciter, [int? surah]) async {
    cancel(reciter, surah);
    final r = reciters[reciter];
    final store = ref.read(audioStoreProvider);
    if (surah == null) {
      await store.deleteAll(r);
    } else {
      final surahs = await ref.read(surahsProvider.future);
      final names = surahFiles(r, surahs[surah - 1]).map((f) => f.name).toSet();
      // Other downloaded surahs still play the basmala.
      if (!r.timed && surah != 1) {
        final kept = await store.files(r);
        final others = surahs.where(
          (s) => s.number != surah && surahProgress(r, s, kept) > 0,
        );
        if (others.any((s) => s.number != 9)) {
          names.remove(r.fileName(const AyahRef(1, 1)));
        }
      }
      await store.delete(r, names);
    }
    ref.invalidate(keptAudioProvider(reciter));
  }

  Future<void> _run() async {
    _running = true;
    final run = _stops;
    final store = ref.read(audioStoreProvider);
    final client = _client ??= ref.read(audioDownloadClientProvider)();
    try {
      final surahs = await ref.read(surahsProvider.future);
      while (run == _stops && state.queue.isNotEmpty) {
        final item = state.queue.first;
        final reciter = reciters[item.reciter];
        final kept = await store.files(reciter);
        final files = surahFiles(reciter, surahs[item.surah - 1]);
        final missing = files.where((f) => !kept.contains(f.name)).toList();
        var done = files.length - missing.length;
        state = DownloadsState(
          queue: state.queue,
          done: done,
          total: files.length,
        );
        var next = 0;
        Future<void> worker() async {
          while (run == _stops && next < missing.length) {
            final file = missing[next++];
            await _fetchWithRetries(client, store, reciter, file, run);
            if (run != _stops) return;
            state = DownloadsState(
              queue: state.queue,
              done: ++done,
              total: files.length,
            );
          }
        }

        await Future.wait([for (var i = 0; i < _parallel; i++) worker()]);
        if (run != _stops) return;
        ref.invalidate(keptAudioProvider(item.reciter));
        state = DownloadsState(queue: state.queue.skip(1).toList());
      }
    } catch (e) {
      if (run != _stops) return;
      final active = state.active;
      if (active != null) ref.invalidate(keptAudioProvider(active.reciter));
      // Stops everything; the user can start again once back online.
      state = DownloadsState(error: downloadError(e));
    } finally {
      if (run == _stops) _running = false;
    }
  }

  Future<void> _fetchWithRetries(
    http.Client client,
    AudioStore store,
    Reciter reciter,
    AudioFile file,
    int run,
  ) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await _fetch(client, store, reciter, file);
      } catch (_) {
        if (attempt >= _tries || run != _stops) rethrow;
        await Future<void>.delayed(retryDelay * attempt);
      }
    }
  }

  /// Wait before trying a file again; shortened in tests.
  static var retryDelay = const Duration(seconds: 1);

  Future<void> _fetch(
    http.Client client,
    AudioStore store,
    Reciter reciter,
    AudioFile file,
  ) async {
    final request = http.Request('GET', file.url)
      ..headers['User-Agent'] = audioUserAgent;
    final response = await client.send(request);
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw http.ClientException('${response.statusCode}', file.url);
    }
    if (file.name.endsWith('.json')) {
      // Kept only if it holds ayah times.
      final text = await response.stream.bytesToString();
      if (parseAyahTimings(text).isEmpty) {
        throw http.ClientException('No ayah times', file.url);
      }
      await store.save(reciter, file.name, Stream.value(utf8.encode(text)));
      return;
    }
    await store.save(reciter, file.name, response.stream);
  }
}

/// A short reason for a failed download, e.g. `HTTP 403` or the
/// connection error.
String downloadError(Object e) {
  final text = e is http.ClientException
      ? (int.tryParse(e.message) != null ? 'HTTP ${e.message}' : e.message)
      : '$e';
  return text.length > 140 ? '${text.substring(0, 140)}…' : text;
}

final audioDownloadsProvider = NotifierProvider<AudioDownloads, DownloadsState>(
  AudioDownloads.new,
);
