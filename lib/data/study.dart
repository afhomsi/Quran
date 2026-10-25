import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'arabic_search.dart';
import 'mushaf_models.dart';
import 'study_cache.dart';

/// The books the study panel reads from: tafsir, qira'at, i'rab and a
/// translation. Only open books are used: classical works, whose authors
/// died long ago, Pickthall's English translation (1930), and al-Jami'
/// al-Wajiz, whose author shares it under CC BY-ND 4.0.
///
/// The books with an [asset] are kept in the app and read without
/// internet. The others come per ayah from the open tafsir_api collection
/// on GitHub (github.com/spa5k/tafsir_api) and the quran-api translations
/// (github.com/fawazahmed0/quran-api), and are kept on the device once read.
enum StudyBook {
  jamiWajiz('ar-tafsir-al-jami-al-wajiz', asset: jamiWajizAssetPath),
  jalalayn(
    'ar-tafsir-al-jalalayn',
    splitAtQuotes: true,
    asset: 'assets/search/jalalayn.json.gz',
  ),
  saadi('ar-tafseer-al-saddi'),
  ibnKathir('ar-tafsir-ibn-kathir'),
  baghawi('ar-tafsir-al-baghawi'),
  tabari('ar-tafsir-al-tabari'),
  nashr('al-nashr-li-ibn-al-jazari'),
  samin('al-dur-al-masun-lil-samin-al-halabi', splitAtQuotes: true),
  english('eng-mohammedmarmadu', asset: 'assets/search/pickthall.json.gz');

  const StudyBook(this.slug, {this.splitAtQuotes = false, this.asset});

  final String slug;

  /// The book's file in the app, a gzipped list of surahs, each a list of
  /// ayah texts; null when it is read from the internet.
  final String? asset;

  /// The book explains the ayah piece by piece in one paragraph, each piece
  /// after the words it quotes, so a word's part starts at its quote.
  final bool splitAtQuotes;

  /// The tafsir tab's books, the one kept in the app first.
  static const tafsirs = [jamiWajiz, saadi, ibnKathir, baghawi, tabari];

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

/// The largest answer read for one ayah of one book, in bytes.
const maxStudyResponseBytes = 2 * 1024 * 1024;

const jamiWajizAssetPath = 'assets/tafsir/jami_wajiz.json.gz';

/// A book kept in the app: its gzipped list of surahs, each a list of ayah
/// texts.
List<List<String>> readBundledBook(Uint8List gzipped) {
  final json = utf8.decode(const GZipDecoder().decodeBytes(gzipped));
  return [
    for (final surah in jsonDecode(json) as List)
      [for (final ayah in surah as List) ayah as String],
  ];
}

Future<List<List<String>>> _loadBook(String path) async {
  final data = await rootBundle.load(path);
  return compute(readBundledBook, data.buffer.asUint8List());
}

/// Fetches study texts and keeps them, in memory and on the device.
class StudyRepository {
  StudyRepository({
    http.Client? client,
    StudyCache? cache,
    Future<List<List<String>>> Function(String asset)? loadBook,
  }) : _client = client ?? http.Client(),
       _cache = cache ?? StudyCache(),
       _load = loadBook ?? _loadBook;

  final http.Client _client;
  final StudyCache _cache;
  final Future<List<List<String>>> Function(String asset) _load;
  final _memory = <String, String>{};
  final _bundled = <String, Future<List<List<String>>>>{};

  /// The text [book] gives for [ayah], or '' when the book says nothing on
  /// it. Throws when it cannot be fetched, e.g. without internet.
  Future<String> text(StudyBook book, AyahRef ayah) async {
    if (book.asset case final asset?) {
      final surahs = await (_bundled[asset] ??= _load(asset));
      if (ayah.surah < 1 || ayah.surah > surahs.length) return '';
      final ayat = surahs[ayah.surah - 1];
      if (ayah.ayah < 1 || ayah.ayah > ayat.length) return '';
      return ayat[ayah.ayah - 1].trim();
    }
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
        // The longest tafsir of one ayah is well under this; a bigger
        // answer is not the book's and is not kept on the device.
        if (response.bodyBytes.length > maxStudyResponseBytes) {
          error = 'Too large';
          continue;
        }
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        if (json is! Map) {
          error = 'Not a study text';
          continue;
        }
        final text = json['text'] ?? '';
        if (text is! String) {
          error = 'Not a study text';
          continue;
        }
        return text.trim();
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
    normalizeForSearch(
      word
          .replaceAll(RegExp('[\u08D3-\u08FF]'), '')
          // The mushaf's صلوٰة is صلاة in books.
          .replaceAll('\u0648\u0670', '\u0627'),
    ).replaceAll(RegExp('[اءؤئ ]'), '').replaceAll('ﷺ', '');

final _quoted = RegExp('﴿([^﴾]*)﴾|\\{([^}]*)\\}');

/// The paragraphs of [text] that speak about the word at [position] of
/// [ayahText]: those quoting it in ﴿ ﴾ or { }, as the books on qira'at and
/// i'rab do. When the word comes more than once
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
    final quotes = [
      for (final m in _quoted.allMatches(paragraph)) m[1] ?? m[2]!,
    ];
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

/// [text] with each quoted piece of the ayah on a line of its own, for the
/// books that explain an ayah piece by piece in one paragraph.
String splitAtQuotes(String text) =>
    text.replaceAllMapped(_pieceStart, (m) => '\n${m[1]}').trim();

// A quote, with the «قوله تعالى:» that may lead it.
final _pieceStart = RegExp(r'\s*((?:و?قوله(?: تعالى)?\s*:?\s*)?[﴿{])');

/// Texts that repeat, as books give one text for a group of ayat, kept
/// once and in order.
List<String> distinctTexts(Iterable<String> texts) {
  final seen = <String>{};
  return [
    for (final t in texts)
      if (t.trim().isNotEmpty && seen.add(t.trim())) t.trim(),
  ];
}
