import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/strings.dart';
import '../../theme/app_theme.dart';
import '../notes/notes_screen.dart';
import '../profile/profile_screen.dart';
import '../recitation/recitation_picker.dart';
import '../self_test/self_test_screen.dart';
import '../settings/settings_screen.dart';
import 'sources_screen.dart';
import '../shell/navigation.dart';

/// "More": the hifz profile, self-test, recitation check, notes, bookmarks,
/// settings and the sources of the app's content.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    void push(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    final colors = Theme.of(context).colorScheme;
    final tiles = [
      _MoreTile(
        icon: Icons.person_rounded,
        label: t.myProfile,
        color: colors.primary,
        onTap: () => push(const ProfileScreen()),
      ),
      _MoreTile(
        icon: Icons.fact_check_rounded,
        label: t.selfTest,
        color: const Color(0xFF7B4FD6),
        onTap: () => push(const SelfTestScreen()),
      ),
      _MoreTile(
        icon: Icons.mic_rounded,
        label: t.recitationCheck,
        color: const Color(0xFFD9534F),
        onTap: () => showRecitationPicker(context),
      ),
      _MoreTile(
        icon: Icons.sticky_note_2_rounded,
        label: t.myNotes,
        color: colors.secondary,
        onTap: () => push(const NotesScreen()),
      ),
      _MoreTile(
        icon: Icons.bookmark_rounded,
        label: t.tabBookmarks,
        color: const Color(0xFF2F72D9),
        onTap: () => ref.read(appTabProvider.notifier).select(AppTab.bookmarks),
      ),
      _MoreTile(
        icon: Icons.tune_rounded,
        label: t.settings,
        color: colors.primary,
        onTap: () => openSettings(context),
      ),
      _MoreTile(
        icon: Icons.verified_rounded,
        label: t.sources,
        color: const Color(0xFF12897A),
        onTap: () => push(const SourcesScreen()),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(t.tabMore)),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: tiles,
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconBadge(icon, color: color, size: 48),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
