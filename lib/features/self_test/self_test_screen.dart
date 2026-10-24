import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/marks.dart';
import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/quran_models.dart';
import '../../data/quran_repository.dart';
import '../../data/self_test.dart';
import '../../l10n/strings.dart';
import '../shell/navigation.dart';

enum _ScopeKind { surah, juz, hifz }

/// Hifz self-test: shows an ayah (or its start) from a surah or juz the
/// user picks and asks them to recite what comes next, then reveals it so
/// they can mark themselves right or wrong.
class SelfTestScreen extends ConsumerStatefulWidget {
  const SelfTestScreen({super.key, this.random});

  /// For tests; a fresh [Random] otherwise.
  final Random? random;

  @override
  ConsumerState<SelfTestScreen> createState() => _SelfTestScreenState();
}

class _SelfTestScreenState extends ConsumerState<SelfTestScreen> {
  var _scopeKind = _ScopeKind.surah;
  var _surah = 1;
  var _juz = 30;
  var _mode = SelfTestMode.nextAyah;
  var _count = 10;

  /// Questions of the test in progress, or null on the setup page.
  List<AyahRef>? _questions;
  var _index = 0;
  var _revealed = false;
  final _wrong = <AyahRef>[];

  late final _random = widget.random ?? Random();

  @override
  Widget build(BuildContext context) {
    final surahs = ref.watch(surahsProvider).value;
    final mushaf = ref.watch(mushafProvider).value;
    final hifz = ref.watch(markersProvider)[MarkerKind.hifz];
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).selfTest)),
      body: surahs == null || mushaf == null
          ? const Center(child: CircularProgressIndicator())
          : switch (_questions) {
              null => _setup(surahs, hifz),
              final q when _index >= q.length => _result(surahs, mushaf, q),
              final q => _question(surahs, q),
            },
    );
  }

  List<AyahRef> _scope(List<Surah> surahs, AyahRef? hifz) =>
      switch (_scopeKind) {
        _ScopeKind.surah => ayahsBetween(
          surahs,
          AyahRef(_surah, 1),
          _surah < surahs.length ? AyahRef(_surah + 1, 1) : null,
        ),
        _ScopeKind.juz => ayahsBetween(
          surahs,
          juzStarts[_juz - 1],
          _juz < juzStarts.length ? juzStarts[_juz] : null,
        ),
        // Everything up to and including the hifz marker.
        _ScopeKind.hifz =>
          hifz == null
              ? const []
              : [...ayahsBetween(surahs, const AyahRef(1, 1), hifz), hifz],
      };

  Widget _setup(List<Surah> surahs, AyahRef? hifz) {
    final scope = _scope(surahs, hifz);
    final theme = Theme.of(context);
    final t = S.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(t.whatToTest, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<_ScopeKind>(
          segments: [
            ButtonSegment(value: _ScopeKind.surah, label: Text(t.surahWord)),
            ButtonSegment(value: _ScopeKind.juz, label: Text(t.juzWord)),
            ButtonSegment(
              value: _ScopeKind.hifz,
              label: Text(t.whatIMemorized),
            ),
          ],
          selected: {_scopeKind},
          onSelectionChanged: (s) => setState(() => _scopeKind = s.first),
        ),
        const SizedBox(height: 12),
        switch (_scopeKind) {
          _ScopeKind.surah => DropdownButtonFormField<int>(
            initialValue: _surah,
            decoration: InputDecoration(labelText: t.surahWord),
            items: [
              for (final s in surahs)
                DropdownMenuItem(
                  value: s.number,
                  child: Text('${t.n(s.number)}. ${t.surahName(s)}'),
                ),
            ],
            onChanged: (v) => setState(() => _surah = v ?? _surah),
          ),
          _ScopeKind.juz => DropdownButtonFormField<int>(
            initialValue: _juz,
            decoration: InputDecoration(labelText: t.juzWord),
            items: [
              for (var j = 1; j <= juzStarts.length; j++)
                DropdownMenuItem(value: j, child: Text(t.juz(j))),
            ],
            onChanged: (v) => setState(() => _juz = v ?? _juz),
          ),
          _ScopeKind.hifz => Text(
            hifz == null
                ? t.noHifzMarker
                : t.upToHifz(surahs[hifz.surah - 1], hifz.ayah),
          ),
        },
        const SizedBox(height: 24),
        Text(t.questionType, style: theme.textTheme.titleMedium),
        RadioGroup<SelfTestMode>(
          groupValue: _mode,
          onChanged: (m) => setState(() => _mode = m ?? _mode),
          child: Column(
            children: [
              RadioListTile(
                value: SelfTestMode.nextAyah,
                title: Text(t.whatComesNext),
                subtitle: Text(t.whatComesNextExplain),
              ),
              RadioListTile(
                value: SelfTestMode.completeAyah,
                title: Text(t.completeTheAyah),
                subtitle: Text(t.completeTheAyahExplain),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(t.questionCount(_count), style: theme.textTheme.titleMedium),
        Slider(
          value: _count.toDouble(),
          min: 5,
          max: 30,
          divisions: 5,
          label: '$_count',
          onChanged: (v) => setState(() => _count = v.round()),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(t.startTest),
          onPressed: scope.length < 2
              ? null
              : () => setState(() {
                  _questions = pickQuestions(scope, _mode, _count, _random);
                  _index = 0;
                  _revealed = false;
                  _wrong.clear();
                }),
        ),
      ],
    );
  }

  Widget _question(List<Surah> surahs, List<AyahRef> questions) {
    final theme = Theme.of(context);
    final t = S.of(context);
    final ayah = questions[_index];
    final text = surahs[ayah.surah - 1].ayahs[ayah.ayah - 1];
    final next = ayah.ayah < surahs[ayah.surah - 1].ayahCount
        ? AyahRef(ayah.surah, ayah.ayah + 1)
        : AyahRef(ayah.surah + 1, 1);
    final quran = theme.textTheme.headlineSmall?.copyWith(height: 2);

    final String prompt;
    final String answer;
    final String question;
    if (_mode == SelfTestMode.nextAyah) {
      prompt = text;
      answer = surahs[next.surah - 1].ayahs[next.ayah - 1];
      question = t.whatComesNext;
    } else {
      final words = text.split(' ');
      final shown = promptWordCount(text);
      prompt = '${words.take(shown).join(' ')} …';
      answer = words.skip(shown).join(' ');
      question = t.completeTheAyah;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LinearProgressIndicator(value: _index / questions.length),
        const SizedBox(height: 8),
        Text(
          '${t.questionOf(_index + 1, questions.length)} · '
          '${t.surahName(surahs[ayah.surah - 1])} ${t.n(ayah.ayah)}',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(prompt, style: quran, textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          question,
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (!_revealed)
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () => setState(() => _revealed = true),
            child: Text(t.showAnswer),
          )
        else ...[
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(answer, style: quran, textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.check_rounded),
                  label: Text(t.gotItRight),
                  onPressed: () => _answer(correct: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close_rounded),
                  label: Text(t.gotItWrong),
                  onPressed: () => _answer(correct: false),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _answer({required bool correct}) => setState(() {
    if (!correct) _wrong.add(_questions![_index]);
    _index++;
    _revealed = false;
  });

  Widget _result(List<Surah> surahs, Mushaf mushaf, List<AyahRef> questions) {
    final theme = Theme.of(context);
    final t = S.of(context);
    final right = questions.length - _wrong.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),
        Icon(
          _wrong.isEmpty ? Icons.emoji_events_rounded : Icons.school_rounded,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 8),
        Text(
          t.score(right, questions.length),
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (_wrong.isNotEmpty) ...[
          Text(t.reviewThese, style: theme.textTheme.titleMedium),
          for (final a in _wrong)
            ListTile(
              leading: const Icon(Icons.replay_rounded),
              title: Text(t.surahAyah(surahs[a.surah - 1], a.ayah)),
              trailing: Text(t.n(mushaf.pageOf(a))),
              onTap: () => openMushaf(context, mushaf.pageOf(a), highlight: a),
            ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => _questions = null),
          child: Text(t.newTest),
        ),
      ],
    );
  }
}
