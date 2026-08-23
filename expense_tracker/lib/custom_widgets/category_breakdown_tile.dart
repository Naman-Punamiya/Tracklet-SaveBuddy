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
                    Text(category),
                    Text(CurrencyService.formatCompact(amount)),
                  ],
                ),
                SizedBox(height: 4),
                LinearProgressIndicator(
                  value: percent / 100,
                  minHeight: 8,
                  color: color,
                  backgroundColor: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Text(
            "${percent.toStringAsFixed(0)}%",
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}
