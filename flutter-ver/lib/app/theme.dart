import 'package:flutter/material.dart';

/// Futechi theme, converted from react-js/src/styles.css design tokens
/// and the Tailwind classes used across pages (DM Sans display, Manrope body).
class FutechiColors {
  static const primary = Color(0xFF2F6B3A); // green — tombol utama & aksen
  static const onPrimary = Color(0xFFFFFFFF);
  static const secondarySoft = Color(0xFFE8F1E6); // bg-secondary / muted
  static const background = Color(0xFFFBF9F4); // warm cream background
  static const card = Color(0xFFFFFFFF);
  static const foreground = Color(0xFF243024); // heading text
  static const mutedForeground = Color(0xFF6B7466);
  static const border = Color(0xFFE4E1D8);

  static const success = Color(0xFF2F8F46);
  static const successSoft = Color(0xFFE2F3E4);
  static const warning = Color(0xFFB97A12);
  static const warningSoft = Color(0xFFF8EEDD);
  static const danger = Color(0xFFC43D3D);
  static const dangerSoft = Color(0xFFFAE8E8);
}

class FutechiTheme {
  static ThemeData build() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: FutechiColors.primary,
        primary: FutechiColors.primary,
        onPrimary: FutechiColors.onPrimary,
        secondary: FutechiColors.primary,
        surface: FutechiColors.card,
        error: FutechiColors.danger,
      ),
      scaffoldBackgroundColor: FutechiColors.background,
    );
    final textTheme = base.textTheme.apply(
      bodyColor: FutechiColors.foreground,
      displayColor: FutechiColors.foreground,
      fontFamily: 'Manrope',
    );
    return base.copyWith(
      textTheme: textTheme.copyWith(
        displaySmall: textTheme.displaySmall
            ?.copyWith(fontFamily: 'DMSans', fontWeight: FontWeight.w700),
        displayMedium: textTheme.displayMedium
            ?.copyWith(fontFamily: 'DMSans', fontWeight: FontWeight.w700),
        headlineMedium: textTheme.headlineMedium
            ?.copyWith(fontFamily: 'DMSans', fontWeight: FontWeight.w700),
        headlineSmall: textTheme.headlineSmall
            ?.copyWith(fontFamily: 'DMSans', fontWeight: FontWeight.w700),
        titleLarge: textTheme.titleLarge
            ?.copyWith(fontFamily: 'DMSans', fontWeight: FontWeight.w700),
        titleMedium: textTheme.titleMedium
            ?.copyWith(fontFamily: 'DMSans', fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: FutechiColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: FutechiColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FutechiColors.primary,
          foregroundColor: FutechiColors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(0, 44),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FutechiColors.foreground,
          side: const BorderSide(color: FutechiColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(0, 44),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? FutechiColors.onPrimary
              : FutechiColors.card,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? FutechiColors.primary
              : FutechiColors.border,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: FutechiColors.primary,
        linearTrackColor: FutechiColors.secondarySoft,
      ),
      dividerTheme: const DividerThemeData(color: FutechiColors.border),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: FutechiColors.foreground,
        contentTextStyle: const TextStyle(color: FutechiColors.background),
      ),
    );
  }
}
