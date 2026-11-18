import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

abstract class AppTextTheme {  static const TextStyle displayLarge = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textWhite,
    letterSpacing: 0.3,
  );

  // --- Theme-aware variants -----------------------------------------------
  // These keep the original sizes/weights but resolve the text color against
  // the active theme, so the same styles stay readable in dark mode.

  static TextStyle displayLargeFor(BuildContext context) =>
      displayLarge.copyWith(color: context.appTextPrimary);

  static TextStyle headlineLargeFor(BuildContext context) =>
      headlineLarge.copyWith(color: context.appTextPrimary);

  static TextStyle titleLargeFor(BuildContext context) =>
      titleLarge.copyWith(color: context.appTextPrimary);

  static TextStyle titleMediumFor(BuildContext context) =>
      titleMedium.copyWith(color: context.appTextPrimary);

  static TextStyle bodyLargeFor(BuildContext context) =>
      bodyLarge.copyWith(color: context.appTextPrimary);

  static TextStyle bodyMediumFor(BuildContext context) =>
      bodyMedium.copyWith(color: context.appTextSecondary);

  static TextStyle bodySmallFor(BuildContext context) =>
      bodySmall.copyWith(color: context.appTextSecondary);
}
