import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/arabic_search.dart';
import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/quran_models.dart';
import '../../data/quran_repository.dart';
import '../../data/study.dart';
import '../../l10n/strings.dart';

/// The four parts of the study panel, from the widest to the narrowest.
enum StudyPart { surah, page, ayah, word }

/// One tab of the study panel. A tab with more than one book lets the
/// reader choose the book.
enum StudyTab {
  stats(StudyPart.surah, []),
  translations(StudyPart.page, [StudyBook.english]),
  // The tafsir comes first, so an ayah opens on it.
  tafsir(StudyPart.ayah, [StudyBook.jamiWajiz]),
  mukhtasar(StudyPart.ayah, [StudyBook.jalalayn]),
  tajweed(StudyPart.ayah, []),
  translation(StudyPart.ayah, [StudyBook.english]),
  // Al-Jalalayn explains the ayah word by word.
  wordMeaning(StudyPart.word, [StudyBook.jalalayn]),
  wordTajweed(StudyPart.word, []);

  const StudyTab(this.part, this.books);

  final StudyPart part;
  final List<StudyBook> books;

  static List<StudyTab> of(StudyPart part) =>
      values.where((t) => t.part == part).toList();

  String label(S t) => switch (this) {
    stats => t.surahStats,
    translations => t.translations,
    mukhtasar => t.mukhtasar,
    tafsir => t.tafsir,
    translation => t.translation,
    wordMeaning => t.meaning,
    tajweed || wordTajweed => t.tajweedTab,
  };

  /// Tabs drawn from the app's own data, which need no book.
  bool get isTajweed => this == tajweed || this == wordTajweed;
}

/// What the panel or the word card shows: a tab, the book chosen in it, the
/// ayah and, for the word tabs, the word's position in the ayah.
typedef StudyRequest = ({
  StudyTab tab,
  StudyBook? book,
  AyahRef ayah,
  int word,
});

/// A piece of what is shown: an optional heading, e.g. the ayah or word it
/// is about, and its text.
class StudySection {
  const StudySection(this.text, {this.heading, this.quran = false});

  final String? heading;
  final String text;

  /// The text is Quran, shown in the Quran's colour.
  final bool quran;

  @override
  String toString() => heading == null ? text : '$heading\n$text';
}

/// The sections for [StudyRequest]. Empty when the book says nothing; the
/// screen then says so.
final studyContentProvider =
    FutureProvider.family<List<StudySection>, StudyRequest>((ref, r) async {
      final surahs = await ref.watch(surahsProvider.future);
      final repo = ref.watch(studyRepositoryProvider);
      final surah = surahs[r.ayah.surah - 1];
      final ayahText = surah.ayahs[r.ayah.ayah - 1];
      final books = r.book == null ? r.tab.books : [r.book!];

      Future<List<StudySection>> onWord() async {
        final found = <StudySection>[];
        for (final book in books) {
          final raw = await repo.text(book, r.ayah);
          final text = book.splitAtQuotes ? splitAtQuotes(raw) : raw;
          for (final p in paragraphsOnWord(text, ayahText, r.word)) {
            found.add(StudySection(p));
          }
          // The first book that speaks of the word is enough.
          if (found.isNotEmpty) break;
        }
        return found;
      }

      switch (r.tab) {
        case StudyTab.stats:
          return [];
        case StudyTab.translations:
          final mushaf = await ref.watch(mushafProvider.future);
          final ayat = {
            for (final w in mushaf.page(mushaf.pageOf(r.ayah)).words) w.ayah,
          }.toList();
          final texts = await Future.wait([
            for (final a in ayat) repo.text(StudyBook.english, a),
          ]);
          return [
            for (var i = 0; i < ayat.length; i++)
              if (texts[i].isNotEmpty)
                StudySection(
                  texts[i],
                  heading:
                      '[${surahs[ayat[i].surah - 1].transliteration} - '
                      '${ayat[i].ayah}]',
                ),
          ];
        case StudyTab.tajweed || StudyTab.wordTajweed:
          // Shown by TajweedView from the bundled rules.
          return [];
        case StudyTab.wordMeaning:
          return onWord();
        default:
          final text = await repo.text(books.first, r.ayah);
          return text.isEmpty ? [] : [StudySection(text)];
      }
    });

/// Counts shown under the surah's statistics, as label and value.
List<(String, String)> surahStats(S t, Surah surah, Mushaf mushaf) {
  final words = surah.ayahs.fold(0, (n, a) => n + ayahWords(a).length);
  final letters = surah.ayahs.fold(
    0,
    (n, a) => n + normalizeForSearch(a).replaceAll(' ', '').length,
  );
  final first = AyahRef(surah.number, 1);
  final last = AyahRef(surah.number, surah.ayahCount);
  final firstPage = mushaf.pageOf(first);
  final lastPage = mushaf.pageOf(last);
  return [
    (t.statRevelation, surah.isMeccan ? t.meccan : t.medinan),
    (t.statOrder, t.n(surah.number)),
    (t.statAyat, t.n(surah.ayahCount)),
    (t.statWords, t.n(words)),
    (t.statLetters, t.n(letters)),
    (t.statPages, t.range(firstPage, lastPage)),
    (t.statJuz, t.range(mushaf.juzOfPage(firstPage), mushaf.juzOfAyah(last))),
  ];
}
