import 'package:flutter/material.dart';

/// Colors extracted from nexusmods.gif icon
class NexusColors {
  // Core palette from icon
  static const background = Color(0xFF262526);       // dark charcoal
  static const surface = Color(0xFF2F2E2F);           // slightly lighter surface
  static const primary = Color(0xFFD58C3F);           // main orange
  static const primaryLight = Color(0xFFDA9144);      // highlight orange
  static const accent = Color(0xFFAC7434);            // dark amber
  static const warmTan = Color(0xFFDABDA0);           // muted warm accent
  static const darkBrown = Color(0xFF5E4B3A);         // dark brown
  static const midGray = Color(0xFF817F80);           // neutral gray
  static const textPrimary = Color(0xFFFCFBF9);      // cream white
  static const textSecondary = Color(0xFFDABDA0);     // warm tan for subtitles
  static const textMuted = Color(0xFF817F80);         // gray for meta text
  static const border = Color(0xFF3A393A);            // subtle border
  static const imagePlaceholder = Color(0xFF1E1D1E);  // darker than background
  static const error = Color(0xFFE74C3C);
}

ThemeData nexusTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: NexusColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: NexusColors.surface,
      foregroundColor: NexusColors.primary,
      elevation: 0,
    ),
    colorScheme: const ColorScheme.dark(
      primary: NexusColors.primary,
      secondary: NexusColors.primaryLight,
      surface: NexusColors.surface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NexusColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: NexusColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: NexusColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: NexusColors.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      labelStyle: const TextStyle(color: NexusColors.textMuted, fontSize: 12),
      hintStyle: const TextStyle(color: NexusColors.darkBrown, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: NexusColors.primary,
        foregroundColor: NexusColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
  );
}
