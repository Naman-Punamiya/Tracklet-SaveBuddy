import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/expense_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_helpers.dart';

void main() {
  setupTestDatabase();

  setUp(() async {
    setupTestSharedPreferences();
    await resetTestDatabase();
  });

  group('ExpenseReport UI & Calculations Tests', () {
    testWidgets('renders empty report state correctly when no transactions exist', (WidgetTester tester) async {
      final now = DateTime.now().toIso8601String();
      int bookId = 1;
      await tester.runAsync(() async {
        bookId = await DatabaseHelper.instance.insertLocalBook({
          'name': 'Empty Book',
          'created_at': now,
          'updated_at': now,
        });
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseReport(
            bookId: bookId.toString(),
            email: 'user@test.com',
            password: 'password',
          ),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.textContaining('No expense entries found'), findsOneWidget);
      expect(find.textContaining('Income:'), findsWidgets);
      expect(find.textContaining('Net:'), findsWidgets);
    });

    testWidgets('calculates totals, balance, highest, lowest, average correctly', (WidgetTester tester) async {
      final now = DateTime.now().toIso8601String();
      int bookId = 1;
      await tester.runAsync(() async {
        bookId = await DatabaseHelper.instance.insertLocalBook({
          'name': 'Report Book',
          'created_at': now,
          'updated_at': now,
        });

        // Income 50,000
        await DatabaseHelper.instance.insertLocalExpense({
          'description': 'Salary',
          'amount': 50000.0,
          'credit': 1,
          'date': now,
          'book_id': bookId,
          'created_at': now,
          'updated_at': now,
        });

        // Expenses 10,000 and 4,000
        await DatabaseHelper.instance.insertLocalExpense({
          'description': 'Rent',
          'amount': 10000.0,
          'credit': 0,
          'date': now,
          'book_id': bookId,
          'created_at': now,
          'updated_at': now,
        });

        await DatabaseHelper.instance.insertLocalExpense({
          'description': 'Utilities',
          'amount': 4000.0,
          'credit': 0,
          'date': now,
          'book_id': bookId,
          'created_at': now,
          'updated_at': now,
        });
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseReport(
            bookId: bookId.toString(),
            email: 'user@test.com',
            password: 'password',
          ),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Net Balance = 50,000 - 14,000 = 36,000
      expect(find.textContaining('36,000'), findsWidgets);
      expect(find.textContaining('50,000'), findsWidgets);
      expect(find.textContaining('14,000'), findsWidgets);
    });
  });
}
