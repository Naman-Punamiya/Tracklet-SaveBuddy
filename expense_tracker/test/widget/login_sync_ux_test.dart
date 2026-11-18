import 'dart:async';
import 'dart:convert';
import 'package:expense_tracker/core/widgets/app_empty_state.dart';
import 'package:expense_tracker/core/widgets/app_loading.dart';
import 'package:expense_tracker/custom_widgets/book_list_skeleton.dart';
import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/pages/Auth/login_page.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/category_page.dart';
import 'package:expense_tracker/pages/HomePage/book_page.dart';
import 'package:expense_tracker/pages/HomePage/investment_page.dart';
import 'package:expense_tracker/pages/HomePage/setting_page.dart';
import 'package:expense_tracker/pages/archived_page.dart';
import 'package:expense_tracker/pages/home_page.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:expense_tracker/services/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/test_helpers.dart';

class MockLoginHttpClient extends http.BaseClient {
  int loginRequests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path.contains('/users/login') || path.endsWith('/login')) {
      loginRequests++;
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"id": 1, "email": "user@example.com"}')),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode('[]')),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

Future<void> pumpAsyncFrames(WidgetTester tester, {int count = 8, int ms = 50}) async {
  for (int i = 0; i < count; i++) {
    await tester.runAsync(() => Future.delayed(Duration(milliseconds: ms)));
    await tester.pump(Duration(milliseconds: ms));
  }
}

