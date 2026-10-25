import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/strings.dart';
import '../../theme/app_theme.dart';
import '../audio/reciters_screen.dart';
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
        icon: Icons.record_voice_over_rounded,
        label: t.reciters,
        color: const Color(0xFF12897A),
        onTap: () => openReciters(context),
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
        crossAxisCount: 3,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.0,
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconBadge(icon, color: color, size: 48),
              const SizedBox(height: 10),
              // Large system text shrinks the label instead of overflowing.
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
