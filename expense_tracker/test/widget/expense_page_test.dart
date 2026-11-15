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
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now().toIso8601String();
      int bookId = 1;
      await tester.runAsync(() async {
        bookId = await DatabaseHelper.instance.insertLocalBook({
          'name': 'Trip Book',
          'created_at': now,
          'updated_at': now,
        });
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
      for (int i = 0; i < 6; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('No Expenses Yet'), findsOneWidget);
      expect(find.widgetWithText(FloatingActionButton, 'Add Expense'), findsOneWidget);
    });

    testWidgets('opens Add Expense modal bottom sheet and validates inputs', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now().toIso8601String();
      int bookId = 1;
      await tester.runAsync(() async {
        bookId = await DatabaseHelper.instance.insertLocalBook({
          'name': 'Home Budget',
          'created_at': now,
          'updated_at': now,
        });
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
      for (int i = 0; i < 6; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Expense'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Add Expense Entry'), findsOneWidget);

      // Attempt save with empty description and amount
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save expense'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Please enter a description'), findsOneWidget);
    });

    testWidgets('adds an expense entry and updates balance summary card', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now().toIso8601String();
      int bookId = 1;
      await tester.runAsync(() async {
        bookId = await DatabaseHelper.instance.insertLocalBook({
          'name': 'Wallet',
          'created_at': now,
          'updated_at': now,
        });
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
      for (int i = 0; i < 6; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Expense'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await tester.enterText(find.widgetWithText(TextField, 'Description'), 'Grocery Purchase');
      await tester.enterText(find.widgetWithText(TextField, 'Amount (₹)'), '1500');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save expense'));
      for (int i = 0; i < 10; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Grocery Purchase'), findsWidgets);
      expect(find.text('Expense Added Successfully'), findsOneWidget);
    });
  });
}