void main() {
  setupTestDatabase();

  setUp(() async {
    setupTestSharedPreferences();
    await resetTestDatabase();
    SyncEngine.resetForTesting();
    ConnectivityService.mockStatus = ConnectivityStatus.offline;
    ConnectivityService.mockStreamController = null;
  });

  tearDown(() {
    SyncEngine.resetForTesting();
    ConnectivityService.mockStreamController = null;
  });

  group('Login & Cloud Synchronization UX Tests', () {
    testWidgets('1. Login starts exactly one initial background sync', (WidgetTester tester) async {
      int syncExecutionCount = 0;
      final syncGate = Completer<void>();
      SyncEngine.syncAllHandler = (auth, {client}) {
        syncExecutionCount++;
        return syncGate.future;
      };

      final mockClient = MockLoginHttpClient();
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(client: mockClient),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');

      final loginButton = find.widgetWithText(ElevatedButton, 'Login');
      await tester.ensureVisible(loginButton);
      await tester.tap(loginButton);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text("Login successful"), findsOneWidget);
      // Synchronously marked before navigation
      expect(SyncEngine.initialSyncStarted, isTrue);
      expect(SyncEngine.isSyncing, isTrue);
      expect(syncExecutionCount, 1);

      syncGate.complete();
      await pumpAsyncFrames(tester);
    });

    testWidgets('2. Page initialization in BookPage, InvestmentPage, CategoryPage, and ArchivedBooksPage does not start another initial sync in the same session', (WidgetTester tester) async {
      SyncEngine.markInitialSyncStarted();
      expect(SyncEngine.initialSyncStarted, isTrue);

      int syncCallCount = 0;
      SyncEngine.syncAllHandler = (auth, {client}) {
        syncCallCount++;
        return Future.value();
      };

      // 1. BookPage
      await tester.pumpWidget(
        const MaterialApp(
          home: BookPage(email: 'user@example.com', password: 'password123'),
        ),
      );
      await pumpAsyncFrames(tester, count: 4, ms: 20);
      expect(syncCallCount, 0, reason: 'BookPage.initState must not start another initial sync');

      // 2. InvestmentPage
      await tester.pumpWidget(
        const MaterialApp(
          home: InvestmentPage(email: 'user@example.com', password: 'password123'),
        ),
      );
      await pumpAsyncFrames(tester, count: 4, ms: 20);
      expect(syncCallCount, 0, reason: 'InvestmentPage.initState must not start another initial sync');

      // 3. CategoryPage
      await tester.pumpWidget(
        const MaterialApp(
          home: CategoryPage(email: 'user@example.com', password: 'password123'),
        ),
      );
      await pumpAsyncFrames(tester, count: 4, ms: 20);
      expect(syncCallCount, 0, reason: 'CategoryPage.initState must not start another initial sync');

      // 4. ArchivedBooksPage
      await tester.pumpWidget(
        const MaterialApp(
          home: ArchivedBooksPage(email: 'user@example.com', password: 'password123'),
        ),
      );
      await pumpAsyncFrames(tester, count: 4, ms: 20);
      expect(syncCallCount, 0, reason: 'ArchivedBooksPage.initState must not start another initial sync');
    });

    testWidgets('3. A failed initial sync does not cause page initialization to start another initial sync', (WidgetTester tester) async {
      SyncEngine.markInitialSyncStarted();
      expect(SyncEngine.initialSyncStarted, isTrue);

      // Failing initial sync
      SyncEngine.syncAllHandler = (auth, {client}) async {
        throw Exception('Server unreachable');
      };

      try {
        await SyncEngine.syncAll('Basic auth');
      } catch (_) {}

      expect(SyncEngine.isSyncing, isFalse);
      expect(SyncEngine.initialSyncStarted, isTrue);

      int subsequentCallCount = 0;
      SyncEngine.syncAllHandler = (auth, {client}) {
        subsequentCallCount++;
        return Future.value();
      };

      // Mounting pages must not restart initial sync after previous sync failure
      await tester.pumpWidget(
        const MaterialApp(
          home: BookPage(email: 'user@example.com', password: 'password123'),
        ),
      );
      await pumpAsyncFrames(tester, count: 4, ms: 20);

      await tester.pumpWidget(
        const MaterialApp(
          home: InvestmentPage(email: 'user@example.com', password: 'password123'),
        ),
      );
      await pumpAsyncFrames(tester, count: 4, ms: 20);

      expect(subsequentCallCount, 0);
    });

    testWidgets('4. Connectivity recovery can still start a subsequent sync', (WidgetTester tester) async {
      SyncEngine.markInitialSyncStarted();
      expect(SyncEngine.initialSyncStarted, isTrue);

      final streamController = StreamController<ConnectivityStatus>.broadcast();
      ConnectivityService.mockStreamController = streamController;

      int recoverySyncCount = 0;
      SyncEngine.syncAllHandler = (auth, {client}) {
        recoverySyncCount++;
        return Future.value();
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: BookPage(email: 'user@example.com', password: 'password123'),
        ),
      );
      await pumpAsyncFrames(tester, count: 4, ms: 20);
      expect(recoverySyncCount, 0);

      // Simulate device reconnecting to Wi-Fi
      streamController.add(ConnectivityStatus.wifi);
      await pumpAsyncFrames(tester, count: 6, ms: 30);

      expect(recoverySyncCount, greaterThanOrEqualTo(1));
      await streamController.close();
      ConnectivityService.mockStreamController = null;
    });

    testWidgets('5. Explicit retry/manual sync remains functional', (WidgetTester tester) async {
      SyncEngine.markInitialSyncStarted();
      expect(SyncEngine.initialSyncStarted, isTrue);

      final dbHelper = DatabaseHelper.instance;
      // Insert a book and a pending delete entry in pending_sync
      await tester.runAsync(() async {
        final db = await dbHelper.database;
        await db.insert('books', {
          'server_id': 888,
          'name': 'Pending Deletion Book',
          'subtitle': 'Sub',
          'archived': 0,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'synced': 1,
        });
        await db.insert('pending_sync', {
          'table_name': 'books',
          'server_id': 888,
          'action': 'DELETE',
          'created_at': DateTime.now().toIso8601String(),
        });
      });

      int manualRetrySyncCount = 0;
      SyncEngine.syncAllHandler = (auth, {client}) {
        manualRetrySyncCount++;
        return Future.value();
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: BookPage(email: 'user@example.com', password: 'password123'),
        ),
      );
      await pumpAsyncFrames(tester, count: 6, ms: 30);

      // Pending deletion banner should be displayed with Retry sync button
      final retryButton = find.text('Retry sync');
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      await pumpAsyncFrames(tester, count: 6, ms: 30);

      expect(manualRetrySyncCount, 1);
    });

    testWidgets('6a. Logout preserves books, expenses, categories, investments, and pending sync records', (WidgetTester tester) async {
      SyncEngine.markInitialSyncStarted();
      expect(SyncEngine.initialSyncStarted, isTrue);

      final dbHelper = DatabaseHelper.instance;
      final nowStr = DateTime.now().toIso8601String();
      await tester.runAsync(() async {
        final db = await dbHelper.database;
        final bookId = await dbHelper.insertLocalBook({
          'server_id': 101,
          'name': 'Active Ledger',
          'subtitle': 'Personal',
          'archived': 0,
          'created_at': nowStr,
          'updated_at': nowStr,
          'synced': 1,
        });
        final catId = await dbHelper.insertLocalCategory({
          'server_id': 301,
          'name': 'Food & Drinks',
          'icon': 'fastfood',
          'created_at': nowStr,
          'updated_at': nowStr,
          'synced': 1,
        });
        await dbHelper.insertLocalExpense({
          'server_id': 201,
          'book_id': bookId,
          'category_id': catId,
          'description': 'Groceries',
          'amount': 45.0,
          'credit': 0,
          'date': nowStr,
          'created_at': nowStr,
          'updated_at': nowStr,
          'synced': 1,
        });
        await dbHelper.insertLocalInvestment({
          'server_id': 401,
          'description': 'Mutual Funds',
          'amount': 5000.0,
          'created_at': nowStr,
          'updated_at': nowStr,
          'synced': 1,
        });
        await db.insert('pending_sync', {
          'table_name': 'books',
          'server_id': 999,
          'action': 'DELETE',
          'created_at': nowStr,
        });
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SettingPage(email: 'user@example.com', password: 'password123'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final logoutTileFinder = find.text("Log Out");
      await tester.ensureVisible(logoutTileFinder);
      await tester.tap(logoutTileFinder);
      await tester.pumpAndSettle();

      final confirmLogout = find.widgetWithText(ElevatedButton, "Logout");
      await tester.tap(confirmLogout);
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      // Verify session marker was reset
      expect(SyncEngine.initialSyncStarted, isFalse);

      // Verify local data is PRESERVED across logout!
      await tester.runAsync(() async {
        final db = await dbHelper.database;
        final books = await dbHelper.getLocalBooks(archived: 0);
        final expenses = await db.query('expenses');
        final categories = await dbHelper.getLocalCategories();
        final investments = await dbHelper.getLocalInvestments();
        final pending = await dbHelper.getPendingDeletes();

        expect(books.length, 1);
        expect(books.first['name'], 'Active Ledger');
        expect(expenses.length, 1);
        expect(expenses.first['description'], 'Groceries');
        expect(categories.any((c) => c['name'] == 'Food & Drinks'), isTrue);
        expect(investments.length, 1);
        expect(pending.length, 1);
      });

      // Verify SharedPreferences: email cleared, last_logged_in_email recorded
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isLoggedIn'), isNull);
      expect(prefs.getString('email'), isNull);
      expect(prefs.getString('last_logged_in_email'), 'user@example.com');
    });

    testWidgets('6b. Logging back into the same account preserves cached data', (WidgetTester tester) async {
      final dbHelper = DatabaseHelper.instance;
      final nowStr = DateTime.now().toIso8601String();
      await tester.runAsync(() async {
        await dbHelper.insertLocalBook({
          'server_id': 777,
          'name': 'User Same Account Ledger',
          'subtitle': 'Persisted',
          'archived': 0,
          'created_at': nowStr,
          'updated_at': nowStr,
          'synced': 1,
        });
      });

      setupTestSharedPreferences(initialValues: {
        'last_logged_in_email': 'user@example.com',
      });

      final syncGate = Completer<void>();
      SyncEngine.syncAllHandler = (auth, {client}) => syncGate.future;

      final mockClient = MockLoginHttpClient();
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(client: mockClient),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');

      final loginButton = find.widgetWithText(ElevatedButton, 'Login');
      await tester.ensureVisible(loginButton);
      await tester.tap(loginButton);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await pumpAsyncFrames(tester, count: 6, ms: 30);

      expect(find.byType(HomePage), findsOneWidget);
      // Cached book must still exist in SQLite!
      await tester.runAsync(() async {
        final books = await dbHelper.getLocalBooks(archived: 0);
        expect(books.any((b) => b['name'] == 'User Same Account Ledger'), isTrue);
      });
      // And must appear on screen immediately
      expect(find.text('User Same Account Ledger'), findsOneWidget);

      syncGate.complete();
      await pumpAsyncFrames(tester);
    });

    testWidgets('6c. Logging into a different account clears all previous account data before HomePage appears', (WidgetTester tester) async {
      final dbHelper = DatabaseHelper.instance;
      final nowStr = DateTime.now().toIso8601String();
      await tester.runAsync(() async {
        await dbHelper.insertLocalBook({
          'server_id': 888,
          'name': "User A's Secret Vault",
          'subtitle': 'Private',
          'archived': 0,
          'created_at': nowStr,
          'updated_at': nowStr,
          'synced': 1,
        });
      });

      setupTestSharedPreferences(initialValues: {
        'last_logged_in_email': 'userA@example.com',
      });
      SyncEngine.markInitialSyncStarted();
      expect(SyncEngine.initialSyncStarted, isTrue);

      final syncGate = Completer<void>();
      SyncEngine.syncAllHandler = (auth, {client}) => syncGate.future;

      final mockClient = MockLoginHttpClient();
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(client: mockClient),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'userB@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'passwordB123');

      final loginButton = find.widgetWithText(ElevatedButton, 'Login');
      await tester.ensureVisible(loginButton);
      await tester.tap(loginButton);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await pumpAsyncFrames(tester, count: 8, ms: 50);

      expect(find.byType(HomePage), findsOneWidget);
      expect(SyncEngine.initialSyncStarted, isTrue);

      // User A's data must be completely wiped from SQLite!
      await tester.runAsync(() async {
        final books = await dbHelper.getLocalBooks(archived: 0);
        expect(books.any((b) => b['name'] == "User A's Secret Vault"), isFalse);
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_logged_in_email'), 'userb@example.com');

      syncGate.complete();
      await pumpAsyncFrames(tester);
    });

    testWidgets('6d. Email comparison is case-insensitive and ignores surrounding whitespace', (WidgetTester tester) async {
      final dbHelper = DatabaseHelper.instance;
      final nowStr = DateTime.now().toIso8601String();
      await tester.runAsync(() async {
        await dbHelper.insertLocalBook({
          'server_id': 999,
          'name': 'Case Insensitive Preserved Ledger',
          'subtitle': 'Preserved',
          'archived': 0,
          'created_at': nowStr,
          'updated_at': nowStr,
          'synced': 1,
        });
      });

      // SharedPreferences has whitespace and mixed-case
      setupTestSharedPreferences(initialValues: {
        'last_logged_in_email': '  UserA@Example.COM  ',
      });

      final syncGate = Completer<void>();
      SyncEngine.syncAllHandler = (auth, {client}) => syncGate.future;

      final mockClient = MockLoginHttpClient();
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(client: mockClient),
        ),
      );
      await tester.pumpAndSettle();

      // Incoming login is lower-case with different surrounding whitespace
      await tester.enterText(find.byType(TextField).at(0), '  usera@example.com  ');
      await tester.enterText(find.byType(TextField).at(1), 'password123');

      final loginButton = find.widgetWithText(ElevatedButton, 'Login');
      await tester.ensureVisible(loginButton);
      await tester.tap(loginButton);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await pumpAsyncFrames(tester, count: 6, ms: 30);

      expect(find.byType(HomePage), findsOneWidget);
      // Because normalized emails match, local data must NOT be cleared!
      await tester.runAsync(() async {
        final books = await dbHelper.getLocalBooks(archived: 0);
        expect(books.any((b) => b['name'] == 'Case Insensitive Preserved Ledger'), isTrue);
      });
      expect(find.text('Case Insensitive Preserved Ledger'), findsOneWidget);

      syncGate.complete();
      await pumpAsyncFrames(tester);
    });

    testWidgets('7. Cached books are not replaced by skeleton placeholders while the initial SQLite read is pending', (WidgetTester tester) async {
      final dbHelper = DatabaseHelper.instance;
      await tester.runAsync(() async {
        await dbHelper.insertLocalBook({
          'server_id': 99,
          'name': 'Cached Offline Ledger',
          'subtitle': 'Locally Available',
          'archived': 0,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'synced': 1,
        });
      });

      final syncGate = Completer<void>();
      SyncEngine.syncAllHandler = (auth, {client}) => syncGate.future;

      unawaited(SyncEngine.syncAll('Basic dXNlcjpwYXNz'));
      expect(SyncEngine.isSyncing, isTrue);

      await tester.pumpWidget(
        const MaterialApp(
          home: BookPage(email: 'user@example.com', password: 'password123'),
        ),
      );

      // Frame 1: Initial local SQLite read is pending.
      // Must show AppLoading, NOT BookListSkeleton!
      await tester.pump();
      expect(find.byType(AppLoading), findsOneWidget);
      expect(find.byType(BookListSkeleton), findsNothing);

      // Once local SQLite read finishes: cached books appear immediately
      await pumpAsyncFrames(tester, count: 6, ms: 30);
      expect(find.text('Cached Offline Ledger'), findsOneWidget);
      expect(find.byType(BookListSkeleton), findsNothing);
      expect(find.byType(AppLoading), findsNothing);

      syncGate.complete();
      await pumpAsyncFrames(tester, count: 6, ms: 30);
    });

    testWidgets('8. An empty local database displays skeletons only after the local read completes and while cloud restoration is active', (WidgetTester tester) async {
      final syncGate = Completer<void>();
      SyncEngine.syncAllHandler = (auth, {client}) => syncGate.future;

      unawaited(SyncEngine.syncAll('Basic dXNlcjpwYXNz'));
      expect(SyncEngine.isSyncing, isTrue);

      await tester.pumpWidget(
        const MaterialApp(
          home: BookPage(email: 'user@example.com', password: 'password123'),
        ),
      );

      // Frame 1: Local SQLite read is pending. Must show AppLoading, NOT skeleton.
      await tester.pump();
      expect(find.byType(AppLoading), findsOneWidget);
      expect(find.byType(BookListSkeleton), findsNothing);

      // After local read finishes: empty local storage confirmed, cloud sync active -> shows skeleton
      await pumpAsyncFrames(tester, count: 6, ms: 30);
      expect(find.byType(BookListSkeleton), findsOneWidget);
      expect(find.byType(AppLoading), findsNothing);
      expect(find.byType(AppEmptyState), findsNothing);

      // Once cloud sync completes: skeleton removed
      syncGate.complete();
      await pumpAsyncFrames(tester, count: 6, ms: 30);
      expect(find.byType(BookListSkeleton), findsNothing);
    });

    testWidgets('9. Existing sync concurrency and restoration tests continue passing', (WidgetTester tester) async {
      int executions = 0;
      final syncGate = Completer<void>();
      SyncEngine.syncAllHandler = (auth, {client}) {
        executions++;
        return syncGate.future;
      };

      // Launch multiple concurrent sync calls
      final f1 = SyncEngine.syncAll('Basic auth');
      final f2 = SyncEngine.syncAll('Basic auth');
      final f3 = SyncEngine.syncAll('Basic auth');

      // All returned futures must be identical (joined the same completer)
      expect(identical(f1, f2), isTrue);
      expect(identical(f2, f3), isTrue);

      syncGate.complete();
      await Future.wait([f1, f2, f3]);
      expect(executions, 1);
    });
  });
}
