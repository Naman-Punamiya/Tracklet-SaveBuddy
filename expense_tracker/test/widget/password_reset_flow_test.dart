import 'dart:async';

import 'package:expense_tracker/pages/Auth/forgot_password_page.dart';
import 'package:expense_tracker/pages/Auth/login_page.dart';
import 'package:expense_tracker/pages/Auth/reset_password_page.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

class FakeUserRepository extends UserRepository {
  FakeUserRepository({
    this.forgotHandler,
    this.resetHandler,
  });

  Future<({bool success, String message})> Function({required String email})? forgotHandler;
  Future<({bool success, String message})> Function({required String token, required String newPassword})? resetHandler;

  int forgotCalls = 0;
  int resetCalls = 0;

  @override
  Future<({bool success, String message})> forgotPassword({required String email}) async {
    forgotCalls++;
    if (forgotHandler != null) return forgotHandler!(email: email);
    return (success: true, message: "If an account exists with this email address, you will receive password reset instructions shortly.");
  }

  @override
  Future<({bool success, String message})> resetPassword({required String token, required String newPassword}) async {
    resetCalls++;
    if (resetHandler != null) return resetHandler!(token: token, newPassword: newPassword);
    return (success: true, message: "Password has been reset successfully. You can now log in with your new password.");
  }
}

void main() {
  setupTestDatabase();

  setUp(() async {
    setupTestSharedPreferences();
    await resetTestDatabase();
  });

  group('Forgot Password flow', () {
    testWidgets('navigates from Login to Forgot Password page', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.text('Forgot Password'), findsOneWidget);
      expect(find.text('Send reset instructions'), findsOneWidget);
    });

    testWidgets('email validation shows errors for empty and invalid email', (tester) async {
      final repo = FakeUserRepository();
      await tester.pumpWidget(MaterialApp(home: ForgotPasswordPage(userRepository: repo)));
      await tester.pump();

      await tester.tap(find.text('Send reset instructions'));
      await tester.pump();
      expect(find.text('Email cannot be empty'), findsOneWidget);
      expect(repo.forgotCalls, 0);

      // Clear the current snackbar before triggering the next validation.
      ScaffoldMessenger.of(tester.element(find.byType(ForgotPasswordPage))).clearSnackBars();
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'invalid-email');
      await tester.tap(find.text('Send reset instructions'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Please enter a valid email address (e.g. user@example.com)'), findsOneWidget);
      expect(repo.forgotCalls, 0);
    });

    testWidgets('successful reset request shows generic success UI', (tester) async {
      final repo = FakeUserRepository(
        forgotHandler: ({required String email}) async => (
          success: true,
          message: "If an account exists with this email address, you will receive password reset instructions shortly.",
        ),
      );
      await tester.pumpWidget(MaterialApp(home: ForgotPasswordPage(userRepository: repo)));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'user@example.com');
      await tester.tap(find.text('Send reset instructions'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repo.forgotCalls, 1);
      expect(find.text('Check your email'), findsOneWidget);
      expect(find.textContaining('If an account exists with this email address'), findsOneWidget);
    });

    testWidgets('network failure shows error UI', (tester) async {
      final repo = FakeUserRepository(
        forgotHandler: ({required String email}) async => (
          success: false,
          message: "Network error. Please try again.",
        ),
      );
      await tester.pumpWidget(MaterialApp(home: ForgotPasswordPage(userRepository: repo)));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'user@example.com');
      await tester.tap(find.text('Send reset instructions'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Network error. Please try again.'), findsOneWidget);
      expect(find.text('Check your email'), findsNothing);
    });

    testWidgets('prevents repeated submissions while request in progress', (tester) async {
      final completer = Completer<({bool success, String message})>();
      final repo = FakeUserRepository(
        forgotHandler: ({required String email}) => completer.future,
      );
      await tester.pumpWidget(MaterialApp(home: ForgotPasswordPage(userRepository: repo)));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'user@example.com');
      await tester.tap(find.text('Send reset instructions'));
      await tester.pump(); // start loading
      final button = find.byType(ElevatedButton);
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();

      expect(repo.forgotCalls, 1);

      completer.complete((success: true, message: "If an account exists with this email address, you will receive password reset instructions shortly."));
      await tester.pumpAndSettle();
      expect(find.text('Check your email'), findsOneWidget);
    });
  });

  group('Reset Password flow', () {
    Finder newPasswordField() => find.widgetWithText(TextField, 'New password');
    Finder confirmPasswordField() => find.widgetWithText(TextField, 'Confirm new password');

    testWidgets('reset screen validation rejects weak password', (tester) async {
      final repo = FakeUserRepository();
      await tester.pumpWidget(MaterialApp(home: ResetPasswordPage(token: 'valid-token', userRepository: repo)));
      await tester.pump();

      await tester.enterText(newPasswordField(), 'short1');
      await tester.enterText(confirmPasswordField(), 'short1');
      await tester.tap(find.text('Reset password'));
      await tester.pump();

      expect(find.text('Password must be at least 8 characters and include at least one letter and one number'), findsWidgets);
      expect(repo.resetCalls, 0);
    });

    testWidgets('password confirmation mismatch shows error', (tester) async {
      final repo = FakeUserRepository();
      await tester.pumpWidget(MaterialApp(home: ResetPasswordPage(token: 'valid-token', userRepository: repo)));
      await tester.pump();

      await tester.enterText(newPasswordField(), 'NewPass123');
      await tester.enterText(confirmPasswordField(), 'Different123');
      await tester.tap(find.text('Reset password'));
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(repo.resetCalls, 0);
    });

    testWidgets('invalid/expired token UI shows error and allows requesting another reset', (tester) async {
      final repo = FakeUserRepository(
        resetHandler: ({required String token, required String newPassword}) async => (
          success: false,
          message: "This reset link has expired. Please request a new one.",
        ),
      );
      await tester.pumpWidget(MaterialApp(home: ResetPasswordPage(token: 'expired-token', userRepository: repo)));
      await tester.pump();

      await tester.enterText(newPasswordField(), 'NewPass123');
      await tester.enterText(confirmPasswordField(), 'NewPass123');
      await tester.tap(find.text('Reset password'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('expired'), findsWidgets);
      expect(find.text('Request a new reset link'), findsOneWidget);

      await tester.tap(find.text('Request a new reset link'));
      await tester.pumpAndSettle();
      expect(find.text('Send reset instructions'), findsOneWidget);
    });

    testWidgets('successful reset navigates back to Login', (tester) async {
      final repo = FakeUserRepository(
        resetHandler: ({required String token, required String newPassword}) async => (
          success: true,
          message: "Password has been reset successfully. You can now log in with your new password.",
        ),
      );
      await tester.pumpWidget(MaterialApp(home: ResetPasswordPage(token: 'valid-token', userRepository: repo)));
      await tester.pump();

      await tester.enterText(newPasswordField(), 'NewPass123');
      await tester.enterText(confirmPasswordField(), 'NewPass123');
      await tester.tap(find.text('Reset password'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Password Reset'), findsOneWidget);
      expect(find.text('Back to Login'), findsOneWidget);

      await tester.tap(find.text('Back to Login'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('invalid token without submission offers request new reset', (tester) async {
      final repo = FakeUserRepository();
      await tester.pumpWidget(MaterialApp(home: ResetPasswordPage(token: '', userRepository: repo)));
      await tester.pump();

      expect(find.textContaining('invalid or missing a token'), findsOneWidget);
      expect(find.text('Request a new reset link'), findsOneWidget);
    });
  });
}
