import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import '../data/mushaf_models.dart';
import '../data/mushaf_repository.dart';
import '../data/quran_repository.dart';
import '../data/reading_state.dart';
import 'audio_store.dart';

const _audioSettingsKey = 'audio_settings';

/// A reciter and where their recordings come from.
///
/// Most are served ayah by ayah by everyayah.com. The rest are whole-surah
/// recordings from mp3quran.net, cut into ayat while playing by the start
/// and end time mp3quran.net gives for each ayah, so every reciter can
/// play a range of ayat and repeat it.
class Reciter {
  /// A reciter with one recording per ayah in everyayah.com's [folder].
  const Reciter(this.name, this.latinName, this.folder) : timingRead = null;

  /// A reciter with one recording per surah in mp3quran.net's [folder]
  /// (e.g. `saber-abdulhakam/r1`), whose ayah times are read [timingRead].
  const Reciter.timed(
    this.name,
    this.latinName,
    this.folder, {
    required int this.timingRead,
  });

  final String name;
  final String latinName;
  final String folder;

  /// mp3quran.net's number for this recording's ayah times; null for an
  /// ayah-by-ayah reciter.
  final int? timingRead;

  /// Whether each ayah is cut out of a whole-surah recording.
  bool get timed => timingRead != null;

  /// URL of the recording that holds [ayah]: its own file, e.g.
  /// `.../002255.mp3`, or the file of its whole surah, e.g. `.../002.mp3`.
  String url(AyahRef ayah) => timed
      ? 'https://cdn.mp3quran.net/audio/$folder/${fileName(ayah)}'
      : 'https://everyayah.com/data/$folder/${fileName(ayah)}';

  /// Name of the file that holds [ayah] once downloaded, the same as in
  /// [url]: `002255.mp3`, or `002.mp3` for a whole-surah recording.
  String fileName(AyahRef ayah) => timed
      ? '${_three(ayah.surah)}.mp3'
      : '${_three(ayah.surah)}${_three(ayah.ayah)}.mp3';

  /// Name of the downloaded ayah times of [surah], e.g. `002.json`.
  String timingsFile(int surah) => '${_three(surah)}.json';

  /// Where mp3quran.net gives this reciter's ayah times of [surah].
  Uri timingsUrl(int surah) => Uri.https(
    'mp3quran.net',
    '/api/v3/ayat_timing',
    {'surah': '$surah', 'read': '$timingRead'},
  );
}

String _three(int n) => '$n'.padLeft(3, '0');

const reciters = [
  Reciter('مشاري العفاسي', 'Mishary Alafasy', 'Alafasy_128kbps'),
  Reciter('محمود خليل الحصري', 'Mahmoud Khalil Al-Husary', 'Husary_128kbps'),
  Reciter(
    'محمد صديق المنشاوي',
    'Muhammad Siddiq Al-Minshawi',
    'Minshawy_Murattal_128kbps',
  ),
  Reciter(
    'عبد الباسط عبد الصمد',
    'Abdul Basit Abdus Samad',
    'Abdul_Basit_Murattal_192kbps',
  ),
  Reciter(
    'عبد الرحمن السديس',
    'Abdur-Rahman As-Sudais',
    'Abdurrahmaan_As-Sudais_192kbps',
  ),
  Reciter('سعد الغامدي', 'Saad Al-Ghamdi', 'Ghamadi_40kbps'),
  Reciter('ماهر المعيقلي', 'Maher Al-Muaiqly', 'MaherAlMuaiqly128kbps'),
  Reciter('سعود الشريم', 'Saud Ash-Shuraim', 'Saood_ash-Shuraym_128kbps'),
  Reciter('ياسر الدوسري', 'Yasser Ad-Dossari', 'Yasser_Ad-Dussary_128kbps'),
  Reciter(
    'أحمد بن علي العجمي',
    'Ahmed Al-Ajmi',
    'Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net',
  ),
  Reciter(
    'أبو بكر الشاطري',
    'Abu Bakr Ash-Shatri',
    'Abu_Bakr_Ash-Shaatree_128kbps',
  ),
  Reciter('ناصر القطامي', 'Nasser Al-Qatami', 'Nasser_Alqatami_128kbps'),
  Reciter('علي الحذيفي', 'Ali Al-Hudhaifi', 'Hudhaify_128kbps'),
  Reciter('فارس عباد', 'Fares Abbad', 'Fares_Abbad_64kbps'),
  // Added later: the saved choice is a position in this list, so new
  // reciters go at the end.
  Reciter('محمد أيوب', 'Muhammad Ayyub', 'Muhammad_Ayyoub_128kbps'),
  Reciter(
    'محمود الحصري - المجوّد',
    'Mahmoud Al-Husary (Mujawwad)',
    'Husary_128kbps_Mujawwad',
  ),
  Reciter(
    'محمود علي البنا',
    'Mahmoud Ali Al-Banna',
    'mahmoud_ali_al_banna_32kbps',
  ),
  Reciter('علي جابر', 'Ali Jaber', 'Ali_Jaber_64kbps'),
  Reciter('مصطفى إسماعيل', 'Mustafa Ismail', 'Mustafa_Ismail_48kbps'),
  Reciter(
    'خالد القحطاني',
    'Khalid Al-Qahtani',
    'Khaalid_Abdullaah_al-Qahtaanee_192kbps',
  ),
  Reciter.timed(
    'صابر عبد الحكم',
    'Saber Abdulhakam',
    'saber-abdulhakam/r1',
    timingRead: 39,
  ),
  Reciter.timed(
    'بندر بليلة',
    'Bandar Baleela',
    'bandar-baleela/r1',
    timingRead: 217,
  ),
  Reciter.timed(
    'خالد المهنا',
    'Khalid Al-Muhanna',
    'khalid-mohanna/r1',
    timingRead: 159,
  ),
];

