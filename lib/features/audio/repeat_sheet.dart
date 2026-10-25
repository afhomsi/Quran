import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/ayah_audio.dart';
import '../../data/mushaf_models.dart';
import '../../data/quran_models.dart';
import '../../data/quran_repository.dart';
import '../../l10n/strings.dart';

/// Asks how many times to repeat each ayah and the whole group, then plays.
///
/// With [ayat], plays those ayat. Otherwise the reader chooses a range of
/// ayat, starting from [from] to [to].
Future<void> showRepeatSheet(
  BuildContext context, {
  AyahRef? from,
  AyahRef? to,
  List<AyahRef>? ayat,
  String? title,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _RepeatSheet(
    from: from ?? ayat?.first ?? const AyahRef(1, 1),
    to: to ?? from ?? ayat?.last ?? const AyahRef(1, 7),
    ayat: ayat,
    title: title,
  ),
);

class _RepeatSheet extends ConsumerStatefulWidget {
  const _RepeatSheet({
    required this.from,
    required this.to,
    this.ayat,
    this.title,
  });

  final AyahRef from;
  final AyahRef to;
  final List<AyahRef>? ayat;
  final String? title;

  @override
  ConsumerState<_RepeatSheet> createState() => _RepeatSheetState();
}

class _RepeatSheetState extends ConsumerState<_RepeatSheet> {
  late AyahRef _from = widget.from;
  late AyahRef _to = widget.to;
  late int _ayahRepeats = ref.read(audioProvider).repeats;
  late int _groupRepeats = ref.read(audioProvider).listRepeats;

  @override
  Widget build(BuildContext context) {
    final surahs = ref.watch(surahsProvider).value;
    final theme = Theme.of(context);
    final t = S.of(context);
    if (surahs == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final controller = ref.read(audioProvider.notifier);
    final ayat = widget.ayat ?? controller.ayatBetween(_from, _to);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title ?? t.repeatTitle,
              style: theme.textTheme.titleLarge,
            ),
            Text(t.ayahCount(ayat.length), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            if (widget.ayat == null) ...[
              _AyahPicker(
                label: t.rangeFrom,
                value: _from,
                surahs: surahs,
                onChanged: (a) => setState(() {
                  _from = a;
                  if (_to < a) _to = a;
                }),
              ),
              const SizedBox(height: 8),
              _AyahPicker(
                label: t.rangeTo,
                value: _to,
                surahs: surahs,
                onChanged: (a) => setState(() {
                  _to = a;
                  if (a < _from) _from = a;
                }),
              ),
              const Divider(height: 24),
            ],
            _Counter(
              label: t.repeatEachAyah(_ayahRepeats),
              value: _ayahRepeats,
              onChanged: (v) => setState(() => _ayahRepeats = v),
            ),
            _Counter(
              label: t.repeatGroup(_groupRepeats),
              value: _groupRepeats,
              onChanged: (v) => setState(() => _groupRepeats = v),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(t.startListening),
              onPressed: () {
                controller.playList(
                  ayat,
                  ayahRepeats: _ayahRepeats,
                  listRepeats: _groupRepeats,
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A surah and an ayah in it.
class _AyahPicker extends StatelessWidget {
  const _AyahPicker({
    required this.label,
    required this.value,
    required this.surahs,
    required this.onChanged,
  });

  final String label;
  final AyahRef value;
  final List<Surah> surahs;
  final ValueChanged<AyahRef> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final count = surahs[value.surah - 1].ayahCount;
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(
          flex: 3,
          child: DropdownButton<int>(
            isExpanded: true,
            value: value.surah,
            menuMaxHeight: 400,
            items: [
              for (final s in surahs)
                DropdownMenuItem(
                  value: s.number,
                  child: Text('${t.n(s.number)}. ${t.surahName(s)}'),
                ),
            ],
            onChanged: (s) => onChanged(AyahRef(s!, 1)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: DropdownButton<int>(
            isExpanded: true,
            value: value.ayah.clamp(1, count),
            menuMaxHeight: 400,
            items: [
              for (var a = 1; a <= count; a++)
                DropdownMenuItem(value: a, child: Text(t.ayahNumber(a))),
            ],
            onChanged: (a) => onChanged(AyahRef(value.surah, a!)),
          ),
        ),
      ],
    );
  }
}

/// A count from 1 to 20 with minus and plus buttons.
class _Counter extends StatelessWidget {
  const _Counter({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton.outlined(
          icon: const Icon(Icons.remove_rounded),
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 40,
          child: Text(
            t.n(value),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton.outlined(
          icon: const Icon(Icons.add_rounded),
          onPressed: value < 20 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
