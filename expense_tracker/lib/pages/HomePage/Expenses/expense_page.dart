import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/widgets/app_empty_state.dart';
import 'package:expense_tracker/core/widgets/app_loading.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:expense_tracker/services/auth_storage_service.dart';
import 'package:expense_tracker/services/connectivity_service.dart';
import 'package:expense_tracker/services/currency_service.dart';

import 'package:expense_tracker/pages/HomePage/Expenses/category_style_helper.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/add_edit_expense_sheet.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/expense_filter_sheet.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/expense_details_dialog.dart';

class ExpensePage extends StatefulWidget {
  final String bookId;
  final String bookName;
  final String email;
  final String password;

  const ExpensePage({
    super.key,
    required this.bookId,
    required this.bookName,
    required this.email,
    this.password = '',
  });

  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  final ExpenseRepository expenseRepo = ExpenseRepository();
  final CategoryRepository categoryRepo = CategoryRepository();

  late Future<List<dynamic>> _expensesFuture;
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;

  List<dynamic> allExpenses = [];
  List<dynamic> filteredExpenses = [];
  List<dynamic> categories = [];

  String selectedFilterCategory = "All";
  String selectedFilterType = "All";
  String selectedDateFilter = "All";
  String selectedSort = "Newest";
  int? selectedMonth;
  bool isSearching = false;

  String? selectedCategoryId;
  String? selectedCategoryName;
  bool isCredit = false;
  bool isSaving = false;

  String get basicAuth => AuthStorageService.instance.currentAuthToken.isNotEmpty
      ? AuthStorageService.instance.currentAuthToken
      : 'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';

  @override
  void initState() {
    super.initState();
    selectedMonth = DateTime.now().month;
    _expensesFuture = fetchExpenses(widget.bookId, basicAuth);
    fetchCategories();

    _connectivitySubscription =
        ConnectivityService.connectivityStream.listen((status) {
      if (status != ConnectivityStatus.offline) {
        _reloadExpenses(resetFilters: false);
      }
    });
  }

  Future<List<dynamic>> fetchExpenses(String bookId, String basicAuth) async {
    return await expenseRepo.getExpenses(bookId);
  }

  Future<void> fetchCategories() async {
    final data = await categoryRepo.getCategories();
    if (!mounted) return;
    setState(() {
      categories = data;
    });
  }

  Future<void> addExpense(
    String description,
    String amount,
    String bookId,
    bool isCredit,
    String? categoryId,
    String? categoryName,
    String basicAuth,
  ) async {
    await expenseRepo.addExpense(
      description,
      amount,
      bookId,
      isCredit,
      categoryId,
      categoryName,
      basicAuth,
    );
  }

  Future<void> updateExpense(
    String id,
    String description,
    String amount,
    bool isCredit,
    String? categoryId,
    String basicAuth,
  ) async {
    await expenseRepo.updateExpense(
      id,
      description,
      amount,
      isCredit,
      categoryId,
      basicAuth,
    );
  }

  Future<void> deleteExpense(String id, String basicAuth) async {
    await expenseRepo.deleteExpense(id, basicAuth);
  }

  Widget _buildSyncBadge(int status) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String text;

