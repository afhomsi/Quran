import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../data/mushaf_models.dart';
import '../data/mushaf_repository.dart';
import '../data/quran_repository.dart';
import '../data/reading_state.dart';

const _audioSettingsKey = 'audio_settings';

/// A reciter whose ayah-by-ayah recordings are served by everyayah.com.
class Reciter {
  const Reciter(this.name, this.latinName, this.folder);

  final String name;
  final String latinName;
  final String folder;

  /// URL of the recording of [ayah], e.g. `.../002255.mp3`.
  String url(AyahRef ayah) =>
      'https://everyayah.com/data/$folder/'
      '${'${ayah.surah}'.padLeft(3, '0')}${'${ayah.ayah}'.padLeft(3, '0')}.mp3';
}

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
];

/// What playback goes back to when it reaches the end of it.
enum AudioLoop { none, ayah, page, surah }

/// Plays one recording at a time. Wraps just_audio so tests can swap it.
abstract class AyahPlayer {
  /// Starts [url] and completes once it has started.
  Future<void> play(String url, {double speed = 1});
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
  Future<void> play(String url, {double speed = 1}) async {
    await _player.setUrl(url);
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
  Stream<void> get completed => _player.playerStateStream
      .where((s) => s.processingState == ProcessingState.completed)
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

  @override
  AudioState build() {
    final player = ref.watch(ayahPlayerProvider);
    _completed = player.completed.listen((_) => _onCompleted());
    ref.onDispose(() => _completed?.cancel());
    final raw = ref
        .read(sharedPreferencesProvider)
        .getString(_audioSettingsKey);
    if (raw == null) return const AudioState();
    final saved = jsonDecode(raw) as Map<String, dynamic>;
    return AudioState(
      reciter: (saved['reciter'] as int).clamp(0, reciters.length - 1),
      repeats: saved['repeats'] as int,
      speed: (saved['speed'] as num).toDouble(),
      loop: AudioLoop.values.byName(saved['loop'] as String),
      listRepeats: saved['listRepeats'] as int? ?? 1,
    );
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

  Future<void> _playAyah(AyahRef ayah) {
    _played = 0;
    return _start(ayah);
  }

  Future<void> _start(AyahRef ayah) async {
    _finished = false;
    state = state.copyWith(
      current: ayah,
      visible: true,
      playing: true,
      loading: true,
      failed: false,
    );
    try {
      await _player.play(reciters[state.reciter].url(ayah), speed: state.speed);
      if (state.current == ayah) state = state.copyWith(loading: false);
    } catch (e) {
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
