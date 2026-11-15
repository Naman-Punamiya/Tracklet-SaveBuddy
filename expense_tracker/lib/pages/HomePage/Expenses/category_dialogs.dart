import 'package:flutter/material.dart';

import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/theme/app_radius.dart';
import 'package:expense_tracker/core/widgets/app_loading.dart';
import 'package:expense_tracker/custom_widgets/category_icon.dart';

class CategoryDialogs {
  static void showAddCategoryDialog({
    required BuildContext context,
    required TextEditingController nameController,
    required List<CategoryIcon> categoryIcons,
    required Future<void> Function(String name, String icon) onAdd,
  }) {
    nameController.clear();
    CategoryIcon selectedIcon = categoryIcons.first;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
              title: const Text(
                "Add Category",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: "Category Name",
                          prefixIcon: const Icon(Icons.category_outlined, color: AppColors.primary),
                          border: OutlineInputBorder(borderRadius: AppRadius.medium),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppRadius.medium,
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Select Icon",
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: categoryIcons.length,
                          itemBuilder: (context, index) {
                            final iconItem = categoryIcons[index];
                            final isSelected = selectedIcon.name == iconItem.name;

                            return GestureDetector(
                              onTap: () {
                                dialogSetState(() {
                                  selectedIcon = iconItem;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.primaryTint,
                                  border: isSelected
                                      ? Border.all(color: AppColors.primary, width: 2)
                                      : null,
                                ),
                                child: Icon(
                                  iconItem.icon,
                                  color: isSelected ? AppColors.textWhite : AppColors.primary,
                                  size: 22,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please enter a category name"),
                                backgroundColor: AppColors.expense,
                              ),
                            );
                            return;
                          }

                          dialogSetState(() => isSaving = true);
                          Navigator.pop(dialogContext);
                          await onAdd(name, selectedIcon.name);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textWhite,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
                  ),
                  child: isSaving ? const AppButtonLoading() : const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static void showEditCategoryDialog({
    required BuildContext context,
    required Map<String, dynamic> item,
    required TextEditingController nameController,
    required List<CategoryIcon> categoryIcons,
    required Future<void> Function(String id, String name, String icon) onUpdate,
  }) {
    nameController.text = item['name']?.toString() ?? '';
    final initialIconName = item['icon']?.toString() ?? 'Food';
    CategoryIcon selectedIcon = categoryIcons.firstWhere(
      (icon) => icon.name == initialIconName,
      orElse: () => categoryIcons.first,
    );
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
              title: const Text(
                "Edit Category",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: "Category Name",
                          prefixIcon: const Icon(Icons.category_outlined, color: AppColors.primary),
                          border: OutlineInputBorder(borderRadius: AppRadius.medium),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppRadius.medium,
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Select Icon",
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: categoryIcons.length,
                          itemBuilder: (context, index) {
                            final iconItem = categoryIcons[index];
                            final isSelected = selectedIcon.name == iconItem.name;

                            return GestureDetector(
                              onTap: () {
                                dialogSetState(() {
                                  selectedIcon = iconItem;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.primaryTint,
                                  border: isSelected
                                      ? Border.all(color: AppColors.primary, width: 2)
                                      : null,
                                ),
                                child: Icon(
                                  iconItem.icon,
                                  color: isSelected ? AppColors.textWhite : AppColors.primary,
                                  size: 22,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please enter a category name"),
                                backgroundColor: AppColors.expense,
                              ),
                            );
                            return;
                          }

                          dialogSetState(() => isSaving = true);
                          Navigator.pop(dialogContext);
                          await onUpdate(item['id'].toString(), name, selectedIcon.name);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textWhite,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
                  ),
                  child: isSaving ? const AppButtonLoading() : const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static void confirmDeleteCategory({
    required BuildContext context,
    required Map<String, dynamic> item,
    required Future<void> Function(String id) onDelete,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: const Text("Delete Category", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete '${item['name']}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await onDelete(item['id'].toString());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}
