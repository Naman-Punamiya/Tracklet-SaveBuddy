import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:expense_tracker/services/connectivity_service.dart';
import '../helpers/test_helpers.dart';

class MockDeletionClient extends http.BaseClient {
  final List<String> deletedUrls = [];
  final List<String> requestedUrls = [];
  int deleteStatusCode = 200;
  List<Map<String, dynamic>> serverBooks = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedUrls.add(request.url.toString());

    if (request.method == 'DELETE') {
      deletedUrls.add(request.url.toString());
      return http.StreamedResponse(
        Stream.value(utf8.encode(deleteStatusCode == 200 ? '{"message": "Book deleted"}' : '{"error": "Failed"}')),
        deleteStatusCode,
        headers: {'content-type': 'application/json'},
      );
    }

    if (request.url.path.endsWith('/books/readAll')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(serverBooks))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    if (request.url.path.endsWith('/books/readAllArchived')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode([]))),
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

void main() {
  setupTestDatabase();

  late DatabaseHelper dbHelper;
  const basicAuth = 'Basic dGVzdEBleGFtcGxlLmNvbTpwYXNzd29yZA==';

  setUp(() async {
    ConnectivityService.mockStatus = ConnectivityStatus.wifi;
    dbHelper = DatabaseHelper.instance;
    await resetTestDatabase();
  });

  group('Book Deletion and Pending Synchronization Tests', () {
    test('1. Online deletion sends the correct server ID and removes pending delete on success', () async {
      final mockClient = MockDeletionClient();
      final bookRepo = BookRepository(client: mockClient);

      final now = DateTime.now().toIso8601String();
      final localId = await dbHelper.insertLocalBook({
        'server_id': 101,
        'name': 'Trip Book',
        'subtitle': 'Tokyo',
        'created_at': now,
        'updated_at': now,
        'synced': 1,
      });

      final cloudDeleted = await bookRepo.deleteBook(localId.toString(), basicAuth);

      expect(cloudDeleted, isTrue);
      expect(mockClient.deletedUrls.length, 1);
      expect(mockClient.deletedUrls.first.endsWith('/books/delete/101'), isTrue);

      // Verify book removed locally
      expect(await dbHelper.getLocalBookById(localId), isNull);

      // Verify pending deletion removed on success
      final pending = await dbHelper.getPendingDeletes();
      expect(pending.where((p) => p['table_name'] == 'books' && p['server_id'] == 101), isEmpty);
    });

    test('2. An unsuccessful HTTP response retains the pending deletion', () async {
      final mockClient = MockDeletionClient()..deleteStatusCode = 500;
      final bookRepo = BookRepository(client: mockClient);

      final now = DateTime.now().toIso8601String();
      final localId = await dbHelper.insertLocalBook({
        'server_id': 102,
        'name': 'Failing Book',
        'created_at': now,
        'updated_at': now,
        'synced': 1,
      });

      final cloudDeleted = await bookRepo.deleteBook(localId.toString(), basicAuth);

      // Returns false because cloud deletion has not succeeded yet
      expect(cloudDeleted, isFalse);
      expect(mockClient.deletedUrls.length, 1);

      // Local book is removed so user can proceed
      expect(await dbHelper.getLocalBookById(localId), isNull);

      // Pending deletion is preserved in queue for background sync retry
      final pending = await dbHelper.getPendingDeletes();
      expect(pending.any((p) => p['table_name'] == 'books' && p['server_id'] == 102), isTrue);
    });

    test('3. Offline deletion persists the pending deletion', () async {
      ConnectivityService.mockStatus = ConnectivityStatus.offline;
      final mockClient = MockDeletionClient();
      final bookRepo = BookRepository(client: mockClient);

      final now = DateTime.now().toIso8601String();
      final localId = await dbHelper.insertLocalBook({
        'server_id': 103,
        'name': 'Offline Book',
        'created_at': now,
        'updated_at': now,
        'synced': 1,
      });

      final cloudDeleted = await bookRepo.deleteBook(localId.toString(), basicAuth);

      expect(cloudDeleted, isFalse);
      expect(mockClient.deletedUrls, isEmpty); // No HTTP call offline

      // Local book is removed
      expect(await dbHelper.getLocalBookById(localId), isNull);

      // Pending delete is persisted in SQLite
      final pending = await dbHelper.getPendingDeletes();
      expect(pending.any((p) => p['table_name'] == 'books' && p['server_id'] == 103), isTrue);
    });

    test('4. Local child expenses are removed with the book', () async {
      final mockClient = MockDeletionClient();
      final bookRepo = BookRepository(client: mockClient);

      final now = DateTime.now().toIso8601String();
      final localId = await dbHelper.insertLocalBook({
        'server_id': 104,
        'name': 'Book With Expenses',
        'created_at': now,
        'updated_at': now,
        'synced': 1,
      });

      await dbHelper.insertLocalExpense({
        'book_id': localId,
        'description': 'Coffee',
        'amount': 4.5,
        'credit': 0,
        'date': now,
        'created_at': now,
        'updated_at': now,
        'synced': 1,
      });

      await dbHelper.insertLocalExpense({
        'book_id': localId,
        'description': 'Sandwich',
        'amount': 8.0,
        'credit': 0,
        'date': now,
        'created_at': now,
        'updated_at': now,
        'synced': 1,
      });

      // Verify expenses exist before book deletion
      final expensesBefore = await dbHelper.getLocalExpensesByBook(localId);
      expect(expensesBefore.length, 2);

      // Delete the book
      await bookRepo.deleteBook(localId.toString(), basicAuth);

      // Verify local child expenses are deleted with the book
      final expensesAfter = await dbHelper.getLocalExpensesByBook(localId);
      expect(expensesAfter, isEmpty);

      final db = await dbHelper.database;
      final rawExpenses = await db.query('expenses', where: 'book_id = ?', whereArgs: [localId]);
      expect(rawExpenses, isEmpty, reason: "No orphaned expenses should remain in SQLite table");
    });

    test('5. A successful pending deletion is removed from the queue during sync', () async {
      final mockClient = MockDeletionClient();
      final bookRepo = BookRepository(client: mockClient);

      // Queue a pending deletion
      await dbHelper.logPendingDelete('books', 105);
      expect((await dbHelper.getPendingDeletes()).length, 1);

      // Run syncBooks
      await bookRepo.syncBooks(basicAuth);

      // Verify DELETE request was sent
      expect(mockClient.deletedUrls.any((url) => url.endsWith('/books/delete/105')), isTrue);

      // Verify pending delete was cleared
      final pendingAfter = await dbHelper.getPendingDeletes();
      expect(pendingAfter.where((p) => p['table_name'] == 'books' && p['server_id'] == 105), isEmpty);
    });

    test('6. A book with a pending deletion is not restored from the server', () async {
      final mockClient = MockDeletionClient();
      // Server still returns book 106 because server-side delete might be in-flight or cached
      mockClient.serverBooks = [
        {'id': 106, 'name': 'Deleted Server Book', 'archived': false},
      ];
      // Simulate backend temporary 500 when flushing delete
      mockClient.deleteStatusCode = 500;

      final bookRepo = BookRepository(client: mockClient);

      // Queue pending deletion for 106
      await dbHelper.logPendingDelete('books', 106);

      // Run syncBooks
      await bookRepo.syncBooks(basicAuth);

      // Verify book was NOT re-inserted into SQLite because isDeletedLocally is true
      final books = await dbHelper.getLocalBooks(archived: 0);
      expect(books.where((b) => b['server_id'] == 106), isEmpty);
    });

    test('7. A local-only book can be deleted without a backend request', () async {
      final mockClient = MockDeletionClient();
      final bookRepo = BookRepository(client: mockClient);

      final now = DateTime.now().toIso8601String();
      // local-only book: server_id is null
      final localId = await dbHelper.insertLocalBook({
        'server_id': null,
        'name': 'Local Only Book',
        'created_at': now,
        'updated_at': now,
        'synced': 0,
      });

      final cloudDeleted = await bookRepo.deleteBook(localId.toString(), basicAuth);

      expect(cloudDeleted, isTrue);
      expect(mockClient.deletedUrls, isEmpty, reason: "Local-only book must not trigger a backend DELETE");
      expect(await dbHelper.getLocalBookById(localId), isNull);

      final pending = await dbHelper.getPendingDeletes();
      expect(pending, isEmpty, reason: "No pending delete should be logged for local-only book");
    });
  });
}
