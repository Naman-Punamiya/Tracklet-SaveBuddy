import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/theme/app_dimensions.dart';
import 'package:expense_tracker/core/theme/app_radius.dart';
import 'package:expense_tracker/core/theme/app_spacing.dart';
import 'package:expense_tracker/core/theme/app_text_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InvestmentDialogs {
  static void showAddInvestmentDialog({
    required BuildContext context,
    required TextEditingController descriptionController,
    required TextEditingController amountController,
    required Future<void> Function(String description, double amount) onAdd,
  }) {
    descriptionController.clear();
    amountController.clear();
    String? descriptionError;
    String? amountError;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
            title: Row(
              children: const [
                Icon(
                  Icons.add_chart_rounded,
                  color: AppColors.primary,
                  size: AppDimensions.icon24,
                ),
                SizedBox(width: AppSpacing.small),
                Text("Add Investment", style: AppTextTheme.titleLarge),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descriptionController,
                  style: AppTextTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: 'Investment Name',
                    errorText: descriptionError,
                    prefixIcon: const Icon(
                      Icons.description_outlined,
                      size: AppDimensions.icon20,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: AppTextTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: 'Invested Amount (₹)',
                    errorText: amountError,
                    prefixIcon: const Icon(
                      Icons.currency_rupee_rounded,
                      size: AppDimensions.icon20,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  "Cancel",
                  style: AppTextTheme.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  dialogSetState(() {
                    descriptionError = null;
                    amountError = null;
                  });

                  final description = descriptionController.text.trim();
                  final amountText = amountController.text.trim();
                  final amount = double.tryParse(amountText);

                  bool isValid = true;
                  if (description.isEmpty) {
                    dialogSetState(() {
                      descriptionError = "Investment name must not be empty";
                    });
                    isValid = false;
                  }
                  if (amountText.isEmpty) {
                    dialogSetState(() {
                      amountError = "Amount must not be empty";
                    });
                    isValid = false;
                  } else if (amount == null || amount <= 0) {
                    dialogSetState(() {
                      amountError = "Enter a valid amount";
                    });
                    isValid = false;
                  }

                  if (!isValid) return;

                  Navigator.pop(dialogContext);
                  await onAdd(description, amount!);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textWhite,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
                ),
                child: const Text("Add"),
              ),
            ],
          );
        },
      ),
    );
  }

  static void showEditInvestmentDialog({
    required BuildContext context,
    required String id,
    required String currentInvestmentDescription,
    required double currentInvestmentAmount,
    required TextEditingController descriptionController,
    required TextEditingController amountController,
    required Future<void> Function(String id, String description, double amount) onUpdate,
  }) {
    descriptionController.text = currentInvestmentDescription;
    amountController.text = currentInvestmentAmount.toString();
    String? descriptionError;
    String? amountError;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
            title: Row(
              children: const [
                Icon(
                  Icons.edit_note_rounded,
                  color: AppColors.primary,
                  size: AppDimensions.icon24,
                ),
                SizedBox(width: AppSpacing.small),
                Text("Edit Investment", style: AppTextTheme.titleLarge),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descriptionController,
                  style: AppTextTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: 'Investment Name / Type',
                    errorText: descriptionError,
                    prefixIcon: const Icon(
                      Icons.description_outlined,
                      size: AppDimensions.icon20,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: AppTextTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: 'Invested Amount (₹)',
                    errorText: amountError,
                    prefixIcon: const Icon(
                      Icons.currency_rupee_rounded,
                      size: AppDimensions.icon20,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  "Cancel",
                  style: AppTextTheme.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  dialogSetState(() {
                    descriptionError = null;
                    amountError = null;
                  });

                  final description = descriptionController.text.trim();
                  final amountText = amountController.text.trim();
                  final amount = double.tryParse(amountText);

                  bool isValid = true;
                  if (description.isEmpty) {
                    dialogSetState(() {
                      descriptionError = "Investment name must not be empty";
                    });
                    isValid = false;
                  }
                  if (amountText.isEmpty) {
                    dialogSetState(() {
                      amountError = "Amount must not be empty";
                    });
                    isValid = false;
                  } else if (amount == null || amount <= 0) {
                    dialogSetState(() {
                      amountError = "Enter a valid amount";
                    });
                    isValid = false;
                  }

                  if (!isValid) return;

                  Navigator.pop(dialogContext);
                  await onUpdate(id, description, amount!);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textWhite,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
                ),
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  static void showInvestmentDetailsDialog({
    required BuildContext context,
    required Map<String, dynamic> item,
    required NumberFormat currencyFormat,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String name = item['description']?.toString() ?? '';
    final double amount = (item['amount'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textWhite : AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.small),
            Container(
              padding: AppSpacing.p12,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                borderRadius: AppRadius.medium,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Invested Amount:",
                    style: TextStyle(
                      color: isDark ? AppColors.textMuted : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    currencyFormat.format(amount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? AppColors.textWhite : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onEdit();
            },
            child: const Text(
              "Edit",
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onDelete();
            },
            child: const Text(
              "Delete",
              style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              "Close",
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
