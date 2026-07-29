import 'dart:async';
import 'dart:convert';

import 'package:expense_tracker/core/widgets/app_empty_state.dart';
import 'package:expense_tracker/core/widgets/app_loading.dart';
import 'package:expense_tracker/custom_widgets/category_icon.dart';
import 'package:expense_tracker/custom_widgets/swipe_expense_card.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/category_page.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:expense_tracker/services/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    required this.password,
  });

  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController quickCatNameController = TextEditingController();

  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;

  late Future<List<dynamic>> _expensesFuture;

  bool isCredit = false;

  String get basicAuth =>
      'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';

  final ExpenseRepository expenseRepo = ExpenseRepository();
  final CategoryRepository categoryRepo = CategoryRepository();

  List<dynamic> categories = [];
  String? selectedCategoryId;
  String? selectedCategoryName;
  List<dynamic> allExpenses = [];
  List<dynamic> filteredExpenses = [];
  bool isSearching = false;
  String selectedFilterCategory = "All";
  String selectedFilterType = "All";
  String selectedDateFilter = "All";
  String selectedSort = "Newest";
  bool isSaving = false;

  final List<CategoryIcon> availableCategoryIcons = [
    CategoryIcon("Food", Icons.fastfood_rounded),
    CategoryIcon("Transportation", Icons.directions_car_rounded),
    CategoryIcon("Shopping", Icons.shopping_bag_rounded),
    CategoryIcon("Home", Icons.home_rounded),
    CategoryIcon("Receipt", Icons.receipt_long_rounded),
    CategoryIcon("Investment", Icons.trending_up_rounded),
    CategoryIcon("Savings", Icons.account_balance_wallet_rounded),
    CategoryIcon("Utilities", Icons.lightbulb_outline_rounded),
    CategoryIcon("Healthcare", Icons.medical_services_rounded),
    CategoryIcon("Gifts", Icons.card_giftcard_rounded),
    CategoryIcon("Travel", Icons.flight_rounded),
    CategoryIcon("Education", Icons.school_rounded),
    CategoryIcon("Pets", Icons.pets_rounded),
    CategoryIcon("Person", Icons.person_rounded),
    CategoryIcon("More", Icons.more_horiz_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _expensesFuture = fetchExpenses(widget.bookId, basicAuth);
    fetchCategories();
    _triggerSync();
    _connectivitySubscription = ConnectivityService.connectivityStream.listen((
      status,
    ) {
      if (status != ConnectivityStatus.offline) {
        _triggerSync();
      }
    });
  }

  Future<void> _triggerSync() async {
    await SyncEngine.syncAll(basicAuth);
    if (mounted) {
      _reloadExpenses(resetFilters: false);
      fetchCategories();
    }
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
        bgColor = const Color(0xFFE8F6F3);
        textColor = const Color(0xFF3EAD91);
        icon = Icons.cloud_done_rounded;
        text = "Synced";
        break;
      case 2:
        bgColor = const Color(0xFFFDE8E8);
        textColor = const Color(0xFFEF4444);
        icon = Icons.cloud_off_rounded;
        text = "Sync Failed";
        break;
      case 0:
      default:
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        icon = Icons.cloud_upload_outlined;
        text = "Pending Sync";
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey<int>(status),
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
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    descriptionController.dispose();
    amountController.dispose();
    searchController.dispose();
    quickCatNameController.dispose();
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
        searchController.clear();
        isSearching = false;
      }
      _expensesFuture = fetchExpenses(widget.bookId, basicAuth);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF9FAFB),
        surfaceTintColor: const Color(0xFFF9FAFB),
        titleSpacing: 16,
        title: isSearching
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: "Search expense or category...",
                    border: InputBorder.none,
                  ),
                  onChanged: searchExpense,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.bookName,
                    style: TextStyle(
                      color: Colors.grey.shade900,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat("MMMM yyyy").format(DateTime.now()),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F6F3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              iconSize: 20,
              tooltip: "Manage Categories",
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoryPage(
                      email: widget.email,
                      password: widget.password,
                    ),
                  ),
                );
                fetchCategories();
                _reloadExpenses(resetFilters: false);
              },
              icon: const Icon(
                Icons.category_outlined,
                color: Color(0xFF3EAD91),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F6F3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              iconSize: 20,
              tooltip: "Search",
              onPressed: () {
                setState(() {
                  isSearching = !isSearching;
                  if (!isSearching) {
                    selectedFilterCategory = "All";
                    selectedFilterType = "All";
                    selectedDateFilter = "All";
                    filteredExpenses = allExpenses;
                    searchController.clear();
                    selectedSort = "Newest";
                  }
                });
              },
              icon: Icon(
                isSearching ? Icons.close_rounded : Icons.search_rounded,
                color: const Color(0xFF3EAD91),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F6F3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              iconSize: 20,
              tooltip: "Filter",
              onPressed: () {
                showFilterSheet();
              },
              icon: const Icon(Icons.tune_rounded, color: Color(0xFF3EAD91)),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F6F3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              iconSize: 20,
              tooltip: "Refresh",
              onPressed: _reloadExpenses,
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF3EAD91)),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _expensesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading();
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (allExpenses.isEmpty && snapshot.hasData) {
            allExpenses = List<dynamic>.from(snapshot.data!);
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

          if (items.isEmpty) {
            if (allExpenses.isNotEmpty) {
              return const AppEmptyState(
                icon: Icons.search_off_rounded,
                title: "No matching expenses found",
                description: "Try another category or keyword.",
              );
            }
            return AppEmptyState(
              icon: Icons.receipt_long_rounded,
              title: "No Transactions Yet",
              description: "Start by adding your first income or expense transaction.",
              buttonLabel: "Add Transaction",
              onButtonPressed: _showAddExpenseDialog,
            );
          }

          return Column(
            children: [
              // Balance Card
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3EAD91), Color(0xFF2E8B73)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x333EAD91),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total Balance",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                        child: Text(
                          "₹$balance",
                          key: ValueKey<int>(balance),
                          style: const TextStyle(
                            fontSize: 34,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.arrow_downward_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Expense",
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "₹$expense",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.arrow_upward_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Income",
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "₹$income",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Filter Chips Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      FilterChip(
                        selected: selectedDateFilter == "This Month",
                        label: const Text("This Month"),
                        avatar: Icon(
                          Icons.calendar_month_rounded,
                          size: 16,
                          color: selectedDateFilter == "This Month"
                              ? const Color(0xFF3EAD91)
                              : Colors.grey.shade600,
                        ),
                        selectedColor: const Color(0xFFE8F6F3),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: selectedDateFilter == "This Month"
                              ? const Color(0xFF3EAD91)
                              : Colors.grey.shade200,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        labelStyle: TextStyle(
                          color: selectedDateFilter == "This Month"
                              ? const Color(0xFF3EAD91)
                              : Colors.grey.shade700,
                          fontWeight: selectedDateFilter == "This Month"
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        onSelected: (_) {
                          setState(() {
                            selectedDateFilter =
                                selectedDateFilter == "This Month" ? "All" : "This Month";
                            _updateFilteredExpenses();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: selectedFilterCategory != "All",
                        label: Text(
                          selectedFilterCategory == "All"
                              ? "Categories"
                              : selectedFilterCategory,
                        ),
                        avatar: Icon(
                          Icons.category_outlined,
                          size: 16,
                          color: selectedFilterCategory != "All"
                              ? const Color(0xFF3EAD91)
                              : Colors.grey.shade600,
                        ),
                        selectedColor: const Color(0xFFE8F6F3),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: selectedFilterCategory != "All"
                              ? const Color(0xFF3EAD91)
                              : Colors.grey.shade200,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        labelStyle: TextStyle(
                          color: selectedFilterCategory != "All"
                              ? const Color(0xFF3EAD91)
                              : Colors.grey.shade700,
                          fontWeight: selectedFilterCategory != "All"
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        onSelected: (_) {
                          showFilterSheet();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: selectedFilterType == "Debit",
                        label: const Text("Debit"),
                        avatar: Icon(
                          Icons.arrow_downward_rounded,
                          size: 16,
                          color: selectedFilterType == "Debit"
                              ? const Color(0xFFEF4444)
                              : Colors.grey.shade600,
                        ),
                        selectedColor: const Color(0xFFFDE8E8),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: selectedFilterType == "Debit"
                              ? const Color(0xFFEF4444)
                              : Colors.grey.shade200,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        labelStyle: TextStyle(
                          color: selectedFilterType == "Debit"
                              ? const Color(0xFFEF4444)
                              : Colors.grey.shade700,
                          fontWeight: selectedFilterType == "Debit"
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        onSelected: (_) {
                          setState(() {
                            selectedFilterType =
                                selectedFilterType == "Debit" ? "All" : "Debit";
                            _updateFilteredExpenses();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: selectedFilterType == "Credit",
                        label: const Text("Credit"),
                        avatar: Icon(
                          Icons.arrow_upward_rounded,
                          size: 16,
                          color: selectedFilterType == "Credit"
                              ? const Color(0xFF10B981)
                              : Colors.grey.shade600,
                        ),
                        selectedColor: const Color(0xFFE6F4EA),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: selectedFilterType == "Credit"
                              ? const Color(0xFF10B981)
                              : Colors.grey.shade200,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        labelStyle: TextStyle(
                          color: selectedFilterType == "Credit"
                              ? const Color(0xFF10B981)
                              : Colors.grey.shade700,
                          fontWeight: selectedFilterType == "Credit"
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        onSelected: (_) {
                          setState(() {
                            selectedFilterType =
                                selectedFilterType == "Credit" ? "All" : "Credit";
                            _updateFilteredExpenses();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Expense List
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index] as Map<String, dynamic>;
                    final description = item['description'] ?? "";
                    final amount = item['amount'] ?? 0;
                    final dateTime = _safeParseDate(item['date']);
                    final isCredit =
                        item['credit'].toString().toLowerCase() == "true";
                    final categoryName =
                        item['category']?['name'] ??
                        item['category_name'] ??
                        "Uncategorized";
                    final categoryIconName = item['category']?['icon'];

                    final syncedVal = item['synced'];
                    final int syncedStatus = syncedVal is int
                        ? syncedVal
                        : (syncedVal == true || syncedVal == null ? 1 : 0);

                    bool showHeader = false;

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

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10, left: 6, top: 4),
                            child: Text(
                              DateFormat("EEEE, dd MMMM").format(dateTime),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ),
                        SwipeExpenseCard(
                          onEdit: () {
                            _showEditDialog(item);
                          },
                          onDelete: () async {
                            final delete = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: const Text(
                                  "Delete Expense",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                content: const Text(
                                  "Delete this expense permanently?",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text(
                                      "Cancel",
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF4444),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text("Delete"),
                                  ),
                                ],
                              ),
                            );

                            if (delete == true) {
                              await _deleteExpense(item["id"].toString());
                            }
                          },
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                _showExpenseDetails(item);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x0C000000),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    _categoryCircle(categoryName, categoryIconName),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            description,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade900,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                getIconFromName(categoryIconName ?? categoryName),
                                                size: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                categoryName,
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            DateFormat(
                                              "dd MMM • hh:mm a",
                                            ).format(dateTime),
                                            style: TextStyle(
                                              color: Colors.grey.shade400,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          _buildSyncBadge(syncedStatus),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "${isCredit ? "+" : "-"} ₹$amount",
                                          style: TextStyle(
                                            color: isCredit
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFEF4444),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Icon(
                                          isCredit
                                              ? Icons.arrow_circle_up_rounded
                                              : Icons.arrow_circle_down_rounded,
                                          color: isCredit
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFEF4444),
                                          size: 24,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_expense_fab',
        elevation: 3,
        backgroundColor: const Color(0xFF3EAD91),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        icon: const Icon(Icons.add_rounded, size: 24),
        label: const Text(
          "Add Expense",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.3,
          ),
        ),
        onPressed: _showAddExpenseDialog,
      ),
    );
  }

  Widget buildToggleButtons(void Function(void Function()) dialogSetState) {
    return ToggleButtons(
      isSelected: [!isCredit, isCredit],
      onPressed: (index) {
        dialogSetState(() {
          isCredit = index == 1;
        });
      },
      borderRadius: BorderRadius.circular(10),
      selectedColor: Colors.white,
      color: Colors.grey.shade700,
      fillColor: const Color(0xFF3EAD91),
      borderColor: Colors.grey.shade300,
      selectedBorderColor: const Color(0xFF3EAD91),
      constraints: const BoxConstraints(minHeight: 46, minWidth: 100),
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text("DEBIT", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text("CREDIT", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  int calculateTotal(List<dynamic> expenses, bool credit) {
    return expenses.fold(0, (total, item) {
      final isCreditExpense = item['credit'].toString().toLowerCase() == 'true';
      if (isCreditExpense == credit) {
        return total + (item['amount'] as num).toInt();
      }
      return total;
    });
  }

  // Dialog for Quick Create Category inline
  Future<void> _showQuickCreateCategoryDialog(
    BuildContext parentContext,
    void Function(void Function()) dialogSetState,
  ) async {
    quickCatNameController.clear();
    CategoryIcon selectedQuickIcon = availableCategoryIcons.first;
    bool isCreatingCat = false;

    await showDialog(
      context: parentContext,
      builder: (quickContext) {
        return StatefulBuilder(
          builder: (context, quickSetState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                "Create New Category",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: quickCatNameController,
                    decoration: InputDecoration(
                      labelText: "Category Name",
                      prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF3EAD91)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF3EAD91), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Select Icon",
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 160,
                    child: GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: availableCategoryIcons.length,
                      itemBuilder: (context, index) {
                        final iconItem = availableCategoryIcons[index];
                        final isSel = selectedQuickIcon.name == iconItem.name;
                        return GestureDetector(
                          onTap: () {
                            quickSetState(() {
                              selectedQuickIcon = iconItem;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSel
                                  ? const Color(0xFF3EAD91)
                                  : const Color(0xFFE8F6F3),
                            ),
                            child: Icon(
                              iconItem.icon,
                              color: isSel ? Colors.white : const Color(0xFF3EAD91),
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(quickContext),
                  child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
                ),
                ElevatedButton(
                  onPressed: isCreatingCat
                      ? null
                      : () async {
                          final name = quickCatNameController.text.trim();
                          if (name.isEmpty) return;

                          quickSetState(() {
                            isCreatingCat = true;
                          });

                          try {
                            await categoryRepo.addCategory(
                              name,
                              selectedQuickIcon.name,
                              basicAuth,
                            );

                            final updatedCats = await categoryRepo.getCategories();
                            final newCat = updatedCats.firstWhere(
                              (c) => c['name'] == name,
                              orElse: () => updatedCats.last,
                            );

                            if (mounted) {
                              setState(() {
                                categories = updatedCats;
                              });
                            }

                            dialogSetState(() {
                              selectedCategoryId = newCat['id'].toString();
                              selectedCategoryName = newCat['name'].toString();
                            });

                            if (quickContext.mounted) {
                              Navigator.pop(quickContext);
                            }
                          } catch (e) {
                            debugPrint("Quick category create error: $e");
                          } finally {
                            if (mounted) {
                              quickSetState(() {
                                isCreatingCat = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3EAD91),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isCreatingCat
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Create"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddExpenseDialog() {
    descriptionController.clear();
    amountController.clear();
    isSaving = false;

    bool dialogIsCredit = false;
    if (categories.isNotEmpty) {
      selectedCategoryId = categories.first['id'].toString();
      selectedCategoryName = categories.first['name'].toString();
    } else {
      selectedCategoryId = null;
      selectedCategoryName = null;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                "Add Expense",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              content: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: descriptionController,
                        decoration: InputDecoration(
                          labelText: "Description",
                          prefixIcon: const Icon(Icons.description_outlined, color: Color(0xFF3EAD91)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF3EAD91), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Amount",
                          prefixIcon: const Icon(Icons.currency_rupee, color: Color(0xFF3EAD91)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF3EAD91), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      ToggleButtons(
                        isSelected: [!dialogIsCredit, dialogIsCredit],
                        onPressed: (index) {
                          dialogSetState(() {
                            dialogIsCredit = index == 1;
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        selectedColor: Colors.white,
                        color: Colors.grey.shade700,
                        fillColor: const Color(0xFF3EAD91),
                        borderColor: Colors.grey.shade300,
                        selectedBorderColor: const Color(0xFF3EAD91),
                        constraints: const BoxConstraints(
                          minHeight: 46,
                          minWidth: 100,
                        ),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text("DEBIT", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text("CREDIT", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Category Dropdown + Quick Create Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedCategoryId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: "Category",
                                prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF3EAD91)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFF3EAD91), width: 1.5),
                                ),
                              ),
                              items: categories.map((category) {
                                final iconData = getIconFromName(category['icon']);
                                return DropdownMenuItem<String>(
                                  value: category['id'].toString(),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE8F6F3),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          iconData,
                                          size: 16,
                                          color: const Color(0xFF3EAD91),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          category['name'].toString(),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                dialogSetState(() {
                                  selectedCategoryId = value;
                                  selectedCategoryName = categories
                                      .firstWhere(
                                        (category) =>
                                            category['id'].toString() == value,
                                      )['name']
                                      .toString();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: "Add New Category",
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                _showQuickCreateCategoryDialog(
                                  dialogContext,
                                  dialogSetState,
                                );
                              },
                              child: Container(
                                height: 56,
                                width: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F6F3),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFF3EAD91).withValues(alpha: 0.3)),
                                ),
                                child: const Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: Color(0xFF3EAD91),
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (isSaving) return;
                          FocusScope.of(context).unfocus();

                          if (!validateExpense()) {
                            return;
                          }

                          dialogSetState(() {
                            isSaving = true;
                          });

                          final messenger = ScaffoldMessenger.of(context);
                          bool isSuccess = false;

                          try {
                            await addExpense(
                              descriptionController.text.trim(),
                              amountController.text.trim(),
                              widget.bookId,
                              dialogIsCredit,
                              selectedCategoryId,
                              selectedCategoryName,
                              basicAuth,
                            );

                            isSuccess = true;

                            if (!mounted) return;
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            _reloadExpenses(resetFilters: false);

                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text("Expense Added Successfully"),
                                backgroundColor: Color(0xFF3EAD91),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            showError("Failed to add expense");
                          } finally {
                            if (mounted) {
                              setState(() {
                                isSaving = false;
                              });
                              if (!isSuccess) {
                                dialogSetState(() {});
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3EAD91),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDialog(Map<String, dynamic> item) {
    isSaving = false;
    selectedCategoryId = item['category']?['id']?.toString() ?? item['category_id']?.toString();
    selectedCategoryName = item['category']?['name']?.toString() ?? item['category_name']?.toString();
    descriptionController.text = item['description']?.toString() ?? '';
    amountController.text = item['amount']?.toString() ?? '';
    isCredit = item['credit'].toString().toLowerCase() == 'true';

    showDialog(
      context: context,
      builder: (dialogContext) {
        void Function(void Function())? updateDialogState;

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            "Edit Expense",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          content: StatefulBuilder(
            builder: (context, dialogSetState) {
              updateDialogState = dialogSetState;
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: descriptionController,
                        decoration: InputDecoration(
                          labelText: "Description",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF3EAD91), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Amount",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF3EAD91), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      buildToggleButtons(dialogSetState),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedCategoryId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: "Category",
                                prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF3EAD91)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFF3EAD91), width: 1.5),
                                ),
                              ),
                              items: categories.map((category) {
                                final iconData = getIconFromName(category['icon']);
                                return DropdownMenuItem<String>(
                                  value: category['id'].toString(),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE8F6F3),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          iconData,
                                          size: 16,
                                          color: const Color(0xFF3EAD91),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          category['name'].toString(),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                dialogSetState(() {
                                  selectedCategoryId = value;
                                  selectedCategoryName = categories
                                      .firstWhere(
                                        (category) =>
                                            category['id'].toString() == value,
                                      )['name']
                                      .toString();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: "Add New Category",
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                _showQuickCreateCategoryDialog(
                                  dialogContext,
                                  dialogSetState,
                                );
                              },
                              child: Container(
                                height: 56,
                                width: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F6F3),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFF3EAD91).withValues(alpha: 0.3)),
                                ),
                                child: const Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: Color(0xFF3EAD91),
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (isSaving) return;
                      FocusScope.of(context).unfocus();

                      if (!validateExpense()) {
                        return;
                      }

                      updateDialogState?.call(() {
                        isSaving = true;
                      });

                      final messenger = ScaffoldMessenger.of(context);
                      bool isSuccess = false;

                      try {
                        await updateExpense(
                          item['id'].toString(),
                          descriptionController.text.trim(),
                          amountController.text.trim(),
                          isCredit,
                          selectedCategoryId,
                          basicAuth,
                        );

                        isSuccess = true;

                        if (!mounted) return;
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        _reloadExpenses(resetFilters: false);

                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text("Expense Updated Successfully"),
                            backgroundColor: Color(0xFF3EAD91),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        showError("Failed to update expense");
                      } finally {
                        if (mounted) {
                          setState(() {
                            isSaving = false;
                          });
                          if (!isSuccess) {
                            updateDialogState?.call(() {});
                          }
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3EAD91),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Save"),
            ),
          ],
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
          backgroundColor: Colors.red,
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
    final description = item['description']?.toString() ?? '';
    final amount = item['amount']?.toString() ?? '';
    final isCreditExpense = item['credit'].toString().toLowerCase() == 'true';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text("Amount: ₹$amount", style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 8),
                Text(
                  isCreditExpense ? "Type: Credit" : "Type: Debit",
                  style: TextStyle(
                    fontSize: 15,
                    color: isCreditExpense ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text("Category: ${item['category']?['name'] ?? item['category_name'] ?? 'Uncategorized'}", style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showEditDialog(item);
              },
              child: const Text("Edit", style: TextStyle(color: Color(0xFF3EAD91))),
            ),
            TextButton(
              onPressed: () async {
                await _deleteExpense(
                  item['id'].toString(),
                  dialogContext: dialogContext,
                );
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text("Close", style: TextStyle(color: Colors.grey.shade600)),
            ),
          ],
        );
      },
    );
  }

  IconData getIconFromName(String? iconName) {
    switch (iconName) {
      case "Food":
        return Icons.fastfood_rounded;
      case "Transportation":
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
      case "More":
        return Icons.more_horiz_rounded;
      default:
        return Icons.category_outlined;
    }
  }

  Widget _categoryCircle(String category, [String? iconName]) {
    Color color;

    switch (category) {
      case "Food":
        color = Colors.orange;
        break;
      case "Shopping":
        color = Colors.purple;
        break;
      case "Travel":
        color = Colors.blue;
        break;
      case "Investment":
        color = const Color(0xFF3EAD91);
        break;
      case "Utilities":
        color = Colors.teal;
        break;
      default:
        color = const Color(0xFF3EAD91);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFFE8F6F3),
        shape: BoxShape.circle,
      ),
      child: Icon(getIconFromName(iconName ?? category), color: color, size: 24),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setBottomState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Filter & Sort",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Category",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text("All"),
                        selected: selectedFilterCategory == "All",
                        selectedColor: const Color(0xFFE8F6F3),
                        labelStyle: TextStyle(
                          color: selectedFilterCategory == "All"
                              ? const Color(0xFF3EAD91)
                              : Colors.grey.shade700,
                        ),
                        onSelected: (_) {
                          setBottomState(() {
                            selectedFilterCategory = "All";
                          });
                        },
                      ),
                      ...categories.map(
                        (category) => FilterChip(
                          avatar: Icon(
                            getIconFromName(category['icon']),
                            size: 14,
                            color: selectedFilterCategory == category["name"]
                                ? const Color(0xFF3EAD91)
                                : Colors.grey.shade600,
                          ),
                          label: Text(category["name"]),
                          selected: selectedFilterCategory == category["name"],
                          selectedColor: const Color(0xFFE8F6F3),
                          labelStyle: TextStyle(
                            color: selectedFilterCategory == category["name"]
                                ? const Color(0xFF3EAD91)
                                : Colors.grey.shade700,
                          ),
                          onSelected: (_) {
                            setBottomState(() {
                              selectedFilterCategory = category["name"];
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "Type",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text("All"),
                        selected: selectedFilterType == "All",
                        selectedColor: const Color(0xFFE8F6F3),
                        labelStyle: TextStyle(
                          color: selectedFilterType == "All"
                              ? const Color(0xFF3EAD91)
                              : Colors.grey.shade700,
                        ),
                        onSelected: (_) {
                          setBottomState(() {
                            selectedFilterType = "All";
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text("Credit"),
                        selected: selectedFilterType == "Credit",
                        selectedColor: const Color(0xFFE6F4EA),
                        labelStyle: TextStyle(
                          color: selectedFilterType == "Credit"
                              ? const Color(0xFF10B981)
                              : Colors.grey.shade700,
                        ),
                        onSelected: (_) {
                          setBottomState(() {
                            selectedFilterType = "Credit";
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text("Debit"),
                        selected: selectedFilterType == "Debit",
                        selectedColor: const Color(0xFFFDE8E8),
                        labelStyle: TextStyle(
                          color: selectedFilterType == "Debit"
                              ? const Color(0xFFEF4444)
                              : Colors.grey.shade700,
                        ),
                        onSelected: (_) {
                          setBottomState(() {
                            selectedFilterType = "Debit";
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "Date",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: ["All", "Today", "This Week", "This Month"].map((
                      date,
                    ) {
                      return FilterChip(
                        label: Text(date),
                        selected: selectedDateFilter == date,
                        selectedColor: const Color(0xFFE8F6F3),
                        labelStyle: TextStyle(
                          color: selectedDateFilter == date
                              ? const Color(0xFF3EAD91)
                              : Colors.grey.shade700,
                        ),
                        onSelected: (_) {
                          setBottomState(() {
                            selectedDateFilter = date;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "Sort",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      "Newest",
                      "Oldest",
                      "Highest",
                      "Lowest",
                      "A-Z",
                      "Z-A",
                    ].map((sort) {
                      return FilterChip(
                        label: Text(sort),
                        selected: selectedSort == sort,
                        selectedColor: const Color(0xFFE8F6F3),
                        labelStyle: TextStyle(
                          color: selectedSort == sort
                              ? const Color(0xFF3EAD91)
                              : Colors.grey.shade700,
                        ),
                        onSelected: (_) {
                          setBottomState(() {
                            selectedSort = sort;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            selectedFilterCategory = "All";
                            selectedFilterType = "All";
                            selectedDateFilter = "All";
                            selectedSort = "Newest";
                            applyFilter();
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text("Reset", style: TextStyle(color: Colors.grey.shade700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            applyFilter();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3EAD91),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("Apply"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
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

      final creditValue = expense['credit'];
      final expenseIsCredit =
          creditValue.toString().toLowerCase() == "true" || creditValue == 1;
      final typeMatch =
          selectedFilterType == "All" ||
          (selectedFilterType == "Credit" && expenseIsCredit) ||
          (selectedFilterType == "Debit" && !expenseIsCredit);

      final expenseDate = _safeParseDate(expense["date"]);
      var dateMatch = true;

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
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
