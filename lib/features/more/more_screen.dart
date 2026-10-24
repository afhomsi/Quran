import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notes/notes_screen.dart';
import '../recitation/recitation_picker.dart';
import '../self_test/self_test_screen.dart';
import '../shell/navigation.dart';

/// "More": the hifz self-test, notes, bookmarks and recitation check.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void push(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(title: const Text('المزيد'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          _MoreCard(
            icon: Icons.fact_check_outlined,
            label: 'اختبار ذاتي للحفظ',
            onTap: () => push(const SelfTestScreen()),
          ),
          _MoreCard(
            icon: Icons.mic_none,
            label: 'تسميع مع تنبيه الأخطاء',
            onTap: () => showRecitationPicker(context),
          ),
          _MoreCard(
            icon: Icons.chat_outlined,
            label: 'تعليقاتي',
            onTap: () => push(const NotesScreen()),
          ),
          _MoreCard(
            icon: Icons.bookmark_border,
            label: 'علاماتي',
            onTap: () =>
                ref.read(appTabProvider.notifier).select(AppTab.bookmarks),
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
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(label, style: theme.textTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }
}
