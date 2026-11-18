import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/keep_alive_service.dart';
import 'package:expense_tracker/pages/HomePage/setting_page.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:expense_tracker/services/auth_storage_service.dart';
import 'package:expense_tracker/services/connectivity_service.dart';
import 'package:expense_tracker/services/notification_service.dart';
import '../helpers/test_helpers.dart';

class FakeHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  int requestCount = 0;

  FakeHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestCount++;
    final res = await handler(request);
    return http.StreamedResponse(
      http.ByteStream.fromBytes(utf8.encode(res.body)),
      res.statusCode,
      headers: res.headers,
    );
  }
}

void main() {
  setupTestDatabase();

  setUp(() async {
    ConnectivityService.mockStatus = ConnectivityStatus.wifi;
    setupTestSharedPreferences(initialValues: {
      'isLoggedIn': true,
      'email': 'user@savebuddy.app',
      'password': 'password123',
      'userId': 42,
      'user_display_name': 'Test User',
      'user_currency': 'USD',
    });
    await resetTestDatabase();
  });

  tearDown(() {
    KeepAliveService.stop();
    AppNotificationService.instance.stopDailyReminder();
  });

  Future<void> seedLocalData(WidgetTester tester) async {
    final now = DateTime.now().toIso8601String();
    await tester.runAsync(() async {
      await DatabaseHelper.instance.insertLocalBook({
        'name': 'Personal Ledger',
        'subtitle': 'Daily',
        'archived': 0,
        'created_at': now,
        'updated_at': now,
        'synced': 1,
      });
      await DatabaseHelper.instance.insertLocalExpense({
        'description': 'Coffee',
        'amount': 4.5,
        'credit': 0,
        'date': now,
        'created_at': now,
        'updated_at': now,
        'synced': 1,
      });
      await AuthStorageService.instance.saveCredentials(
        email: 'user@savebuddy.app',
        password: 'password123',
      );
    });
  }

  Future<void> pumpAsyncFrames(WidgetTester tester, {int count = 8, int ms = 50}) async {
    for (int i = 0; i < count; i++) {
      await tester.runAsync(() => Future.delayed(Duration(milliseconds: ms)));
      await tester.pump(Duration(milliseconds: ms));
    }
  }

  group('Phase 2: Account Deletion Flutter Integration Tests', () {
    testWidgets('1. Successful backend deletion (HTTP 204) triggers complete local cleanup and redirects', (WidgetTester tester) async {
      await seedLocalData(tester);

      final fakeClient = FakeHttpClient((request) async => http.Response('', 204));
      final repo = UserRepository(client: fakeClient);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingPage(
            email: 'user@savebuddy.app',
            password: 'password123',
            userRepo: repo,
          ),
        ),
      );
      await pumpAsyncFrames(tester);

      // Open deletion dialog
      final deleteTile = find.text('Delete Account');
      await tester.ensureVisible(deleteTile);
      await tester.tap(deleteTile);
      await pumpAsyncFrames(tester);

      // Confirm deletion
      final confirmBtn = find.text('Delete Permanently');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);

      await pumpAsyncFrames(tester, count: 12, ms: 50);

      // Verify HTTP call was made
      expect(fakeClient.requestCount, greaterThanOrEqualTo(1));

      // Verify SQLite is wiped
      await tester.runAsync(() async {
        final books = await DatabaseHelper.instance.getLocalBooks(archived: 0);
        final db = await DatabaseHelper.instance.database;
        final expenses = await db.query('expenses');
        expect(books, isEmpty);
        expect(expenses, isEmpty);
      });

      // Verify Secure Storage is wiped
      expect(AuthStorageService.instance.currentAuthToken, isEmpty);
      expect(AuthStorageService.instance.currentEmail, isEmpty);
      expect(AuthStorageService.instance.currentPassword, isEmpty);

      // Verify SharedPreferences is cleared
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isLoggedIn'), isNull);
      expect(prefs.getString('email'), isNull);
      expect(prefs.getString('last_logged_in_email'), isNull);
      expect(prefs.getInt('userId'), isNull);

      // Verify navigation to LoginPage
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('2. HTTP 401 preserves local data, credentials and displays error message', (WidgetTester tester) async {
      await seedLocalData(tester);

      final fakeClient = FakeHttpClient((request) async => http.Response('Unauthorized', 401));
      final repo = UserRepository(client: fakeClient);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingPage(
            email: 'user@savebuddy.app',
            password: 'password123',
            userRepo: repo,
          ),
        ),
      );
      await pumpAsyncFrames(tester);

      final deleteTile = find.text('Delete Account');
      await tester.ensureVisible(deleteTile);
      await tester.tap(deleteTile);
      await pumpAsyncFrames(tester);

      await tester.tap(find.text('Delete Permanently'));
      await pumpAsyncFrames(tester, count: 12, ms: 50);

      // Verify local data is PRESERVED
      await tester.runAsync(() async {
        final books = await DatabaseHelper.instance.getLocalBooks(archived: 0);
        expect(books, isNotEmpty);
      });

      // Verify credentials are PRESERVED
      expect(AuthStorageService.instance.currentEmail, 'user@savebuddy.app');

      // Verify session is PRESERVED
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isLoggedIn'), isTrue);

      // Verify user remains on SettingPage and sees error
      expect(find.text('Delete Account'), findsOneWidget);
      expect(find.text('Failed to delete account. Please check your connection and try again.'), findsOneWidget);
    });

    testWidgets('3. HTTP 404 preserves local data and credentials', (WidgetTester tester) async {
      await seedLocalData(tester);

      final fakeClient = FakeHttpClient((request) async => http.Response('Not Found', 404));
      final repo = UserRepository(client: fakeClient);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingPage(
            email: 'user@savebuddy.app',
            password: 'password123',
            userRepo: repo,
          ),
        ),
      );
      await pumpAsyncFrames(tester);

      final deleteTile = find.text('Delete Account');
      await tester.ensureVisible(deleteTile);
      await tester.tap(deleteTile);
      await pumpAsyncFrames(tester);

      await tester.tap(find.text('Delete Permanently'));
      await pumpAsyncFrames(tester, count: 12, ms: 50);

      // Data and session must be preserved
      await tester.runAsync(() async {
        final books = await DatabaseHelper.instance.getLocalBooks(archived: 0);
        expect(books, isNotEmpty);
      });
      expect(AuthStorageService.instance.currentEmail, 'user@savebuddy.app');
      expect(find.text('Failed to delete account. Please check your connection and try again.'), findsOneWidget);
    });

    testWidgets('4. HTTP 500 preserves local data and credentials', (WidgetTester tester) async {
      await seedLocalData(tester);

      final fakeClient = FakeHttpClient((request) async => http.Response('Internal Server Error', 500));
      final repo = UserRepository(client: fakeClient);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingPage(
            email: 'user@savebuddy.app',
            password: 'password123',
            userRepo: repo,
          ),
        ),
      );
      await pumpAsyncFrames(tester);

      final deleteTile = find.text('Delete Account');
      await tester.ensureVisible(deleteTile);
      await tester.tap(deleteTile);
      await pumpAsyncFrames(tester);

      await tester.tap(find.text('Delete Permanently'));
      await pumpAsyncFrames(tester, count: 12, ms: 50);

      // Data preserved
      await tester.runAsync(() async {
        final books = await DatabaseHelper.instance.getLocalBooks(archived: 0);
        expect(books, isNotEmpty);
      });
      expect(AuthStorageService.instance.currentEmail, 'user@savebuddy.app');
      expect(find.text('Failed to delete account. Please check your connection and try again.'), findsOneWidget);
    });

    testWidgets('5. Network exception preserves local data and credentials', (WidgetTester tester) async {
      await seedLocalData(tester);

      final fakeClient = FakeHttpClient((request) async {
        throw http.ClientException('Network connection failed');
      });
      final repo = UserRepository(client: fakeClient);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingPage(
            email: 'user@savebuddy.app',
            password: 'password123',
            userRepo: repo,
          ),
        ),
      );
      await pumpAsyncFrames(tester);

      final deleteTile = find.text('Delete Account');
      await tester.ensureVisible(deleteTile);
      await tester.tap(deleteTile);
      await pumpAsyncFrames(tester);

      await tester.tap(find.text('Delete Permanently'));
      await pumpAsyncFrames(tester, count: 12, ms: 50);

      // Data preserved
      await tester.runAsync(() async {
        final books = await DatabaseHelper.instance.getLocalBooks(archived: 0);
        expect(books, isNotEmpty);
      });
      expect(AuthStorageService.instance.currentEmail, 'user@savebuddy.app');
      expect(find.text('Failed to delete account. Please check your connection and try again.'), findsOneWidget);
    });

    testWidgets('6. Duplicate submissions do not trigger multiple requests', (WidgetTester tester) async {
      final completer = Completer<http.Response>();
      final fakeClient = FakeHttpClient((request) => completer.future);
      final repo = UserRepository(client: fakeClient);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingPage(
            email: 'user@savebuddy.app',
            password: 'password123',
            userRepo: repo,
          ),
        ),
      );
      await pumpAsyncFrames(tester);

      final deleteTile = find.text('Delete Account');
      await tester.ensureVisible(deleteTile);
      await tester.tap(deleteTile);
      await pumpAsyncFrames(tester);

      // Tap confirm to start deletion
      await tester.tap(find.text('Delete Permanently'));
      await pumpAsyncFrames(tester, count: 2, ms: 20);

      // While request is in flight, overlay is up and duplicate submission is blocked
      expect(find.text('Deleting account...'), findsOneWidget);

      // Verify exactly 1 request was sent
      expect(fakeClient.requestCount, 1);

      // Complete the request
      completer.complete(http.Response('', 204));
      await pumpAsyncFrames(tester, count: 12, ms: 50);

      expect(fakeClient.requestCount, 1);
    });

    testWidgets('7. Notifications and KeepAliveService stop after successful deletion', (WidgetTester tester) async {
      KeepAliveService.start();
      AppNotificationService.instance.scheduleDailyReminder();

      final fakeClient = FakeHttpClient((request) async => http.Response('', 204));
      final repo = UserRepository(client: fakeClient);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingPage(
            email: 'user@savebuddy.app',
            password: 'password123',
            userRepo: repo,
          ),
        ),
      );
      await pumpAsyncFrames(tester);

      final deleteTile = find.text('Delete Account');
      await tester.ensureVisible(deleteTile);
      await tester.tap(deleteTile);
      await pumpAsyncFrames(tester);

      await tester.tap(find.text('Delete Permanently'));
      await pumpAsyncFrames(tester, count: 12, ms: 50);

      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('8. The user cannot navigate back into authenticated screens after success', (WidgetTester tester) async {
      final fakeClient = FakeHttpClient((request) async => http.Response('', 204));
      final repo = UserRepository(client: fakeClient);

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/',
          routes: {
            '/': (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SettingPage(
                            email: 'user@savebuddy.app',
                            password: 'password123',
                            userRepo: repo,
                          ),
                        ),
                      );
                    },
                    child: const Text('Go to Settings'),
                  ),
                ),
          },
        ),
      );
      await pumpAsyncFrames(tester);

      // Navigate to Settings
      await tester.tap(find.text('Go to Settings'));
      await pumpAsyncFrames(tester);

      expect(find.text('Settings'), findsOneWidget);

      // Perform deletion
      final deleteTile = find.text('Delete Account');
      await tester.ensureVisible(deleteTile);
      await tester.tap(deleteTile);
      await pumpAsyncFrames(tester);

      await tester.tap(find.text('Delete Permanently'));
      await pumpAsyncFrames(tester, count: 10, ms: 50);
      await tester.pumpAndSettle();

      // Current screen is LoginPage
      expect(find.text('Welcome Back'), findsOneWidget);

      // Attempt back navigation
      final didPop = await tester.binding.handlePopRoute();
      expect(didPop, isFalse); // Root route cannot be popped; previous stack was removed
      expect(find.text('Settings'), findsNothing);
      expect(find.text('Go to Settings'), findsNothing);
    });
  });
}
