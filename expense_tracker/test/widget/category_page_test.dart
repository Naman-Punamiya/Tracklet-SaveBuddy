import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/category_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_helpers.dart';

void main() {
  setupTestDatabase();

  setUp(() async {
    setupTestSharedPreferences();
    await resetTestDatabase();
  });

  group('CategoryPage UI & Interaction Tests', () {
    testWidgets('renders category page title and floating action button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CategoryPage(email: 'user@test.com', password: 'password'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Category Management'), findsOneWidget);
      expect(find.widgetWithText(FloatingActionButton, 'Add Category'), findsOneWidget);
    });

    testWidgets('opens Add Category dialog and validates empty name', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CategoryPage(email: 'user@test.com', password: 'password'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Category'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Select Icon'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Please enter a category name'), findsOneWidget);
    });

    testWidgets('creates new category and adds it to list', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CategoryPage(email: 'user@test.com', password: 'password'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Category'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.widgetWithText(TextField, 'Category Name'), 'Streaming Services');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Category Created Successfully'), findsOneWidget);
      expect(find.text('Streaming Services'), findsOneWidget);
    });

    testWidgets('opens delete category confirmation dialog', (WidgetTester tester) async {
      final now = DateTime.now().toIso8601String();
      await DatabaseHelper.instance.insertLocalCategory({
        'name': 'Gym & Fitness',
        'icon': 'Healthcare',
        'color': '#000000',
        'created_at': now,
        'updated_at': now,
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CategoryPage(email: 'user@test.com', password: 'password'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Gym & Fitness'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete').first);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Delete Category'), findsOneWidget);
      expect(find.textContaining('Gym & Fitness'), findsWidgets);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Category Deleted'), findsOneWidget);
      expect(find.text('Gym & Fitness'), findsNothing);
    });
  });
}
