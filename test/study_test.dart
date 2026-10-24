import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/study.dart';

// Al-Ma'idah 18, as in the bundled mushaf text.
const _ayah =
    'وَقَالَتِ ٱلۡيَهُودُ وَٱلنَّصَٰرَىٰ نَحۡنُ أَبۡنَـٰٓؤُاْ ٱللَّهِ '
    'وَأَحِبَّـٰٓؤُهُۥۚ قُلۡ فَلِمَ يُعَذِّبُكُم بِذُنُوبِكُمۖ بَلۡ أَنتُم '
    'بَشَرٞ مِّمَّنۡ خَلَقَۚ يَغۡفِرُ لِمَن يَشَآءُ وَيُعَذِّبُ مَن '
    'يَشَآءُۚ وَلِلَّهِ مُلۡكُ ٱلسَّمَٰوَٰتِ وَٱلۡأَرۡضِ وَمَا بَيۡنَهُمَاۖ '
    'وَإِلَيۡهِ ٱلۡمَصِيرُ';

// From "Tahlil Kalimat al-Qur'an" on the same ayah.
const _tasreef =
    '• ﴿وَ﴾ حرف عطف، ﴿قَالَتِ﴾ فعل ماض ثلاثي مجرد، من مادّة قول.\n\n'
    '• ﴿ٱلْ﴾، ﴿يَهُودُ﴾ علم، من مادّة هود، مذكر، جمع.\n\n'
    '• ﴿وَ﴾ حرف عطف، ﴿ٱل﴾، ﴿نَّصَٰرَىٰ﴾ علم، من مادّة نصر، جمع.\n\n'
    '• ﴿وَ﴾ حرف عطف، ﴿أَحِبَّٰٓؤُ﴾ اسم، من مادّة حبب، ﴿هُۥ﴾ ضمير.\n\n'
    '• ﴿يَشَآءُ﴾ فعل مضارع، الأول.\n\n'
    '• ﴿يَشَآءُ﴾ فعل مضارع، الثاني.';

// From "Al-Muyassar fil-Gharib" on the same ayah.
const _gharib =
    '﴿نَحۡنُ أَبۡنَـٰٓؤُاْ ٱللَّهِ﴾: فقالت اليهودُ: عزيرٌ ابنُ اللهِ.\n\n'
    '﴿أَنتُم بَشَرࣱ﴾: أنتم خَلْقٌ مثلُ سائرِ بني آدمَ.\n\n'
    '﴿ٱلۡمَصِيرُ﴾: المَرْجِعُ.';

void main() {
  test('words are split as on the printed page', () {
    expect(ayahWords(_ayah), hasLength(30));
    expect(wordAt(_ayah, 29), 'وَإِلَيۡهِ');
    expect(wordAt(_ayah, 99), 'ٱلۡمَصِيرُ');
  });

  test('finds what a book says on a word, across spellings', () {
    expect(paragraphsOnWord(_tasreef, _ayah, 2).single, contains('هود'));
    expect(paragraphsOnWord(_tasreef, _ayah, 3).single, contains('نصر'));
    expect(paragraphsOnWord(_tasreef, _ayah, 7).single, contains('حبب'));
    expect(paragraphsOnWord(_gharib, _ayah, 14).single, contains('خَلْقٌ'));
    expect(paragraphsOnWord(_gharib, _ayah, 30).single, contains('المَرْجِعُ'));
    expect(paragraphsOnWord(_gharib, _ayah, 1), isEmpty);
  });

  test('a repeated word gets its own occurrence first', () {
    expect(paragraphsOnWord(_tasreef, _ayah, 19).first, contains('الأول'));
    expect(paragraphsOnWord(_tasreef, _ayah, 22).first, contains('الثاني'));
  });

  test('the surah introduction is kept apart from the tafsir', () {
    const text =
        'تسمية السورة\n\n• سميت المائدة.\n\nمن مقاصد السورة\n\n• بيان.\n\n'
        '[التفسير]\n\nيا أيها الذين آمنوا.';
    expect(surahIntro(text), startsWith('تسمية السورة'));
    expect(surahIntro(text), isNot(contains('يا أيها')));
    expect(withoutSurahIntro(text), 'يا أيها الذين آمنوا.');
    expect(surahIntro('يا أيها'), isEmpty);
    // Al-Ma'idah has no mark before its tafsir.
    const unmarked =
        'تسمية السورة\n\n• سميت المائدة.\n\nمن مقاصد السورة\n\n• بيان.\n\n'
        'يا أيها الذين صدقوا.';
    expect(surahIntro(unmarked), endsWith('• بيان.'));
    expect(withoutSurahIntro(unmarked), 'يا أيها الذين صدقوا.');
    expect(withoutSurahIntro('يا أيها'), 'يا أيها');
  });

  test('repeated texts of grouped ayat are kept once', () {
    expect(distinctTexts(['a', 'a', '', 'b', 'a ']), ['a', 'b']);
  });

  test('books are read from GitHub and its mirror', () {
    final urls = StudyBook.mukhtasar.urls(const AyahRef(5, 18));
    expect(
      urls.first.toString(),
      'https://raw.githubusercontent.com/spa5k/tafsir_api/main/tafsir/'
      'ar-tafsir-al-mukhtasar/5/18.json',
    );
    expect(
      urls.last.toString(),
      'https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir/'
      'ar-tafsir-al-mukhtasar/5/18.json',
    );
    expect(
      StudyBook.english.urls(const AyahRef(1, 2)).first.toString(),
      'https://raw.githubusercontent.com/fawazahmed0/quran-api/1/editions/'
      'eng-ummmuhammad/1/2.json',
    );
  });
}
