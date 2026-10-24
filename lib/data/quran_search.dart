import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'arabic_search.dart';
import 'mushaf_models.dart';
import 'quran_models.dart';
import 'quran_repository.dart';

/// What the search looks in: the words of the ayat, or their meaning as
/// told by Tafsir al-Jalalayn (Arabic) or Pickthall's translation (Latin
/// letters).
enum SearchMode { text, meaning }

/// Where a hit was found.
enum HitSource { ayah, tafsir, translation }

/// The choices the user can make beside the search box.
@immutable
class SearchOptions {
  const SearchOptions({
    this.mode = SearchMode.text,
    this.wholeWord = false,
    this.anyOrder = false,
    this.withTafsir = false,
  });

  final SearchMode mode;

  /// The words must stand alone, not be part of longer words.
  final bool wholeWord;

  /// The words of the phrase may come apart and in any order.
  final bool anyOrder;

  /// In text mode, also find ayat whose tafsir has the words.
  final bool withTafsir;

  /// Some option is on (tafsir counts only where it can be chosen).
  bool get changed =>
      wholeWord || anyOrder || (mode == SearchMode.text && withTafsir);

  SearchOptions copyWith({
    SearchMode? mode,
    bool? wholeWord,
    bool? anyOrder,
    bool? withTafsir,
  }) => SearchOptions(
    mode: mode ?? this.mode,
    wholeWord: wholeWord ?? this.wholeWord,
    anyOrder: anyOrder ?? this.anyOrder,
    withTafsir: withTafsir ?? this.withTafsir,
  );

  /// The same mode with every option off.
  SearchOptions reset() => SearchOptions(mode: mode);
}

/// What the user typed, ready for matching.
class SearchQuery {
  SearchQuery(String input, SearchOptions options)
    : wholeWord = options.wholeWord,
      terms = _terms(normalizeForSearch(input), options.anyOrder);

  final List<String> terms;
  final bool wholeWord;

  static List<String> _terms(String q, bool anyOrder) {
    if (q.isEmpty) return const [];
    if (!anyOrder) return [q];
    return q.split(' ').toSet().toList();
  }

  /// Too short to search for.
  bool get isEmpty => terms.join().length < 2;

  /// Whether the query is written in Latin letters.
  bool get isLatin => RegExp('[a-z]').hasMatch(terms.join());

  /// Where every term is found in [text], or null when one is missing.
  List<(int, int)>? match(String text) {
    final found = <(int, int)>[];
    for (final term in terms) {
      final before = found.length;
      var at = text.indexOf(term);
      while (at >= 0) {
        final end = at + term.length;
        if (!wholeWord || (_edge(text, at - 1) && _edge(text, end))) {
          found.add((at, end));
        }
        at = text.indexOf(term, at + 1);
      }
      if (found.length == before) return null;
    }
    found.sort((a, b) => a.$1 - b.$1);
    return found;
  }

  static final _letter = RegExp(r'[\p{L}\p{N}]', unicode: true);

  static bool _edge(String text, int i) =>
      i < 0 || i >= text.length || !_letter.hasMatch(text[i]);
}

/// One ayah found, with the text it was found in and where.
class SearchHit {
  const SearchHit(this.ayah, this.source, this.text, this.ranges);

  final AyahRef ayah;
  final HitSource source;

  /// The ayah, or its tafsir or translation.
  final String text;

  /// The matches in [text].
  final List<(int, int)> ranges;
}

/// Every ayah, and the books searched for meaning, ready for matching.
class QuranSearchIndex {
  QuranSearchIndex(this.surahs, {required this.tafsir, required this.english})
    : _ayat = [
        for (final s in surahs)
          for (final a in s.ayahs) NormalizedText(a),
      ],
      _refs = [
        for (final s in surahs)
          for (var a = 1; a <= s.ayahCount; a++) AyahRef(s.number, a),
      ];

  final List<Surah> surahs;
  final List<NormalizedText> _ayat;
  final List<AyahRef> _refs;

  /// Tafsir al-Jalalayn, one text per ayah ('' when it explains the ayah
  /// with the one before).
  final List<NormalizedText> tafsir;

  /// Pickthall's translation, one text per ayah.
  final List<NormalizedText> english;

  /// The ayat matching [input], in the order of the mushaf.
  List<SearchHit> search(String input, SearchOptions options) {
    final query = SearchQuery(input, options);
    if (query.isEmpty) return const [];
    final hits = <SearchHit>[];
    for (var i = 0; i < _refs.length; i++) {
      final hit = switch (options.mode) {
        SearchMode.text =>
          _hit(query, i, _ayat, HitSource.ayah) ??
              (options.withTafsir
                  ? _hit(query, i, tafsir, HitSource.tafsir)
                  : null),
        SearchMode.meaning =>
          query.isLatin
              ? _hit(query, i, english, HitSource.translation)
              : _hit(query, i, tafsir, HitSource.tafsir),
      };
      if (hit != null) hits.add(hit);
    }
    return hits;
  }

  SearchHit? _hit(
    SearchQuery query,
    int i,
    List<NormalizedText> texts,
    HitSource source,
  ) {
    if (i >= texts.length) return null;
    final text = texts[i];
    final found = query.match(text.text);
    if (found == null) return null;
    return SearchHit(_refs[i], source, text.original, [
      for (final (a, b) in found) text.originalRange(a, b),
    ]);
  }
}

const jalalaynAssetPath = 'assets/search/jalalayn.json.gz';
const pickthallAssetPath = 'assets/search/pickthall.json.gz';

/// A bundled book: a gzipped list of surahs, each a list of ayah texts.
List<NormalizedText> readBook(Uint8List gzipped) {
  final json = utf8.decode(const GZipDecoder().decodeBytes(gzipped));
  return [
    for (final surah in jsonDecode(json) as List)
      for (final ayah in surah as List) NormalizedText(ayah as String),
  ];
}

Future<List<NormalizedText>> _loadBook(String path) async {
  final data = await rootBundle.load(path);
  return compute(readBook, data.buffer.asUint8List());
}

/// The search index, made the first time the search screen opens.
final quranSearchProvider = FutureProvider<QuranSearchIndex>((ref) async {
  final surahs = await ref.watch(surahsProvider.future);
  final (tafsir, english) = await (
    _loadBook(jalalaynAssetPath),
    _loadBook(pickthallAssetPath),
  ).wait;
  return QuranSearchIndex(surahs, tafsir: tafsir, english: english);
});
