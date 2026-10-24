import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'arabic_search.dart';
import 'mushaf_models.dart';
import 'study_cache.dart';

/// The books the study panel reads from: tafsir, qira'at, word analysis,
/// i'rab, rare words, reflections and a translation.
///
/// They come per ayah from the open tafsir_api collection on GitHub
/// (github.com/spa5k/tafsir_api) and the quran-api translations
/// (github.com/fawazahmed0/quran-api), and are kept on the device once read.
enum StudyBook {
  mukhtasar('ar-tafsir-al-mukhtasar'),
  muyassar('ar-tafsir-muyassar'),
  saadi('ar-tafseer-al-saddi'),
  ibnKathir('ar-tafsir-ibn-kathir'),
  baghawi('ar-tafsir-al-baghawi'),
  tabari('ar-tafsir-al-tabari'),
  nashr('al-nashr-li-ibn-al-jazari'),
  qiraat('al-qira-at-al-mawsoo-ah-al-qur-aniyyah'),
  tasreef('tahlil-kalimat-al-qur-an'),
  irabMuyassar('al-i-rab-al-muyassar'),
  irabJadwal('al-jadwal-fi-i-rab-al-quran'),
  irabDarwish('i-rab-al-quran-li-al-darwish'),
  gharib('al-muyassar-fi-al-gharib'),
  tadabbur('tadabbur-wa-amal'),
  english('eng-ummmuhammad');

  const StudyBook(this.slug);

  final String slug;

  static const tafsirs = [muyassar, saadi, ibnKathir, baghawi, tabari];
  static const qiraatBooks = [nashr, qiraat];
  static const irabBooks = [irabMuyassar, irabJadwal, irabDarwish];

  /// Where the text of [ayah] can be read, mirrors first.
  List<Uri> urls(AyahRef ayah) {
    final (repo, version, folder) = this == english
        ? ('fawazahmed0/quran-api', '1', 'editions')
        : ('spa5k/tafsir_api', 'main', 'tafsir');
    final file = '$folder/$slug/${ayah.surah}/${ayah.ayah}.json';
    return [
      Uri.parse('https://raw.githubusercontent.com/$repo/$version/$file'),
      Uri.parse('https://cdn.jsdelivr.net/gh/$repo@$version/$file'),
    ];
  }
}

/// Fetches study texts and keeps them, in memory and on the device.
class StudyRepository {
  StudyRepository({http.Client? client, StudyCache? cache})
    : _client = client ?? http.Client(),
      _cache = cache ?? StudyCache();

  final http.Client _client;
  final StudyCache _cache;
  final _memory = <String, String>{};

  /// The text [book] gives for [ayah], or '' when the book says nothing on
  /// it. Throws when it cannot be fetched, e.g. without internet.
  Future<String> text(StudyBook book, AyahRef ayah) async {
    final key = '${book.slug}/${ayah.surah}/${ayah.ayah}';
    if (_memory[key] case final text?) return text;
    var text = await _cache.read(key);
    if (text == null) {
      text = await _fetch(book, ayah);
      await _cache.write(key, text);
    }
    return _memory[key] = text;
  }

  Future<String> _fetch(StudyBook book, AyahRef ayah) async {
    Object? error;
    for (final url in book.urls(ayah)) {
      try {
        final response = await _client
            .get(url)
            .timeout(const Duration(seconds: 20));
        // Books skip the ayat they have nothing on.
        if (response.statusCode == 404) return '';
        if (response.statusCode != 200) {
          error = 'HTTP ${response.statusCode}';
          continue;
        }
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        return ((json as Map)['text'] as String? ?? '').trim();
      } catch (e) {
        error = e;
      }
    }
    throw StudyFetchError(error);
  }
}

class StudyFetchError implements Exception {
  StudyFetchError(this.cause);

  final Object? cause;

  @override
  String toString() => 'StudyFetchError: $cause';
}

final studyRepositoryProvider = Provider<StudyRepository>(
  (ref) => StudyRepository(),
);

/// The text of one book on one ayah.
final studyTextProvider = FutureProvider.family<String, (StudyBook, AyahRef)>(
  (ref, key) => ref.watch(studyRepositoryProvider).text(key.$1, key.$2),
);

