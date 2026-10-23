import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mushaf_models.dart';
import '../../data/mushaf_repository.dart';
import '../../data/page_fonts.dart';
import '../../data/quran_models.dart';
import '../../data/quran_repository.dart';
import '../../data/reading_state.dart';
import 'mushaf_page_view.dart';

/// Swipeable 604-page mushaf. Remembers the last page read.
class MushafScreen extends ConsumerStatefulWidget {
  const MushafScreen({super.key, required this.initialPage, this.highlight});

  final int initialPage;

  /// Ayah to highlight on open, e.g. when coming from a bookmark.
  final AyahRef? highlight;

  @override
  ConsumerState<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends ConsumerState<MushafScreen> {
  late final _controller = PageController(initialPage: widget.initialPage - 1);
  late int _page = widget.initialPage;
  late AyahRef? _selected = widget.highlight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPageChanged(_page));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _page = page);
    ref.read(lastPageProvider.notifier).set(page);
    final fonts = ref.read(pageFontsProvider);
    for (final p in [page - 1, page + 1]) {
      if (p >= 1 && p <= mushafPageCount) fonts.load(p);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mushaf = ref.watch(mushafProvider).value;
    final surahs = ref.watch(surahsProvider).value;
    if (mushaf == null || surahs == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final current = mushaf.page(_page);
    return Scaffold(
      appBar: AppBar(
        title: Text(surahs[current.firstAyah.surah - 1].name),
        actions: [
          Center(child: Text('الجزء ${mushaf.juzOfPage(_page)}')),
          IconButton(
            tooltip: 'انتقال إلى صفحة',
            icon: const Icon(Icons.numbers),
            onPressed: () => _goToPage(context),
          ),
        ],
      ),
      body: SafeArea(
        child: PageView.builder(
          controller: _controller,
          itemCount: mushafPageCount,
          onPageChanged: (i) => _onPageChanged(i + 1),
          itemBuilder: (context, i) => _PageSlot(
            page: mushaf.page(i + 1),
            surahs: surahs,
            selected: _selected,
            onAyahTap: (a) =>
                setState(() => _selected = _selected == a ? null : a),
            onAyahLongPress: (a) => _showAyahActions(context, a, surahs),
          ),
        ),
      ),
    );
  }

  Future<void> _goToPage(BuildContext context) async {
    final page = await showDialog<int>(
      context: context,
      builder: (_) => const GoToPageDialog(),
    );
    if (page != null) _controller.jumpToPage(page - 1);
  }

  void _showAyahActions(
    BuildContext context,
    AyahRef ayah,
    List<Surah> surahs,
  ) {
    setState(() => _selected = ayah);
    final text = surahs[ayah.surah - 1].ayahs[ayah.ayah - 1];
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final bookmarked = ref.watch(bookmarksProvider).contains(ayah);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    'سورة ${surahs[ayah.surah - 1].name} · آية ${ayah.ayah}',
                  ),
                ),
                ListTile(
                  leading: Icon(
                    bookmarked ? Icons.bookmark_remove : Icons.bookmark_add,
                  ),
                  title: Text(bookmarked ? 'إزالة العلامة' : 'إضافة علامة'),
                  onTap: () {
                    ref.read(bookmarksProvider.notifier).toggle(ayah);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('نسخ نص الآية'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: text));
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Waits for the page font, then draws the page with its page number.
class _PageSlot extends ConsumerWidget {
  const _PageSlot({
    required this.page,
    required this.surahs,
    required this.selected,
    required this.onAyahTap,
    required this.onAyahLongPress,
  });

  final MushafPage page;
  final List<Surah> surahs;
  final AyahRef? selected;
  final ValueChanged<AyahRef> onAyahTap;
  final ValueChanged<AyahRef> onAyahLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fonts = ref.watch(pageFontsProvider);
    return FutureBuilder(
      future: fonts.ready(page.number),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('تعذر تحميل الصفحة\n${snapshot.error}'));
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Column(
            children: [
              Expanded(
                child: MushafPageView(
                  page: page,
                  surahName: (s) => surahs[s - 1].name,
                  selected: selected,
                  onAyahTap: onAyahTap,
                  onAyahLongPress: onAyahLongPress,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  '${page.number}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class GoToPageDialog extends StatefulWidget {
  const GoToPageDialog({super.key});

  @override
  State<GoToPageDialog> createState() => _GoToPageDialogState();
}

class _GoToPageDialogState extends State<GoToPageDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  int? get _page {
    final n = int.tryParse(_text.text);
    return n != null && n >= 1 && n <= mushafPageCount ? n : null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('انتقال إلى صفحة'),
      content: TextField(
        controller: _text,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: '1 – $mushafPageCount'),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) {
          if (_page != null) Navigator.pop(context, _page);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _page == null ? null : () => Navigator.pop(context, _page),
          child: const Text('انتقال'),
        ),
      ],
    );
  }
}
