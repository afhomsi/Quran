import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/data/arabic_search.dart';

void main() {
  test('ignores diacritics and spelling variants', () {
    expect(searchMatches('الاسراء', texts: ['الإسراء']), isTrue);
    expect(searchMatches('مريم', texts: ['مَرۡيَمَ']), isTrue);
    expect(searchMatches('الضحي', texts: ['الضحى']), isTrue);
    expect(searchMatches('البقره', texts: ['البقرة']), isTrue);
    expect(searchMatches('النساء', texts: ['البقرة']), isFalse);
  });

  test('matches numbers by their start, in either digit style', () {
    expect(searchMatches('5', numbers: [5]), isTrue);
    expect(searchMatches('5', numbers: [52]), isTrue);
    expect(searchMatches('5', numbers: [15]), isFalse);
    expect(searchMatches('٢٩٣', numbers: [293]), isTrue);
  });

  test('an empty query matches everything', () {
    expect(searchMatches('  ', numbers: [1]), isTrue);
  });
}
