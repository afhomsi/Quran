import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/ayah_audio.dart';
import '../../data/backup.dart';
import '../../data/khatma.dart';
import '../../data/marks.dart';
import '../../data/mushaf_text.dart';
import '../../data/recitation_history.dart';
import '../../data/reading_state.dart';
import '../../l10n/strings.dart';
import '../../settings/app_settings.dart';
import '../mushaf/text_size_sheet.dart';
import '../../theme/app_theme.dart';

void openSettings(BuildContext context) {
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
}

/// Every setting of the app, grouped by what it changes: appearance,
/// reading, reciting, language and the user's data.
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _SectionTitle(t.appearanceSection, Icons.palette_rounded),
          _Group(
            children: [
              _Switch(
                icon: Icons.dark_mode_rounded,
                title: t.nightMode,
                value: settings.nightMode,
                onChanged: (v) => update((s) => s.copyWith(nightMode: v)),
              ),
              _PageColorPicker(
                selected: settings.pageTheme,
                onSelected: (c) => update((s) => s.copyWith(pageTheme: c)),
              ),
              _Switch(
                icon: Icons.format_color_text_rounded,
                title: t.tajweed,
                value: settings.tajweedColors,
                onChanged: (v) => update((s) => s.copyWith(tajweedColors: v)),
              ),
              _Switch(
                icon: Icons.auto_awesome_rounded,
                title: t.jalala,
                value: settings.jalalaColors,
                onChanged: (v) => update((s) => s.copyWith(jalalaColors: v)),
              ),
              if (settings.jalalaColors)
                _JalalaColorPicker(
                  selected: settings.jalalaColor,
                  onSelected: (c) => update((s) => s.copyWith(jalalaColor: c)),
                ),
              _Switch(
                icon: Icons.brightness_7_rounded,
                title: t.showHizbMarks,
                value: settings.showHizbMarks,
                onChanged: (v) => update((s) => s.copyWith(showHizbMarks: v)),
              ),
              ListTile(
                leading: const IconBadge(Icons.format_size_rounded),
                title: Text(t.textSize),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: MushafTextSizeControl(),
              ),
            ],
          ),
          _SectionTitle(t.pagesSection, Icons.chrome_reader_mode_rounded),
          _Group(
            children: [
              _Switch(
                icon: Icons.swap_vert_rounded,
                title: t.verticalScroll,
                value: settings.verticalScroll,
                onChanged: (v) => update((s) => s.copyWith(verticalScroll: v)),
              ),
              _Switch(
                icon: Icons.auto_stories_rounded,
                title: t.twoPagesInLandscape,
                value: settings.twoPagesInLandscape,
                onChanged: (v) =>
                    update((s) => s.copyWith(twoPagesInLandscape: v)),
              ),
              _Switch(
                icon: Icons.autorenew_rounded,
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
                  min: minAutoPageSeconds.toDouble(),
                  max: maxAutoPageSeconds.toDouble(),
                  divisions: 19,
                  label: t.autoPageEvery(settings.autoPageSeconds),
                  onChanged: (v) =>
                      update((s) => s.copyWith(autoPageSeconds: v.round())),
                ),
              _Switch(
                icon: Icons.touch_app_rounded,
                title: t.tapOpensAyahMenu,
                value: settings.tapOpensAyahMenu,
                onChanged: (v) =>
                    update((s) => s.copyWith(tapOpensAyahMenu: v)),
              ),
              _Switch(
                icon: Icons.light_mode_rounded,
                title: t.keepScreenOn,
                value: settings.keepScreenOn,
                onChanged: (v) => update((s) => s.copyWith(keepScreenOn: v)),
              ),
            ],
          ),
          _SectionTitle(t.reciteSection, Icons.record_voice_over_rounded),
          _Group(
            children: [
              _Switch(
                icon: Icons.mic_off_rounded,
                title: t.hideRecitationButton,
                value: settings.hideRecitationButton,
                onChanged: (v) =>
                    update((s) => s.copyWith(hideRecitationButton: v)),
              ),
              _Switch(
                icon: Icons.visibility_off_rounded,
                title: t.hideWhileListening,
                value: settings.hideWhileListening,
                onChanged: (v) =>
                    update((s) => s.copyWith(hideWhileListening: v)),
              ),
            ],
          ),
          _SectionTitle(t.languageTitle, Icons.translate_rounded),
          _Group(
            children: [
              _LanguagePicker(
                selected: settings.language,
                onSelected: (l) => update((s) => s.copyWith(language: l)),
              ),
              // English is written with 123 already.
              if (settings.language != AppLanguage.en)
                _Switch(
                  icon: Icons.pin_rounded,
                  title: t.westernDigitsTitle,
                  value: settings.westernDigits,
                  onChanged: (v) => update((s) => s.copyWith(westernDigits: v)),
                ),
              _Switch(
                icon: Icons.format_size_rounded,
                title: t.followSystemFontSize,
                value: settings.followSystemFontSize,
                onChanged: (v) =>
                    update((s) => s.copyWith(followSystemFontSize: v)),
              ),
            ],
          ),
          _SectionTitle(t.dataSection, Icons.folder_rounded),
          _Group(
            children: [
              ListTile(
                leading: const IconBadge(Icons.cloud_sync_rounded),
                title: Text(t.backupRestore),
                trailing: const Icon(Icons.chevron_right_rounded),
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
  const _SectionTitle(this.text, this.icon);

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.secondary;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 22, 4, 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: color.withValues(alpha: 0.35))),
        ],
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
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 68,
                endIndent: 16,
                color: colors.outlineVariant.withValues(alpha: 0.6),
              ),
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
      secondary: IconBadge(
        icon,
        color: onChanged == null ? Theme.of(context).colorScheme.outline : null,
      ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
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
          const IconBadge(Icons.language_rounded),
          const SizedBox(width: 12),
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
      leading: const IconBadge(Icons.format_paint_rounded),
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
                            ? const Icon(
                                Icons.check_rounded,
                                color: Color(0xFF0F5B66),
                              )
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

/// The colours for the name of Allah, each shown on the word itself.
class _JalalaColorPicker extends StatelessWidget {
  const _JalalaColorPicker({required this.selected, required this.onSelected});

  final JalalaColor selected;
  final ValueChanged<JalalaColor> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(72, 0, 16, 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          for (final c in JalalaColor.values)
            Semantics(
              button: true,
              selected: c == selected,
              label: t.jalalaColorName(c),
              child: InkWell(
                key: ValueKey('jalala-color-${c.name}'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => onSelected(c),
                child: Container(
                  width: 56,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: c == selected
                          ? colors.primary
                          : colors.outlineVariant,
                      width: c == selected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    mushafDisplayText('ٱللَّهُ'),
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: mushafFont,
                      fontSize: 20,
                      height: 1.2,
                      color: c.color(dark),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
            icon: const Icon(Icons.copy_rounded),
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
            icon: const Icon(Icons.settings_backup_restore_rounded),
            label: Text(t.restore),
            onPressed: _restore,
          ),
        ],
      ),
    );
  }
}