/// Where one ayah is in its surah's recording.
typedef AyahSpan = ({Duration start, Duration end});

/// Fetches from mp3quran.net when each ayah starts and ends in a
/// whole-surah recording, keeping what it has fetched. Times of a
/// downloaded surah are read from the phone, so it plays without internet.
class AyahTimings {
  AyahTimings({http.Client? client, this.store})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// Where the ayah times of downloaded surahs are kept.
  final AudioStore? store;
  final _surahs = <(int, int), Future<Map<int, AyahSpan>>>{};

  /// Where [ayah] is in the surah recording of [reciter].
  Future<AyahSpan> span(Reciter reciter, AyahRef ayah) async {
    final key = (reciter.timingRead!, ayah.surah);
    final surah = _surahs[key] ??= _fetch(reciter, ayah.surah);
    try {
      final span = (await surah)[ayah.ayah];
      if (span == null) throw StateError('No time for $ayah');
      return span;
    } catch (_) {
      // Try again next time, e.g. once the device is back online.
      if (_surahs[key] == surah) _surahs.remove(key);
      rethrow;
    }
  }

  Future<Map<int, AyahSpan>> _fetch(Reciter reciter, int surah) async {
    final kept = await store?.readText(reciter, reciter.timingsFile(surah));
    if (kept != null) {
      try {
        final spans = parseAyahTimings(kept);
        if (spans.isNotEmpty) return spans;
      } catch (_) {
        // Fetched again below.
      }
    }
    return parseAyahTimings(await fetchText(reciter.timingsUrl(surah)));
  }

  /// The ayah times at [url], as mp3quran.net gives them.
  Future<String> fetchText(Uri url) async {
    final response = await _client.get(url);
    if (response.statusCode != 200) {
      throw http.ClientException('Ayah times: ${response.statusCode}');
    }
    return response.body;
  }

  void dispose() => _client.close();
}

/// Reads mp3quran.net's ayah times: a list of `{ayah, start_time,
/// end_time}` in milliseconds. Entries that are not ayat are left out.
Map<int, AyahSpan> parseAyahTimings(String body) {
  final spans = <int, AyahSpan>{};
  for (final entry in jsonDecode(body) as List) {
    if (entry is! Map) continue;
    final ayah = entry['ayah'];
    final start = entry['start_time'];
    final end = entry['end_time'];
    if (ayah is! int || ayah < 1 || start is! num || end is! num) continue;
    if (end <= start) continue;
    spans[ayah] = (
      start: Duration(milliseconds: start.round()),
      end: Duration(milliseconds: end.round()),
    );
  }
  return spans;
}

/// Where downloaded recordings are kept.
final audioStoreProvider = Provider<AudioStore>((ref) => AudioStore());

final ayahTimingsProvider = Provider<AyahTimings>((ref) {
  final timings = AyahTimings(store: ref.watch(audioStoreProvider));
  ref.onDispose(timings.dispose);
  return timings;
});

/// What playback goes back to when it reaches the end of it.
enum AudioLoop { none, ayah, page, surah }

