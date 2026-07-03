import 'dart:convert';
import 'package:expense_tracker/constant.dart';
import 'package:expense_tracker/database/database_helper.dart';
import 'package:http/http.dart' as http;

Future<List<dynamic>> fetchExpenses(String bookId, dynamic basicAuth) async {
  final dbHelper = DatabaseHelper();
  try {
    final url = Uri.parse('${expenseUrl}book/$bookId');
    final res = await http.get(url, headers: {'Authorization': basicAuth});
    if (res.statusCode != 200) {
      throw Exception('Failed: ${res.statusCode}');
    }
    return jsonDecode(res.body) as List<dynamic>;
  } catch (e) {
    print("Loading from Local Database");
    final localExpenses = await dbHelper.getAllExpenses();
    return localExpenses;
  }
}

Future<void> addExpense(
  String description,
  String amount,
  String bookId,
  bool isCredit,
  String? categoryId,
  String? categoryName,
  dynamic basicAuth,
) async {
  final dbHelper = DatabaseHelper();
  await dbHelper.insertExpense(
    description: description,
    amount: double.tryParse(amount) ?? 0,
    credit: isCredit,
    date: DateTime.now().toIso8601String(),
    categoryId: int.parse(categoryId!),
    categoryName: categoryName ?? "Uncategorized",
    bookId: int.parse(bookId),
  );
  final expenses = await dbHelper.getAllExpenses();
  print(expenses);
  try {
    final url = Uri.parse('${expenseUrl}create');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': basicAuth},
      body: jsonEncode({
        'description': description,
        'amount': double.tryParse(amount) ?? 0,
        'credit': isCredit,
        'date': DateTime.now().toIso8601String(),
        'book': {'id': int.parse(bookId)},
        'category': {'id': int.parse(categoryId)},
      }),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      print("Cloud sync successful");
    } else {
      print("Stored locally, cloud failed");
    }
  } catch (e) {
    print(e);
  }
}

Future<void> updateExpense(
  String id,
  String description,
  String amount,
  bool isCredit,
  String? categoryId,
  dynamic basicAuth,
) async {
  final url = Uri.parse('${expenseUrl}edit/$id');

  final res = await http.put(
    url,
    headers: {'Content-Type': 'application/json', 'Authorization': basicAuth},
    body: jsonEncode({
      'description': description,
      'amount': double.tryParse(amount) ?? 0,
      'credit': isCredit,
      'date': DateTime.now().toIso8601String(),
      'category': {'id': int.parse(categoryId!)},
    }),
  );
  if (res.statusCode != 200 && res.statusCode != 201) {
    throw Exception('Failed to update expense');
  }
}

Future<void> deleteExpense(String id, dynamic basicAuth) async {
  final url = Uri.parse('${expenseUrl}delete/$id');

  final res = await http.delete(url, headers: {'Authorization': basicAuth});

  if (res.statusCode != 200) {
    throw Exception('Failed to delete expense');
  }
}

Future<void> syncExpenses(String basicAuth) async {
  final dbHelper = DatabaseHelper();
  final expenses = await dbHelper.getUnsyncedExpenses();
  for (final expense in expenses) {
    try {
      final url = Uri.parse('${expenseUrl}create');
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': basicAuth,
        },
        body: jsonEncode({
          'description': expense['description'],
          'amount': expense['amount'],
          'credit': expense['credit'] == 1,
          'date': expense['date'],
          'book': {'id': expense['book_id']},
          'category': {'id': expense['category_id']},
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        await dbHelper.markExpenseAsSynced(expense['id']);
      }
    } catch (_) {}
  }
}
