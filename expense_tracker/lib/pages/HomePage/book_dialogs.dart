import 'package:flutter/material.dart';

import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/theme/app_text_theme.dart';

class BookDialogs {
  static void showAddBookDialog({
    required BuildContext context,
    required TextEditingController nameController,
    required TextEditingController subtitleController,
    required Future<void> Function(String name, String subtitle) onAdd,
  }) {
    nameController.clear();
    subtitleController.clear();
    String? nameError;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text(
              "Add Book",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: "Book Name",
                    hintText: "e.g. Personal Expenses, Travel",
                    errorText: nameError,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF0A7A3E), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: subtitleController,
                  decoration: InputDecoration(
                    labelText: "Book Subtitle",
                    hintText: "Optional short note or tag",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF0A7A3E), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final trimmedName = nameController.text.trim();
                  if (trimmedName.isEmpty) {
                    dialogSetState(() {
                      nameError = "Book name must not be empty";
                    });
                    return;
                  }

                  Navigator.pop(dialogContext);
                  await onAdd(trimmedName, subtitleController.text.trim());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A7A3E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Add"),
              ),
            ],
          );
        },
      ),
    );
  }

  static void showEditBookDialog({
    required BuildContext context,
    required String id,
    required String currentName,
    required String currentSubtitle,
    required TextEditingController nameController,
    required TextEditingController subtitleController,
    required Future<void> Function(String id, String name, String subtitle) onUpdate,
  }) {
    nameController.text = currentName;
    subtitleController.text = currentSubtitle;
    String? nameError;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text(
              "Edit Book",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Book Name",
                    errorText: nameError,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF0A7A3E), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: subtitleController,
                  decoration: InputDecoration(
                    labelText: "Book Subtitle",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF0A7A3E), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final trimmedName = nameController.text.trim();
                  if (trimmedName.isEmpty) {
                    dialogSetState(() {
                      nameError = "Book name must not be empty";
                    });
                    return;
                  }

                  Navigator.pop(dialogContext);
                  await onUpdate(id, trimmedName, subtitleController.text.trim());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A7A3E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  static void showBookDetails({
    required BuildContext context,
    required Map<String, dynamic> item,
    required VoidCallback onEdit,
    required VoidCallback onArchive,
    required VoidCallback onDelete,
  }) {
    final String bookName = item['name']?.toString() ?? '';
    final String bookSubtitle = item['subtitle']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Book Options",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Book Name: $bookName", style: AppTextTheme.bodyLarge),
            if (bookSubtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text("Subtitle: $bookSubtitle", style: AppTextTheme.bodyMedium),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onEdit();
            },
            child: const Text("Edit", style: TextStyle(color: Color(0xFF0A7A3E), fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              showDialog(
                context: context,
                builder: (confirmContext) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: const Text("Manage Book", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  content: const Text("Choose an action for this expense book:", style: TextStyle(fontSize: 15)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(confirmContext),
                      child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(confirmContext);
                        onArchive();
                      },
                      child: const Text("Archive", style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(confirmContext);
                        onDelete();
                      },
                      child: const Text("Delete", style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
            child: const Text("Delete / Archive", style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Close", style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
