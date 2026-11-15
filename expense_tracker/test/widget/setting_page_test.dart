import 'package:expense_tracker/pages/HomePage/setting_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/test_helpers.dart';

void main() {
  setupTestDatabase();

  setUp(() async {
    setupTestSharedPreferences(initialValues: {
      'isLoggedIn': true,
      'email': 'admin@savebuddy.com',
      'password': 'secretpassword',
    });
    await resetTestDatabase();
  });

  group('SettingPage UI & Interaction Tests', () {
    testWidgets('renders user profile card and settings options', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingPage(
            email: 'admin@savebuddy.com',
            password: 'secretpassword',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('admin@savebuddy.com'), findsOneWidget);
      expect(find.text('Security'), findsOneWidget);
      expect(find.text('Category Management'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);

      final aboutFinder = find.text('About');
      await tester.ensureVisible(aboutFinder);
      expect(aboutFinder, findsOneWidget);

      final logoutFinder = find.text('Log Out');
      await tester.ensureVisible(logoutFinder);
      expect(logoutFinder, findsOneWidget);
    });

    testWidgets('allows selecting Light, Dark, or System Default theme options', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingPage(
            email: 'admin@savebuddy.com',
            password: 'secretpassword',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final themeTile = find.text('Theme');
      await tester.ensureVisible(themeTile);
      await tester.tap(themeTile);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Select Theme'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      await tester.tap(find.text('Dark'));
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('opens info dialogs on tile taps', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingPage(
            email: 'admin@savebuddy.com',
            password: 'secretpassword',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final securityFinder = find.text('Security');
      await tester.ensureVisible(securityFinder);
      await tester.tap(securityFinder);
      await tester.pumpAndSettle();

      expect(find.text('Security & Password'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('shows Logout confirmation dialog and clears session on confirm', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingPage(
            email: 'admin@savebuddy.com',
            password: 'secretpassword',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final logoutTileFinder = find.text('Log Out');
      await tester.ensureVisible(logoutTileFinder);
      await tester.tap(logoutTileFinder);
      await tester.pumpAndSettle();

      expect(find.text('Logout'), findsWidgets);
      expect(find.text('Are you sure you want to log out of Tracklet SaveBuddy?'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Logout'));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      // Navigation back to LoginPage
      expect(find.text('Welcome Back'), findsOneWidget);

      // Verify SharedPreferences cleared
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isLoggedIn'), isNull);
    });
  });
}
