import 'package:flutter/material.dart';

abstract class AppColors {
  // Brand Colors - Emerald Trust
  static const Color primary = Color(0xFF059669);
  static const Color primaryLight = Color(0xFF10B981);
  static const Color primaryTint = Color(0xFFECFDF5);
  static const Color primaryDark = Color(0xFF047857);
  static const Color primaryAccent = Color(0xFF34D399);

  // Background & Surface - Light
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Colors.white;

  // Background & Surface - Dark (Slate)
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF1E293B);

  // Financial Status Colors
  static const Color income = Color(0xFF10B981);
  static const Color incomeTint = Color(0xFFD1FAE5);
  static const Color expense = Color(0xFFEF4444);
  static const Color expenseTint = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningTint = Color(0xFFFEF3C7);

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textWhite = Colors.white;

  // Borders & Dividers
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF334155);

  // Shadow Colors
  static const Color shadow = Color(0x0C000000);
  static const Color shadowPrimary = Color(0x33059669);

  // Hero Gradients
  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF047857)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Chart Category Palette
  static const List<Color> categoryPalette = [
    Color(0xFF059669),
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
  Color(0xFF10B981),
  Color(0xFF34D399),
  Color(0xFF6EE7B7),
  Color(0xFFA7F3D0),
];