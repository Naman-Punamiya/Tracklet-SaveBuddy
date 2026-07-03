import 'dart:convert';

import 'package:expense_tracker/constant.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/category_page.dart';
import 'package:expense_tracker/services/expense_api_service.dart';
import 'package:flutter/material.dart';
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

  final TextEditingController amountController = TextEditingController();

  late Future<List<dynamic>> _expensesFuture;

  bool isCredit = false;

  String get basicAuth =>
      'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';

  List<dynamic> categories = [];
  String? selectedCategoryId;
  String? selectedCategoryName;

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
      _expensesFuture = fetchExpenses(widget.bookId, basicAuth);
    });
  }

  // =====================================
  // TOGGLE WIDGET
  // =====================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          widget.bookName,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryPage(
                    email: widget.email,
                    password: widget.password,
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.sell_outlined,
              color: Colors.black,
              size: 28,
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search, color: Colors.black, size: 28),
          ),
          SizedBox(width: 8),
          IconButton(
            onPressed: _reloadExpenses,
            icon: const Icon(Icons.refresh, color: Colors.black, size: 28),
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

          final items = snapshot.data ?? [];
          final income = calculateTotal(items, true);
          final expense = calculateTotal(items, false);
          final balance = income - expense;
          // EMPTY
          if (items.isEmpty) {
            return const Center(child: Text("No Expenses Found"));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 2,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                  height: 75,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Income",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              '₹$income',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 45,
                          child: VerticalDivider(
                            color: Colors.black,
                            thickness: 2,
                            width: 20,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Expense",
                              style: TextStyle(fontSize: 18, color: Colors.red),
                            ),
                            Text(
                              '₹$expense',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 45,
                          child: VerticalDivider(
                            color: Colors.black,
                            thickness: 2,
                            width: 20,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Balance",
                              style: TextStyle(
                                fontSize: 18,
                                color: balance >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                            Text(
                              '₹$balance',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: balance >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,

                  itemBuilder: (context, index) {
                    final item = items[index] as Map<String, dynamic>;

                    final description = item['description']?.toString() ?? '';

                    final amount = item['amount']?.toString() ?? '';

                    final dateTime = DateTime.parse(item['date'].toString());

                    final date = DateFormat('MMMM d, yyyy').format(dateTime);

                    final isCreditExpense =
                        item['credit'].toString().toLowerCase() == 'true';

                    return Padding(
                      padding: const EdgeInsets.all(8),

                      child: ListTile(
                        shape: const Border(
                          bottom: BorderSide(color: Colors.grey, width: 1.0),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple.shade50,
                          child: Icon(
                            getIconFromName(item['category']?['icon']),
                            color: Colors.deepPurple,
                          ),
                        ),
                        title: Text(
                          description,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(date, style: TextStyle(fontSize: 14)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isCreditExpense ? '₹$amount' : '₹$amount',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isCreditExpense
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              isCreditExpense
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: isCreditExpense
                                  ? Colors.green
                                  : Colors.red,
                              size: 20,
                            ),
                          ],
                        ),
                        onTap: () {
                          _showExpenseDetails(item);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,

        onPressed: () async {
          _showAddExpenseDialog();
        },
        child: const Icon(Icons.add, color: Colors.white),
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
              title: const Text("Add Expense"),

              content: SingleChildScrollView(
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
                      decoration: const InputDecoration(
                        labelText: "Category",
                        border: OutlineInputBorder(),
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
          title: const Text("Edit Expense"),

          content: StatefulBuilder(
            builder: (context, dialogSetState) {
              return SingleChildScrollView(
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
          title: const Text("Expense Details"),

          content: Column(
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
}