/// Plays one recording at a time. Wraps just_audio so tests can swap it.
abstract class AyahPlayer {
  /// Starts [url] and completes once it has started. With [start] and
  /// [end], plays only that part of it.
  Future<void> play(
    String url, {
    double speed = 1,
    Duration? start,
    Duration? end,
  });
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> setSpeed(double speed);

  /// Fires when a recording plays to its end.
  Stream<void> get completed;

  void dispose();
}

class JustAudioAyahPlayer implements AyahPlayer {
  final _player = AudioPlayer();

  @override
  Future<void> play(
    String url, {
    double speed = 1,
    Duration? start,
    Duration? end,
  }) async {
    // Loading a new recording over a finished one is ignored on the web, so
    // the first ayah played again and again. Stop first to start afresh.
    await _player.stop();
    final source = AudioSource.uri(Uri.parse(url));
    await _player.setAudioSource(
      start == null && end == null
          ? source
          : ClippingAudioSource(child: source, start: start, end: end),
    );
    await _player.setSpeed(speed);
    // play() only returns once playback stops, so don't wait for it.
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() async => unawaited(_player.play());

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Stream<void> get completed => _player.processingStateStream
      // Once per ending: stopping a finished recording repeats its state.
      .distinct()
      .where((s) => s == ProcessingState.completed)
      .map((_) {});

  @override
  void dispose() => _player.dispose();
}

final ayahPlayerProvider = Provider<AyahPlayer>((ref) {
  final player = JustAudioAyahPlayer();
  ref.onDispose(player.dispose);
  return player;
});

class AudioState {
  const AudioState({
    this.current,
    this.visible = false,
    this.playing = false,
    this.loading = false,
    this.failed = false,
    this.loop = AudioLoop.none,
    this.reciter = 0,
    this.repeats = 1,
    this.speed = 1,
    this.playlist,
    this.listRepeats = 1,
    this.pass = 1,
  });

  /// The ayah playing or paused; null before anything has played.
  final AyahRef? current;

  /// Whether the player bar is shown.
  final bool visible;
  final bool playing;
  final bool loading;

  /// Whether the last recording could not be played, usually because the
  /// device is offline.
  final bool failed;
  final AudioLoop loop;

  /// Index in [reciters].
  final int reciter;

  /// How many times each ayah is played before moving on.
  final int repeats;
  final double speed;

  /// The ayat chosen to play and repeat together, e.g. a range of ayat or
  /// the ayat recited with mistakes. Null when playing on through the
  /// mushaf.
  final List<AyahRef>? playlist;

  /// How many times the whole [playlist] is played.
  final int listRepeats;

  /// Which time the [playlist] is playing now, from 1.
  final int pass;

  AudioState copyWith({
    AyahRef? current,
    bool? visible,
    bool? playing,
    bool? loading,
    bool? failed,
    AudioLoop? loop,
    int? reciter,
    int? repeats,
    double? speed,
    List<AyahRef>? playlist,
    bool clearPlaylist = false,
    int? listRepeats,
    int? pass,
  }) => AudioState(
    current: current ?? this.current,
    visible: visible ?? this.visible,
    playing: playing ?? this.playing,
    loading: loading ?? this.loading,
    failed: failed ?? this.failed,
    loop: loop ?? this.loop,
    reciter: reciter ?? this.reciter,
    repeats: repeats ?? this.repeats,
    speed: speed ?? this.speed,
    playlist: clearPlaylist ? null : playlist ?? this.playlist,
    listRepeats: listRepeats ?? this.listRepeats,
    pass: pass ?? this.pass,
  );
}

/// Ayah-by-ayah recitation for listening and memorizing: plays on from
/// the chosen ayah, repeats each ayah, and can loop an ayah, page or surah,
/// or a chosen list of ayat a chosen number of times.
class AudioController extends Notifier<AudioState> {
  StreamSubscription<void>? _completed;

  /// Times the current ayah has played to its end.
  var _played = 0;

  /// Position of the current ayah in the playlist.
  var _index = 0;

  /// Whether playback stopped by reaching its end.
  var _finished = false;

  /// Whether the basmala is playing before the current ayah.
  var _basmala = false;

  /// Counts the recordings started, so a slow one that was overtaken by
  /// another choice does not start after it.
  var _starts = 0;

