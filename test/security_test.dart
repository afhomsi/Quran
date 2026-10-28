import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/audio/audio_store.dart';
import 'package:hifz/audio/ayah_audio.dart';
import 'package:hifz/data/backup.dart';
import 'package:hifz/data/khatma.dart';
import 'package:hifz/data/marks.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:hifz/data/recitation_history.dart';
import 'package:hifz/data/study.dart';
import 'package:hifz/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_player.dart';

/// Checks that data from outside the app, a pasted backup, saved data
/// changed by hand or an answer from the internet, cannot crash or slow
/// down the app, and that it only talks to the internet encrypted.
void main() {
  Future<(SharedPreferences, ProviderContainer)> load(
    Map<String, Object> saved,
  ) async {
    SharedPreferences.setMockInitialValues(saved);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ayahPlayerProvider.overrideWithValue(FakePlayer()),
        audioStoreProvider.overrideWithValue(AudioStore.none()),
      ],
    );
    addTearDown(container.dispose);
    return (prefs, container);
  }

  group('ayat in saved data', () {
    test('the ayah counts match the bundled Quran', () {
      final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
      expect(ayahCounts, [for (final s in surahs) s.ayahCount]);
      expect(ayahCounts.fold(0, (a, b) => a + b), 6236);
    });

    test('only ayat of the mushaf are read', () {
      expect(AyahRef.tryParse('2:255'), const AyahRef(2, 255));
      expect(AyahRef.tryParse('114:6'), const AyahRef(114, 6));
      for (final bad in [
        '2:287',
        '0:1',
        '115:1',
        '1:0',
        '-1:2',
        '1:7:1',
        ' 1:7',
        '1:07x',
        '١:٢',
        '99999999999999999999:1',
        '',
        null,
        12,
        ['1:1'],
      ]) {
        expect(AyahRef.tryParse(bad), isNull, reason: '$bad');
      }
      expect(() => AyahRef.parseValid('9:130'), throwsFormatException);
    });

    test('bookmarks, markers, highlights and notes skip ayat that do not '
        'exist', () async {
      final (_, c) = await load({
        'bookmarks': ['2:255', '999:999', 'x', '1:8'],
        'markers': jsonEncode({
          'reading': '2:300',
          'hifz': '3:1',
          'other': '1:1',
          'review': 5,
        }),
        'highlights': jsonEncode({'1:1': 2, '1:99': 1, '2:2': 'red'}),
        'notes': jsonEncode({'1:1': 'ok', '0:0': 'bad', '1:2': 5}),
      });
      expect(c.read(bookmarksProvider), [const AyahRef(2, 255)]);
      expect(c.read(markersProvider), {MarkerKind.hifz: const AyahRef(3, 1)});
      expect(c.read(highlightsProvider), {const AyahRef(1, 1): 2});
      expect(c.read(notesProvider), {const AyahRef(1, 1): 'ok'});
    });

    test('a page outside the mushaf is not resumed', () async {
      for (final page in [0, -3, 605, 1 << 40]) {
        final (_, c) = await load({'last_page': page});
        expect(c.read(lastPageProvider), isNull, reason: '$page');
      }
      final (_, c) = await load({'last_page': 604});
      expect(c.read(lastPageProvider), 604);
    });

    test('a very long note is cut, also when saved', () async {
      final (_, c) = await load({
        'notes': jsonEncode({'1:1': 'ا' * (maxNoteLength * 3)}),
      });
      expect(
        c.read(notesProvider)[const AyahRef(1, 1)],
        hasLength(maxNoteLength),
      );
      c
          .read(notesProvider.notifier)
          .set(const AyahRef(1, 2), 'ب' * (maxNoteLength + 5));
      expect(
        c.read(notesProvider)[const AyahRef(1, 2)],
        hasLength(maxNoteLength),
      );
    });

    test('one damaged recitation is left out, not the whole history', () async {
      final good = RecitationRecord(
        date: DateTime(2026, 10, 24),
        surah: 1,
        first: const AyahRef(1, 1),
        last: const AyahRef(1, 7),
        wordsDone: 29,
        wordsTotal: 29,
        complete: true,
        mistakes: const [MistakeRecord(AyahRef(1, 2), 'خطأ')],
      ).toJson();
      final (_, c) = await load({
        recitationHistoryKey: jsonEncode([
          good,
          {...good, 'first': '1:500'},
          {...good, 'date': 'yesterday'},
          'nonsense',
          good,
        ]),
      });
      expect(c.read(recitationHistoryProvider), hasLength(2));
    });

    test('a khatma cannot be longer than the mushaf has pages', () async {
      final plan = {
        'id': '1',
        'title': 'ختمة',
        'type': 'custom',
        'color': 0,
        'days': 1000000000,
        'created': '2026-10-24T00:00:00.000',
        'done': <int>[],
      };
      final (_, c) = await load({
        'khatma_plans': jsonEncode([
          plan,
          {...plan, 'id': '2', 'type': 'ramadan', 'days': 0},
          {...plan, 'id': '3', 'color': 99},
          {...plan, 'id': '4', 'type': 'unknown'},
        ]),
      });
      final plans = c.read(khatmaPlansProvider);
      expect(plans.map((p) => p.id), ['1', '2']);
      expect(plans[0].days, 604);
      expect(plans[1].days, 30);
    });

    test('settings out of range are brought back into range', () {
      expect(
        AppSettings.fromJson({'autoPageSeconds': 0}).autoPageSeconds,
        minAutoPageSeconds,
      );
      expect(
        AppSettings.fromJson({'autoPageSeconds': -50}).autoPageSeconds,
        minAutoPageSeconds,
      );
      expect(
        AppSettings.fromJson({'autoPageSeconds': 1 << 40}).autoPageSeconds,
        maxAutoPageSeconds,
      );
    });

    test('the player choices are kept within their ranges', () async {
      final (_, c) = await load({
        'audio_settings': jsonEncode({
          'reciter': 500,
          'repeats': -4,
          'speed': 99,
          'loop': 'surah',
          'listRepeats': 1000,
        }),
      });
      final audio = c.read(audioProvider);
      expect(audio.reciter, reciters.length - 1);
      expect(audio.repeats, 1);
      expect(audio.speed, 1.5);
      expect(audio.listRepeats, 20);
    });
  });

  group('restoring a backup', () {
    test('refuses text that is not a backup of this app', () async {
      final (prefs, _) = await load({'last_page': 10});
      for (final text in [
        '',
        'hello',
        '[1, 2]',
        '{"app": "other", "last_page": 3}',
        '{"app": "hifz"',
        jsonEncode({'app': 'hifz', 'last_page': 3})
            .padRight(maxBackupLength + 1),
      ]) {
        expect(await importBackup(prefs, text), isFalse);
      }
      expect(prefs.getInt('last_page'), 10);
    });

    test('leaves out values that are wrong', () async {
      final (prefs, c) = await load({'last_page': 10});
      final ok = await importBackup(
        prefs,
        jsonEncode({
          'app': 'hifz',
          'last_page': 9999,
          'bookmarks': ['1:1', '200:1', 3, '2:286'],
          'settings': {'nightMode': 'yes', 'autoPageSeconds': 1},
          'markers': 'not a map',
          'notes': {'1:1': 'ملاحظة', '1:100': 'x'},
        }),
      );
      expect(ok, isTrue);
      expect(prefs.getInt('last_page'), 10);
      expect(prefs.getStringList('bookmarks'), ['1:1', '2:286']);
      expect(prefs.getString('markers'), isNull);
      final settings = c.read(settingsProvider);
      expect(settings.nightMode, isFalse);
      expect(settings.autoPageSeconds, minAutoPageSeconds);
      expect(c.read(notesProvider), {const AyahRef(1, 1): 'ملاحظة'});
    });

    test('everything saved comes back from a backup', () async {
      final (prefs, c) = await load({});
      c.read(bookmarksProvider.notifier).toggle(const AyahRef(2, 255));
      c
          .read(markersProvider.notifier)
          .set(MarkerKind.hifz, const AyahRef(3, 7));
      c.read(highlightsProvider.notifier).set(const AyahRef(1, 2), 3);
      c.read(notesProvider.notifier).set(const AyahRef(1, 3), 'راجع');
      c.read(lastPageProvider.notifier).set(77);
      c
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(nightMode: true, autoPageSeconds: 45));
      final backup = exportBackup(prefs);

      final (fresh, c2) = await load({});
      expect(await importBackup(fresh, backup), isTrue);
      expect(c2.read(bookmarksProvider), [const AyahRef(2, 255)]);
      expect(c2.read(markersProvider), {MarkerKind.hifz: const AyahRef(3, 7)});
      expect(c2.read(highlightsProvider), {const AyahRef(1, 2): 3});
      expect(c2.read(notesProvider), {const AyahRef(1, 3): 'راجع'});
      expect(c2.read(lastPageProvider), 77);
      expect(c2.read(settingsProvider).nightMode, isTrue);
      expect(c2.read(settingsProvider).autoPageSeconds, 45);
    });
  });

  test('the study books are read from the app, without internet', () async {
    final r = StudyRepository(
      loadBook: (path) async => readBundledBook(File(path).readAsBytesSync()),
    );
    expect(
      await r.text(StudyBook.jamiWajiz, const AyahRef(2, 255)),
      contains('الحي'),
    );
    expect(await r.text(StudyBook.jalalayn, const AyahRef(1, 2)), isNotEmpty);
    expect(await r.text(StudyBook.english, const AyahRef(1, 1)), isNotEmpty);
    expect(await r.text(StudyBook.jamiWajiz, const AyahRef(1, 99)), '');
  });

  group('the app as installed', () {
    test('every web address in the app is HTTPS', () {
      final insecure = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        for (final m in RegExp(
          r'http://[^\s'
          "'"
          r'"]+',
        ).allMatches(f.readAsStringSync())) {
          insecure.add('${f.path}: ${m[0]}');
        }
      }
      expect(insecure, isEmpty);
    });

    test('every recording is fetched over HTTPS from a known site', () {
      for (final r in reciters) {
        final url = Uri.parse(r.url(const AyahRef(114, 6)));
        expect(url.scheme, 'https');
        expect(url.host, r.timed ? 'cdn.mp3quran.net' : 'everyayah.com');
        expect(url.pathSegments.last, r.timed ? '114.mp3' : '114006.mp3');
      }
    });

    test('Android allows only encrypted connections', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(manifest, contains('android:usesCleartextTraffic="false"'));
      expect(
        manifest,
        contains(
          'android:networkSecurityConfig="@xml/network_security_config"',
        ),
      );
      final config = File(
        'android/app/src/main/res/xml/network_security_config.xml',
      ).readAsStringSync();
      expect(config, contains('cleartextTrafficPermitted="false"'));
      expect(config, isNot(contains('src="user"')));
    });

    test('Android asks only for the microphone and the internet', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      final permissions = RegExp(r'uses-permission android:name="([^"]+)"')
          .allMatches(manifest)
          .map((m) => m[1])
          .toSet();
      expect(permissions, {
        'android.permission.RECORD_AUDIO',
        'android.permission.INTERNET',
      });
    });

    test('iOS does not allow unencrypted connections', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, isNot(contains('NSAllowsArbitraryLoads')));
      expect(plist, contains('NSMicrophoneUsageDescription'));
    });

    test('no keys or passwords are kept in the code', () {
      final secret = RegExp(
        r'''(api[_-]?key|secret|password|token)\s*[:=]\s*['"][^'"]{8,}''',
        caseSensitive: false,
      );
      final found = <String>[];
      for (final dir in ['lib', 'android', 'ios', 'web']) {
        for (final f in Directory(dir).listSync(recursive: true)) {
          if (f is! File) continue;
          final String text;
          try {
            text = f.readAsStringSync();
          } on FileSystemException {
            continue; // not text, e.g. an image
          }
          if (secret.hasMatch(text)) found.add(f.path);
        }
      }
      expect(found, isEmpty);
    });
  });
}
