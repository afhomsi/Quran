import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/data/mushaf_models.dart';

import 'dart:io';

import 'package:hifz/data/study.dart';
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

  test('books are read from GitHub and its mirror', () {
    final urls = StudyBook.jalalayn.urls(const AyahRef(5, 18));
    expect(
      urls.first.toString(),
      'https://raw.githubusercontent.com/spa5k/tafsir_api/main/tafsir/'
      'ar-tafsir-al-jalalayn/5/18.json',
    );
    expect(
      urls.last.toString(),
      'https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir/'
      'ar-tafsir-al-jalalayn/5/18.json',
    );
    expect(
      StudyBook.english.urls(const AyahRef(1, 2)).first.toString(),
      'https://raw.githubusercontent.com/fawazahmed0/quran-api/1/editions/'
      'eng-mohammedmarmadu/1/2.json',
    );
  });

  test('names the tajweed rules on the words of an ayah', () {
    final map = parseTajweed(File(tajweedAssetPath).readAsStringSync());
    // Al-Fatiha 7: ad-dallin carries the necessary madd.
    expect(map.ofAyah(const AyahRef(1, 7))[9], contains(TajweedRule.maddLazim));
    // Al-Baqarah 4: bima unzila, the obligatory madd and an ikhfa.
    final baqarah4 = map.ofAyah(const AyahRef(2, 4));
    expect(baqarah4[3], {TajweedRule.maddWajib});
    expect(baqarah4[4], {TajweedRule.ghunna});
    expect(
      baqarah4[9],
      containsAll([TajweedRule.tafkhim, TajweedRule.qalqala]),
    );
  });
}
