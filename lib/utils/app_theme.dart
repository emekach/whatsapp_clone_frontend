// lib/utils/app_theme.dart

import 'package:flutter/material.dart';

class AppTheme {
  // ── WhatsApp 2026 Modern Palette ────────────────────────────────
  static const primary = Color(0xFF25D366);
  static const primaryDark = Color(0xFF128C7E);
  static const surfaceGreen = Color(0xFF00A884);
  static const secondary = Color(0xFF25D366);
  static const accent = Color(0xFF34B7F1);

  // Dark Mode (Deep Charcoal)
  static const darkBg = Color(0xFF0B141A);
  static const darkSurface = Color(0xFF111B21);
  static const darkHeader = Color(0xFF202C33);
  static const darkCard = Color(0xFF202C33);
  static const darkText = Color(0xFFE9EDEF);
  static const darkTextSub = Color(0xFF8696A0);
  static const darkBubbleOut = Color(0xFF005C4B);
  static const darkBubbleIn = Color(0xFF202C33);

  // Light Mode
  static const lightBg = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFF7F8FA);
  static const lightText = Color(0xFF111B21);
  static const lightTextSub = Color(0xFF667781);
  static const lightBubbleOut = Color(0xFFE7FFDB);
  static const lightBubbleIn = Color(0xFFFFFFFF);

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primary,
        surface: darkSurface,
        onSurface: darkText,
        surfaceContainer: darkHeader,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        foregroundColor: darkText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: darkText,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkBg,
        selectedItemColor: primary,
        unselectedItemColor: darkTextSub,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: surfaceGreen,
        secondary: surfaceGreen,
        surface: lightBg,
        onSurface: lightText,
        surfaceContainer: lightSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        foregroundColor: surfaceGreen,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: surfaceGreen,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightBg,
        selectedItemColor: surfaceGreen,
        unselectedItemColor: lightTextSub,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }
}

class AppConstants {
  static const String baseUrl = 'https://test.ignisynclab.com/api';
  static const String tokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
}
