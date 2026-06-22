import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class RehabColors {
  static const background = Color(0xFFF8FAFF);
  static const portalBackground = Color(0xFFF4F7FE);
  static const surface = Colors.white;
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const subtle = Color(0xFF94A3B8);
  static const border = Color(0xFFE8F0FE);
  static const input = Color(0xFFF1F5FF);
  static const primary = Color(0xFF1565C0);
  static const primaryLight = Color(0xFFEEF4FF);
  static const cyan = Color(0xFF0891B2);
  static const green = Color(0xFF059669);
  static const physio = Color(0xFF52C97F);
  static const purple = Color(0xFF7C3AED);
  static const admin = Color(0xFF9B8DC8);
  static const amber = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);

  static const patientGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, cyan],
  );

  static const progressGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [purple, primary],
  );

  static const darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ink, primary],
  );
}

abstract final class RehabTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: RehabColors.primary,
      brightness: Brightness.light,
      primary: RehabColors.primary,
      secondary: RehabColors.cyan,
      surface: RehabColors.surface,
      error: RehabColors.danger,
    );
    final textTheme = GoogleFonts.plusJakartaSansTextTheme().apply(
      bodyColor: RehabColors.ink,
      displayColor: RehabColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: RehabColors.background,
      canvasColor: RehabColors.background,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: RehabColors.ink,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: RehabColors.ink,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: RehabColors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: RehabColors.border),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: RehabColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RehabColors.input,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RehabColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RehabColors.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: RehabColors.muted),
        hintStyle: const TextStyle(color: RehabColors.subtle),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: RehabColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: RehabColors.primary,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: RehabColors.primary,
          side: const BorderSide(color: RehabColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: RehabColors.primaryLight,
        selectedColor: RehabColors.primary,
        secondarySelectedColor: RehabColors.primary,
        side: const BorderSide(color: RehabColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(
          color: RehabColors.muted,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
      ),
      dividerTheme: const DividerThemeData(
        color: RehabColors.border,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: RehabColors.primary,
        linearTrackColor: RehabColors.input,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: RehabColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: RehabColors.primary,
        unselectedItemColor: RehabColors.subtle,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
