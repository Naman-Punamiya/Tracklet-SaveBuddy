import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/theme/app_radius.dart';
import 'package:expense_tracker/core/theme/app_shadows.dart';
import 'package:flutter/material.dart';

abstract class AppDecorations {
  static final BoxDecoration card = BoxDecoration(
    color: AppColors.lightCard,
    borderRadius: AppRadius.large,
    boxShadow: AppShadows.cardShadowList,
  );

  static final BoxDecoration cardRounded20 = BoxDecoration(
    color: AppColors.lightCard,
    borderRadius: AppRadius.xLarge,
    boxShadow: AppShadows.cardShadowList,
  );

  static final BoxDecoration iconBadgeMint = const BoxDecoration(
    color: AppColors.primaryTint,
    shape: BoxShape.circle,
  );

  static final OutlineInputBorder inputBorder = OutlineInputBorder(
    borderRadius: AppRadius.medium,
    borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
  );

  static final OutlineInputBorder inputFocusedBorder = OutlineInputBorder(
    borderRadius: AppRadius.medium,
    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
  );
}
