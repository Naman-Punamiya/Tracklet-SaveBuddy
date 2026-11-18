import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/pages/archived_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_helpers.dart';

void main() {
  setupTestDatabase();

  setUp(() async {
    setupTestSharedPreferences();
    await resetTestDatabase();
  });

  group('ArchivedBooksPage Tests', () {
    testWidgets('shows empty state when no archived books exist', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArchivedBooksPage(email: 'user@test.com', password: 'password'),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Archived Books', skipOffstage: false), findsOneWidget);
      expect(find.text('No Books Yet'), findsOneWidget);
    });

    testWidgets('displays archived books and allows restoring', (WidgetTester tester) async {
      final now = DateTime.now().toIso8601String();
      await tester.runAsync(() async {
        await DatabaseHelper.instance.insertLocalBook({
          'name': 'Old 2025 Book',
          'subtitle': 'Archived',
          'archived': 1,
          'created_at': now,
          'updated_at': now,
        });
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ArchivedBooksPage(email: 'user@test.com', password: 'password'),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Old 2025 Book'), findsOneWidget);

      await tester.tap(find.text('Old 2025 Book'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Book Details'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);

      await tester.tap(find.text('Restore'));
      for (int i = 0; i < 10; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Book Restored Successfully'), findsOneWidget);
      expect(find.text('No Books Yet'), findsOneWidget);
    });

    testWidgets('allows permanently deleting an archived book', (WidgetTester tester) async {
      final now = DateTime.now().toIso8601String();
      await tester.runAsync(() async {
        await DatabaseHelper.instance.insertLocalBook({
          'name': 'Trash Book',
          'subtitle': 'Delete Me',
          'archived': 1,
          'created_at': now,
          'updated_at': now,
        });
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ArchivedBooksPage(email: 'user@test.com', password: 'password'),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Trash Book'), findsOneWidget);
      await tester.tap(find.text('Trash Book'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Delete'));
      for (int i = 0; i < 10; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('No Books Yet'), findsOneWidget);
      expect(find.text('Book deleted.'), findsOneWidget);
    });

    testWidgets('shows empty state for real user email (no preloaded books appear on fresh install)', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArchivedBooksPage(email: 'real_user@example.com', password: 'secretpassword'),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('No Books Yet'), findsOneWidget);
      expect(find.text('2023 Personal Expenses'), findsNothing);
      expect(find.text('Freelance Q4 2022'), findsNothing);
      expect(find.text('Home Renovation Fund'), findsNothing);
    });

    testWidgets('removes default/system-generated books if present in database for existing users', (WidgetTester tester) async {
      final now = DateTime.now().toIso8601String();
      await tester.runAsync(() async {
        // Pre-existing default books in database
        await DatabaseHelper.instance.insertLocalBook({
          'name': '2023 Personal Expenses',
          'subtitle': 'JAN 2023 - DEC 2023',
          'archived': 1,
          'created_at': now,
          'updated_at': now,
        });
        await DatabaseHelper.instance.insertLocalBook({
          'name': 'Freelance Q4 2022',
          'subtitle': 'OCT 2022 - DEC 2022',
          'archived': 1,
          'created_at': now,
          'updated_at': now,
        });
        await DatabaseHelper.instance.insertLocalBook({
          'name': 'Home Renovation Fund',
          'subtitle': 'MAR 2021 - DEC 2021',
          'archived': 1,
          'created_at': now,
          'updated_at': now,
        });
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ArchivedBooksPage(email: 'existing_user@example.com', password: 'password'),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Default books must not appear, empty state should be shown
      expect(find.text('2023 Personal Expenses'), findsNothing);
      expect(find.text('Freelance Q4 2022'), findsNothing);
      expect(find.text('Home Renovation Fund'), findsNothing);
      expect(find.text('No Books Yet'), findsOneWidget);
    });

    testWidgets('preserves user-created archived books and filters only default books', (WidgetTester tester) async {
      final now = DateTime.now().toIso8601String();
      await tester.runAsync(() async {
        // Pre-existing default book
        await DatabaseHelper.instance.insertLocalBook({
          'name': '2023 Personal Expenses',
          'subtitle': 'JAN 2023 - DEC 2023',
          'archived': 1,
          'created_at': now,
          'updated_at': now,
        });
        // User created archived book
        final bookId = await DatabaseHelper.instance.insertLocalBook({
          'name': 'European Vacation 2024',
          'subtitle': 'Summer Trip',
          'archived': 1,
          'created_at': now,
          'updated_at': now,
        });
        // Add an expense to the user's archived book
        await DatabaseHelper.instance.insertLocalExpense({
          'description': 'Flight Ticket',
          'amount': 450.0,
          'credit': 0,
          'date': now,
          'book_id': bookId,
          'created_at': now,
          'updated_at': now,
        });
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ArchivedBooksPage(email: 'user@example.com', password: 'password'),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      // User book must be displayed
      expect(find.text('European Vacation 2024'), findsOneWidget);
      expect(find.text('SUMMER TRIP'), findsOneWidget);
      expect(find.text('1 ITEMS'), findsOneWidget);

      // Default book must not be displayed
      expect(find.text('2023 Personal Expenses'), findsNothing);
    });
  });
}
