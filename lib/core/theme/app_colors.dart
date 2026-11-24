import 'package:flutter/material.dart';

/// Semantic brand colors and centralized palette for ExpenCircle.
/// Single source of truth for the app's visual styling.
class AppColors {
  AppColors._();

  // --- Primary Brand: Imperial Pine Green (Darker Green) ---
  static const Color primary = Color(0xFF006948);
  static const Color primaryDark = Color(0xFF004D34);
  static const Color primaryDeep = Color(0xFF003825);
  static const Color primaryContainer = Color(0xFF00855D);
  static const Color onPrimary = Colors.white;
  static const Color onPrimaryContainer = Color(0xFFF5FFF7);
  static const Color primaryLight = Color(0xFFE8F5E9);
  static const Color primaryFill = Color(0xFFF0FDF4);
  static const Color primaryBorder = Color(0xFFA7F3D0);
  static const Color primaryBorderMedium = Color(0xFF6EE7B7);

  // --- Secondary: Electric Indigo ---
  static const Color secondary = Color(0xFF4B41E1);
  static const Color secondaryContainer = Color(0xFF645EFB);
  static const Color onSecondary = Colors.white;

  // --- Tertiary: Ocean Teal ---
  static const Color tertiary = Color(0xFF008096);
  static const Color tertiaryContainer = Color(0xFF00A2BE);

  // --- Backgrounds & Surfaces ---
  static const Color background = Color(0xFFFAF8FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF4F6F9);

  // --- Text & Typography ---
  static const Color textPrimary = Color(0xFF131B2E);
  static const Color textSecondary = Color(0xFF3D4A42);
  static const Color textMuted = Color(0xFF6D7A72);

  // --- Outlines & Dividers ---
  static const Color outline = Color(0xFF6D7A72);
  static const Color outlineVariant = Color(0xFFBCCAC0);
  static const Color borderSubtle = Color(0x0A000000);

  // --- Status & Accents ---
  static const Color success = Color(0xFF006948);
  static const Color successDark = Color(0xFF004D34);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color successFill = Color(0xFFF0FDF4);
  static const Color successBorder = Color(0xFFA7F3D0);
  static const Color onSuccess = Colors.white;

  // Accents & Badges
  static const Color accentMint = Color(0xFF85F8C4);
  static const Color onAccentMint = Color(0xFF002114);
  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningBorder = Color(0xFFFDE68A);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color errorBorder = Color(0xFFFECACA);
}
