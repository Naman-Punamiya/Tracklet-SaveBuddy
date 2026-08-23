import 'package:expense_tracker/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_helpers.dart';

void main() {
  setupTestDatabase();

  setUp(() async {
    setupTestSharedPreferences();
    await resetTestDatabase();
  });

  group('HomePage Navigation & Tabs Tests', () {
    testWidgets('renders BottomNavigationBar with Books, Investment, Settings', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomePage(
            userId: 1,
            email: 'test@example.com',
            password: 'password123',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Books'), findsOneWidget);
      expect(find.text('Investment'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('switches to Investment tab when tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomePage(
            userId: 1,
            email: 'test@example.com',
            password: 'password123',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Investment'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Investments'), findsOneWidget);
    });

    testWidgets('switches to Settings tab when tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomePage(
            userId: 1,
            email: 'test@example.com',
            password: 'password123',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Settings'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Profile Information'), findsOneWidget);
    });
  });
}
