import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/strings.dart';
import '../notes/notes_screen.dart';
import '../recitation/recitation_picker.dart';
import '../self_test/self_test_screen.dart';
import '../settings/settings_screen.dart';
import '../shell/navigation.dart';

/// "More": the hifz self-test, recitation check, notes, bookmarks and
/// settings.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    void push(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(title: Text(t.tabMore), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          _MoreCard(
            icon: Icons.fact_check_outlined,
            label: t.selfTest,
            onTap: () => push(const SelfTestScreen()),
          ),
          _MoreCard(
            icon: Icons.mic_none,
            label: t.recitationCheck,
            onTap: () => showRecitationPicker(context),
          ),
          _MoreCard(
            icon: Icons.chat_outlined,
            label: t.myNotes,
            onTap: () => push(const NotesScreen()),
          ),
          _MoreCard(
            icon: Icons.bookmark_border,
            label: t.tabBookmarks,
            onTap: () =>
                ref.read(appTabProvider.notifier).select(AppTab.bookmarks),
          ),
          _MoreCard(
            icon: Icons.settings_outlined,
            label: t.settings,
            onTap: () => openSettings(context),
          ),
        ],
      ),
    );
  }
}

class _MoreCard extends StatelessWidget {
  const _MoreCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(icon, size: 44, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                label,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
