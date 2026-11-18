import 'package:flutter/material.dart';

import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/theme/app_radius.dart';
import 'package:expense_tracker/core/theme/app_text_theme.dart';
import 'package:expense_tracker/repositories/repository.dart';

class ExpenseDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ExpenseDetailsDialog({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final description = item['description']?.toString() ?? '';
    final amount = item['amount']?.toString() ?? '';
    final isCreditExpense = isTransactionCredit(item['credit']);
    final categoryName = item['category']?['name'] ?? item['category_name'] ?? 'Uncategorized';

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.dialog,
      ),
      title: const Text(
        "Expense Details",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      content: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Description: $description",
              style: AppTextTheme.bodyLargeFor(context),
            ),
            const SizedBox(height: 8),
            Text("Amount: ₹$amount", style: AppTextTheme.bodyMediumFor(context)),
            const SizedBox(height: 8),
            Text(
              isCreditExpense ? "Type: Credit" : "Type: Debit",
              style: TextStyle(
                fontSize: 15,
                color: isCreditExpense ? AppColors.income : AppColors.expense,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text("Category: $categoryName", style: AppTextTheme.bodyMediumFor(context)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onEdit();
          },
          child: Text("Edit", style: TextStyle(color: context.appPrimary, fontWeight: FontWeight.bold)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onDelete();
          },
          child: const Text("Delete", style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Close", style: TextStyle(color: context.appTextSecondary)),
        ),
      ],
    );
  }
}