  @override
  AudioState build() {
    final player = ref.watch(ayahPlayerProvider);
    // Go on outside the player's own event, which cannot load the next
    // recording while it is being delivered.
    _completed = player.completed.listen((_) => Future(_onCompleted));
    ref.onDispose(() => _completed?.cancel());
    final raw = ref
        .read(sharedPreferencesProvider)
        .getString(_audioSettingsKey);
    return readStored(raw, (json) {
      final saved = json as Map<String, dynamic>;
      return AudioState(
        reciter: (saved['reciter'] as int).clamp(0, reciters.length - 1),
        repeats: (saved['repeats'] as int).clamp(1, 20),
        speed: (saved['speed'] as num).toDouble().clamp(0.5, 1.5),
        loop: AudioLoop.values.byName(saved['loop'] as String),
        listRepeats: (saved['listRepeats'] as int? ?? 1).clamp(1, 20),
      );
    }, const AudioState());
  }

  AyahPlayer get _player => ref.read(ayahPlayerProvider);

  /// Shows the player bar, ready to start at [ayah] unless something is
  /// playing already.
  void show(AyahRef ayah) => state = state.copyWith(
    visible: true,
    current: state.playing ? state.current : ayah,
  );

  /// Plays on through the mushaf from [ayah], leaving any playlist.
  Future<void> playFrom(AyahRef ayah) {
    state = state.copyWith(clearPlaylist: true);
    return _playAyah(ayah);
  }

  /// Plays [ayat] in order, each ayah [ayahRepeats] times, and the whole
  /// list [listRepeats] times, then stops.
  Future<void> playList(
    List<AyahRef> ayat, {
    required int ayahRepeats,
    required int listRepeats,
  }) async {
    final list = ayat.toSet().toList();
    if (list.isEmpty) return;
    _saveSettings(
      state.copyWith(repeats: ayahRepeats, listRepeats: listRepeats),
    );
    state = state.copyWith(playlist: list, pass: 1);
    _index = 0;
    await _playAyah(list.first);
  }

  /// Plays the ayat from [first] to [last], both included, as a playlist.
  Future<void> playRange(
    AyahRef first,
    AyahRef last, {
    required int ayahRepeats,
    required int listRepeats,
  }) => playList(
    ayatBetween(first, last),
    ayahRepeats: ayahRepeats,
    listRepeats: listRepeats,
  );

  /// The ayat from [first] to [last], both included, across surahs.
  List<AyahRef> ayatBetween(AyahRef first, AyahRef last) {
    if (last < first) (first, last) = (last, first);
    final ayat = <AyahRef>[];
    for (AyahRef? a = first; a != null && !(last < a); a = _after(a)) {
      ayat.add(a);
    }
    return ayat;
  }

  /// Leaves the playlist and plays on through the mushaf.
  void leavePlaylist() => state = state.copyWith(clearPlaylist: true);

  /// Starts [ayah] afresh. The first ayah of a surah comes after the
  /// basmala, as recited, except in al-Fatiha, where the basmala is the
  /// first ayah, and at-Tawbah, which has none.
  Future<void> _playAyah(AyahRef ayah) {
    _played = 0;
    return _start(
      ayah,
      basmala: ayah.ayah == 1 && ayah.surah != 1 && ayah.surah != 9,
    );
  }

  /// Plays [ayah], or the basmala before it when [basmala] is true.
  Future<void> _start(AyahRef ayah, {bool basmala = false}) async {
    _finished = false;
    _basmala = basmala;
    final start = ++_starts;
    state = state.copyWith(
      current: ayah,
      visible: true,
      playing: true,
      loading: true,
      failed: false,
    );
    try {
      final recording = basmala ? const AyahRef(1, 1) : ayah;
      final reciter = reciters[state.reciter];
      final span = reciter.timed
          ? await ref.read(ayahTimingsProvider).span(reciter, recording)
          : null;
      // A downloaded recording plays from the phone, without internet.
      final kept = await ref
          .read(audioStoreProvider)
          .find(reciter, reciter.fileName(recording));
      // Something else was chosen while the ayah times were fetched.
      if (start != _starts || !state.playing) return;
      await _player.play(
        kept != null ? Uri.file(kept).toString() : reciter.url(recording),
        speed: state.speed,
        start: span?.start,
        end: span?.end,
      );
      if (state.current == ayah) state = state.copyWith(loading: false);
    } catch (e) {
      if (start != _starts) return;
      state = state.copyWith(playing: false, loading: false, failed: true);
    }
  }