    switch (status) {
      case 1:
        bgColor = AppColors.primaryTint;
        textColor = AppColors.primary;
        icon = Icons.cloud_done_rounded;
        text = "Synced";
        break;
      case 2:
        bgColor = AppColors.expenseTint;
        textColor = AppColors.expense;
        icon = Icons.cloud_off_rounded;
        text = "Sync Failed";
        break;
      case 0:
      default:
        bgColor = AppColors.warningTint;
        textColor = AppColors.warning;
        icon = Icons.cloud_upload_outlined;
        text = "Pending Sync";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 13),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    descriptionController.dispose();
    amountController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _reloadExpenses({bool resetFilters = true}) {
    if (!mounted) return;
    setState(() {
      allExpenses.clear();
      filteredExpenses.clear();

      if (resetFilters) {
        selectedFilterCategory = "All";
        selectedFilterType = "All";
        selectedDateFilter = "All";
        selectedSort = "Newest";
        selectedMonth = DateTime.now().month;
        searchController.clear();
        isSearching = false;
      }
      _expensesFuture = fetchExpenses(widget.bookId, basicAuth);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFFBF9F4);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: _expensesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoading();
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.expense),
                    const SizedBox(height: 12),
                    const Text("Failed to load expenses"),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => _reloadExpenses(resetFilters: false),
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              );
            }

            if (allExpenses.isEmpty && snapshot.hasData) {
              allExpenses = List<dynamic>.from(snapshot.data!);
              if (selectedMonth != null &&
                  allExpenses.isNotEmpty &&
                  !allExpenses.any((e) => _safeParseDate(e['date']).month == selectedMonth)) {
                selectedMonth = null;
              }
              final query = searchController.text.trim();
              if (query.isEmpty) {
                filteredExpenses = _buildFilteredExpenses(allExpenses);
              } else {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _updateFilteredExpenses();
                });
              }
            }

            final items = filteredExpenses;
            final income = calculateTotal(items, true);
            final expense = calculateTotal(items, false);
            final balance = income - expense;

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isDark),
                  const SizedBox(height: 16),
                  _buildSummaryCard(balance, income, expense, isDark),
                  const SizedBox(height: 16),
                  _buildSearchBar(isDark),
                  const SizedBox(height: 14),
                  _buildFilterChips(isDark),
                  const SizedBox(height: 12),
                  Expanded(
                    child: items.isEmpty
                        ? (allExpenses.isNotEmpty
                            ? const AppEmptyState(
                                icon: Icons.search_off_rounded,
                                title: "No matching expenses found",
                                description: "Try another month, category or keyword.",
                              )
                            : AppEmptyState(
                                icon: Icons.receipt_long_rounded,
                                title: "No Expenses Yet",
                                description:
                                    "Start by adding your first income or expense transaction.",
                                buttonLabel: "Add Transaction",
                                onButtonPressed: _showAddExpenseDialog,
                              ))
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 90),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index] as Map<String, dynamic>;
                              final dateTime = _safeParseDate(item['date']);

                              bool showHeader = false;
                              String groupHeader = "";

                              if (index == 0) {
                                showHeader = true;
                              } else {
                                final previous = _safeParseDate(items[index - 1]['date']);
                                if (previous.day != dateTime.day ||
                                    previous.month != dateTime.month ||
                                    previous.year != dateTime.year) {
                                  showHeader = true;
                                }
                              }

                              if (showHeader) {
                                final now = DateTime.now();
                                final today = DateTime(now.year, now.month, now.day);
                                final yesterday = today.subtract(const Duration(days: 1));
                                final itemDate = DateTime(
                                  dateTime.year,
                                  dateTime.month,
                                  dateTime.day,
                                );

                                if (itemDate == today) {
                                  groupHeader = "Today";
                                } else if (itemDate == yesterday) {
                                  groupHeader = "Yesterday";
                                } else {
                                  groupHeader =
                                      DateFormat("d MMMM yyyy").format(dateTime);
                                }
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (showHeader)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: index == 0 ? 4 : 16,
                                        bottom: 8,
                                        left: 4,
                                      ),
                                      child: Text(
                                        groupHeader,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                  _buildExpenseTile(item, isDark),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF065F46),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        tooltip: 'Add Expense',
        onPressed: _showAddExpenseDialog,
        child: Stack(
          alignment: Alignment.center,
          children: const [
            Icon(Icons.add_rounded, size: 30),
            Opacity(
              opacity: 0,
              child: SizedBox(
                width: 0,
                height: 0,
                child: Text("Add Expense"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final currentMonthName = selectedMonth != null
        ? DateFormat('MMMM').format(DateTime(2026, selectedMonth!))
        : "All Months";

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.centerLeft,
            child: Icon(
              Icons.chevron_left_rounded,
              size: 28,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
        ),
        GestureDetector(
          onTap: _showMonthPickerSheet,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentMonthName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: isDark ? Colors.white70 : const Color(0xFF4B5563),
              ),
            ],
          ),
        ),
        Text(
          widget.bookName,
          style: GoogleFonts.caveat(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  void _showMonthPickerSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Select Month",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (selectedMonth != null)
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            selectedMonth = null;
                            filteredExpenses = _buildFilteredExpenses(allExpenses);
                          });
                        },
                        child: const Text("Show All Months"),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 12,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.2,
                  ),
                  itemBuilder: (context, index) {
                    final monthNum = index + 1;
                    final isCurrent = selectedMonth == monthNum;
                    final monthLabel = DateFormat('MMMM').format(DateTime(2026, monthNum));
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          selectedMonth = monthNum;
                          filteredExpenses = _buildFilteredExpenses(allExpenses);
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? const Color(0xFF0F766E)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          monthLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: isCurrent
                                ? Colors.white
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(double balance, double income, double expense, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Balance",
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.textMuted : const Color(0xFF6B7280),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          CurrencyService.format(balance),
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              "+${CurrencyService.format(income)} in",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF059669),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              "−${CurrencyService.format(expense)} out",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEDEDEA),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: searchController,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
        ),
        decoration: InputDecoration(
          hintText: "Search transactions",
          hintStyle: TextStyle(
            color: isDark ? AppColors.textMuted : const Color(0xFF6B7280),
            fontSize: 14,
          ),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  color: const Color(0xFF6B7280),
                  onPressed: () {
                    searchController.clear();
                    _updateFilteredExpenses();
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (val) {
          searchExpense(val);
        },
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    final bool isAll = selectedFilterType == "All" && selectedFilterCategory == "All";
    final bool isDebit = selectedFilterType == "Debit";
    final bool isCredit = selectedFilterType == "Credit";
    final bool hasCategory = selectedFilterCategory != "All";

    Widget buildPill({
      required String label,
      required bool isSelected,
      required VoidCallback onTap,
      Widget? trailing,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF065F46)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFEDEDEA)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF1F2937)),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                trailing,
              ],
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          buildPill(
            label: "All",
            isSelected: isAll,
            onTap: () {
              setState(() {
                selectedFilterType = "All";
                selectedFilterCategory = "All";
                filteredExpenses = _buildFilteredExpenses(allExpenses);
              });
            },
          ),
          buildPill(
            label: "Debit",
            isSelected: isDebit,
            onTap: () {
              setState(() {
                selectedFilterType = "Debit";
                filteredExpenses = _buildFilteredExpenses(allExpenses);
              });
            },
          ),
          buildPill(
            label: "Credit",
            isSelected: isCredit,
            onTap: () {
              setState(() {
                selectedFilterType = "Credit";
                filteredExpenses = _buildFilteredExpenses(allExpenses);
              });
            },
          ),
          buildPill(
            label: hasCategory ? selectedFilterCategory : "Category",
            isSelected: hasCategory,
            trailing: Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: hasCategory
                  ? Colors.white
                  : (isDark ? Colors.white70 : const Color(0xFF1F2937)),
            ),
            onTap: _showCategoryFilterPicker,
          ),
        ],
      ),
    );
  }

  void _showCategoryFilterPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Filter by Category",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text("All"),
                      selected: selectedFilterCategory == "All",
                      selectedColor: const Color(0xFF065F46),
                      labelStyle: TextStyle(
                        color: selectedFilterCategory == "All" ? Colors.white : null,
                      ),
                      onSelected: (_) {
                        Navigator.pop(ctx);
                        setState(() {
                          selectedFilterCategory = "All";
                          filteredExpenses = _buildFilteredExpenses(allExpenses);
                        });
                      },
                    ),
                    ...categories.map((cat) {
                      final name = cat['name']?.toString() ?? '';
                      final isSelected = selectedFilterCategory == name;
                      return ChoiceChip(
                        label: Text(name),
                        selected: isSelected,
                        selectedColor: const Color(0xFF065F46),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : null,
                        ),
                        onSelected: (_) {
                          Navigator.pop(ctx);
                          setState(() {
                            selectedFilterCategory = isSelected ? "All" : name;
                            filteredExpenses = _buildFilteredExpenses(allExpenses);
                          });
                        },
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpenseTile(Map<String, dynamic> item, bool isDark) {
    final description = item['description']?.toString() ?? '';
    final amount = item['amount'] ?? 0;
    final isCredit = isTransactionCredit(item['credit']);
    final categoryName = item['category']?['name']?.toString() ??
        item['category_name']?.toString() ??
        'General';
    final dateTime = _safeParseDate(item['date']);

    final style = getCategoryStyle(categoryName, isCredit);
    final amountNum = (amount as num).toDouble();
    final formattedAmount = CurrencyService.format(amountNum);
    final displayAmount = isCredit ? "+$formattedAmount" : "−$formattedAmount";
    final amountColor = isCredit
        ? const Color(0xFF059669)
        : (isDark ? Colors.white : const Color(0xFF111827));
    final timeStr = DateFormat('h:mm a').format(dateTime);

    final syncedVal = item['synced'];
    final int syncedStatus = syncedVal is int
        ? syncedVal
        : (syncedVal == true || syncedVal == null ? 1 : 0);

    return InkWell(
      onTap: () => _showExpenseDetails(item),
      onLongPress: () => _showEditDialog(item),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: style.bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                style.monogram,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: style.textColor,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (syncedStatus != 1) ...[
                    _buildSyncBadge(syncedStatus),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    "$categoryName · $timeStr",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textMuted : const Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              displayAmount,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double calculateTotal(List<dynamic> expenses, bool credit) {
    return expenses.fold(0.0, (total, item) {
      final isCreditExpense = item['credit'] == 1 ||
          item['credit'] == true ||
          item['credit'].toString().toLowerCase() == 'true';
      if (isCreditExpense == credit) {
        return total + ((item['amount'] as num?)?.toDouble() ?? 0.0);
      }
      return total;
    });
  }

  void _showAddExpenseDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return AddEditExpenseSheet(
          isEdit: false,
          bookId: widget.bookId,
          bookName: widget.bookName,
          basicAuth: basicAuth,
          categories: categories,
          onExpenseSaved: () => _reloadExpenses(resetFilters: false),
          onQuickCategoryCreated: (newCat) {
            setState(() {
              categories.add(newCat);
            });
          },
        );
      },
    );
  }

  void _showEditDialog(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return AddEditExpenseSheet(
          isEdit: true,
          existingExpense: item,
          bookId: widget.bookId,
          bookName: widget.bookName,
          basicAuth: basicAuth,
          categories: categories,
          onExpenseSaved: () => _reloadExpenses(resetFilters: false),
          onExpenseDeleted: () => _deleteExpense(item['id'].toString(), dialogContext: ctx),
          onQuickCategoryCreated: (newCat) {
            setState(() {
              categories.add(newCat);
            });
          },
        );
      },
    );
  }

  Future<void> _deleteExpense(String id, {BuildContext? dialogContext}) async {
    if (dialogContext != null && Navigator.of(dialogContext).canPop()) {
      Navigator.pop(dialogContext);
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await deleteExpense(id, basicAuth);
      if (!mounted) return;
      _reloadExpenses(resetFilters: false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Expense Deleted"),
          backgroundColor: AppColors.expense,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text("Failed to delete expense")),
      );
    }
  }

  void _showExpenseDetails(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return ExpenseDetailsDialog(
          item: item,
          onEdit: () => _showEditDialog(item),
          onDelete: () => _deleteExpense(
            item['id'].toString(),
            dialogContext: dialogContext,
          ),
        );
      },
    );
  }

  Future<void> _updateFilteredExpenses([String? query]) async {
    if (!mounted) return;
    final trimmedQuery = (query ?? searchController.text).trim();
    if (trimmedQuery.isEmpty) {
      if (!mounted) return;
      setState(() {
        filteredExpenses = _buildFilteredExpenses(allExpenses, searchQuery: "");
      });
    } else {
      final results = await expenseRepo.searchExpenses(
        widget.bookId,
        trimmedQuery,
      );
      if (!mounted) return;
      setState(() {
        filteredExpenses = _buildFilteredExpenses(
          results,
          searchQuery: trimmedQuery,
        );
      });
    }
  }

  void searchExpense(String query) {
    _updateFilteredExpenses(query);
  }

  void showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ExpenseFilterSheet(
          initialDateFilter: selectedDateFilter,
          initialType: selectedFilterType,
          initialSort: selectedSort,
          initialCategory: selectedFilterCategory,
          categories: categories,
          bookName: widget.bookName,
          onApply: (dateFilter, type, sort, category) {
            setState(() {
              selectedDateFilter = dateFilter;
              selectedFilterType = type;
              selectedSort = sort;
              selectedFilterCategory = category;
            });
            applyFilter();
          },
          onReset: () {
            setState(() {
              selectedFilterCategory = "All";
              selectedFilterType = "All";
              selectedDateFilter = "All";
              selectedSort = "Newest";
            });
            applyFilter();
          },
        );
      },
    );
  }

  void applyFilter() {
    _updateFilteredExpenses();
  }

  List<dynamic> _buildFilteredExpenses(
    List<dynamic> source, {
    String? searchQuery,
  }) {
    final now = DateTime.now();

    final filtered = source.where((expense) {
      final categoryName =
          expense['category']?['name']?.toString() ??
          expense['category_name']?.toString() ??
          "Uncategorized";
      final categoryMatch =
          selectedFilterCategory == "All" ||
          categoryName == selectedFilterCategory;

      final expenseIsCredit = isTransactionCredit(expense['credit']);
      final typeMatch =
          selectedFilterType == "All" ||
          (selectedFilterType == "Credit" && expenseIsCredit) ||
          (selectedFilterType == "Debit" && !expenseIsCredit);

      final expenseDate = _safeParseDate(expense["date"]);
      var dateMatch = true;

      if (selectedMonth != null) {
        dateMatch = (expenseDate.month == selectedMonth);
      } else {
        switch (selectedDateFilter) {
          case "Today":
            dateMatch =
                expenseDate.year == now.year &&
                expenseDate.month == now.month &&
                expenseDate.day == now.day;
            break;
          case "This Week":
            final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
            final endOfWeek = startOfWeek.add(const Duration(days: 7));
            dateMatch =
                expenseDate.isAfter(
                  startOfWeek.subtract(const Duration(seconds: 1)),
                ) &&
                expenseDate.isBefore(endOfWeek);
            break;
          case "This Month":
            dateMatch =
                expenseDate.year == now.year && expenseDate.month == now.month;
            break;
        }
      }

      return categoryMatch && typeMatch && dateMatch;
    }).toList();

    switch (selectedSort) {
      case "Newest":
        filtered.sort(
          (a, b) =>
              _safeParseDate(b["date"]).compareTo(_safeParseDate(a["date"])),
        );
        break;
      case "Oldest":
        filtered.sort(
          (a, b) =>
              _safeParseDate(a["date"]).compareTo(_safeParseDate(b["date"])),
        );
        break;
      case "Highest":
        filtered.sort((a, b) => _amountOf(b).compareTo(_amountOf(a)));
        break;
      case "Lowest":
        filtered.sort((a, b) => _amountOf(a).compareTo(_amountOf(b)));
        break;
      case "A-Z":
        filtered.sort(
          (a, b) => a["description"].toString().compareTo(
            b["description"].toString(),
          ),
        );
        break;
      case "Z-A":
        filtered.sort(
          (a, b) => b["description"].toString().compareTo(
            a["description"].toString(),
          ),
        );
        break;
    }

    final query = (searchQuery ?? searchController.text).trim().toLowerCase();
    if (query.isEmpty) {
      return filtered;
    }

    return filtered.where((expense) {
      final description = expense['description'].toString().toLowerCase();
      final category =
          (expense['category']?['name'] ?? expense['category_name'] ?? "")
              .toString()
              .toLowerCase();
      return description.contains(query) || category.contains(query);
    }).toList();
  }

  double _amountOf(dynamic expense) {
    final value = expense["amount"];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? "0") ?? 0;
  }

  DateTime _safeParseDate(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? "") ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool validateExpense() {
    final description = descriptionController.text.trim();

    if (description.isEmpty) {
      showError("Please enter a description");
      return false;
    }

    final amount = double.tryParse(amountController.text);

    if (amount == null) {
      showError("Please enter a valid amount");
      return false;
    }

    if (amount <= 0) {
      showError("Amount must be greater than 0");
      return false;
    }

    if (selectedCategoryId == null && categories.isNotEmpty) {
      showError("Please select a category");
      return false;
    }

    return true;
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.expense,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
