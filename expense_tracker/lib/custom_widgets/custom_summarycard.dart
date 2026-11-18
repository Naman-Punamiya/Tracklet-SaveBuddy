import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class CustomSummaryCard extends StatefulWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;

  const CustomSummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  State<CustomSummaryCard> createState() => _CustomSummaryCardState();
}

class _CustomSummaryCardState extends State<CustomSummaryCard> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: AppColors.borderDark) : null,
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0C000000), // ~5% opacity soft shadow
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: isDark ? 0.2 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, color: widget.color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "₹${widget.amount.toStringAsFixed(0)}",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : Colors.grey.shade900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
