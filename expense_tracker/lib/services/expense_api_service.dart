import 'package:expense_tracker/repositories/repository.dart';

final ExpenseRepository _expenseRepo = ExpenseRepository();

Future<List<dynamic>> fetchExpenses(String bookId, dynamic basicAuth) async {
  return await _expenseRepo.getExpenses(bookId);
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
  await _expenseRepo.addExpense(
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
  dynamic basicAuth,
) async {
  await _expenseRepo.updateExpense(
    id,
    description,
    amount,
    isCredit,
    categoryId,
    basicAuth,
  );
}

Future<void> deleteExpense(String id, dynamic basicAuth) async {
  await _expenseRepo.deleteExpense(id, basicAuth);
}

Future<void> syncExpenses(String basicAuth) async {
  await SyncEngine.syncAll(basicAuth);
}
