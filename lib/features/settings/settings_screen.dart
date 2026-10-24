import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/ayah_audio.dart';
import '../../data/backup.dart';
import '../../data/khatma.dart';
import '../../data/marks.dart';
import '../../data/recitation_history.dart';
import '../../data/reading_state.dart';
import '../../l10n/strings.dart';
import '../../settings/app_settings.dart';

void openSettings(BuildContext context) {
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
}

/// Every setting of the app, grouped as in the screenshots Ahmad shared:
/// language, pages, notes and data. Settings that need data the app does
/// not have yet are shown greyed out as "coming soon".
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final t = S.of(context);
    void update(AppSettings Function(AppSettings) change) =>
        ref.read(settingsProvider.notifier).update(change);

    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionTitle(t.languageTitle),
          _Group(
            children: [
              _LanguagePicker(
                selected: settings.language,
                onSelected: (l) => update((s) => s.copyWith(language: l)),
              ),
            ],
          ),
          _SectionTitle(t.pagesSection),
          _Group(
            children: [
              _Switch(
                icon: Icons.dark_mode,
                title: t.nightMode,
                value: settings.nightMode,
                onChanged: (v) => update((s) => s.copyWith(nightMode: v)),
              ),
              _PageColorPicker(
                selected: settings.pageTheme,
                onSelected: (c) => update((s) => s.copyWith(pageTheme: c)),
              ),
              _Switch(
                icon: Icons.auto_stories_outlined,
                title: t.twoPagesInLandscape,
                value: settings.twoPagesInLandscape,
                onChanged: (v) =>
                    update((s) => s.copyWith(twoPagesInLandscape: v)),
              ),
              _ComingSoon(
                icon: Icons.play_circle_outline,
                title: t.playerOnTouch,
              ),
              _Switch(
                icon: Icons.autorenew,
                title: t.autoPageTurn,
                subtitle: settings.autoPageTurn
                    ? t.autoPageEvery(settings.autoPageSeconds)
                    : null,
                value: settings.autoPageTurn,
                onChanged: (v) => update((s) => s.copyWith(autoPageTurn: v)),
              ),
              if (settings.autoPageTurn)
                Slider(
                  value: settings.autoPageSeconds.toDouble(),
                  min: 15,
                  max: 300,
                  divisions: 19,
                  label: t.autoPageEvery(settings.autoPageSeconds),
                  onChanged: (v) =>
                      update((s) => s.copyWith(autoPageSeconds: v.round())),
                ),
              _Switch(
                icon: Icons.swap_vert,
                title: t.verticalScroll,
                value: settings.verticalScroll,
                onChanged: (v) => update((s) => s.copyWith(verticalScroll: v)),
              ),
              _Switch(
                icon: Icons.brush_outlined,
                title: t.tajweed,
                value: settings.tajweedColors,
                onChanged: (v) => update((s) => s.copyWith(tajweedColors: v)),
              ),
              _Switch(
                icon: Icons.touch_app_outlined,
                title: t.tapOpensAyahMenu,
                value: settings.tapOpensAyahMenu,
                onChanged: (v) =>
                    update((s) => s.copyWith(tapOpensAyahMenu: v)),
              ),
              _Switch(
                icon: Icons.screen_lock_portrait_outlined,
                title: t.keepScreenOn,
                value: settings.keepScreenOn,
                onChanged: (v) => update((s) => s.copyWith(keepScreenOn: v)),
              ),
              _ComingSoon(icon: Icons.topic_outlined, title: t.thematicTafsir),
              // English is written with 123 already.
              if (settings.language != AppLanguage.en)
                _Switch(
                  icon: Icons.tag,
                  title: t.westernDigitsTitle,
                  value: settings.westernDigits,
                  onChanged: (v) => update((s) => s.copyWith(westernDigits: v)),
                ),
              _Switch(
                icon: Icons.text_fields,
                title: t.followSystemFontSize,
                value: settings.followSystemFontSize,
                onChanged: (v) =>
                    update((s) => s.copyWith(followSystemFontSize: v)),
              ),
              _Switch(
                icon: Icons.mic_off_outlined,
                title: t.hideRecitationButton,
                value: settings.hideRecitationButton,
                onChanged: (v) =>
                    update((s) => s.copyWith(hideRecitationButton: v)),
              ),
              _Switch(
                icon: Icons.brightness_7_outlined,
                title: t.showHizbMarks,
                value: settings.showHizbMarks,
                onChanged: (v) => update((s) => s.copyWith(showHizbMarks: v)),
              ),
              _ComingSoon(icon: Icons.checklist, title: t.plansInAyahMenu),
            ],
          ),
          _SectionTitle(t.notesSection),
          _Group(
            children: [
              _ComingSoon(icon: Icons.text_format, title: t.advancedEditor),
            ],
          ),
          _SectionTitle(t.dataSection),
          _Group(
            children: [
              ListTile(
                leading: const Icon(Icons.settings_backup_restore),
                title: Text(t.backupRestore),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const BackupScreen())),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 24, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.brightness == Brightness.dark
              ? const Color(0xFFD9BC8C)
              : const Color(0xFFA9874F),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// A rounded card of settings with thin lines between them.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// A setting that needs data the app does not have yet.
class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => _Switch(
    icon: icon,
    title: title,
    subtitle: S.of(context).comingSoon,
    value: false,
    onChanged: null,
  );
}

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.selected, required this.onSelected});

  final AppLanguage selected;
  final ValueChanged<AppLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.language, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          for (final l in AppLanguage.values)
            Expanded(
              child: TextButton(
                onPressed: () => onSelected(l),
                style: TextButton.styleFrom(
                  foregroundColor: l == selected
                      ? colors.primary
                      : colors.onSurface,
                  backgroundColor: l == selected
                      ? colors.primaryContainer
                      : null,
                ),
                child: FittedBox(
                  child: Text(
                    l.nativeName,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PageColorPicker extends StatelessWidget {
  const _PageColorPicker({required this.selected, required this.onSelected});

  final PageTheme selected;
  final ValueChanged<PageTheme> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: Text(t.pageColor),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final p in PageTheme.values)
                  Semantics(
                    button: true,
                    selected: p == selected,
                    label: p.name,
                    child: InkWell(
                      key: ValueKey('page-color-${p.name}'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onSelected(p),
                      child: Container(
                        width: 48,
                        height: 36,
                        decoration: BoxDecoration(
                          color: p.color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: p == selected
                                ? colors.primary
                                : colors.outlineVariant,
                            width: p == selected ? 2 : 1,
                          ),
                        ),
                        child: p == selected
                            ? const Icon(Icons.check, color: Color(0xFF6B5A2E))
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            if (dark) ...[
              const SizedBox(height: 4),
              Text(t.pageColorInNightMode),
            ],
          ],
        ),
      ),
    );
  }
}

/// Copies the user's data as text, or restores it from pasted text.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _pasted = TextEditingController();

  @override
  void dispose() {
    _pasted.dispose();
    super.dispose();
  }

  void _say(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _copy() async {
    final text = exportBackup(ref.read(sharedPreferencesProvider));
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _say(S.of(context).backupCopied);
  }

  Future<void> _restore() async {
    final t = S.of(context);
    final ok = await importBackup(
      ref.read(sharedPreferencesProvider),
      _pasted.text,
    );
    if (!mounted) return;
    if (!ok) return _say(t.invalidBackup);
    // Stop any recitation: the player's choices are restored too.
    await ref.read(audioProvider.notifier).close();
    if (!mounted) return;
    ref
      ..invalidate(settingsProvider)
      ..invalidate(bookmarksProvider)
      ..invalidate(lastPageProvider)
      ..invalidate(markersProvider)
      ..invalidate(highlightsProvider)
      ..invalidate(notesProvider)
      ..invalidate(khatmaPlansProvider)
      ..invalidate(recitationHistoryProvider)
      ..invalidate(audioProvider);
    _pasted.clear();
    // The language may have changed, so say it in the restored one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _say(S.of(context).backupRestored);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.backupRestore)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t.backupExplain),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.copy),
            label: Text(t.copyBackup),
            onPressed: _copy,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _pasted,
            minLines: 3,
            maxLines: 6,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: t.pasteBackup,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.settings_backup_restore),
            label: Text(t.restore),
            onPressed: _restore,
          ),
        ],
      ),
    );
  }
}
