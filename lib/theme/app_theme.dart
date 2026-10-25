import 'package:flutter/material.dart';

/// The app's own look: deep teal with a warm gold accent, on clean white
/// cards over a soft grey (or a deep blue-green night), set in IBM Plex Sans
/// Arabic, with a floating tab bar and pill-shaped buttons.

/// The interface font, IBM Plex Sans Arabic (SIL Open Font License,
/// assets/fonts/plex). Quran text never uses it: it is drawn with the
/// mushaf's own font (see quranTextStyle).
const uiFont = 'Plex';

class AppColors {
  static const teal = Color(0xFF0F5B66);
  static const tealLight = Color(0xFF7FD0DB);
  static const gold = Color(0xFFB07D2B);
  static const goldLight = Color(0xFFE2B866);
}

ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        brightness: brightness,
      ).copyWith(
        primary: dark ? AppColors.tealLight : AppColors.teal,
        onPrimary: dark ? const Color(0xFF00363D) : Colors.white,
        primaryContainer: dark
            ? const Color(0xFF164C55)
            : const Color(0xFFCDE7EA),
        onPrimaryContainer: dark
            ? const Color(0xFFCDE7EA)
            : const Color(0xFF04363D),
        secondary: dark ? AppColors.goldLight : AppColors.gold,
        onSecondary: dark ? const Color(0xFF3D2A05) : Colors.white,
        secondaryContainer: dark
            ? const Color(0xFF4F3B12)
            : const Color(0xFFF6E7C8),
        onSecondaryContainer: dark
            ? const Color(0xFFF6E7C8)
            : const Color(0xFF3D2A05),
        surface: dark ? const Color(0xFF0E1517) : const Color(0xFFF5F6F8),
        surfaceContainerLowest: dark
            ? const Color(0xFF0A1012)
            : const Color(0xFFFFFFFF),
        surfaceContainerLow: dark
            ? const Color(0xFF131C1E)
            : const Color(0xFFFAFCFC),
        surfaceContainer: dark
            ? const Color(0xFF172124)
            : const Color(0xFFFFFFFF),
        surfaceContainerHigh: dark
            ? const Color(0xFF1D282B)
            : const Color(0xFFEEF1F3),
        surfaceContainerHighest: dark
            ? const Color(0xFF243134)
            : const Color(0xFFE3E7EA),
        onSurface: dark ? const Color(0xFFE6ECED) : const Color(0xFF1B2124),
        onSurfaceVariant: dark
            ? const Color(0xFFAAB8BA)
            : const Color(0xFF5D686C),
        outlineVariant: dark
            ? const Color(0xFF2E3D40)
            : const Color(0xFFE3E7EA),
      );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  );
  final pill = WidgetStatePropertyAll<OutlinedBorder>(const StadiumBorder());
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: uiFont,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: uiFont,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
      actionsIconTheme: IconThemeData(color: scheme.primary),
    ),
    navigationBarTheme: NavigationBarThemeData(
      // Drawn inside the floating card of AppNavigationBar.
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 66,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 26,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: uiFont,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: dark ? 0 : 1,
      shadowColor: const Color(0x1F0B2A30),
      color: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: rounded,
    ),
    listTileTheme: ListTileThemeData(iconColor: scheme.primary),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: pill,
        minimumSize: const WidgetStatePropertyAll(Size(64, 46)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w600),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        shape: pill,
        minimumSize: const WidgetStatePropertyAll(Size(64, 46)),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 3,
      shape: const StadiumBorder(),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: rounded,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? scheme.onPrimary : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) &&
                !states.contains(WidgetState.disabled)
            ? scheme.primary
            : null,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: scheme.surfaceContainerHighest,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      indicatorColor: scheme.secondary,
      dividerColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

/// A small rounded square with an icon on a tinted background, used before
/// the rows of the settings and the tools.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color, this.size = 36});

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: c, size: size * 0.58),
    );
  }
}
