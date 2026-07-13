import 'dart:convert';

import 'package:expense_tracker/constant.dart';
import 'package:expense_tracker/services/expense_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:http/http.dart' as http;
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

  late Future<List<dynamic>> _expensesFuture;

  bool isCredit = false;

  String get basicAuth =>
      'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';

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

  @override
  void initState() {
    super.initState();
    syncExpenses(basicAuth);
    _expensesFuture = fetchExpenses(widget.bookId, basicAuth);
    fetchCategories();
  }

  @override
  void dispose() {
    descriptionController.dispose();
    amountController.dispose();

    super.dispose();
  }

  // =====================================
  // RELOAD
  // =====================================

  void _reloadExpenses() {
    setState(() {
      allExpenses.clear();

      filteredExpenses.clear();

      selectedFilterCategory = "All";
      selectedFilterType = "All";
      selectedDateFilter = "All";
      selectedSort = "Newest";

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
            allExpenses = snapshot.data!;
            filteredExpenses = snapshot.data!;
          }

          final items = filteredExpenses;
          final income = calculateTotal(items, true);
          final expense = calculateTotal(items, false);
          final balance = income - expense;
          // EMPTY
          if (items.isEmpty) {
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

                    final dateTime = DateTime.parse(item['date']);

                    final isCredit =
                        item['credit'].toString().toLowerCase() == "true";

                    final categoryName =
                        item['category']?['name'] ??
                        item['category_name'] ??
                        "Other";

                    final synced = item['synced'] == null
                        ? true
                        : item['synced'] == 1;

                    bool showHeader = false;

                    if (index == 0) {
                      showHeader = true;
                    } else {
                      final previous = DateTime.parse(items[index - 1]['date']);

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

                        Slidable(
                          key: ValueKey(item['id']),

                          // Swipe Right
                          startActionPane: ActionPane(
                            motion: const StretchMotion(), // Rubber-band effect

                            dismissible: DismissiblePane(
                              onDismissed: () {
                                _showEditDialog(item);
                              },
                            ),

                            children: [
                              CustomSlidableAction(
                                onPressed: (_) => _showEditDialog(item),

                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(22),
                                  ),

                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.edit_outlined,
                                        color: Colors.white,
                                        size: 32,
                                      ),

                                      SizedBox(height: 10),

                                      Text(
                                        "Edit",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Swipe Left
                          endActionPane: ActionPane(
                            motion: const StretchMotion(),

                            dismissible: DismissiblePane(
                              onDismissed: () async {
                                final delete = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text("Delete Expense"),
                                    content: const Text(
                                      "Are you sure you want to delete this expense?",
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
                                  await deleteExpense(
                                    item['id'].toString(),
                                    basicAuth,
                                  );

                                  _reloadExpenses();
                                }
                              },
                            ),

                            children: [
                              CustomSlidableAction(
                                onPressed: (_) async {
                                  final delete = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("Delete Expense"),
                                      content: const Text(
                                        "Are you sure you want to delete this expense?",
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
                                    await deleteExpense(
                                      item['id'].toString(),
                                      basicAuth,
                                    );
                                    _reloadExpenses();
                                  }
                                },

                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(22),
                                  ),

                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.delete_outline,
                                        color: Colors.white,
                                        size: 32,
                                      ),

                                      SizedBox(height: 10),

                                      Text(
                                        "Delete",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
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

                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),

                                          decoration: BoxDecoration(
                                            color: synced
                                                ? Colors.green.shade50
                                                : Colors.orange.shade50,

                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),

                                          child: Text(
                                            synced ? "☁ Synced" : "📱 Local",

                                            style: TextStyle(
                                              color: synced
                                                  ? Colors.green
                                                  : Colors.orange,

                                              fontSize: 12,

                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
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
                          print("Categories count: ${categories.length}");
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
                  onPressed: () async {
                    if (selectedCategoryId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please select a category"),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext);

                    await addExpense(
                      descriptionController.text,
                      amountController.text,
                      widget.bookId,
                      dialogIsCredit,
                      selectedCategoryId,
                      selectedCategoryName,
                      basicAuth,
                    );

                    _reloadExpenses();
                  },
                  child: const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> fetchCategories() async {
    final url = Uri.parse('${categoryUrl}readAll');

    final res = await http.get(url, headers: {'Authorization': basicAuth});
    print(jsonDecode(res.body));
    if (res.statusCode == 200) {
      if (!mounted) return;
      setState(() {
        categories = jsonDecode(res.body);
      });
      print(categories);
    } else {
      throw Exception("Failed to load categories");
    }
  }

  void _showEditDialog(Map<String, dynamic> item) {
    selectedCategoryId = item['category']?['id']?.toString();
    selectedCategoryName = item['category']?['name']?.toString();

    isCredit = item['credit'].toString().toLowerCase() == 'true';

    descriptionController.text = item['description']?.toString() ?? '';

    amountController.text = item['amount']?.toString() ?? '';

    isCredit = item['credit'].toString().toLowerCase() == 'true';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: const Text("Edit Expense"),

          content: StatefulBuilder(
            builder: (context, dialogSetState) {
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
              onPressed: () async {
                Navigator.pop(dialogContext);

                await updateExpense(
                  item['id'].toString(),
                  descriptionController.text,
                  amountController.text,
                  isCredit,
                  selectedCategoryId,
                  basicAuth,
                );

                if (!mounted) return;

                _reloadExpenses();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Expense Updated")),
                );
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteExpense(String id, BuildContext dialogContext) async {
    Navigator.pop(dialogContext);

    await deleteExpense(id, basicAuth);

    if (!mounted) return;

    _reloadExpenses();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Expense Deleted")));
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
                await _deleteExpense(item['id'].toString(), dialogContext);
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
    setState(() {
      if (query.isEmpty) {
        selectedFilterCategory = "All";
        selectedFilterType = "All";
        selectedDateFilter = "All";
        filteredExpenses = allExpenses;
      } else {
        List<dynamic> source = allExpenses.where((expense) {
          bool categoryMatch =
              selectedFilterCategory == "All" ||
              (expense['category']?['name'] ?? expense['category_name']) ==
                  selectedFilterCategory;

          bool isCredit =
              expense['credit'].toString().toLowerCase() == "true" ||
              expense['credit'] == 1;

          bool typeMatch =
              selectedFilterType == "All" ||
              (selectedFilterType == "Credit" && isCredit) ||
              (selectedFilterType == "Debit" && !isCredit);

          return categoryMatch && typeMatch;
        }).toList();

        filteredExpenses = source.where((expense) {
          final description = expense['description'].toString().toLowerCase();

          final category =
              (expense['category']?['name'] ?? expense['category_name'] ?? "")
                  .toString()
                  .toLowerCase();

          return description.contains(query.toLowerCase()) ||
              category.contains(query.toLowerCase());
        }).toList();
      }
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
                            setState(() {
                              selectedFilterCategory = "All";
                              selectedFilterType = "All";
                              selectedDateFilter = "All";
                              filteredExpenses = allExpenses;
                              selectedSort = "Newest";
                            });

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
    setState(() {
      // Step 1: Filter
      filteredExpenses = allExpenses.where((expense) {
        // Category Filter
        bool categoryMatch =
            selectedFilterCategory == "All" ||
            (expense['category']?['name']?.toString() ??
                    expense['category_name']?.toString() ??
                    "") ==
                selectedFilterCategory;

        // Type Filter
        bool isCredit =
            expense['credit'].toString().toLowerCase() == "true" ||
            expense['credit'] == 1;

        bool typeMatch =
            selectedFilterType == "All" ||
            (selectedFilterType == "Credit" && isCredit) ||
            (selectedFilterType == "Debit" && !isCredit);

        // Date Filter
        DateTime expenseDate = DateTime.parse(expense["date"]);
        DateTime now = DateTime.now();

        bool dateMatch = true;

        switch (selectedDateFilter) {
          case "Today":
            dateMatch =
                expenseDate.year == now.year &&
                expenseDate.month == now.month &&
                expenseDate.day == now.day;
            break;

          case "This Week":
            DateTime startOfWeek = now.subtract(
              Duration(days: now.weekday - 1),
            );

            dateMatch = expenseDate.isAfter(
              startOfWeek.subtract(const Duration(days: 1)),
            );
            break;

          case "This Month":
            dateMatch =
                expenseDate.year == now.year && expenseDate.month == now.month;
            break;

          default:
            dateMatch = true;
        }

        return categoryMatch && typeMatch && dateMatch;
      }).toList();

      // Step 2: Sort
      switch (selectedSort) {
        case "Newest":
          filteredExpenses.sort(
            (a, b) =>
                DateTime.parse(b["date"]).compareTo(DateTime.parse(a["date"])),
          );
          break;

        case "Oldest":
          filteredExpenses.sort(
            (a, b) =>
                DateTime.parse(a["date"]).compareTo(DateTime.parse(b["date"])),
          );
          break;

        case "Highest":
          filteredExpenses.sort(
            (a, b) => (b["amount"] as num).compareTo(a["amount"] as num),
          );
          break;

        case "Lowest":
          filteredExpenses.sort(
            (a, b) => (a["amount"] as num).compareTo(b["amount"] as num),
          );
          break;

        case "A-Z":
          filteredExpenses.sort(
            (a, b) => a["description"].toString().compareTo(
              b["description"].toString(),
            ),
          );
          break;

        case "Z-A":
          filteredExpenses.sort(
            (a, b) => b["description"].toString().compareTo(
              a["description"].toString(),
            ),
          );
          break;
      }
    });
  }
}
