import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/app.dart';
import 'package:hifz/data/quran_models.dart';
import 'package:hifz/data/quran_repository.dart';

void main() {
  testWidgets('app starts right-to-left with the surah list', (tester) async {
    const fatiha = Surah(
      number: 1,
      name: 'الفاتحة',
      transliteration: 'Al-Fatihah',
      isMeccan: true,
      ayahs: ['بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ'],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          surahsProvider.overrideWith((ref) async => [fatiha]),
        ],
        child: const HifzApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('السور'), findsOneWidget);
    final dir = Directionality.of(tester.element(find.text('السور')));
    expect(dir, TextDirection.rtl);
    expect(find.text('الفاتحة'), findsOneWidget);

    await tester.tap(find.text('الفاتحة'));
    await tester.pumpAndSettle();
    expect(find.textContaining('﴿1﴾'), findsOneWidget);
  });
}
