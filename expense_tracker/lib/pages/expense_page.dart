import 'package:expense_tracker/constant.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<List<dynamic>> fetchExpenses(String bookId) async {
  final url = Uri.parse('${expenseUrl}book/$bookId'); // LAN IP for real device
  final res = await http.get(url);
  if (res.statusCode != 200) {
    throw Exception('Failed: ${res.statusCode}');
  }
  return jsonDecode(res.body) as List<dynamic>;
}

Future<void> addExpense(
  String description,
  String amount,
  String bookId,
) async {
  final url = Uri.parse('${expenseUrl}create');
  final res = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'description': description,
      'amount': double.parse(amount),
      'book': {'id': int.parse(bookId)},
    }),
  );
  if (res.statusCode != 200 && res.statusCode != 201) {
    throw Exception('Failed to add expense: ${res.statusCode}');
  }
}

Future<dynamic> deleteExpense(String id) async {
  final url = Uri.parse('${expenseUrl}delete/$id');
  final res = await http.delete(url);
  if (res.statusCode != 200) {
    throw Exception('Failed to delete expense: ${res.statusCode}');
  }
  return jsonDecode(res.body);
}

Future<dynamic> updateExpense(
  String id,
  String description,
  String amount,
) async {
  final url = Uri.parse('${expenseUrl}edit/$id');
  final res = await http.put(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'description': description, 'amount': double.parse(amount)}),
  );
  if (res.statusCode != 200 && res.statusCode != 401) {
    throw Exception('Failed to update expense: ${res.statusCode}');
  }
  return jsonDecode(res.body);
}

class ExpensePage extends StatefulWidget {
  final String bookId;
  final String bookName;

  const ExpensePage({super.key, required this.bookId, required this.bookName});

  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  TextEditingController descriptionController = TextEditingController();
  TextEditingController amountController = TextEditingController();

  // Add a reload trigger
  late Future<List<dynamic>> _expensesFuture;

  @override
  void initState() {
    super.initState();
    _expensesFuture = fetchExpenses(
      widget.bookId,
    ); // Pass bookId to fetch expenses for the specific book
  }

  void _reloadExpenses() {
    setState(() {
      _expensesFuture = fetchExpenses(
        widget.bookId,
      ); // Reload expenses for the specific book
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookName, style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _expensesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: \\${snapshot.error}'));
          }

          final items = snapshot.data ?? [];
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index] as Map<String, dynamic>;
              final description = item['description']?.toString() ?? '';
              final amount = item['amount']?.toString() ?? '';

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListTile(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: Text("Expense Details"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Description: $description"),
                            SizedBox(height: 8),
                            Text("Amount: $amount"),
                          ],
                        ),
                        actions: [
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  showDialog(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextField(
                                            controller: descriptionController
                                              ..text = description,
                                            decoration: InputDecoration(
                                              labelText: 'Description',
                                            ),
                                          ),
                                          TextField(
                                            controller: amountController
                                              ..text = amount,
                                            decoration: InputDecoration(
                                              labelText: 'Amount',
                                            ),
                                            keyboardType: TextInputType.number,
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(dialogContext);
                                          },
                                          child: Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            updateExpense(
                                              item['id'].toString(),
                                              descriptionController.text,
                                              amountController.text,
                                            ).then((_) {
                                              _reloadExpenses();
                                            });
                                            Navigator.pop(dialogContext);
                                          },
                                          child: Text("Save"),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Text("Edit"),
                              ),
                              SizedBox(width: 8),
                              TextButton(
                                onPressed: () {
                                  deleteExpense(item['id'].toString()).then((
                                    _,
                                  ) {
                                    _reloadExpenses();
                                  });
                                  Navigator.pop(dialogContext);
                                },
                                child: Text("Delete"),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                },
                                child: Text("Close"),
                              ),
                            ],
                          ),
                          // Optional: Add Edit or Delete buttons here
                        ],
                      ),
                    );
                    // Optional: Implement edit or delete functionality here
                  },
                  tileColor: Colors.grey[200],
                  title: Text(
                    description,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  trailing: Text(
                    amount,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text("Add Expense"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(labelText: 'Description'),
                  ),
                  TextField(
                    controller: amountController,
                    decoration: InputDecoration(labelText: 'Amount'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text("Cancel"),
                ),
                TextButton(
                  onPressed: () async {
                    await addExpense(
                      descriptionController.text,
                      amountController.text,
                      widget.bookId, // Pass bookId when adding an expense
                    );
                    Navigator.pop(dialogContext);
                    _reloadExpenses();
                    descriptionController.clear();
                    amountController.clear();
                  },
                  child: Text("Add"),
                ),
              ],
            ),
          );
        },
        backgroundColor: Colors.blueAccent,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
