import 'dart:async';
import 'dart:convert';

import 'package:expense_tracker/custom_widgets/swipe_expense_card.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:expense_tracker/services/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// =====================================
// API METHODS
// =====================================
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

  @override
  void initState() {
    super.initState();
    _expensesFuture = fetchExpenses(widget.bookId, basicAuth);
    fetchCategories();
    _triggerSync();
    _connectivitySubscription = ConnectivityService.connectivityStream.listen((status) {
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

  Future<void> addExpense(
    String description,
    String amount,
    String bookId,
    bool isCredit,
    String? categoryId,
    String? categoryName,
    String basicAuth,
  ) async {
    await expenseRepo.addExpense(description, amount, bookId, isCredit, categoryId, categoryName, basicAuth);
  }

  Future<void> updateExpense(
    String id,
    String description,
    String amount,
    bool isCredit,
    String? categoryId,
    String basicAuth,
  ) async {
    await expenseRepo.updateExpense(id, description, amount, isCredit, categoryId, basicAuth);
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
        bgColor = Colors.green.shade50;
        textColor = Colors.green;
        icon = Icons.cloud_done;
        text = "Synced";
        break;
      case 2:
        bgColor = Colors.red.shade50;
        textColor = Colors.red;
        icon = Icons.cloud_off;
        text = "Sync Failed";
        break;
      case 0:
      default:
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange;
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
            Icon(
              icon,
              color: textColor,
              size: 13,
            ),
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

    super.dispose();
  }

  // =====================================
  // RELOAD
  // =====================================

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

  // =====================================
  // TOGGLE WIDGET
  // =====================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,

        titleSpacing: 8,

        title: isSearching
            ? TextField(
                controller: searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: "Search expenses...",
                  border: InputBorder.none,
                ),
                onChanged: searchExpense,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.bookName,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_month,
                        size: 16,
                        color: Colors.grey,
                      ),

                      const SizedBox(width: 4),

                      Text(
                        DateFormat("MMMM yyyy").format(DateTime.now()),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: IconButton(
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
              icon: Icon(isSearching ? Icons.close : Icons.search),
            ),
          ),

          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () {
                showFilterSheet();
              },
              icon: const Icon(Icons.tune, color: Colors.black),
            ),
          ),

          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _reloadExpenses,
              icon: const Icon(Icons.refresh, color: Colors.black),
            ),
          ),
        ],
      ),

      body: FutureBuilder<List<dynamic>>(
        future: _expensesFuture,
        builder: (context, snapshot) {
          // LOADING
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ERROR
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (allExpenses.isEmpty && snapshot.hasData) {
            allExpenses = List<dynamic>.from(snapshot.data!);
            filteredExpenses = _buildFilteredExpenses(allExpenses);
          }

          final items = filteredExpenses;
          final income = calculateTotal(items, true);
          final expense = calculateTotal(items, false);
          final balance = income - expense;
          // EMPTY
          if (items.isEmpty) {
            if (allExpenses.isNotEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 90,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "No matching expenses found",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10), 
                    Text(
                      "Try another keyword or clear filters.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 90,
                    color: Colors.grey.shade400,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "No Expenses Yet",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "Tap the button below\nand add your first expense.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    width: double.infinity,

                    padding: const EdgeInsets.all(22),

                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),

                      gradient: const LinearGradient(
                        colors: [Color(0xff5B5FEF), Color(0xff7D6BFF)],
                      ),

                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Text(
                          "Total Balance",
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          "₹$balance",
                          style: const TextStyle(
                            fontSize: 34,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 28),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  Row(
                                    children: const [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Colors.white24,
                                        child: Icon(
                                          Icons.arrow_downward,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),

                                      SizedBox(width: 8),

                                      Text(
                                        "Expense",
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  Text(
                                    "₹$expense",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
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
                                    children: const [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Colors.white24,
                                        child: Icon(
                                          Icons.arrow_upward,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),

                                      SizedBox(width: 8),

                                      Text(
                                        "Income",
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  Text(
                                    "₹$income",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
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
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,

                  child: Row(
                    children: [
                      FilterChip(
                        selected: true,

                        label: const Text("This Month"),

                        avatar: const Icon(Icons.calendar_month, size: 18),

                        onSelected: (_) {},
                      ),

                      const SizedBox(width: 10),

                      FilterChip(
                        selected: false,

                        label: const Text("All Categories"),

                        avatar: const Icon(Icons.category, size: 18),

                        onSelected: (_) {},
                      ),

                      const SizedBox(width: 10),

                      FilterChip(
                        selected: false,

                        label: const Text("Debit"),

                        avatar: const Icon(Icons.arrow_downward, size: 18),

                        onSelected: (_) {},
                      ),

                      const SizedBox(width: 10),

                      FilterChip(
                        selected: false,

                        label: const Text("Credit"),

                        avatar: const Icon(Icons.arrow_upward, size: 18),

                        onSelected: (_) {},
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
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
                        "Other";

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
                            padding: const EdgeInsets.only(bottom: 10, left: 6),

                            child: Text(
                              DateFormat("EEEE, dd MMMM").format(dateTime),

                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
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
                                title: const Text("Delete Expense"),
                                content: const Text(
                                  "Delete this expense permanently?",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text("Cancel"),
                                  ),

                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text("Delete"),
                                  ),
                                ],
                              ),
                            );

                            if (delete == true) {
                              await _deleteExpense(item["id"].toString());
                            }
                          },

                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () {
                              _showExpenseDetails(item);
                            },
                            child: Container(
                              // Keep your existing Container exactly as it is.
                              padding: const EdgeInsets.all(18),

                              decoration: BoxDecoration(
                                color: Colors.white,

                                borderRadius: BorderRadius.circular(22),

                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),

                              child: Row(
                                children: [
                                  _categoryCircle(categoryName),

                                  const SizedBox(width: 16),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,

                                      children: [
                                        Text(
                                          description,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        const SizedBox(height: 6),

                                        Text(
                                          categoryName,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),

                                        const SizedBox(height: 4),

                                        Text(
                                          DateFormat(
                                            "dd MMM • hh:mm a",
                                          ).format(dateTime),
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 10),

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
                                              ? Colors.green
                                              : Colors.red,

                                          fontWeight: FontWeight.bold,

                                          fontSize: 22,
                                        ),
                                      ),

                                      const SizedBox(height: 10),

                                      Icon(
                                        isCredit
                                            ? Icons.arrow_circle_up
                                            : Icons.arrow_circle_down,

                                        color: isCredit
                                            ? Colors.green
                                            : Colors.red,

                                        size: 28,
                                      ),
                                    ],
                                  ),
                                ],
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
        elevation: 8,
        backgroundColor: const Color(0xff5B5FEF),
        foregroundColor: Colors.white,

        icon: const Icon(Icons.add),

        label: const Text(
          "Add Expense",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),

        onPressed: () {
          _showAddExpenseDialog();
        },
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

      borderRadius: BorderRadius.circular(8),

      selectedColor: Colors.white,
      color: Colors.grey.shade700,

      fillColor: Colors.deepPurple,

      borderColor: Colors.grey.shade400,
      selectedBorderColor: Colors.deepPurple,

      constraints: const BoxConstraints(minHeight: 50, minWidth: 110),

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

  void _showAddExpenseDialog() {
    descriptionController.clear();
    amountController.clear();
    isSaving = false;

    bool dialogIsCredit = false;
    selectedCategoryId = null;
    selectedCategoryName = null;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              backgroundColor: Colors.white,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: const Text("Add Expense"),

              content: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(10),

                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: descriptionController,
                        decoration: InputDecoration(
                          labelText: "Description",

                          prefixIcon: const Icon(Icons.description),

                          filled: true,

                          fillColor: Colors.grey.shade100,

                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Amount",

                          prefixIcon: const Icon(Icons.currency_rupee),

                          filled: true,

                          fillColor: Colors.grey.shade100,

                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      ToggleButtons(
                        isSelected: [!dialogIsCredit, dialogIsCredit],

                        onPressed: (index) {
                          dialogSetState(() {
                            dialogIsCredit = index == 1;
                          });
                        },

                        borderRadius: BorderRadius.circular(8),

                        selectedColor: Colors.white,
                        color: Colors.grey.shade700,

                        fillColor: Colors.deepPurple,

                        constraints: const BoxConstraints(
                          minHeight: 50,
                          minWidth: 110,
                        ),

                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text("DEBIT"),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text("CREDIT"),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategoryId,
                        decoration: InputDecoration(
                          labelText: "Category",

                          prefixIcon: const Icon(Icons.category),

                          filled: true,

                          fillColor: Colors.grey.shade100,

                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: categories.map((category) {
                          return DropdownMenuItem<String>(
                            value: category['id'].toString(),
                            child: Text(category['name'].toString()),
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
                    ],
                  ),
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text("Cancel"),
                ),

                TextButton(
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

                            Navigator.pop(dialogContext);
                            _reloadExpenses(resetFilters: false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Expense Added"),
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
                  child: isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
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

  Future<void> fetchCategories() async {
    final data = await categoryRepo.getCategories();
    if (!mounted) return;
    setState(() {
      categories = data;
    });
  }

  void _showEditDialog(Map<String, dynamic> item) {
    isSaving = false;
    selectedCategoryId = item['category']?['id']?.toString();
    selectedCategoryName = item['category']?['name']?.toString();

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
            borderRadius: BorderRadius.circular(28),
          ),
          title: const Text("Edit Expense"),

          content: StatefulBuilder(
            builder: (context, dialogSetState) {
              updateDialogState = dialogSetState;
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(10),

                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: "Description",
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Amount"),
                      ),

                      const SizedBox(height: 20),

                      buildToggleButtons(dialogSetState),

                      const SizedBox(height: 20),

                      DropdownButtonFormField<String>(
                        initialValue: selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: "Category",
                          border: OutlineInputBorder(),
                        ),
                        items: categories.map((category) {
                          return DropdownMenuItem<String>(
                            value: category['id'].toString(),
                            child: Row(
                              children: [
                                Icon(
                                  getIconFromName(category['icon']),
                                  color: Colors.deepPurple,
                                ),
                                const SizedBox(width: 8),
                                Text(category['name']),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          dialogSetState(() {
                            selectedCategoryId = value;
                          });
                        },
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
              child: const Text("Cancel"),
            ),

            TextButton(
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

                        Navigator.pop(dialogContext);
                        _reloadExpenses(resetFilters: false);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Expense Updated")),
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
              child: isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
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

    try {
      await deleteExpense(id, basicAuth);

      if (!mounted) return;

      _reloadExpenses(resetFilters: false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Expense Deleted")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to delete expense")));
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
            borderRadius: BorderRadius.circular(28),
          ),
          title: const Text("Expense Details"),

          content: Padding(
            padding: const EdgeInsets.all(10),

            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Description: $description"),

                const SizedBox(height: 8),

                Text("Amount: ₹$amount"),

                const SizedBox(height: 8),

                Text(isCreditExpense ? "Type: Credit" : "Type: Debit"),

                const SizedBox(height: 8),

                Text("Category: ${item['category']?['name'] ?? 'N/A'}"),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                _showEditDialog(item);
              },
              child: const Text("Edit"),
            ),

            TextButton(
              onPressed: () async {
                await _deleteExpense(
                  item['id'].toString(),
                  dialogContext: dialogContext,
                );
              },
              child: const Text("Delete"),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  IconData getIconFromName(String? iconName) {
    switch (iconName) {
      case "Food":
        return Icons.fastfood;

      case "Transportation":
        return Icons.directions_car;

      case "Shopping":
        return Icons.shopping_bag;

      case "Home":
        return Icons.home;

      case "Receipt":
        return Icons.receipt_long;

      case "Investment":
        return Icons.trending_up;

      case "Savings":
        return Icons.account_balance_wallet;

      case "Utilities":
        return Icons.lightbulb_outline;

      case "Healthcare":
        return Icons.medical_services;

      case "Gifts":
        return Icons.card_giftcard;

      case "Travel":
        return Icons.flight;

      case "Education":
        return Icons.school;

      case "Pets":
        return Icons.pets;

      case "Person":
        return Icons.person;

      case "More":
        return Icons.more_horiz;

      default:
        return Icons.category_outlined;
    }
  }

  Widget _categoryCircle(String category) {
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
        color = Colors.green;
        break;

      case "Utilities":
        color = Colors.teal;
        break;

      default:
        color = Colors.deepPurple;
    }

    return CircleAvatar(
      radius: 28,

      backgroundColor: color.withOpacity(.12),

      child: Icon(getIconFromName(category), color: color, size: 28),
    );
  }

  void searchExpense(String query) {
    if (!mounted) return;
    setState(() {
      filteredExpenses = _buildFilteredExpenses(
        allExpenses,
        searchQuery: query,
      );
    });
  }

  void showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setBottomState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Category",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 15),

                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text("All"),
                        selected: selectedFilterCategory == "All",
                        onSelected: (_) {
                          setBottomState(() {
                            selectedFilterCategory = "All";
                          });
                        },
                      ),

                      ...categories.map(
                        (category) => FilterChip(
                          label: Text(category["name"]),
                          selected: selectedFilterCategory == category["name"],
                          onSelected: (_) {
                            setBottomState(() {
                              selectedFilterCategory = category["name"];
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Type",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 15),

                  Wrap(
                    spacing: 10,
                    children: [
                      FilterChip(
                        label: const Text("All"),
                        selected: selectedFilterType == "All",
                        onSelected: (_) {
                          setBottomState(() {
                            selectedFilterType = "All";
                          });
                        },
                      ),

                      FilterChip(
                        label: const Text("Credit"),
                        selected: selectedFilterType == "Credit",
                        onSelected: (_) {
                          setBottomState(() {
                            selectedFilterType = "Credit";
                          });
                        },
                      ),

                      FilterChip(
                        label: const Text("Debit"),
                        selected: selectedFilterType == "Debit",
                        onSelected: (_) {
                          setBottomState(() {
                            selectedFilterType = "Debit";
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Date",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 15),

                  Wrap(
                    spacing: 8,
                    children: ["All", "Today", "This Week", "This Month"].map((
                      date,
                    ) {
                      return FilterChip(
                        label: Text(date),
                        selected: selectedDateFilter == date,
                        onSelected: (_) {
                          setBottomState(() {
                            selectedDateFilter = date;
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Sort",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 15),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        [
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
                            onSelected: (_) {
                              setBottomState(() {
                                selectedSort = sort;
                              });
                            },
                          );
                        }).toList(),
                  ),

                  const SizedBox(height: 25),

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
                          child: const Text("Reset"),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            applyFilter();
                            Navigator.pop(context);
                          },
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
    if (!mounted) return;
    setState(() {
      filteredExpenses = _buildFilteredExpenses(allExpenses);
    });
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
          "";
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

    if (selectedCategoryId == null) {
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
