import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/strings.dart';
import '../../recitation/offline_model.dart';
import '../../recitation/recitation_matcher.dart';
import '../../recitation/recitation_session.dart';
import '../../settings/app_settings.dart';

/// Orange for a word said with a wrong haraka, beside red for a wrong word.
const harakatColor = Color(0xFFEF8F00);

/// Asks how strictly to check the recitation about to start, unless the
/// reciter chose once for all in the settings. Null when dismissed.
Future<RecitationMode?> chooseRecitationMode(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final settings = container.read(settingsProvider);
  if (!settings.askRecitationMode) return settings.recitationMode;
  final chosen = await showModalBottomSheet<(RecitationMode, bool)>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ModeSheet(initial: settings.recitationMode),
  );
  if (chosen == null) return null;
  final (mode, remember) = chosen;
  container
      .read(settingsProvider.notifier)
      .update(
        (s) => s.copyWith(recitationMode: mode, askRecitationMode: !remember),
      );
  return mode;
}

class _ModeSheet extends ConsumerStatefulWidget {
  const _ModeSheet({required this.initial});

  final RecitationMode initial;

  @override
  ConsumerState<_ModeSheet> createState() => _ModeSheetState();
}

class _ModeSheetState extends ConsumerState<_ModeSheet> {
  bool _remember = false;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final textTheme = TextTheme.of(context);
    final model = ref.watch(offlineModelProvider).status;
    void choose(RecitationMode mode) =>
        Navigator.pop(context, (mode, _remember));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.chooseRecitationMode,
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            _ModeCard(
              key: const ValueKey('mode-strict'),
              icon: Icons.fact_check_rounded,
              title: t.strictMode,
              hint: t.strictModeHint,
              note: model == OfflineModelStatus.ready
                  ? null
                  : t.strictNeedsModel,
              selected: widget.initial == RecitationMode.strict,
              onTap: () => choose(RecitationMode.strict),
            ),
            const SizedBox(height: 10),
            _ModeCard(
              key: const ValueKey('mode-lenient'),
              icon: Icons.notes_rounded,
              title: t.lenientMode,
              hint: t.lenientModeHint,
              selected: widget.initial == RecitationMode.lenient,
              onTap: () => choose(RecitationMode.lenient),
            ),
            CheckboxListTile(
              value: _remember,
              onChanged: (v) => setState(() => _remember = v ?? false),
              title: Text(t.rememberRecitationMode),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    this.note,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String hint;
  final String? note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = TextTheme.of(context);
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.primary, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(hint, style: textTheme.bodyMedium),
                    if (note != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        note!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lists the mistakes of [session] by kind: wrong words and ayat in red,
/// wrong harakat in orange. It keeps up with the session, as the last
/// words heard are checked once the recognizer settles them.
Future<void> showMistakesReport(
  BuildContext context,
  RecitationSession session,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => MistakesReport(session: session),
);

class MistakesReport extends StatelessWidget {
  const MistakesReport({super.key, required this.session});

  final RecitationSession session;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final t = S.of(context);
    final colors = Theme.of(context).colorScheme;
    final textTheme = TextTheme.of(context);
    final words = [
      for (final m in session.mistakes)
        if (m.kind == MistakeKind.word) m.message,
    ];
    final harakat = [
      for (final m in session.mistakes)
        if (m.kind == MistakeKind.harakat) m.message,
    ];
    final String? harakatNote = session.mode == RecitationMode.lenient
        ? t.harakatOff
        : session.heardHarakat
        ? null
        : t.harakatNotChecked;

    Widget section(String title, Color color, List<String> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$title (${t.n(items.length)})',
                  style: textTheme.titleMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          Text(t.noMistakesOfKind, style: textTheme.bodyMedium),
        for (final (i, m) in items.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text('${t.n(i + 1)}. $m', style: textTheme.bodyMedium),
          ),
      ],
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              t.mistakesReport,
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              t.reportSummary(words.length, harakat.length),
              textAlign: TextAlign.center,
            ),
            section(t.wordMistakes, colors.error, words),
            if (harakatNote == null)
              section(t.harakatMistakes, harakatColor, harakat)
            else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  harakatNote,
                  style: textTheme.bodyMedium?.copyWith(color: colors.outline),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// What to say once a recitation is finished: well done, or how many
/// mistakes of each kind.
String finishedStatus(S t, RecitationResult result) {
  final words = result.mistakeCount, harakat = result.harakatMistakeCount;
  if (words == 0 && harakat == 0) return t.perfectRecitation;
  return harakat == 0
      ? t.finishedWithMistakes(words)
      : t.finishedWithKinds(words, harakat);
}
