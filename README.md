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
- `assets/mushaf/`: page layout of the Madinah mushaf
- `assets/fonts/`: the mushaf font
- `tool/`: scripts that build the bundled data

## Data sources

`assets/quran/hafs_uthmani.json` is the Uthmani (Hafs) text taken from
[risan/quran-json](https://github.com/risan/quran-json) (CC BY-SA 4.0,
see `assets/quran/LICENSE-quran-json.txt`), which takes it from
[The Noble Qur'an Encyclopedia](https://quranenc.com).
We changed seven ayat (2:72, 11:41, 15:7, 27:20, 36:22, 37:164, 41:47) to
match Quran.com's QPC Hafs text: a sukun on the hamza of فَٱدَّٰرَٰءۡتُمۡ,
the imala sign of مَجۡر۪ىٰهَا, and five words that the mushaf prints apart
(such as مَا لِيَ). `tool/compare_with_quran_com.py` compares all 6236
ayat with Quran.com's text again.

`assets/mushaf/layout.json`, the 15-line page layout, is built by
`tool/build_mushaf_data.py` from the layout of the
[Quranic Universal Library](https://qul.tarteel.ai), as packaged in
[quran_library](https://pub.dev/packages/quran_library) (MIT), with the
words of `hafs_uthmani.json`.

The pages are drawn with the DigitalKhatt New Madina font
(`assets/fonts/madina.otf`, by Amine Anane and Tarteel, under the SIL Open
Font License 1.1, see `assets/fonts/LICENSE-madina.txt`). The tajweed
colours are worked out by the app from the text (`lib/data/tajweed.dart`).

The study panel reads books kept in the app, without internet: al-Jami'
al-Wajiz (CC BY-ND 4.0), the classical tafsir of al-Jalalayn from
[spa5k/tafsir_api](https://github.com/spa5k/tafsir_api), and Pickthall's
English translation (1930) from
[fawazahmed0/quran-api](https://github.com/fawazahmed0/quran-api). The app's
"Sources and rights" page names every source.
