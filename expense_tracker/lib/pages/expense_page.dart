import 'dart:convert';

import 'package:expense_tracker/constant.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  @override
  void initState() {
    super.initState();

    _expensesFuture = fetchExpenses(widget.bookId);
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
      _expensesFuture = fetchExpenses(widget.bookId);
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
        centerTitle: true,
        title: Text(
          widget.bookName,
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
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
              Container(
                height: 85,
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Color(0xffFFBD5A),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          const Text("Expenses", style: TextStyle(fontSize: 18)),
                          Text(
                            expense.toString(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 30,
                        child: VerticalDivider(
                          color: Colors.black,
                          thickness: 2,
                          width: 20,
                        ),
                      ),
                      Column(
                        children: [
                          const Text("Income", style: TextStyle(fontSize: 18)),
                          Text(
                            income.toString(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 30,
                        child: VerticalDivider(
                          color: Colors.black,
                          thickness: 2,
                          width: 20,
                        ),
                      ),
                      Column(
                        children: [
                          const Text("Balance", style: TextStyle(fontSize: 18)),
                          Text(
                            balance.toString(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
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

                    final isCreditExpense =
                        item['credit'].toString().toLowerCase() == 'true';

                    return Padding(
                      padding: const EdgeInsets.all(8),

                      child: ListTile(
                        tileColor: Colors.grey.shade200,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),

                        title: Text(
                          description,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        trailing: Text(
                          isCreditExpense ? '+ ₹$amount' : '- ₹$amount',

                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isCreditExpense ? Colors.green : Colors.red,
                          ),
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

        onPressed: _showAddExpenseDialog,

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

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: const Text("Add Expense"),

              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: "Description"),
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
                        child: Text(
                          "DEBIT",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),

                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          "CREDIT",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
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

                    await addExpense(
                      descriptionController.text,
                      amountController.text,
                      widget.bookId,
                      dialogIsCredit,
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

  void _showEditDialog(Map<String, dynamic> item) {
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
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: "Description"),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Amount"),
                  ),

                  const SizedBox(height: 20),

                  buildToggleButtons(dialogSetState),
                ],
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

    await deleteExpense(id);

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

  Future<List<dynamic>> fetchExpenses(String bookId) async {
    final url = Uri.parse('${expenseUrl}book/$bookId');

    final res = await http.get(url, headers: {'Authorization': basicAuth});

    if (res.statusCode != 200) {
      throw Exception('Failed: ${res.statusCode}');
    }

    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<void> addExpense(
    String description,
    String amount,
    String bookId,
    bool isCredit,
  ) async {
    final url = Uri.parse('${expenseUrl}create');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': basicAuth},
      body: jsonEncode({
        'description': description,
        'amount': double.tryParse(amount) ?? 0,
        'book': {'id': int.parse(bookId)},
        'credit': isCredit,
      }),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to add expense');
    }
  }

  Future<void> updateExpense(
    String id,
    String description,
    String amount,
    bool isCredit,
  ) async {
    final url = Uri.parse('${expenseUrl}edit/$id');

    final res = await http.put(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': basicAuth},
      body: jsonEncode({
        'description': description,
        'amount': double.tryParse(amount) ?? 0,
        'isCredit': isCredit,
      }),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to update expense');
    }
  }

  Future<void> deleteExpense(String id) async {
    final url = Uri.parse('${expenseUrl}delete/$id');

    final res = await http.delete(url, headers: {'Authorization': basicAuth});

    if (res.statusCode != 200) {
      throw Exception('Failed to delete expense');
    }
  }
}
