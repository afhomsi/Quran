import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/arabic_search.dart';
import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/quran_models.dart';
import '../../data/quran_repository.dart';
import '../../l10n/strings.dart';

/// Where to open the mushaf: a page, and the ayah to highlight on it when
/// the user chose a surah and ayah.
typedef GoToTarget = ({int page, AyahRef? ayah});

/// Asks for a surah and ayah, or a page number.
Future<GoToTarget?> showGoToDialog(BuildContext context) =>
    showDialog<GoToTarget>(
      context: context,
      builder: (_) => const GoToDialog(),
    );

class GoToDialog extends ConsumerStatefulWidget {
  const GoToDialog({super.key});

  @override
  ConsumerState<GoToDialog> createState() => _GoToDialogState();
}

class _GoToDialogState extends ConsumerState<GoToDialog> {
  bool _byPage = false;
  Surah? _surah;
  final _ayah = TextEditingController();
  final _page = TextEditingController();

  @override
  void dispose() {
    _ayah.dispose();
    _page.dispose();
    super.dispose();
  }

  int? _number(TextEditingController c, int max) {
    final n = int.tryParse(normalizeForSearch(c.text));
    return n != null && n >= 1 && n <= max ? n : null;
  }

  GoToTarget? _target(Mushaf mushaf) {
    if (_byPage) {
      final page = _number(_page, mushafPageCount);
      return page == null ? null : (page: page, ayah: null);
    }
    final surah = _surah;
    if (surah == null) return null;
    // An empty ayah box means the start of the surah.
    final ayah = _ayah.text.trim().isEmpty
        ? 1
        : _number(_ayah, surah.ayahCount);
    if (ayah == null) return null;
    final ref = AyahRef(surah.number, ayah);
    return (page: mushaf.pageOf(ref), ayah: ref);
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final surahs = ref.watch(surahsProvider).value;
    final mushaf = ref.watch(mushafProvider).value;
    if (surahs == null || mushaf == null) {
      return const AlertDialog(content: LinearProgressIndicator());
    }
    final target = _target(mushaf);
    void go() {
      if (target != null) Navigator.pop(context, target);
    }

    return AlertDialog(
      title: Text(t.goTo),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(t.surahAndAyah)),
                ButtonSegment(value: true, label: Text(t.pageWord)),
              ],
              selected: {_byPage},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _byPage = v.single),
            ),
            const SizedBox(height: 16),
            if (_byPage)
              TextField(
                key: const ValueKey('go-to-page'),
                controller: _page,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: t.pageWord,
                  hintText: '${t.n(1)} – ${t.n(mushafPageCount)}',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => go(),
              )
            else ...[
              DropdownMenu<Surah>(
                key: const ValueKey('go-to-surah'),
                label: Text(t.surahField),
                expandedInsets: EdgeInsets.zero,
                menuHeight: 300,
                enableFilter: true,
                requestFocusOnTap: true,
                // Without diacritics or hamza, by name or number.
                filterCallback: (entries, query) => [
                  for (final e in entries)
                    if (searchMatches(
                      query,
                      numbers: [e.value.number],
                      texts: [e.value.name, e.value.transliteration, e.label],
                    ))
                      e,
                ],
                dropdownMenuEntries: [
                  for (final s in surahs)
                    DropdownMenuEntry(
                      value: s,
                      label: '${t.n(s.number)}. ${t.surahName(s)}',
                    ),
                ],
                onSelected: (s) => setState(() {
                  _surah = s;
                  _ayah.clear();
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('go-to-ayah'),
                controller: _ayah,
                enabled: _surah != null,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: t.ayahField(_surah?.ayahCount),
                  hintText: t.n(1),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => go(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel),
        ),
        FilledButton(onPressed: target == null ? null : go, child: Text(t.go)),
      ],
    );
  }
}
