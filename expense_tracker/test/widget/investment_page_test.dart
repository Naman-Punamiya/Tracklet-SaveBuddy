import 'package:expense_tracker/pages/HomePage/investment_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_helpers.dart';

void main() {
  setupTestDatabase();

  setUp(() async {
    setupTestSharedPreferences();
    await resetTestDatabase();
  });

  group('InvestmentPage UI & Interaction Tests', () {
    testWidgets('shows empty state when no investments exist', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: InvestmentPage(email: 'user@test.com', password: 'password'),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Investments'), findsOneWidget);
      expect(find.text('No Investments Yet'), findsOneWidget);
    });

    testWidgets('validates Add Investment form fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: InvestmentPage(email: 'user@test.com', password: 'password'),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Investment'));
      await tester.pumpAndSettle();

      // Submit empty
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.text('Investment name must not be empty'), findsOneWidget);
      expect(find.text('Amount must not be empty'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('validates zero/negative amount in Add Investment', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: InvestmentPage(email: 'user@test.com', password: 'password'),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Investment'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Investment Name'), 'Crypto');
      await tester.enterText(find.widgetWithText(TextField, 'Invested Amount (₹)'), '0');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid amount'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('successfully creates an investment and updates total card', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: InvestmentPage(email: 'user@test.com', password: 'password'),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Investment'));
      await tester.pumpAndSettle();

      final dialogFields = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
      await tester.enterText(dialogFields.at(0), 'Mutual Fund SIP');
      await tester.enterText(dialogFields.at(1), '5000');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      for (int i = 0; i < 10; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Mutual Fund SIP'), findsWidgets);
      expect(find.text('1 Investments'), findsOneWidget);
      expect(find.text('Investment added successfully.'), findsOneWidget);
    });
  });
}
