import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/quran_repository.dart';

import 'dart:io';

import 'package:hifz/data/study.dart';
import 'package:hifz/features/study/study_content.dart';
import 'package:hifz/data/tajweed.dart';

// Al-Ma'idah 18, as in the bundled mushaf text.
const _ayah =
    'وَقَالَتِ ٱلۡيَهُودُ وَٱلنَّصَٰرَىٰ نَحۡنُ أَبۡنَـٰٓؤُاْ ٱللَّهِ '
    'وَأَحِبَّـٰٓؤُهُۥۚ قُلۡ فَلِمَ يُعَذِّبُكُم بِذُنُوبِكُمۖ بَلۡ أَنتُم '
    'بَشَرٞ مِّمَّنۡ خَلَقَۚ يَغۡفِرُ لِمَن يَشَآءُ وَيُعَذِّبُ مَن '
    'يَشَآءُۚ وَلِلَّهِ مُلۡكُ ٱلسَّمَٰوَٰتِ وَٱلۡأَرۡضِ وَمَا بَيۡنَهُمَاۖ '
    'وَإِلَيۡهِ ٱلۡمَصِيرُ';

// From al-Jalalayn on the same ayah: one paragraph, piece by piece.
const _jalalayn =
    '﴿وقالَتْ اليَهُود والنَّصارى﴾ أيْ كُلّ مِنهُما ﴿نَحْنُ أبْناء اللَّه '
    'وأَحِبّاؤُهُ﴾ أيْ كَأَبْنائِهِ فِي القُرْب ﴿قُلْ﴾ لَهُمْ يا مُحَمَّد '
    '﴿بَلْ أنْتُمْ بَشَر مِمَّنْ﴾ مِن جُمْلَة مَن ﴿خَلَقَ﴾ مِن البَشَر '
    '﴿يَغْفِر لِمَن يَشاء﴾ المَغْفِرَة لَهُ ﴿ويُعَذِّب مَن يَشاء﴾ تَعْذِيبه '
    '﴿ولِلَّهِ مُلْك السَّماوات والأَرْض وما بَيْنهما وإلَيْهِ المَصِير﴾ '
    'المَرْجِع';

// From ad-Durr al-Masun on the same ayah, which quotes in { }.
const _samin =
    'قوله تعالى: {فَلِمَ} : هذه الفاءُ جوابُ شرط مقدر. '
    'والباء في «بذنوبكم» سببية.';

void main() {
  test('words are split as on the printed page', () {
    expect(ayahWords(_ayah), hasLength(30));
    expect(wordAt(_ayah, 29), 'وَإِلَيۡهِ');
    expect(wordAt(_ayah, 99), 'ٱلۡمَصِيرُ');
  });

  test('finds what a book says on a word, across spellings', () {
    final jalalayn = splitAtQuotes(_jalalayn);
    expect(paragraphsOnWord(jalalayn, _ayah, 1).single, contains('كُلّ'));
    expect(paragraphsOnWord(jalalayn, _ayah, 4).single, contains('القُرْب'));
    expect(paragraphsOnWord(jalalayn, _ayah, 16).single, contains('البَشَر'));
    expect(paragraphsOnWord(jalalayn, _ayah, 30).single, contains('المَرْجِع'));
    expect(paragraphsOnWord(jalalayn, _ayah, 9), isEmpty);
  });

  test('a repeated word gets its own occurrence first', () {
    final jalalayn = splitAtQuotes(_jalalayn);
    expect(
      paragraphsOnWord(jalalayn, _ayah, 19).first,
      contains('المَغْفِرَة'),
    );
    expect(paragraphsOnWord(jalalayn, _ayah, 22).first, contains('تَعْذِيبه'));
  });

  test('a word quoted in braces keeps the words that lead its quote', () {
    final samin = paragraphsOnWord(splitAtQuotes(_samin), _ayah, 9).single;
    expect(samin, startsWith('قوله تعالى: {فَلِمَ}'));
    expect(samin, contains('جوابُ شرط'));
  });

  test('repeated texts of grouped ayat are kept once', () {
    expect(distinctTexts(['a', 'a', '', 'b', 'a ']), ['a', 'b']);
  });

  test('al-Jami\' al-Wajiz is in the app, on every ayah', () {
    final book = readBundledBook(File(jamiWajizAssetPath).readAsBytesSync());
    final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
    expect(
      [for (final s in book) s.length],
      [for (final s in surahs) s.ayahCount],
    );
    expect(book.expand((s) => s).where((t) => t.trim().isEmpty), isEmpty);
  });

  test('an ayah opens on the tafsir, the book kept in the app first', () {
    expect(StudyTab.of(StudyPart.ayah).first, StudyTab.tafsir);
    expect(StudyTab.tafsir.books.first, StudyBook.jamiWajiz);
    expect(StudyBook.jamiWajiz.asset, isNotNull);
  });

  group('tajweed', () {
    final map = TajweedMap(
      parseSurahs(File(quranAssetPath).readAsStringSync()),
    );

    test('names the rules on the words of an ayah', () {
      // Al-Fatiha 7: ad-dallin carries the necessary madd.
      expect(
        map.ofAyah(const AyahRef(1, 7))[9],
        contains(TajweedRule.maddLazim),
      );
      // Al-Baqarah 4: bima unzila, the obligatory madd and an ikhfa.
      final baqarah4 = map.ofAyah(const AyahRef(2, 4));
      expect(baqarah4[3], {TajweedRule.maddWajib});
      expect(baqarah4[4], {TajweedRule.ghunna});
      expect(baqarah4[9], {TajweedRule.tafkhim, TajweedRule.qalqala});
    });

    test('marks the letters that take each rule', () {
      // Ad-dallin: the silent hamzat wasl and lam, the heavy dad, the madd
      // on the alif with its madda, and the madd at the stop.
      expect(map.spansOf(const AyahRef(1, 7))[8], [
        (start: 0, end: 1, rule: TajweedRule.silent),
        (start: 1, end: 2, rule: TajweedRule.silent),
        (start: 2, end: 5, rule: TajweedRule.tafkhim),
        (start: 5, end: 7, rule: TajweedRule.maddLazim),
        (start: 10, end: 11, rule: TajweedRule.maddJaiz),
      ]);
    });

    test('reads the lam of the name of Allah heavy after a or u', () {
      bool heavy(AyahRef ayah, int word) =>
          map.ofAyah(ayah)[word]?.contains(TajweedRule.tafkhim) ?? false;
      expect(heavy(const AyahRef(1, 1), 2), isFalse); // bismi llahi
      expect(heavy(const AyahRef(2, 7), 2), isTrue); // khatama llahu
      expect(heavy(const AyahRef(112, 2), 1), isTrue); // allahu s-samad
    });
  });
}
