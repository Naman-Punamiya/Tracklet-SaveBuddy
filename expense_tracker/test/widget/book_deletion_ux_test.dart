import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/custom_widgets/pending_deletion_banner.dart';
import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/pages/HomePage/book_page.dart';
import 'package:expense_tracker/pages/archived_page.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:expense_tracker/services/connectivity_service.dart';
import '../helpers/test_helpers.dart';

void main() {
  setupTestDatabase();

  setUp(() async {
    setupTestSharedPreferences();
    await resetTestDatabase();
    ConnectivityService.mockStatus = ConnectivityStatus.offline;
  });

  group('PendingDeletionBanner Widget Tests', () {
    testWidgets('displays singular text when count is 1', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PendingDeletionBanner(
              count: 1,
              isRetrying: false,
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.text('Deletion waiting to sync'), findsOneWidget);
      expect(find.text('Retry sync'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    });

    testWidgets('displays plural text when count is greater than 1', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PendingDeletionBanner(
              count: 3,
              isRetrying: false,
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.text('3 deletions waiting to sync'), findsOneWidget);
      expect(find.text('Retry sync'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    });

    testWidgets('displays loading indicator when isRetrying is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PendingDeletionBanner(
              count: 2,
              isRetrying: true,
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Retry sync'), findsNothing);
    });

    testWidgets('triggers onRetry callback when Retry button tapped', (WidgetTester tester) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PendingDeletionBanner(
              count: 1,
              isRetrying: false,
              onRetry: () {
                retried = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Retry sync'));
      await tester.pump();

      expect(retried, isTrue);
    });

    testWidgets('renders properly in both Light and Dark modes', (WidgetTester tester) async {
      // Light Mode
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: PendingDeletionBanner(
              count: 1,
              isRetrying: false,
              onRetry: () {},
            ),
          ),
        ),
      );
      expect(find.text('Deletion waiting to sync'), findsOneWidget);

      // Dark Mode
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: PendingDeletionBanner(
              count: 1,
              isRetrying: false,
              onRetry: () {},
            ),
          ),
        ),
      );
      expect(find.text('Deletion waiting to sync'), findsOneWidget);
    });
  });

  group('BookRepository Deletion UX & Pending Counts', () {
    test('getPendingDeletionsCount returns accurate count', () async {
      final dbHelper = DatabaseHelper.instance;
      final bookRepo = BookRepository();

      expect(await bookRepo.getPendingDeletionsCount(), 0);

      await dbHelper.logPendingDelete('books', 101);
      expect(await bookRepo.getPendingDeletionsCount(), 1);

      await dbHelper.logPendingDelete('books', 102);
      expect(await bookRepo.getPendingDeletionsCount(), 2);

      // Non-book pending delete should not count
      await dbHelper.logPendingDelete('expenses', 501);
      expect(await bookRepo.getPendingDeletionsCount(), 2);
    });
  });

  group('BookPage Optimistic Deletion & Sync Indicator Tests', () {
    testWidgets('deleting a book removes it immediately and displays "Book deleted."', (WidgetTester tester) async {
      final now = DateTime.now().toIso8601String();
      await tester.runAsync(() async {
        await DatabaseHelper.instance.insertLocalBook({
          'server_id': 201,
          'name': 'Trip to Kyoto',
          'subtitle': 'Vacation 2026',
          'archived': 0,
          'created_at': now,
          'updated_at': now,
          'synced': 1,
        });
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: BookPage(email: 'user@test.com', password: 'password'),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Trip to Kyoto'), findsOneWidget);

      // Long press book card to open details dialog
      await tester.longPress(find.text('Trip to Kyoto'));
      await tester.pumpAndSettle();

      expect(find.text('Book Options'), findsOneWidget);
      expect(find.text('Delete / Archive'), findsOneWidget);

      // Tap Delete / Archive
      await tester.tap(find.text('Delete / Archive'));
      await tester.pumpAndSettle();

      expect(find.text('Manage Book'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Delete'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      for (int i = 0; i < 8; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      // 1. Immediately removed from visible list
      expect(find.text('Trip to Kyoto'), findsNothing);

      // 2. Short, user-friendly success message
      expect(find.text('Book deleted.'), findsOneWidget);
      expect(find.text('Book deleted locally. Cloud deletion pending sync.'), findsNothing);

      // 3. Deletion is offline, so pending sync indicator appears
      expect(find.text('Deletion waiting to sync'), findsOneWidget);
      expect(find.text('Retry sync'), findsOneWidget);
    });

    testWidgets('pending deletion indicator remains visible when all books are deleted (empty state)', (WidgetTester tester) async {
      // Put a pending delete in SQLite
      await tester.runAsync(() async {
        await DatabaseHelper.instance.logPendingDelete('books', 999);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: BookPage(email: 'user@test.com', password: 'password'),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Empty state is rendered
      expect(find.text('No Books Yet'), findsOneWidget);

      // AND the pending deletion banner is displayed above the empty state!
      expect(find.text('Deletion waiting to sync'), findsOneWidget);
      expect(find.text('Retry sync'), findsOneWidget);
    });
  });

  group('ArchivedBooksPage Optimistic Deletion & Sync Indicator Tests', () {
    testWidgets('deleting archived book removes it immediately and displays "Book deleted."', (WidgetTester tester) async {
      final now = DateTime.now().toIso8601String();
      await tester.runAsync(() async {
        await DatabaseHelper.instance.insertLocalBook({
          'server_id': 301,
          'name': 'Old Project 2024',
          'subtitle': 'Archived work',
          'archived': 1,
          'created_at': now,
          'updated_at': now,
          'synced': 1,
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

      expect(find.text('Old Project 2024'), findsOneWidget);

      // Tap on the archived book to open details dialog
      await tester.tap(find.text('Old Project 2024'));
      await tester.pumpAndSettle();

      expect(find.text('Book Details'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Tap Delete
      await tester.tap(find.text('Delete'));
      for (int i = 0; i < 8; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      // 1. Immediately removed from visible list
      expect(find.text('Old Project 2024'), findsNothing);

      // 2. Short, user-friendly success message
      expect(find.text('Book deleted.'), findsOneWidget);
      expect(find.text('Book deleted locally. Cloud deletion pending sync.'), findsNothing);

      // 3. Deletion is offline, so pending sync indicator appears
      expect(find.text('Deletion waiting to sync'), findsOneWidget);
      expect(find.text('Retry sync'), findsOneWidget);
    });

    testWidgets('shows pending deletion banner on ArchivedBooksPage when pending sync exists', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await DatabaseHelper.instance.logPendingDelete('books', 777);
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

      expect(find.text('Deletion waiting to sync'), findsOneWidget);
      expect(find.text('Retry sync'), findsOneWidget);
    });
  });
}
