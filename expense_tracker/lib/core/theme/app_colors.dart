import 'package:flutter/material.dart';

abstract class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF3EAD91);
  static const Color primaryTint = Color(0xFFE8F6F3);
  static const Color primaryDark = Color(0xFF2E8B73);

  // Background & Surface - Light
  static const Color lightBackground = Color(0xFFF9FAFB);
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Colors.white;

  // Background & Surface - Dark
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF242424);

  // Financial Status Colors
  static const Color income = Color(0xFF10B981);
  static const Color incomeTint = Color(0xFFE6F4EA);
  static const Color expense = Color(0xFFEF4444);
  static const Color expenseTint = Color(0xFFFDE8E8);
  static const Color warning = Color(0xFFD97706);
  static const Color warningTint = Color(0xFFFEF3C7);

  // Text Colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textWhite = Colors.white;

  // Borders & Dividers
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF374151);

  // Shadow Colors
  static const Color shadow = Color(0x0C000000);
  static const Color shadowPrimary = Color(0x333EAD91);

  // Chart Category Palette
  static const List<Color> categoryPalette = [
    Color(0xFF3EAD91),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFF3B82F6),
    Color(0xFF14B8A6),
    Color(0xFFEC4899),
    Color(0xFF6366F1),
    Color(0xFF10B981),
  ];
}

const List<Color> pieColors = [
  AppColors.primary,
  AppColors.primaryDark,
  Color(0xFF6FCF97),
  Color(0xFF8ED1B2),
  Color(0xFFB7E4C7),
  Color(0xFFD8F3DC),
];