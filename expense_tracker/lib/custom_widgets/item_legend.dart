import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class LegendBox extends StatefulWidget {
  final Color color;
  final String name;
  final double amount;

  const LegendBox({
    super.key,
    required this.color,
    required this.name,
    required this.amount,
  });

  @override
  State<LegendBox> createState() => _LegendBoxState();
}

class _LegendBoxState extends State<LegendBox> {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,

      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),

        SizedBox(width: 8),

        Text(
          "${widget.name} (₹${widget.amount.toStringAsFixed(0)})",
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
