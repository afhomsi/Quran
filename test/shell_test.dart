import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/app.dart';
import 'package:hifz/audio/ayah_audio.dart';
import 'package:hifz/data/khatma.dart';
import 'package:hifz/data/marks.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/mushaf_repository.dart';
import 'package:hifz/data/page_fonts.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:hifz/data/study.dart';
import 'package:hifz/data/study_cache.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hifz/features/mushaf/mushaf_page_view.dart';
import 'package:hifz/features/study/study_panel.dart';
import 'package:hifz/features/study/word_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_player.dart';

/// Skips real font loading, which needs the asset bundle.
class _FakePageFonts extends PageFonts {
  _FakePageFonts() : super(rootBundle);

  @override
  Future<String> load(int page, MushafPalette palette) async =>
      PageFonts.familyFor(page, palette);
}

/// Keeps nothing, so no files are written in tests.
class _NoCache extends StudyCache {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String text) async {}
}

Future<(ProviderContainer, FakePlayer)> _start(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final mushaf = parseMushaf(File(mushafLayoutAssetPath).readAsStringSync());
  final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
  final player = FakePlayer();
  tester.view.physicalSize = const Size(1080, 2316);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        mushafProvider.overrideWith((ref) async => mushaf),
        surahsProvider.overrideWith((ref) async => surahs),
        pageFontsProvider.overrideWithValue(_FakePageFonts()),
        ayahPlayerProvider.overrideWithValue(player),
        screenWakeProvider.overrideWithValue((on) async {}),
        // The books say nothing, without going to the internet.
        studyRepositoryProvider.overrideWithValue(
          StudyRepository(
            client: MockClient((_) async => http.Response('', 404)),
            cache: _NoCache(),
          ),
        ),
      ],
      child: const HifzApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  return (container, player);
}

/// A word of the mushaf page on screen; the first one is al-Fatiha 1.
Finder _word() => find
    .descendant(
      of: find.byType(MushafPageView),
      matching: find.byType(GestureDetector),
    )
    .first;

Finder _inCard(String text) =>
    find.descendant(of: find.byType(WordCard), matching: find.text(text));

