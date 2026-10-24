import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/arabic_search.dart';
import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/quran_models.dart';
import '../../data/quran_repository.dart';
import '../../data/study.dart';
import '../../data/tajweed.dart';
import '../../l10n/strings.dart';

/// The four parts of the study panel, from the widest to the narrowest.
enum StudyPart { surah, page, ayah, word }

/// One tab of the study panel. A tab with more than one book lets the
/// reader choose the book.
enum StudyTab {
  naming(StudyPart.surah, [StudyBook.muyassar]),
  stats(StudyPart.surah, []),
  benefits(StudyPart.page, [StudyBook.tadabbur]),
  translations(StudyPart.page, [StudyBook.english]),
  mukhtasar(StudyPart.ayah, [StudyBook.mukhtasar]),
  tafsir(StudyPart.ayah, StudyBook.tafsirs),
  tajweed(StudyPart.ayah, []),
  qiraat(StudyPart.ayah, StudyBook.qiraatBooks),
  tasreef(StudyPart.ayah, [StudyBook.tasreef]),
  irab(StudyPart.ayah, StudyBook.irabBooks),
  tadabbur(StudyPart.ayah, [StudyBook.tadabbur]),
  translation(StudyPart.ayah, [StudyBook.english]),
  // Common words are not in the book of rare words; their analysis says
  // what they are.
  wordMeaning(StudyPart.word, [StudyBook.gharib, StudyBook.tasreef]),
  wordTajweed(StudyPart.word, []),
  wordQiraat(StudyPart.word, StudyBook.qiraatBooks),
  wordTasreef(StudyPart.word, [StudyBook.tasreef]),
  wordIrab(StudyPart.word, [StudyBook.irabMuyassar]),
  // Quran.com's word-by-word English, bundled with the app.
  wordTranslation(StudyPart.word, []);

  const StudyTab(this.part, this.books);

  final StudyPart part;
  final List<StudyBook> books;

  static List<StudyTab> of(StudyPart part) =>
      values.where((t) => t.part == part).toList();

  String label(S t) => switch (this) {
    naming => t.surahNaming,
    stats => t.surahStats,
    benefits => t.benefits,
    translations => t.translations,
    mukhtasar => t.mukhtasar,
    tafsir => t.tafsir,
    qiraat || wordQiraat => t.qiraat,
    tasreef || wordTasreef => t.tasreef,
    irab => t.irabAyah,
    wordIrab => t.irab,
    tadabbur => t.tadabbur,
    translation || wordTranslation => t.translation,
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
          final text = await repo.text(book, r.ayah);
          for (final p in paragraphsOnWord(text, ayahText, r.word)) {
            found.add(StudySection(p));
          }
          // The first book that speaks of the word is enough.
          if (found.isNotEmpty) break;
        }
        return found;
      }

      switch (r.tab) {
        case StudyTab.naming:
          final text = await repo.text(
            StudyBook.muyassar,
            AyahRef(r.ayah.surah, 1),
          );
          final intro = surahIntro(text);
          return intro.isEmpty ? [] : [StudySection(intro)];
        case StudyTab.stats:
          return [];
        case StudyTab.benefits || StudyTab.translations:
          final mushaf = await ref.watch(mushafProvider.future);
          final ayat = {
            for (final w in mushaf.page(mushaf.pageOf(r.ayah)).words) w.ayah,
          }.toList();
          final book = r.tab.books.single;
          final texts = await Future.wait([
            for (final a in ayat) repo.text(book, a),
          ]);
          if (book == StudyBook.english) {
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
          }
          return [for (final t in distinctTexts(texts)) StudySection(t)];
        case StudyTab.wordTranslation:
          final meanings = await ref.watch(wordMeaningsProvider.future);
          final text = meanings.of(r.ayah, r.word);
          return text.isEmpty ? [] : [StudySection(text)];
        case StudyTab.tajweed || StudyTab.wordTajweed:
          // Shown by TajweedView from the bundled rules.
          return [];
        case StudyTab.wordMeaning ||
            StudyTab.wordQiraat ||
            StudyTab.wordTasreef ||
            StudyTab.wordIrab:
          return onWord();
        case StudyTab.qiraat when r.book == null:
          // Both books, as each covers ayat the other leaves out.
          final texts = await Future.wait([
            for (final b in books) repo.text(b, r.ayah),
          ]);
          return [for (final t in distinctTexts(texts)) StudySection(t)];
        default:
          final text = await repo.text(books.first, r.ayah);
          final clean = r.ayah.ayah == 1 ? withoutSurahIntro(text) : text;
          return clean.isEmpty ? [] : [StudySection(clean)];
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
