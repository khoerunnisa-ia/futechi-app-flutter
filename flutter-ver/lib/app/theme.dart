import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Futechi theme, converted from react-js/src/styles.css design tokens
/// and the Tailwind classes used across pages.
///
/// Tipografi: Space Grotesk untuk heading (display/headline/title),
/// DM Sans untuk body/label, lewat paket google_fonts.
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
  /// Skala ukuran font:
  /// - displaySmall 30 — judul hero, angka besar
  /// - headlineSmall 24 — judul halaman, nilai statistik
  /// - titleLarge 20 — judul section/kartu
  /// - titleMedium 17 — sub-judul kartu
  /// - bodyLarge 15, bodyMedium 14 (default), bodySmall 12 (caption), labelSmall 11
  static TextTheme buildTextTheme(TextTheme base) {
    TextStyle heading(TextStyle? style, double size) =>
        GoogleFonts.spaceGrotesk(textStyle: style).copyWith(
          fontSize: size,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: FutechiColors.foreground,
        );
    TextStyle body(TextStyle? style, double size,
            [FontWeight weight = FontWeight.w400]) =>
        GoogleFonts.dmSans(textStyle: style).copyWith(
          fontSize: size,
          fontWeight: weight,
          color: FutechiColors.foreground,
        );
    return base.copyWith(
      displayLarge: heading(base.displayLarge, 40),
      displayMedium: heading(base.displayMedium, 34),
      displaySmall: heading(base.displaySmall, 30),
      headlineLarge: heading(base.headlineLarge, 28),
      headlineMedium: heading(base.headlineMedium, 26),
      headlineSmall: heading(base.headlineSmall, 24),
      titleLarge: heading(base.titleLarge, 20),
      titleMedium: heading(base.titleMedium, 17),
      titleSmall: body(base.titleSmall, 15, FontWeight.w600),
      bodyLarge: body(base.bodyLarge, 15),
      bodyMedium: body(base.bodyMedium, 14),
      bodySmall: body(base.bodySmall, 12),
      labelLarge: body(base.labelLarge, 14, FontWeight.w600),
      labelMedium: body(base.labelMedium, 12, FontWeight.w600),
      labelSmall: body(base.labelSmall, 11, FontWeight.w600),
    );
  }

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
    final textTheme = buildTextTheme(base.textTheme);
    return base.copyWith(
      textTheme: textTheme,
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
      appBarTheme: AppBarTheme(titleTextStyle: textTheme.titleLarge),
      dividerTheme: const DividerThemeData(color: FutechiColors.border),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: FutechiColors.foreground,
        contentTextStyle: TextStyle(color: FutechiColors.background),
      ),
    );
  }
}