Finder _inPanel(String text) =>
    find.descendant(of: find.byType(StudyPanel), matching: find.text(text));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the bottom bar switches between the five tabs', (tester) async {
    await _start(tester);
    // Opens on the mushaf, at the first page.
    expect(find.text('1 الفاتحة (7)'), findsWidgets);
    for (final (tab, title) in [
      ('ختمة', 'ختمتي'),
      ('الفهرس', 'الربع'),
      ('علاماتي', 'آيات محفوظة'),
      ('المزيد', 'اختبار ذاتي للحفظ'),
    ]) {
      await _tap(tester, find.text(tab));
      expect(find.text(title), findsOneWidget, reason: tab);
    }
  });

  testWidgets('marks and colors an ayah and lists it in my marks', (
    tester,
  ) async {
    final (container, _) = await _start(tester);
    // A long press opens the word card; its bookmark saves the ayah.
    await tester.longPress(_word());
    await tester.pumpAndSettle();
    expect(find.byType(WordCard), findsOneWidget);
    await _tap(tester, _inCard('فاصل'));
    expect(container.read(bookmarksProvider), [const AyahRef(1, 1)]);
    expect(find.text('تمت إضافة العلامة المرجعية'), findsOneWidget);

    // "More" opens the study panel, with the place markers and colors.
    await _tap(tester, _inCard('المزيد'));
    expect(find.byType(StudyPanel), findsOneWidget);
    await _tap(tester, _inPanel('فاصل'));
    await _tap(tester, find.text('علامة الحفظ'));
    expect(container.read(markersProvider), {
      MarkerKind.hifz: const AyahRef(1, 1),
    });
    await _tap(tester, _inPanel('تلوين'));
    await _tap(tester, find.byTooltip('أزرق'));
    await _tap(tester, find.widgetWithText(FilledButton, 'تلوين'));
    expect(container.read(highlightsProvider), {const AyahRef(1, 1): 2});
    await _tap(
      tester,
      find.descendant(
        of: find.byType(StudyPanel),
        matching: find.byTooltip('إغلاق'),
      ),
    );

    await _tap(tester, find.text('علاماتي'));
    expect(find.text('الفاتحة : الآية 1'), findsWidgets);
    expect(find.text('الصفحة 1 - الآية 1'), findsWidgets);

    // Opening it goes back to the mushaf.
    await _tap(tester, find.text('الفاتحة : الآية 1').first);
    expect(find.byType(MushafPageView), findsOneWidget);
  });

  testWidgets('creates a khatma and opens its next portion', (tester) async {
    final (container, _) = await _start(tester);
    await _tap(tester, find.text('ختمة'));
    await _tap(tester, find.byTooltip('ختمة جديدة'));
    await _tap(tester, find.text('ختمة رمضان'));
    await _tap(tester, find.text('التالي'));
    await _tap(tester, find.byTooltip('لون العلامة 3'));
    await _tap(tester, find.widgetWithText(FilledButton, 'إنشاء خطة'));

    final plan = container.read(khatmaPlansProvider).single;
    expect(plan.type, KhatmaType.ramadan);
    expect(plan.color, 2);
    expect(find.text('الصفحات 1 – 21 · من الفاتحة 1'), findsOneWidget);

    await _tap(tester, find.text('قرأته'));
    expect(find.text('الصفحات 22 – 41 · من البقرة 142'), findsOneWidget);
    await _tap(tester, find.text('اقرأ الورد'));
    expect(container.read(lastPageProvider), 22);
    // The plan's ribbon is on the page where it stands.
    expect(find.byTooltip(plan.title), findsOneWidget);
  });

  testWidgets('plays from an ayah and follows it to the next page', (
    tester,
  ) async {
    final (container, player) = await _start(tester);
    await tester.longPress(_word());
    await tester.pumpAndSettle();
    await _tap(tester, _inCard('استماع'));
    expect(player.played.single, endsWith('/001001.mp3'));
    expect(find.byTooltip('إيقاف مؤقت'), findsOneWidget);

    await container.read(audioProvider.notifier).playFrom(const AyahRef(1, 7));
    player.finish();
    await tester.pumpAndSettle();
    expect(container.read(audioProvider).current, const AyahRef(2, 1));
    expect(container.read(lastPageProvider), 2);

    await _tap(tester, find.byTooltip('إغلاق المشغل'));
    expect(find.byTooltip('إيقاف مؤقت'), findsNothing);
  });

  testWidgets('searches the Quran and jumps to the ayah', (tester) async {
    final (container, _) = await _start(tester);
    await _tap(tester, find.byTooltip('بحث في القرآن'));
    await tester.enterText(find.byType(TextField), 'اصحب الكهف');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('الكهف : الآية 9'));
    expect(container.read(lastPageProvider), 294);
  });

  testWidgets('switches to plain text and to night mode', (tester) async {
    await _start(tester);
    await _tap(tester, find.byTooltip('عرض النص'));
    expect(find.byType(MushafPageView), findsNothing);
    expect(find.textContaining('﴿٧﴾'), findsOneWidget);

    await _tap(tester, find.byTooltip('الوضع الليلي'));
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
  });

  testWidgets('the self-test asks for the next ayah and scores', (
    tester,
  ) async {
    await _start(tester);
    await _tap(tester, find.text('المزيد'));
    await _tap(tester, find.text('اختبار ذاتي للحفظ'));
    await _tap(tester, find.text('ابدأ الاختبار'));
    // Al-Fatiha has 7 ayat, so 6 can be asked about.
    for (var i = 0; i < 6; i++) {
      expect(find.text('ما الآية التالية؟'), findsOneWidget);
      await _tap(tester, find.text('أظهر الإجابة'));
      await _tap(tester, find.text(i == 0 ? 'أخطأت' : 'أصبت'));
    }
    expect(find.text('النتيجة: 5 من 6'), findsOneWidget);
    expect(find.text('راجع هذه الآيات:'), findsOneWidget);
  });
  testWidgets('a tap on the page hides the bars and the header leads on', (
    tester,
  ) async {
    final (container, _) = await _start(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    await _tap(tester, _word());
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('بحث في القرآن'), findsNothing);

    // The page number opens the page navigator.
    await _tap(tester, find.byTooltip('التنقل بين الصفحات'));
    expect(find.byType(Slider), findsOneWidget);
    await _tap(tester, find.text('3').last);
    expect(container.read(lastPageProvider), 3);
    await _tap(tester, find.byTooltip('إغلاق'));
    expect(find.byType(Slider), findsNothing);

    // The juz opens its tab of the index.
    await _tap(tester, find.text('الجزء 1 (1/8)'));
    expect(find.text('جزء 1'), findsOneWidget);

    await _tap(tester, find.text('المصحف'));
    await _tap(tester, _word());
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
