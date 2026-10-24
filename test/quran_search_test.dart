import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/data/arabic_search.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/quran_search.dart';
import 'package:hifz/features/search/search_screen.dart';

/// The search index from the bundled files.
QuranSearchIndex loadSearchIndex() => QuranSearchIndex(
  parseSurahs(File(quranAssetPath).readAsStringSync()),
  tafsir: readBook(File(jalalaynAssetPath).readAsBytesSync()),
  english: readBook(File(pickthallAssetPath).readAsBytesSync()),
);

void main() {
  final index = loadSearchIndex();
  List<AyahRef> find(String q, [SearchOptions o = const SearchOptions()]) => [
    for (final h in index.search(q, o)) h.ayah,
  ];

  test('the books have one text for every ayah', () {
    expect(index.tafsir, hasLength(6236));
    expect(index.english, hasLength(6236));
  });

  test('keeps track of the original text', () {
    final n = NormalizedText('ٱلصَّلَوٰةَ  وَ-ءَاتُواْ');
    expect(n.text, 'الصلاه و ءاتوا');
    final (a, b) = n.originalRange(0, 6);
    expect(n.original.substring(a, b), 'ٱلصَّلَوٰةَ');
  });

  test('finds a phrase as typed, without diacritics', () {
    expect(find('اصحب الكهف'), contains(const AyahRef(18, 9)));
    expect(find('أقيموا الصلاة'), isNotEmpty);
    expect(find('ا'), isEmpty);
  });

  test('a whole word is not found inside longer words', () {
    final part = find('رحم');
    final whole = find('رحم', const SearchOptions(wholeWord: true));
    expect(part.length, greaterThan(whole.length));
    expect(part, contains(const AyahRef(1, 1)));
    expect(whole, isNot(contains(const AyahRef(1, 1))));
  });

  test('words apart may come in any order', () {
    const apart = SearchOptions(anyOrder: true);
    expect(find('الكهف اصحب'), isEmpty);
    expect(find('الكهف اصحب', apart), contains(const AyahRef(18, 9)));
  });

  test('with tafsir also finds ayat by their explanation', () {
    final hits = index.search(
      'لا معبود بحق',
      const SearchOptions(withTafsir: true),
    );
    expect(hits.map((h) => h.ayah), contains(const AyahRef(2, 255)));
    expect(hits.first.source, HitSource.tafsir);
    expect(find('لا معبود بحق'), isEmpty);
  });

  test('searches the meaning in Arabic and in English', () {
    const meaning = SearchOptions(mode: SearchMode.meaning);
    final arabic = index.search('لا معبود بحق', meaning);
    expect(arabic.first.source, HitSource.tafsir);
    final english = index.search('neither slumber nor sleep', meaning);
    expect(english.map((h) => h.ayah), [const AyahRef(2, 255)]);
    expect(english.single.source, HitSource.translation);
    final (a, b) = english.single.ranges.single;
    expect(english.single.text.substring(a, b), 'Neither slumber nor sleep');
  });

  test('a snippet keeps the match and moves its range', () {
    final text = List.filled(60, 'word').join(' ');
    final (s, ranges) = snippet(text, [(150, 154)], before: 20, after: 20);
    expect(s, startsWith('… '));
    expect(s, endsWith(' …'));
    final (a, b) = ranges.single;
    expect(s.substring(a, b), 'word');
  });
}
