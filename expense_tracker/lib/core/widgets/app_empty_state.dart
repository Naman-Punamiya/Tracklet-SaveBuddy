import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/theme/app_dimensions.dart';
import 'package:expense_tracker/core/theme/app_radius.dart';
import 'package:expense_tracker/core/theme/app_spacing.dart';
import 'package:expense_tracker/core/theme/app_text_theme.dart';
import 'package:flutter/material.dart';

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? buttonLabel;
  final VoidCallback? onButtonPressed;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.buttonLabel,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.p32,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: AppSpacing.p24,
              decoration: const BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppDimensions.icon72,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xLarge),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextTheme.headlineLarge,
            ),
            const SizedBox(height: AppSpacing.xSmall),
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTextTheme.bodyMedium.copyWith(height: 1.4),
            ),
            if (buttonLabel != null && onButtonPressed != null) ...[
              const SizedBox(height: AppSpacing.xxLarge),
              SizedBox(
                width: 180,
                height: AppDimensions.buttonHeight50,
                child: ElevatedButton.icon(
                  onPressed: onButtonPressed,
                  icon: const Icon(Icons.add_rounded, color: AppColors.textWhite, size: AppDimensions.icon22),
                  label: Text(
                    buttonLabel!,
                    style: AppTextTheme.buttonText,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.medium,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
