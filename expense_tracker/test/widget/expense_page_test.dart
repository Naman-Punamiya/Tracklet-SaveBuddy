import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/expense_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_helpers.dart';

void main() {
  setupTestDatabase();

  setUp(() async {
    setupTestSharedPreferences();
    await resetTestDatabase();
  });

  group('ExpensePage UI & Interaction Tests', () {
    testWidgets('renders expense page header and floating action buttons', (WidgetTester tester) async {
      final now = DateTime.now().toIso8601String();
      final bookId = await DatabaseHelper.instance.insertLocalBook({
        'name': 'Trip Book',
        'created_at': now,
        'updated_at': now,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensePage(
            bookId: bookId.toString(),
            bookName: 'Trip Book',
            email: 'user@test.com',
            password: 'password',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Trip Book'), findsOneWidget);
      expect(find.text('No Expenses Yet'), findsOneWidget);
      expect(find.widgetWithText(FloatingActionButton, 'Add Income'), findsOneWidget);
      expect(find.widgetWithText(FloatingActionButton, 'Add Expense'), findsOneWidget);
    });

    testWidgets('opens Add Expense modal bottom sheet and validates inputs', (WidgetTester tester) async {
      final now = DateTime.now().toIso8601String();
      final bookId = await DatabaseHelper.instance.insertLocalBook({
        'name': 'Home Budget',
        'created_at': now,
        'updated_at': now,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensePage(
            bookId: bookId.toString(),
            bookName: 'Home Budget',
            email: 'user@test.com',
            password: 'password',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Expense'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Add Expense Entry'), findsOneWidget);

      // Attempt save with empty description and amount
      await tester.tap(find.text('Save Expense Entry'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Please enter a description'), findsOneWidget);
    });

    testWidgets('adds an expense entry and updates balance summary card', (WidgetTester tester) async {
      final now = DateTime.now().toIso8601String();
      final bookId = await DatabaseHelper.instance.insertLocalBook({
        'name': 'Wallet',
        'created_at': now,
        'updated_at': now,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensePage(
            bookId: bookId.toString(),
            bookName: 'Wallet',
            email: 'user@test.com',
            password: 'password',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Expense'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.widgetWithText(TextField, 'Description'), 'Grocery Purchase');
      await tester.enterText(find.widgetWithText(TextField, 'Amount (₹)'), '1500');

      await tester.tap(find.text('Save Expense Entry'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Grocery Purchase'), findsOneWidget);
      expect(find.text('Expense Added Successfully'), findsOneWidget);
    });
  });
}
