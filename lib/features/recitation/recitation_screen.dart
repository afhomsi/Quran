import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/quran_models.dart';
import '../../data/quran_repository.dart';
import '../../l10n/strings.dart';
import '../../recitation/alert_sound.dart';
import '../../recitation/recitation_matcher.dart';
import '../../recitation/recitation_session.dart';
import '../../recitation/speech_listener.dart';

/// Recite a surah or a mushaf page from memory; the app listens and points
/// out mistakes.
class RecitationScreen extends ConsumerWidget {
  /// Recite a whole surah.
  const RecitationScreen.surah(int this.surah, {super.key}) : page = null;

  /// Recite the ayat on a page of the mushaf.
  const RecitationScreen.page(int this.page, {super.key}) : surah = null;

  final int? surah;
  final int? page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surahs = ref.watch(surahsProvider);
    final mushaf = page == null ? null : ref.watch(mushafProvider);
    final t = S.of(context);
    return switch ((surahs, mushaf)) {
      (AsyncData(value: final s), null || AsyncData()) => _RecitationView(
        key: ValueKey((surah, page)),
        title: surah != null
            ? t.reciteSurahTitle(s[surah! - 1])
            : t.recitePageTitle(page!),
        words: wordsToRecite(_ayahs(s, mushaf?.value)),
        surahs: s,
        listener: ref.read(speechListenerProvider),
      ),
      (AsyncError(:final error), _) ||
      (_, AsyncError(:final error)) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(t.loadTextError(error))),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }

  Iterable<(int, int, String)> _ayahs(
    List<Surah> surahs,
    Mushaf? mushaf,
  ) sync* {
    if (surah != null) {
      final ayahs = surahs[surah! - 1].ayahs;
      for (var i = 0; i < ayahs.length; i++) {
        yield (surah!, i + 1, ayahs[i]);
      }
      return;
    }
    final seen = <AyahRef>{};
    for (final w in mushaf!.page(page!).words) {
      if (seen.add(w.ayah)) {
        yield (
          w.ayah.surah,
          w.ayah.ayah,
          surahs[w.ayah.surah - 1].ayahs[w.ayah.ayah - 1],
        );
      }
    }
  }
}

class _RecitationView extends StatefulWidget {
  const _RecitationView({
    super.key,
    required this.title,
    required this.words,
    required this.surahs,
    required this.listener,
  });

  final String title;
  final List<ExpectedWord> words;
  final List<Surah> surahs;
  final SpeechListener listener;

  @override
  State<_RecitationView> createState() => _RecitationViewState();
}

class _RecitationViewState extends State<_RecitationView> {
  late final RecitationSession _session = RecitationSession(
    listener: widget.listener,
    expected: widget.words,
    surahName: (s) => widget.surahs[s - 1].name,
  )..onMistake = (_) => playMistakeAlert();

  late final List<_Group> _groups = _groupWords(widget.words);
  final _scroll = ScrollController();
  final _groupKeys = <int, GlobalKey>{};
  int _followedGroup = 0;

  /// Hifz is recited from memory, so the text is hidden until recited.
  bool _showText = false;

  @override
  void initState() {
    super.initState();
    _session.addListener(_follow);
  }

  @override
  void dispose() {
    _session.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Keeps the ayah being recited in view.
  void _follow() {
    final progress = _session.result.progress;
    final group = _groups.lastIndexWhere((g) => g.start <= progress);
    if (group <= _followedGroup) return;
    _followedGroup = group;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _groupKeys[group]?.currentContext;
      if (context != null && context.mounted) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.3,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
  }

  Future<void> _reset() async {
    await _session.reset();
    _followedGroup = 0;
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final result = _session.result;
        final mistakes = _session.mistakes;
        final t = S.of(context);
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            actions: [
              IconButton(
                tooltip: _showText ? t.hideText : t.showText,
                icon: Icon(_showText ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showText = !_showText),
              ),
              IconButton(
                tooltip: t.restartRecitation,
                icon: const Icon(Icons.restart_alt),
                onPressed: _reset,
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
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: _groups.length,
                  itemBuilder: (context, i) => KeyedSubtree(
                    key: _groupKeys.putIfAbsent(i, GlobalKey.new),
                    child: _GroupView(
                      group: _groups[i],
                      result: result,
                      showText: _showText,
                      surahName: (s) => widget.surahs[s - 1].name,
                    ),
                  ),
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
            label: Text(_session.isListening ? t.stop : t.startRecitation),
          ),
        );
      },
    );
  }
}

/// Consecutive words of one ayah, or of the basmala or isti'adha.
class _Group {
  _Group(this.start, this.end, this.first);

  final int start;
  int end;
  final ExpectedWord first;
}

List<_Group> _groupWords(List<ExpectedWord> words) {
  final groups = <_Group>[];
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    final last = groups.isEmpty ? null : groups.last;
    if (last != null &&
        last.first.surah == w.surah &&
        last.first.ayah == w.ayah &&
        last.first.kind == w.kind) {
      last.end = i + 1;
    } else {
      groups.add(_Group(i, i + 1, w));
    }
  }
  return groups;
}

class _GroupView extends StatelessWidget {
  const _GroupView({
    required this.group,
    required this.result,
    required this.showText,
    required this.surahName,
  });

  final _Group group;
  final RecitationResult result;
  final bool showText;
  final String Function(int surah) surahName;

  @override
  Widget build(BuildContext context) {
    final words = result.words.sublist(group.start, group.end);
    final kind = group.first.kind;
    if (kind == WordKind.istiadha) {
      // Not shown, only what was said wrongly in its place.
      return Wrap(
        spacing: 6,
        children: [
          for (final w in words)
            for (final e in w.extrasBefore) _ExtraWord(e),
        ],
      );
    }
    final surah = group.first.surah;
    final startsSurah =
        kind == WordKind.basmala ||
        (group.first.ayah == 1 && (surah == 1 || surah == 9));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (startsSurah)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'سورة ${surahName(surah)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          Wrap(
            alignment: kind == WordKind.basmala
                ? WrapAlignment.center
                : WrapAlignment.start,
            spacing: 6,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final w in words) ...[
                for (final e in w.extrasBefore) _ExtraWord(e),
                _Word(word: w, showText: showText),
              ],
              if (kind == WordKind.ayah) _AyahEnd(group.first.ayah),
              if (group.end == result.words.length)
                for (final e in result.extrasAtEnd) _ExtraWord(e),
            ],
          ),
        ],
      ),
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
    final total = result.words.where((w) => !w.word.optional).length;
    final done = result.words
        .take(result.progress)
        .where((w) => !w.word.optional)
        .length;
    final t = S.of(context);
    final String status;
    if (result.isComplete) {
      status = result.mistakeCount == 0
          ? t.perfectRecitation
          : t.finishedWithMistakes(result.mistakeCount);
    } else if (session.isListening) {
      status = t.listening(done, total);
    } else {
      status = t.pressStart;
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
              t.heard(heard),
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
        S.of(context).heard(word.heard ?? ''),
      ),
      WordStatus.skipped => (
        Colors.orange.shade100,
        Colors.orange.shade900,
        S.of(context).forgotten,
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
          Text(
            S.of(context).extraWord,
            style: TextStyle(fontSize: 12, color: scheme.error),
          ),
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
