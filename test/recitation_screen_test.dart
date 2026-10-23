import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/data/quran_repository.dart';
import 'package:hifz/features/recitation/recitation_screen.dart';
import 'package:hifz/recitation/speech_listener.dart';

/// Plays back text instead of listening to a microphone.
class _FakeListener implements SpeechListener {
  void Function(String text, bool isFinal)? _onResult;
  late void Function() _onDone;
  bool listening = false;

  void say(String text, {bool isFinal = false}) =>
      _onResult?.call(text, isFinal);

  @override
  Future<bool> initialize({
    required void Function(String message) onError,
    required void Function() onDone,
  }) async {
    _onDone = onDone;
    return true;
  }

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    _onResult = onResult;
    listening = true;
  }

  @override
  Future<void> stop() async {
    if (!listening) return;
    listening = false;
    _onDone();
  }
}

void main() {
  testWidgets('alerts on a mistake while reciting Al-Fatiha', (tester) async {
    final listener = _FakeListener();
    final surahs = parseSurahs(File(quranAssetPath).readAsStringSync());
    final alamin = surahs.first.ayahs[1].split(' ').last;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          surahsProvider.overrideWith((ref) async => surahs),
          speechListenerProvider.overrideWithValue(listener),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: RecitationScreen.surah(1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('تسميع سورة الفاتحة'), findsOneWidget);

    await tester.tap(find.text('ابدأ التسميع'));
    await tester.pumpAndSettle();
    expect(listener.listening, isTrue);
    expect(find.text('إيقاف'), findsOneWidget);

    listener.say('بسم الله الرحمن الرحيم الحمد لله رب الناس');
    await tester.pump();
    expect(find.textContaining('خطأ'), findsNothing);

    listener.say('بسم الله الرحمن الرحيم الحمد لله رب الناس', isFinal: true);
    await tester.pump();
    expect(
      find.text('خطأ في الآية 2: سمعت «الناس» والصواب «$alamin»'),
      findsOneWidget,
    );
    expect(find.text('سمعت: الناس'), findsOneWidget);

    await tester.tap(find.byTooltip('إعادة التسميع'));
    await tester.pumpAndSettle();
    expect(find.textContaining('خطأ'), findsNothing);
    expect(find.text('ابدأ التسميع'), findsOneWidget);
  });
}
