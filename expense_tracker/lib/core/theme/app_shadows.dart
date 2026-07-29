import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

abstract class AppShadows {
  static const BoxShadow card = BoxShadow(
    color: AppColors.shadow,
    blurRadius: 10,
    offset: Offset(0, 4),
  );

  static const BoxShadow fab = BoxShadow(
    color: AppColors.shadowPrimary,
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  static const List<BoxShadow> cardShadowList = [card];
  static const List<BoxShadow> fabShadowList = [fab];
}
