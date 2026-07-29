import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AppLoading extends StatelessWidget {
  final double size;
  final Color color;

  const AppLoading({
    super.key,
    this.size = 24.0,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          color: color,
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}

class AppButtonLoading extends StatelessWidget {
  final Color color;

  const AppButtonLoading({
    super.key,
    this.color = AppColors.textWhite,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color,
      ),
    );
  }
}
