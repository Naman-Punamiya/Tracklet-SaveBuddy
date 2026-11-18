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
  });
}
