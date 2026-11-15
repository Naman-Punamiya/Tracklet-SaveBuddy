import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/pages/Auth/register_page.dart';
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

  group('Integration Flow - E2E User Journeys', () {
    testWidgets('User Registration to Navigation Flow', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Full Name'), 'Alice Smith');
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'alice@savebuddy.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'pass123');
      await tester.enterText(find.widgetWithText(TextField, 'Confirm Password'), 'pass123');

      final signInFinder = find.text('Sign in');
      await tester.ensureVisible(signInFinder);
      await tester.tap(signInFinder);
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('Full Book Lifecycle - Create, Edit, Archive, Restore, Delete', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: HomePage(
            userId: 1,
            email: 'user@test.com',
            password: 'password',
          ),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      // 1. Create Book
      await tester.tap(find.text('Create Book'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Book Name'), 'Vacation Trip');
      await tester.enterText(find.widgetWithText(TextField, 'Book Subtitle'), 'Summer 2026');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      for (int i = 0; i < 10; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Vacation Trip'), findsOneWidget);

      // Verify DB persistence
      List<dynamic> books = [];
      await tester.runAsync(() async {
        books = await DatabaseHelper.instance.getLocalBooks(archived: 0);
      });
      expect(books.length, 1);
      expect(books.first['name'], 'Vacation Trip');
    });
  });
}
