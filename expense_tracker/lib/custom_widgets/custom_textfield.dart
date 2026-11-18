import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/theme/app_dimensions.dart';
import 'package:expense_tracker/core/theme/app_radius.dart';
import 'package:expense_tracker/core/theme/app_spacing.dart';
import 'package:expense_tracker/core/theme/app_text_theme.dart';
import 'package:flutter/material.dart';

class CustomTextfield extends StatefulWidget {
  final TextEditingController textEditingController;
  final String hintText;
  final IconData icon;
  final bool isPassword;

  const CustomTextfield({
    super.key,
    required this.textEditingController,
    required this.hintText,
    required this.icon,
    required this.isPassword,
  });

  @override
  State<CustomTextfield> createState() => _CustomTextfieldState();
}

class _CustomTextfieldState extends State<CustomTextfield> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    TextInputType keyboardType = TextInputType.text;
    if (widget.isPassword) {
      keyboardType = TextInputType.visiblePassword;
    } else if (widget.hintText.toLowerCase().contains('email')) {
      keyboardType = TextInputType.emailAddress;
    }

    return TextField(
      controller: widget.textEditingController,
      obscureText: widget.isPassword ? _obscureText : false,
      keyboardType: keyboardType,
      style: AppTextTheme.bodyLarge.copyWith(
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
      ),
      cursorColor: isDark ? AppColors.primaryAccent : AppColors.primary,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: AppTextTheme.bodyMedium.copyWith(
          color: AppColors.textMuted,
        ),
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: AppSpacing.medium, right: AppSpacing.xSmall),
          child: Icon(widget.icon, color: iconColor, size: AppDimensions.icon22),
        ),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: iconColor,
                  size: AppDimensions.icon22,
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          vertical: AppSpacing.medium,
          horizontal: AppSpacing.medium,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: BorderSide(
            color: isDark ? AppColors.primaryAccent : AppColors.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
