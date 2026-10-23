# حفظ — Hifz

A Flutter app for iOS and Android (also runs in Chrome for testing) that helps you memorize the Quran.
Offline-first, Hafs riwayah.

## Status

Milestone **M1** (mushaf reader): the 604-page Madinah mushaf, line by line
as printed, with navigation by surah, juz and page, resume where you left
off, and ayah bookmarks. See the roadmap below.

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
flutter run              # or: flutter run -d chrome
```

Code layout:

- `lib/data/`: Quran models and the repository that loads bundled text
- `lib/features/`: one folder per screen or feature
- `assets/quran/`: bundled Quran text
- `assets/mushaf/`: page layout and per-page fonts of the Madinah mushaf
- `tool/`: scripts that build the bundled data

## Data sources

`assets/quran/hafs_uthmani.json` is the Uthmani (Hafs) text taken from
[risan/quran-json](https://github.com/risan/quran-json) (CC BY-SA 4.0,
see `assets/quran/LICENSE-quran-json.txt`), which takes it from
[The Noble Qur'an Encyclopedia](https://quranenc.com).

`assets/mushaf/` is built by `tool/build_mushaf_data.py`:

- The 15-line page layout and word glyphs (QPC v4) come from
  [Quranic Universal Library](https://qul.tarteel.ai), as packaged in
  [quran_library](https://pub.dev/packages/quran_library) (MIT).
- The per-page QCF v4 fonts of the King Fahd Glorious Quran Printing Complex
  come from [qcf_quran](https://pub.dev/packages/qcf_quran) (MIT). The app
  converts each font from WOFF to TrueType when it loads the page.
