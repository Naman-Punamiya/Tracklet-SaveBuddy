import 'package:expense_tracker/database/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_helpers.dart';

void main() {
  setupTestDatabase();

  late DatabaseHelper dbHelper;

  setUp(() async {
    dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;
    await db.delete('expenses');
    await db.delete('books');
    await db.delete('categories');
    await db.delete('investments');
    await db.delete('pending_sync');
  });

  group('DatabaseHelper - Books CRUD & Search', () {
    test('insertLocalBook and getLocalBooks (archived 0 and 1)', () async {
      final now = DateTime.now().toIso8601String();
      final id1 = await dbHelper.insertLocalBook({
        'name': 'Personal Wallet',
        'subtitle': 'Daily Cash',
        'archived': 0,
        'created_at': now,
        'updated_at': now,
        'synced': 0,
      });

      final id2 = await dbHelper.insertLocalBook({
        'name': 'Old Trip',
        'subtitle': 'Archived Expenses',
        'archived': 1,
        'created_at': now,
        'updated_at': now,
        'synced': 0,
      });

      final activeBooks = await dbHelper.getLocalBooks(archived: 0);
      final archivedBooks = await dbHelper.getLocalBooks(archived: 1);

      expect(activeBooks.length, 1);
      expect(activeBooks.first['name'], 'Personal Wallet');
      expect(activeBooks.first['id'], id1);

      expect(archivedBooks.length, 1);
      expect(archivedBooks.first['name'], 'Old Trip');
      expect(archivedBooks.first['id'], id2);
    });

    test('updateLocalBook and getLocalBookById', () async {
      final now = DateTime.now().toIso8601String();
      final id = await dbHelper.insertLocalBook({
        'name': 'Office',
        'subtitle': 'Work',
        'archived': 0,
        'created_at': now,
        'updated_at': now,
        'synced': 0,
      });

      await dbHelper.updateLocalBook(id, {
        'name': 'Office Expenses Updated',
        'subtitle': 'Work & Business',
        'updated_at': now,
      });

      final book = await dbHelper.getLocalBookById(id);
      expect(book, isNotNull);
      expect(book!['name'], 'Office Expenses Updated');
      expect(book['subtitle'], 'Work & Business');
    });

    test('searchLocalBooks matches exact, partial, and case-insensitive', () async {
      final now = DateTime.now().toIso8601String();
      await dbHelper.insertLocalBook({
        'name': 'Travel Vacation',
        'subtitle': 'Paris 2026',
        'archived': 0,
        'created_at': now,
        'updated_at': now,
        'synced': 0,
      });

      final exact = await dbHelper.searchLocalBooks('Travel Vacation', 0);
      expect(exact.length, 1);

      final partial = await dbHelper.searchLocalBooks('travel', 0);
      expect(partial.length, 1);

      final subtitleMatch = await dbHelper.searchLocalBooks('paris', 0);
      expect(subtitleMatch.length, 1);

      final noMatch = await dbHelper.searchLocalBooks('nonexistent', 0);
      expect(noMatch.isEmpty, isTrue);
    });

    test('deleteLocalBook removes record', () async {
      final now = DateTime.now().toIso8601String();
      final id = await dbHelper.insertLocalBook({
        'name': 'To Delete',
        'created_at': now,
        'updated_at': now,
      });

      await dbHelper.deleteLocalBook(id);
      final book = await dbHelper.getLocalBookById(id);
      expect(book, isNull);
    });

    test('removeDefaultArchivedBooks removes only unlinked default archived books without affecting user books or active books', () async {
      final now = DateTime.now().toIso8601String();

      // 1. Unlinked default books in archived state
      await dbHelper.insertLocalBook({
        'name': '2023 Personal Expenses',
        'subtitle': 'JAN 2023 - DEC 2023',
        'archived': 1,
        'created_at': now,
        'updated_at': now,
      });
      await dbHelper.insertLocalBook({
        'name': 'Freelance Q4 2022',
        'subtitle': 'OCT 2022 - DEC 2022',
        'archived': 1,
        'created_at': now,
        'updated_at': now,
      });

      // 2. User-created archived book (no expenses)
      final userBookId = await dbHelper.insertLocalBook({
        'name': 'User Custom Project',
        'subtitle': 'Custom Notes',
        'archived': 1,
        'created_at': now,
        'updated_at': now,
      });

      // 3. User-created active book
      final activeBookId = await dbHelper.insertLocalBook({
        'name': 'Active Daily Expenses',
        'subtitle': 'Current',
        'archived': 0,
        'created_at': now,
        'updated_at': now,
      });

      // 4. Default book name but with user transactions (must NOT be deleted)
      final defaultWithExpensesId = await dbHelper.insertLocalBook({
        'name': 'Home Renovation Fund',
        'subtitle': 'MAR 2021 - DEC 2021',
        'archived': 1,
        'created_at': now,
        'updated_at': now,
      });
      await dbHelper.insertLocalExpense({
        'description': 'Tiles purchase',
        'amount': 1500.0,
        'credit': 0,
        'date': now,
        'book_id': defaultWithExpensesId,
        'created_at': now,
        'updated_at': now,
      });

      // getLocalBooks should exclude only unlinked default books without expenses
      final archivedBooks = await dbHelper.getLocalBooks(archived: 1);
      final archivedNames = archivedBooks.map((b) => b['name']).toList();
      expect(archivedNames.contains('2023 Personal Expenses'), isFalse);
      expect(archivedNames.contains('Freelance Q4 2022'), isFalse);
      expect(archivedNames.contains('User Custom Project'), isTrue);
      expect(archivedNames.contains('Home Renovation Fund'), isTrue);

      // Verify active books are untouched
      final activeBooks = await dbHelper.getLocalBooks(archived: 0);
      expect(activeBooks.any((b) => b['id'] == activeBookId), isTrue);

      // Run removeDefaultArchivedBooks
      final deletedCount = await dbHelper.removeDefaultArchivedBooks();
      expect(deletedCount, 2); // 2023 Personal Expenses and Freelance Q4 2022

      // User book and Home Renovation Fund (with expenses) still exist in database
      final userBook = await dbHelper.getLocalBookById(userBookId);
      expect(userBook, isNotNull);
      final bookWithExp = await dbHelper.getLocalBookById(defaultWithExpensesId);
      expect(bookWithExp, isNotNull);
    });
  });

  group('DatabaseHelper - Categories CRUD & Seeding', () {
    test('getLocalCategories seeds default categories when empty', () async {
      final categories = await dbHelper.getLocalCategories();
      expect(categories.isNotEmpty, isTrue);
      expect(categories.any((c) => c['name'] == 'Food'), isTrue);
      expect(categories.any((c) => c['name'] == 'Transportation'), isTrue);
    });

    test('insert, update, delete, and search categories', () async {
      final now = DateTime.now().toIso8601String();
      final id = await dbHelper.insertLocalCategory({
        'name': 'Gadgets',
        'icon': 'Shopping',
        'color': '#000000',
        'created_at': now,
        'updated_at': now,
        'synced': 0,
      });

      final fetched = await dbHelper.getLocalCategoryById(id);
      expect(fetched!['name'], 'Gadgets');

      await dbHelper.updateLocalCategory(id, {'name': 'Electronics'});
      final updated = await dbHelper.getLocalCategoryById(id);
      expect(updated!['name'], 'Electronics');

      final searchRes = await dbHelper.searchLocalCategories('electr');
      expect(searchRes.length, 1);

      await dbHelper.deleteLocalCategory(id);
      final deleted = await dbHelper.getLocalCategoryById(id);
      expect(deleted, isNull);
    });
  });

  group('DatabaseHelper - Expenses CRUD & Formatting', () {
    test('insertLocalExpense and getLocalExpensesByBook', () async {
      final now = DateTime.now().toIso8601String();
      final bookId = await dbHelper.insertLocalBook({
        'name': 'Test Book',
        'created_at': now,
        'updated_at': now,
      });

      final catId = await dbHelper.insertLocalCategory({
        'name': 'Food',
        'icon': 'Food',
        'color': '#000000',
        'created_at': now,
        'updated_at': now,
      });

      final expId = await dbHelper.insertLocalExpense({
        'description': 'Lunch Buffet',
        'amount': 250.50,
        'credit': 0,
        'date': now,
        'book_id': bookId,
        'category_id': catId,
        'created_at': now,
        'updated_at': now,
        'synced': 0,
      });

      final list = await dbHelper.getLocalExpensesByBook(bookId);
      expect(list.length, 1);
      final exp = list.first;
      expect(exp['id'], expId);
      expect(exp['description'], 'Lunch Buffet');
      expect(exp['amount'], 250.50);
      expect(exp['credit'], false);
      expect(exp['category'], isNotNull);
      expect(exp['category']['name'], 'Food');
    });

    test('searchLocalExpenses by description or category name', () async {
      final now = DateTime.now().toIso8601String();
      final bookId = await dbHelper.insertLocalBook({'name': 'Book', 'created_at': now, 'updated_at': now});
      final catId = await dbHelper.insertLocalCategory({'name': 'Utilities', 'created_at': now, 'updated_at': now});

      await dbHelper.insertLocalExpense({
        'description': 'Electricity Bill',
        'amount': 1200.0,
        'credit': 0,
        'date': now,
        'book_id': bookId,
        'category_id': catId,
        'created_at': now,
        'updated_at': now,
      });

      final byDesc = await dbHelper.searchLocalExpenses(bookId, 'Electric');
      expect(byDesc.length, 1);

      final byCat = await dbHelper.searchLocalExpenses(bookId, 'Util');
      expect(byCat.length, 1);
    });
  });

  group('DatabaseHelper - Investments & Sync Queue', () {
    test('insertLocalInvestment, search, and update', () async {
      final now = DateTime.now().toIso8601String();
      final id = await dbHelper.insertLocalInvestment({
        'description': 'Mutual Funds SIP',
        'amount': 5000.0,
        'created_at': now,
        'updated_at': now,
        'synced': 0,
      });

      final list = await dbHelper.getLocalInvestments();
      expect(list.length, 1);
      expect(list.first['description'], 'Mutual Funds SIP');

      final searchRes = await dbHelper.searchLocalInvestments('Mutual');
      expect(searchRes.length, 1);

      await dbHelper.deleteLocalInvestment(id);
      expect((await dbHelper.getLocalInvestments()).isEmpty, isTrue);
    });

    test('logPendingDelete, getPendingDeletes, removePendingSync', () async {
      await dbHelper.logPendingDelete('books', 101);
      await dbHelper.logPendingDelete('expenses', 202);

      final pending = await dbHelper.getPendingDeletes();
      expect(pending.length, 2);

      final bookPending = pending.firstWhere((p) => p['table_name'] == 'books');
      expect(bookPending['server_id'], 101);

      await dbHelper.removePendingSync(bookPending['id']);
      final remaining = await dbHelper.getPendingDeletes();
      expect(remaining.length, 1);
      expect(remaining.first['table_name'], 'expenses');
    });

    test('clearAllData purges all tables for user isolation', () async {
      final now = DateTime.now().toIso8601String();
      await dbHelper.insertLocalBook({
        'name': 'Test Book',
        'subtitle': 'Sub',
        'archived': 0,
        'created_at': now,
        'updated_at': now,
        'synced': 1,
      });
      await dbHelper.insertLocalInvestment({
        'description': 'Test Inv',
        'amount': 1000.0,
        'created_at': now,
        'updated_at': now,
        'synced': 1,
      });
      await dbHelper.logPendingDelete('books', 999);

      // Verify records exist
      expect((await dbHelper.getLocalBooks(archived: 0)).isNotEmpty, isTrue);
      expect((await dbHelper.getLocalInvestments()).isNotEmpty, isTrue);
      expect((await dbHelper.getPendingDeletes()).isNotEmpty, isTrue);

      // Purge all data
      await dbHelper.clearAllData();

      // Verify all tables are empty
      expect((await dbHelper.getLocalBooks(archived: 0)).isEmpty, isTrue);
      expect((await dbHelper.getLocalInvestments()).isEmpty, isTrue);
      expect((await dbHelper.getPendingDeletes()).isEmpty, isTrue);
    });
  });
}