/// The introduction of a surah, its name and aims, which al-Muyassar puts
/// before the tafsir of its first ayah. Empty when there is none.
String surahIntro(String muyassarFirstAyah) =>
    _splitIntro(muyassarFirstAyah).$1;

/// The tafsir of an ayah without the surah introduction in front of it.
String withoutSurahIntro(String text) => _splitIntro(text).$2;

const _tafsirMark = '[التفسير]';
const _introHeadings = {'تسمية السورة', 'من مقاصد السورة'};

/// The introduction and the tafsir. Most surahs mark where the tafsir
/// starts; otherwise the introduction is its headings and their points.
(String, String) _splitIntro(String text) {
  final i = text.indexOf(_tafsirMark);
  if (i >= 0) {
    return (
      text.substring(0, i).trim(),
      text.substring(i + _tafsirMark.length).trim(),
    );
  }
  final paragraphs = text.split('\n');
  if (paragraphs.first.trim() != _introHeadings.first) return ('', text);
  final end = paragraphs.indexWhere((p) {
    final line = p.trim();
    return line.isNotEmpty &&
        !_introHeadings.contains(line) &&
        !line.startsWith('•');
  });
  if (end < 0) return (text.trim(), '');
  return (
    paragraphs.take(end).join('\n').trim(),
    paragraphs.skip(end).join('\n').trim(),
  );
}

/// The words of [ayahText], split as in the printed mushaf, so that the
/// word at a position on the page is `words[position - 1]`.
List<String> ayahWords(String ayahText) {
  final words = <String>[];
  for (final w in ayahText.split(' ')) {
    if (w.trim().isEmpty) continue;
    // إِلۡ يَاسِينَ (37:130) is printed with a gap but is one word.
    if (words.isNotEmpty && words.last == _il) {
      words.last += ' $w';
    } else {
      words.add(w);
    }
  }
  return words;
}

const _il = '\u0625\u0650\u0644\u06E1';

/// The word at [position] of [ayahText], or '' past its end.
String wordAt(String ayahText, int position) {
  final words = ayahWords(ayahText);
  if (words.isEmpty) return '';
  return words[(position - 1).clamp(0, words.length - 1)];
}

/// Reduces a word to its letters for matching the mushaf spelling with the
/// usual spelling in books: no marks, no alef or hamza, which the two
/// spellings write differently.
String matchKey(String word) =>
    // Some books write the tanween with the extended Arabic marks.
    normalizeForSearch(word.replaceAll(RegExp('[\u08D3-\u08FF]'), ''))
        .replaceAll(RegExp('[اءؤئ ]'), '')
        .replaceAll('ﷺ', '');

final _quoted = RegExp('﴿([^﴾]*)﴾');

/// The paragraphs of [text] that speak about the word at [position] of
/// [ayahText]: those quoting it in ﴿ ﴾, as the books on rare words,
/// qira'at, word analysis and i'rab do. When the word comes more than once
/// in the ayah, the paragraph for its own occurrence comes first.
List<String> paragraphsOnWord(String text, String ayahText, int position) {
  final words = ayahWords(ayahText);
  if (words.isEmpty) return const [];
  final index = (position - 1).clamp(0, words.length - 1);
  final key = matchKey(words[index]);
  if (key.isEmpty) return const [];
  final before = words.take(index).where((w) => matchKey(w) == key).length;
  final found = <String>[];
  for (final paragraph in text.split('\n')) {
    final quotes = [for (final m in _quoted.allMatches(paragraph)) m[1]!];
    if (quotes.isEmpty) continue;
    final joined = matchKey(quotes.join());
    final quotedWords = quotes.expand((q) => q.split(' ')).map(matchKey);
    if (joined == key || quotedWords.contains(key)) {
      found.add(paragraph.trim());
    }
  }
  if (found.length <= 1) return found;
  final own = before.clamp(0, found.length - 1);
  return [found[own], ...found.take(own), ...found.skip(own + 1)];
}

/// Texts that repeat, as books give one text for a group of ayat, kept
/// once and in order.
List<String> distinctTexts(Iterable<String> texts) {
  final seen = <String>{};
  return [
    for (final t in texts)
      if (t.trim().isNotEmpty && seen.add(t.trim())) t.trim(),
  ];
}
