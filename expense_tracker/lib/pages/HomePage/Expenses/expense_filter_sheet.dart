import 'package:flutter/material.dart';

import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/theme/app_radius.dart';
import 'package:expense_tracker/core/theme/app_shadows.dart';

class ExpenseFilterSheet extends StatefulWidget {
  final String initialDateFilter;
  final String initialType;
  final String initialSort;
  final String initialCategory;
  final List<dynamic> categories;
  final String bookName;
  final Function(String dateFilter, String type, String sort, String category) onApply;
  final VoidCallback onReset;

  const ExpenseFilterSheet({
    super.key,
    required this.initialDateFilter,
    required this.initialType,
    required this.initialSort,
    required this.initialCategory,
    required this.categories,
    required this.bookName,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<ExpenseFilterSheet> createState() => _ExpenseFilterSheetState();
}

class _ExpenseFilterSheetState extends State<ExpenseFilterSheet> {
  late String _selectedDateFilter;
  late String _selectedType;
  late String _selectedSort;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedDateFilter = widget.initialDateFilter;
    _selectedType = widget.initialType;
    _selectedSort = widget.initialSort;
    _selectedCategory = widget.initialCategory;
  }

  IconData _getIconFromName(String? iconName) {
    switch (iconName) {
      case "Food":
        return Icons.fastfood_rounded;
      case "Transportation":
      case "Transport":
        return Icons.directions_car_rounded;
      case "Shopping":
        return Icons.shopping_bag_rounded;
      case "Home":
        return Icons.home_rounded;
      case "Receipt":
        return Icons.receipt_long_rounded;
      case "Investment":
        return Icons.trending_up_rounded;
      case "Savings":
        return Icons.account_balance_wallet_rounded;
      case "Utilities":
        return Icons.lightbulb_outline_rounded;
      case "Healthcare":
        return Icons.medical_services_rounded;
      case "Gifts":
        return Icons.card_giftcard_rounded;
      case "Travel":
        return Icons.flight_rounded;
      case "Education":
        return Icons.school_rounded;
      case "Pets":
        return Icons.pets_rounded;
      case "Person":
        return Icons.person_rounded;
      default:
        return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: AppShadows.cardShadowList,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  borderRadius: AppRadius.pill,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Filters",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textWhite : AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? AppColors.textMuted : AppColors.textSecondary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 1. DATE RANGE Section
            Text(
              "DATE RANGE",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: isDark ? AppColors.textMuted : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.primaryTint,
                borderRadius: AppRadius.large,
              ),
              child: Row(
                children: ["This Week", "This Month", "All"].map((dateOpt) {
                  final isSelected = _selectedDateFilter == dateOpt;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDateFilter = dateOpt;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? AppColors.darkCard : AppColors.lightCard)
                              : Colors.transparent,
                          borderRadius: AppRadius.medium,
                          boxShadow: isSelected ? AppShadows.cardShadowList : null,
                        ),
                        child: Center(
                          child: Text(
                            dateOpt,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark ? AppColors.textMuted : AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // 2. TRANSACTION TYPE Section
            Text(
              "TRANSACTION TYPE",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: isDark ? AppColors.textMuted : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.primaryTint,
                borderRadius: AppRadius.large,
              ),
              child: Row(
                children: ["All", "Credit", "Debit"].map((typeOpt) {
                  final isSelected = _selectedType == typeOpt;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedType = typeOpt;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? AppColors.darkCard : AppColors.lightCard)
                              : Colors.transparent,
                          borderRadius: AppRadius.medium,
                          boxShadow: isSelected ? AppShadows.cardShadowList : null,
                        ),
                        child: Center(
                          child: Text(
                            typeOpt == "Credit" ? "Income" : typeOpt == "Debit" ? "Expense" : "All",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark ? AppColors.textMuted : AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // 3. SORT BY Section
            Text(
              "SORT BY",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: isDark ? AppColors.textMuted : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ["Newest", "Oldest", "Highest", "Lowest"].map((sortOpt) {
                  final isSelected = _selectedSort == sortOpt;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(sortOpt),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      backgroundColor: isDark ? AppColors.darkSurface : AppColors.primaryTint,
                      selectedColor: AppColors.primary,
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (_) {
                        setState(() {
                          _selectedSort = sortOpt;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // 4. CATEGORIES Section
            Text(
              "CATEGORY",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: isDark ? AppColors.textMuted : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // "All" Category Pill
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = "All";
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedCategory == "All"
                            ? AppColors.primary
                            : (isDark ? AppColors.darkSurface : AppColors.primaryTint),
                        borderRadius: AppRadius.pill,
                      ),
                      child: Text(
                        "All",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _selectedCategory == "All" ? Colors.white : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  // Individual Category Pills
                  ...widget.categories.map((cat) {
                    final catName = cat['name'].toString();
                    final isSelected = _selectedCategory == catName;
                    final iconData = _getIconFromName(cat['icon']);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = isSelected ? "All" : catName;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? AppColors.darkSurface : AppColors.primaryTint),
                          borderRadius: AppRadius.pill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              iconData,
                              size: 14,
                              color: isSelected ? Colors.white : AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              catName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 5. Actions (Reset & Apply)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      widget.onReset();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    child: Text(
                      "Reset",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply(
                        _selectedDateFilter,
                        _selectedType,
                        _selectedSort,
                        _selectedCategory,
                      );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      "Apply Filters",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
