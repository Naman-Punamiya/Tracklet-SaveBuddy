import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/pages/HomePage/book_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_helpers.dart';

void main() {
  setupTestDatabase();

  setUp(() async {
    setupTestSharedPreferences();
    await resetTestDatabase();
  });

  group('BookPage UI & Interaction Tests', () {
    testWidgets('shows empty state when no books exist', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BookPage(email: 'user@test.com', password: 'password'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('No Books Yet'), findsOneWidget);
      expect(find.text('Create Book'), findsWidgets);
    });

    testWidgets('opens Add Book dialog and validates empty name', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BookPage(email: 'user@test.com', password: 'password'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Book'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Add Book'), findsWidgets);

      // Tap Add without entering name
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Book name must not be empty'), findsOneWidget);
    });

    testWidgets('successfully creates a book and displays it', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BookPage(email: 'user@test.com', password: 'password'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Book'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.widgetWithText(TextField, 'Book Name'), 'Office Expenses');
      await tester.enterText(find.widgetWithText(TextField, 'Book Subtitle'), 'Monthly Office Supplies');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Office Expenses'), findsOneWidget);
      expect(find.text('Monthly Office Supplies'), findsOneWidget);
      expect(find.text('Book Added Successfully'), findsOneWidget);
    });

    testWidgets('search filters books and retains search bar on zero results', (WidgetTester tester) async {
      final now = DateTime.now().toIso8601String();
      await DatabaseHelper.instance.insertLocalBook({
        'name': 'Personal Cash',
        'subtitle': 'Wallet',
        'archived': 0,
        'created_at': now,
        'updated_at': now,
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: BookPage(email: 'user@test.com', password: 'password'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Personal Cash'), findsOneWidget);

      // Search matching term
      await tester.enterText(find.widgetWithText(TextField, 'Search books...'), 'personal');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Personal Cash'), findsOneWidget);

      // Search non-matching term
      await tester.enterText(find.widgetWithText(TextField, 'Search books...'), 'nonexistent');
      await tester.pump(const Duration(milliseconds: 300));

      // Search bar must REMAIN visible when there are no results
      expect(find.widgetWithText(TextField, 'Search books...'), findsOneWidget);
      expect(find.text('No matching books found'), findsOneWidget);
      expect(find.text('Personal Cash'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Personal Cash'), findsOneWidget);
    });
  });
}