  Future<void> togglePlay() async {
    final current = state.current;
    if (current == null) return;
    if (state.playing) {
      state = state.copyWith(playing: false);
      await _player.pause();
    } else if (_finished && state.playlist != null) {
      state = state.copyWith(pass: 1);
      _index = 0;
      await _playAyah(state.playlist!.first);
    } else if (state.loading || state.failed || _finished) {
      await _playAyah(current);
    } else {
      state = state.copyWith(playing: true);
      await _player.resume();
    }
  }

  Future<void> next() async {
    final list = state.playlist;
    if (list != null) {
      if (_index + 1 < list.length) await _playAyah(list[++_index]);
      return;
    }
    final current = state.current;
    final after = current == null ? null : _after(current);
    if (after != null) await _playAyah(after);
  }

  Future<void> previous() async {
    final list = state.playlist;
    if (list != null) {
      if (_index > 0) await _playAyah(list[--_index]);
      return;
    }
    final current = state.current;
    final before = current == null ? null : _before(current);
    if (before != null) await _playAyah(before);
  }

  Future<void> close() async {
    state = state.copyWith(
      visible: false,
      playing: false,
      loading: false,
      clearPlaylist: true,
    );
    await _player.stop();
  }

  /// Steps through no loop, ayah, page and surah.
  void cycleLoop() => _saveSettings(
    state.copyWith(
      loop: AudioLoop.values[(state.loop.index + 1) % AudioLoop.values.length],
    ),
  );

  void setReciter(int reciter) {
    _saveSettings(state.copyWith(reciter: reciter));
    if (state.playing && state.current != null) _playAyah(state.current!);
  }

  void setRepeats(int repeats) =>
      _saveSettings(state.copyWith(repeats: repeats));

  Future<void> setSpeed(double speed) {
    _saveSettings(state.copyWith(speed: speed));
    return _player.setSpeed(speed);
  }

  void _saveSettings(AudioState s) {
    state = s;
    ref
        .read(sharedPreferencesProvider)
        .setString(
          _audioSettingsKey,
          jsonEncode({
            'reciter': s.reciter,
            'repeats': s.repeats,
            'speed': s.speed,
            'loop': s.loop.name,
            'listRepeats': s.listRepeats,
          }),
        );
  }

  void _onCompleted() {
    final current = state.current;
    if (current == null || !state.playing) return;
    if (_basmala) {
      _start(current);
      return;
    }
    _played++;
    final list = state.playlist;
    if (_played < state.repeats ||
        (list == null && state.loop == AudioLoop.ayah)) {
      _start(current);
      return;
    }
    if (list != null) {
      if (_index + 1 < list.length) {
        _playAyah(list[++_index]);
      } else if (state.pass < state.listRepeats) {
        state = state.copyWith(pass: state.pass + 1);
        _index = 0;
        _playAyah(list.first);
      } else {
        _finished = true;
        state = state.copyWith(playing: false);
      }
      return;
    }
    final next = _nextInLoop(current);
    if (next == null) {
      _finished = true;
      state = state.copyWith(playing: false);
    } else {
      _playAyah(next);
    }
  }

  /// The ayah to play after [ayah] has finished, keeping inside the loop.
  AyahRef? _nextInLoop(AyahRef ayah) {
    final after = _after(ayah);
    final mushaf = ref.read(mushafProvider).value;
    switch (state.loop) {
      case AudioLoop.none:
      case AudioLoop.ayah:
        return after;
      case AudioLoop.page:
        if (mushaf == null) return after;
        final page = mushaf.pageOf(ayah);
        return after != null && mushaf.pageOf(after) == page
            ? after
            : mushaf.page(page).firstAyah;
      case AudioLoop.surah:
        return after != null && after.surah == ayah.surah
            ? after
            : AyahRef(ayah.surah, 1);
    }
  }

  AyahRef? _after(AyahRef a) {
    final surahs = ref.read(surahsProvider).value;
    if (surahs == null) return null;
    if (a.ayah < surahs[a.surah - 1].ayahCount) {
      return AyahRef(a.surah, a.ayah + 1);
    }
    return a.surah < surahs.length ? AyahRef(a.surah + 1, 1) : null;
  }

  AyahRef? _before(AyahRef a) {
    final surahs = ref.read(surahsProvider).value;
    if (surahs == null) return null;
    if (a.ayah > 1) return AyahRef(a.surah, a.ayah - 1);
    return a.surah > 1
        ? AyahRef(a.surah - 1, surahs[a.surah - 2].ayahCount)
        : null;
  }
}

final audioProvider = NotifierProvider<AudioController, AudioState>(
  AudioController.new,
);
