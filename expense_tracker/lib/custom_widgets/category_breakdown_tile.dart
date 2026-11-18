import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/services/currency_service.dart';
import 'package:flutter/material.dart';

class CategoryBreakdownTile extends StatelessWidget {
  final String category;
  final double amount;
  final double percent;
  final Color color;

  const CategoryBreakdownTile({
    super.key,
    required this.category,
    required this.amount,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final accentColor =
        isDark ? Color.lerp(color, Colors.white, 0.35)! : color;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color,
            // child: Icon(icon, color: Colors.white),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(category, style: TextStyle(color: textColor)),
                    Text(
                      CurrencyService.formatCompact(amount),
                      style: TextStyle(color: textColor),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                LinearProgressIndicator(
                  value: percent / 100,
                  minHeight: 8,
                  color: color,
                  backgroundColor: isDark
                      ? AppColors.borderDark
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Text(
            "${percent.toStringAsFixed(0)}%",
            style: TextStyle(color: accentColor),
          ),
        ],
      ),
    );
  }
}
