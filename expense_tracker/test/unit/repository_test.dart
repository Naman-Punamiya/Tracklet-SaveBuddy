import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_helpers.dart';

void main() {
  setupTestDatabase();

  late DatabaseHelper dbHelper;
  late BookRepository bookRepo;
  late CategoryRepository categoryRepo;
  late ExpenseRepository expenseRepo;
  late InvestmentRepository investmentRepo;

  const basicAuth = 'Basic dGVzdEB0ZXN0LmNvbTpwYXNzd29yZA==';

  setUp(() async {
    dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;
    await db.delete('expenses');
    await db.delete('books');
    await db.delete('categories');
    await db.delete('investments');
    await db.delete('pending_sync');

    bookRepo = BookRepository();
    categoryRepo = CategoryRepository();
    expenseRepo = ExpenseRepository();
    investmentRepo = InvestmentRepository();
  });

  group('BookRepository Offline Behavior', () {
    test('addBook saves book locally and sets synced to 0 when offline', () async {
      await bookRepo.addBook('My Offline Book', 'Subtitle', basicAuth);

      final books = await bookRepo.getBooks(archived: 0);
      expect(books.length, 1);
      expect(books.first['name'], 'My Offline Book');
      expect(books.first['subtitle'], 'Subtitle');
    });

    test('updateBook updates local record', () async {
      await bookRepo.addBook('Book 1', 'Sub 1', basicAuth);
      final books = await bookRepo.getBooks(archived: 0);
      final id = books.first['id'].toString();

      await bookRepo.updateBook(id, 'Book 1 Updated', 'Sub 1 Updated', basicAuth);

      final updatedBooks = await bookRepo.getBooks(archived: 0);
      expect(updatedBooks.first['name'], 'Book 1 Updated');
      expect(updatedBooks.first['subtitle'], 'Sub 1 Updated');
    });

    test('archiveBook and restoreBook toggle archived flag', () async {
      await bookRepo.addBook('Archive Test', 'Sub', basicAuth);
      final active1 = await bookRepo.getBooks(archived: 0);
      final id = active1.first['id'].toString();

      await bookRepo.archiveBook(id, basicAuth);
      final active2 = await bookRepo.getBooks(archived: 0);
      final archived1 = await bookRepo.getBooks(archived: 1);

      expect(active2.isEmpty, isTrue);
      expect(archived1.length, 1);

      await bookRepo.restoreBook(id, basicAuth);
      final active3 = await bookRepo.getBooks(archived: 0);
      expect(active3.length, 1);
    });

    test('deleteBook removes local book and logs pending sync if serverId exists', () async {
      final now = DateTime.now().toIso8601String();
      final localId = await dbHelper.insertLocalBook({
        'server_id': 99,
        'name': 'Server Book',
        'created_at': now,
        'updated_at': now,
        'synced': 1,
      });

      await bookRepo.deleteBook(localId.toString(), basicAuth);

      final books = await bookRepo.getBooks(archived: 0);
      expect(books.isEmpty, isTrue);

      final pending = await dbHelper.getPendingDeletes();
      expect(pending.any((p) => p['table_name'] == 'books' && p['server_id'] == 99), isTrue);
    });
  });

  group('CategoryRepository Offline Operations', () {
    test('addCategory creates category locally', () async {
      await categoryRepo.addCategory('Groceries', 'Food', basicAuth);

      final cats = await categoryRepo.getCategories();
      expect(cats.any((c) => c['name'] == 'Groceries'), isTrue);
    });

    test('updateCategory modifies category details', () async {
      final now = DateTime.now().toIso8601String();
      final id = await dbHelper.insertLocalCategory({
        'name': 'FastFood',
        'icon': 'Food',
        'created_at': now,
        'updated_at': now,
      });

      await categoryRepo.updateCategory(id.toString(), 'Fast Food & Snacks', 'Food', basicAuth);

      final cats = await categoryRepo.getCategories();
      final cat = cats.firstWhere((c) => c['id'] == id);
      expect(cat['name'], 'Fast Food & Snacks');
    });

    test('deleteCategory deletes category locally', () async {
      final now = DateTime.now().toIso8601String();
      final id = await dbHelper.insertLocalCategory({
        'name': 'Temp Cat',
        'icon': 'More',
        'created_at': now,
        'updated_at': now,
      });

      await categoryRepo.deleteCategory(id.toString(), basicAuth);
      final cats = await categoryRepo.getCategories();
      expect(cats.any((c) => c['id'] == id), isFalse);
    });
  });

  group('ExpenseRepository Operations', () {
    test('addExpense inserts income/expense record properly', () async {
      final now = DateTime.now().toIso8601String();
      final bookId = await dbHelper.insertLocalBook({'name': 'B1', 'created_at': now, 'updated_at': now});
      final catId = await dbHelper.insertLocalCategory({'name': 'Salary', 'created_at': now, 'updated_at': now});

      await expenseRepo.addExpense(
        'Monthly Salary',
        '50000',
        bookId.toString(),
        true, // credit (income)
        catId.toString(),
        'Salary',
        basicAuth,
      );

      final expenses = await expenseRepo.getExpenses(bookId.toString());
      expect(expenses.length, 1);
      final exp = expenses.first;
      expect(exp['description'], 'Monthly Salary');
      expect(exp['amount'], 50000.0);
      expect(exp['credit'], isTrue);
    });

    test('updateExpense and deleteExpense perform expected local mutations', () async {
      final now = DateTime.now().toIso8601String();
      final bookId = await dbHelper.insertLocalBook({'name': 'B1', 'created_at': now, 'updated_at': now});

      final expId = await dbHelper.insertLocalExpense({
        'description': 'Coffee',
        'amount': 100.0,
        'credit': 0,
        'date': now,
        'book_id': bookId,
        'created_at': now,
        'updated_at': now,
      });

      await expenseRepo.updateExpense(
        expId.toString(),
        'Starbucks Coffee',
        '250.0',
        false,
        null,
        basicAuth,
      );

      final updatedList = await expenseRepo.getExpenses(bookId.toString());
      expect(updatedList.first['description'], 'Starbucks Coffee');
      expect(updatedList.first['amount'], 250.0);

      await expenseRepo.deleteExpense(expId.toString(), basicAuth);
      final emptyList = await expenseRepo.getExpenses(bookId.toString());
      expect(emptyList.isEmpty, isTrue);
    });
  });

  group('InvestmentRepository Operations', () {
    test('addInvestment and updateInvestment work correctly', () async {
      await investmentRepo.addInvestment('Stocks Portfolio', 15000.0, basicAuth);

      final list = await investmentRepo.getInvestments();
      expect(list.length, 1);
      expect(list.first['description'], 'Stocks Portfolio');
      expect(list.first['amount'], 15000.0);

      final id = list.first['id'].toString();
      await investmentRepo.updateInvestment(id, 'Stocks & Mutual Funds', 20000.0, basicAuth);

      final updatedList = await investmentRepo.getInvestments();
      expect(updatedList.first['description'], 'Stocks & Mutual Funds');
      expect(updatedList.first['amount'], 20000.0);
    });
  });
}
