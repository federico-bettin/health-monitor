import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ─── Palette principale ───────────────────────────────────
  static const Color primary = Color(0xFF5B8DEF);
  static const Color primaryDark = Color(0xFF3A6FD8);
  static const Color secondary = Color(0xFF00E5A0);
  static const Color error = Color(0xFFFF4D6A);
  static const Color warning = Color(0xFFFFB347);

  // ─── Dark surfaces ────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF09090F);
  static const Color surfaceDark = Color(0xFF13131F);
  static const Color cardDark = Color(0xFF1A1A2A);
  static const Color borderDark = Color(0xFF2A2A3A);

  // ─── Light surfaces ───────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF4F6FB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);

  // ─── Testo dark ───────────────────────────────────────────
  static const Color textPrimaryDark = Color(0xFFE8EAF2);
  static const Color textSecondaryDark = Color(0xFF7B7F9E);
  static const Color textSecondaryLight = Color(0xFF6C757D);
  static const Color textPrimaryLight = Color(0xFF1A1A2E);

  // ─── Dark Theme (default) ────────────────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: primary,
          secondary: secondary,
          error: error,
          surface: surfaceDark,
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onSurface: textPrimaryDark,
          outline: borderDark,
        ),
        scaffoldBackgroundColor: backgroundDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundDark,
          foregroundColor: textPrimaryDark,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textPrimaryDark,
          ),
        ),
        cardTheme: CardThemeData(
          color: cardDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: borderDark, width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: borderDark),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: borderDark),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          labelStyle: const TextStyle(color: textSecondaryDark),
          hintStyle: const TextStyle(color: textSecondaryDark),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
            textStyle: const TextStyle(
              fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: primary),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: textPrimaryDark),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textPrimaryDark),
          headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: textPrimaryDark),
          headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimaryDark),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimaryDark),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textPrimaryDark),
          titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textSecondaryDark, letterSpacing: 0.5),
          bodyLarge: TextStyle(fontSize: 16, color: textPrimaryDark),
          bodyMedium: TextStyle(fontSize: 14, color: textPrimaryDark),
          bodySmall: TextStyle(fontSize: 12, color: textSecondaryDark),
          labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimaryDark),
        ),
        dividerTheme: const DividerThemeData(color: borderDark, thickness: 1),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surfaceDark,
          selectedItemColor: primary,
          unselectedItemColor: textSecondaryDark,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: borderDark)),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: cardDark,
          contentTextStyle: const TextStyle(color: textPrimaryDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: textSecondaryDark,
          textColor: textPrimaryDark,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? primary : textSecondaryDark),
          trackColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? primary.withOpacity(0.4) : borderDark),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? primary : Colors.transparent),
          side: const BorderSide(color: textSecondaryDark),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      );

  // ─── Light Theme ─────────────────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
          primary: primary,
          secondary: secondary,
          error: error,
          surface: surfaceLight,
        ),
        scaffoldBackgroundColor: backgroundLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: surfaceLight,
          foregroundColor: textPrimaryLight,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter', fontSize: 20,
            fontWeight: FontWeight.w600, color: textPrimaryLight),
        ),
        cardTheme: CardThemeData(
          color: cardLight,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: backgroundLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primary, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary, foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: textPrimaryLight),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textPrimaryLight),
          headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: textPrimaryLight),
          headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimaryLight),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimaryLight),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textPrimaryLight),
          bodyLarge: TextStyle(fontSize: 16, color: textPrimaryLight),
          bodyMedium: TextStyle(fontSize: 14, color: textPrimaryLight),
          bodySmall: TextStyle(fontSize: 12, color: textSecondaryLight),
          labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimaryLight),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surfaceLight,
          selectedItemColor: primary,
          unselectedItemColor: textSecondaryLight,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary, foregroundColor: Colors.white, elevation: 4),
      );
}
