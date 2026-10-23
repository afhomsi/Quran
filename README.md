# حفظ — Hifz

A Flutter app for iOS and Android that helps you memorize the Quran.
Offline-first, Hafs riwayah.

## Status

Milestone **M0** (project setup): app skeleton, Arabic RTL theme, bundled
Quran text, surah list and a simple reader, CI. See the roadmap below.

| Milestone | Scope |
|---|---|
| M0 | Project setup |
| M1 | Page-accurate Madinah mushaf reader |
| M2 | Audio recitation with ayah repetition |
| M3 | Guided memorization and self-test |
| M4 | Review schedule (spaced repetition) and progress |
| M5 | Beta (TestFlight, Play internal testing) |

## Development

```sh
flutter pub get
flutter test
flutter run
```

Code layout:

- `lib/data/`: Quran models and the repository that loads bundled text
- `lib/features/`: one folder per screen or feature
- `assets/quran/`: bundled Quran data

## Data sources

`assets/quran/hafs_uthmani.json` is the Uthmani (Hafs) text taken from
[risan/quran-json](https://github.com/risan/quran-json) (CC BY-SA 4.0,
see `assets/quran/LICENSE-quran-json.txt`), which takes it from
[The Noble Qur'an Encyclopedia](https://quranenc.com). M1 will move to
KFGQPC page-layout data for the mushaf view.
