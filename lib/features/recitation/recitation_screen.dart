import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/quran_models.dart';
import '../../data/quran_repository.dart';
import '../../recitation/alert_sound.dart';
import '../../recitation/recitation_matcher.dart';
import '../../recitation/recitation_session.dart';
import '../../recitation/speech_listener.dart';

/// Recite a surah from memory; the app listens and points out mistakes.
class RecitationScreen extends ConsumerWidget {
  const RecitationScreen({super.key, required this.surahNumber});

  final int surahNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(surahsProvider)) {
      AsyncData(value: final surahs) => _RecitationView(
        surah: surahs[surahNumber - 1],
        listener: ref.read(speechListenerProvider),
      ),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('تعذر تحميل السورة\n$error')),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _RecitationView extends StatefulWidget {
  const _RecitationView({required this.surah, required this.listener});

  final Surah surah;
  final SpeechListener listener;

  @override
  State<_RecitationView> createState() => _RecitationViewState();
}

class _RecitationViewState extends State<_RecitationView> {
  late final RecitationSession _session = RecitationSession(
    listener: widget.listener,
    surahName: widget.surah.name,
    ayahs: widget.surah.ayahs,
  )..onMistake = (_) => playMistakeAlert();

  /// Hifz is recited from memory, so the text is hidden until recited.
  bool _showText = false;

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final result = _session.result;
        final mistakes = _session.mistakes;
        return Scaffold(
          appBar: AppBar(
            title: Text('تسميع سورة ${widget.surah.name}'),
            actions: [
              IconButton(
                tooltip: _showText ? 'إخفاء النص' : 'إظهار النص',
                icon: Icon(_showText ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showText = !_showText),
              ),
              IconButton(
                tooltip: 'إعادة التسميع',
                icon: const Icon(Icons.restart_alt),
                onPressed: _session.reset,
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_session.error != null)
                _Banner(
                  color: Theme.of(context).colorScheme.errorContainer,
                  icon: Icons.mic_off,
                  text: _session.error!,
                ),
              if (mistakes.isNotEmpty)
                _Banner(
                  key: ValueKey(mistakes.length),
                  color: Theme.of(context).colorScheme.errorContainer,
                  icon: Icons.warning_amber_rounded,
                  text: mistakes.last.message,
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _SurahWords(result: result, showText: _showText),
                ),
              ),
              _StatusBar(session: _session),
            ],
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _session.isListening ? _session.stop : _session.start,
            icon: Icon(_session.isListening ? Icons.stop : Icons.mic),
            label: Text(_session.isListening ? 'إيقاف' : 'ابدأ التسميع'),
          ),
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.color,
    required this.icon,
    required this.text,
  });

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.session});

  final RecitationSession session;

  @override
  Widget build(BuildContext context) {
    final result = session.result;
    final total = result.words.length;
    final String status;
    if (result.isComplete) {
      status = result.mistakeCount == 0
          ? 'أحسنت! أتممت السورة بلا أخطاء.'
          : 'أتممت السورة. عدد الأخطاء: ${result.mistakeCount}';
    } else if (session.isListening) {
      status = 'أستمع إليك… ${result.progress} من $total كلمة';
    } else {
      status = 'اضغط «ابدأ التسميع» ثم اقرأ السورة من حفظك.';
    }
    final heard = session.heardText;
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainer,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status, style: Theme.of(context).textTheme.titleMedium),
          if (heard.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'سمعت: $heard',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.rtl,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _SurahWords extends StatelessWidget {
  const _SurahWords({required this.result, required this.showText});

  final RecitationResult result;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final words = result.words;
    return Wrap(
      spacing: 6,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < words.length; i++) ...[
          for (final extra in words[i].extrasBefore) _ExtraWord(extra),
          _Word(word: words[i], showText: showText),
          if (i == words.length - 1 || words[i + 1].ayah != words[i].ayah)
            _AyahEnd(words[i].ayah),
        ],
        for (final extra in result.extrasAtEnd) _ExtraWord(extra),
      ],
    );
  }
}

const _wordStyle = TextStyle(fontSize: 26, height: 1.6);

class _Word extends StatelessWidget {
  const _Word({required this.word, required this.showText});

  final WordResult word;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (
      Color? background,
      Color foreground,
      String? note,
    ) = switch (word.status) {
      WordStatus.correct => (null, Colors.green.shade700, null),
      WordStatus.wrong => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        'سمعت: ${word.heard}',
      ),
      WordStatus.skipped => (
        Colors.orange.shade100,
        Colors.orange.shade900,
        'نسيتها',
      ),
      WordStatus.pending when showText => (null, scheme.onSurface, null),
      WordStatus.pending => (
        scheme.surfaceContainerHighest,
        Colors.transparent,
        null,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(word.text, style: _wordStyle.copyWith(color: foreground)),
          if (note != null)
            Text(note, style: TextStyle(fontSize: 12, color: foreground)),
        ],
      ),
    );
  }
}

class _ExtraWord extends StatelessWidget {
  const _ExtraWord(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.error),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: _wordStyle.copyWith(
              color: scheme.error,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          Text('زائدة', style: TextStyle(fontSize: 12, color: scheme.error)),
        ],
      ),
    );
  }
}

class _AyahEnd extends StatelessWidget {
  const _AyahEnd(this.ayah);

  final int ayah;

  @override
  Widget build(BuildContext context) {
    const digits = '٠١٢٣٤٥٦٧٨٩';
    final number = '$ayah'.split('').map((d) => digits[int.parse(d)]).join();
    return Text(
      '﴿$number﴾',
      style: _wordStyle.copyWith(color: Theme.of(context).colorScheme.primary),
    );
  }
}
