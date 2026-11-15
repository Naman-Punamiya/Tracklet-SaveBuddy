import 'package:expense_tracker/pages/Auth/login_page.dart';
import 'package:expense_tracker/pages/Auth/register_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_helpers.dart';

void main() {
  setupTestDatabase();

  setUp(() async {
    setupTestSharedPreferences();
    await resetTestDatabase();
  });

  group('LoginPage Widget & Interaction Tests', () {
    testWidgets('renders login UI elements correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Login to continue'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Create one'), findsOneWidget);
    });

    testWidgets('shows validation snackbar on empty email', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump();

      expect(find.text('Email cannot be empty'), findsOneWidget);
    });

    testWidgets('shows validation snackbar on empty password', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'user@example.com');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump();

      expect(find.text('Password cannot be empty'), findsOneWidget);
    });

    testWidgets('shows coming soon snackbar on Forgot Password tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Forgot Password?'));
      await tester.pump();

      expect(find.text('Forgot password functionality coming soon!'), findsOneWidget);
    });

    testWidgets('navigates to RegisterPage when Create one is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final createOneFinder = find.text('Create one');
      await tester.ensureVisible(createOneFinder);
      await tester.tap(createOneFinder);
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
    });
  });

  group('RegisterPage Widget & Interaction Tests', () {
    testWidgets('renders register UI elements correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Full Name'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Confirm Password'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Register'), findsOneWidget);
    });

    testWidgets('shows snackbar when passwords do not match', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Full Name'), 'John Doe');
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'john@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'pass123');
      await tester.enterText(find.widgetWithText(TextField, 'Confirm Password'), 'pass456');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('shows validation snackbar on empty name', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'pass123');
      await tester.enterText(find.widgetWithText(TextField, 'Confirm Password'), 'pass123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pump();

      expect(find.text('Please enter your full name'), findsOneWidget);
    });

    testWidgets('navigates to LoginPage when Sign in is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterPage(),
        ),
      );
      await tester.pumpAndSettle();

      final signInFinder = find.text('Sign in');
      await tester.ensureVisible(signInFinder);
      await tester.tap(signInFinder);
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
    });
  });
}
