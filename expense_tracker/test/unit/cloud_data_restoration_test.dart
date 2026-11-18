import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:expense_tracker/services/connectivity_service.dart';
import '../helpers/test_helpers.dart';

class MockBackendClient extends http.BaseClient {
  final Map<String, dynamic> dataStore;
  final bool failCategories;
  final bool failAll;
  final String? expectedAuth;
  final List<String> requestedUrls = [];

  MockBackendClient({
    required this.dataStore,
    this.failCategories = false,
    this.failAll = false,
    this.expectedAuth,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedUrls.add(request.url.toString());

    if (failAll) {
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"error": "Network down"}')),
        500,
        headers: {'content-type': 'application/json'},
      );
    }

    if (expectedAuth != null) {
      final authHeader = request.headers['Authorization'] ?? request.headers['authorization'];
      if (authHeader != expectedAuth) {
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"error": "Unauthorized"}')),
          401,
          headers: {'content-type': 'application/json'},
        );
      }
    }

    final path = request.url.path;

    if (failCategories && path.contains('categories')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"error": "Category service unavailable"}')),
        500,
        headers: {'content-type': 'application/json'},
      );
    }

    // Books
    if (path.endsWith('/books/readAll')) {
      final books = dataStore['books_active'] ?? [];
      return _jsonResponse(books);
    }
    if (path.endsWith('/books/readAllArchived') || path.endsWith('/books/archived')) {
      final books = dataStore['books_archived'] ?? [];
      return _jsonResponse(books);
    }
    if (path.endsWith('/books/create') && request.method == 'POST') {
      final body = await _readBody(request);
      final newBook = {
        'id': 999,
        'name': body['name'],
        'subtitle': body['subtitle'],
        'archived': false,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      return _jsonResponse(newBook);
    }

    // Categories
    if (path.endsWith('/categories/readAll')) {
      final cats = dataStore['categories'] ?? [];
      return _jsonResponse(cats);
    }
    if (path.endsWith('/categories/create') && request.method == 'POST') {
      final body = await _readBody(request);
      final newCat = {
        'id': 888,
        'name': body['name'],
        'icon': body['icon'],
        'color': body['color'],
      };
      return _jsonResponse(newCat);
    }

    // Expenses
    if (path.endsWith('/expenses/readAll')) {
      final expenses = dataStore['expenses'] ?? [];
      return _jsonResponse(expenses);
    }
    if (path.contains('/expenses/book/')) {
      final bookId = int.tryParse(path.split('/').last);
      final allExpenses = (dataStore['expenses'] as List<dynamic>?) ?? [];
      final filtered = allExpenses.where((e) => e['book']?['id'] == bookId).toList();
      return _jsonResponse(filtered);
    }
    if (path.endsWith('/expenses/create') && request.method == 'POST') {
      final body = await _readBody(request);
      final newExpense = {
        'id': 777,
        'description': body['description'],
        'amount': body['amount'],
        'credit': body['credit'],
        'date': body['date'],
        'book': body['book'],
        'category': body['category'],
      };
      return _jsonResponse(newExpense);
    }

    // Investments
    if (path.endsWith('/investments/readAll')) {
      final investments = dataStore['investments'] ?? [];
      return _jsonResponse(investments);
    }
    if (path.endsWith('/investments/create') && request.method == 'POST') {
      final body = await _readBody(request);
      final newInv = {
        'id': 666,
        'description': body['description'],
        'amount': body['amount'],
      };
      return _jsonResponse(newInv);
    }

    return _jsonResponse([]);
  }

  Future<Map<String, dynamic>> _readBody(http.BaseRequest request) async {
    if (request is http.Request) {
      return jsonDecode(request.body) as Map<String, dynamic>;
    }
    return {};
  }

  http.StreamedResponse _jsonResponse(dynamic body, [int status = 200]) {
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      status,
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

  group('Cloud Data Restoration & Synchronization Tests', () {
    test('1. Fresh SQLite database + existing backend books -> books restored locally', () async {
      // Simulate backend state
      final serverBooks = [
        {
          'id': 101,
          'name': 'Personal Ledger',
          'subtitle': 'Primary accounts',
          'archived': false,
          'createdAt': '2026-01-01T00:00:00Z',
          'updatedAt': '2026-01-01T00:00:00Z',
        },
        {
          'id': 102,
          'name': 'Business Vault',
          'subtitle': 'LLC Expenses',
          'archived': false,
          'createdAt': '2026-01-02T00:00:00Z',
          'updatedAt': '2026-01-02T00:00:00Z',
        },
      ];

      final client = MockBackendClient(dataStore: {
        'books_active': serverBooks,
        'books_archived': [],
      });

      // Initially SQLite has 0 books
      expect((await dbHelper.getLocalBooks(archived: 0)).isEmpty, isTrue);

      // Perform sync
      await SyncEngine.syncAll(basicAuth, client: client);

      // Verify books restored
      final restoredBooks = await dbHelper.getLocalBooks(archived: 0);
      expect(restoredBooks.length, 2);
      expect(restoredBooks.any((b) => b['server_id'] == 101 && b['name'] == 'Personal Ledger'), isTrue);
      expect(restoredBooks.any((b) => b['server_id'] == 102 && b['name'] == 'Business Vault'), isTrue);
      for (final book in restoredBooks) {
        expect(book['synced'], 1);
      }
    });

    test('2. Fresh database + existing expenses -> expenses restored with correct book relationships', () async {
      final serverBooks = [
        {
          'id': 201,
          'name': 'Trip Book',
          'subtitle': 'Vacation',
          'archived': false,
        },
      ];
      final serverExpenses = [
        {
          'id': 501,
          'description': 'Flight Ticket',
          'amount': 350.0,
          'credit': false,
          'date': '2026-05-10T10:00:00Z',
          'book': {'id': 201},
        },
        {
          'id': 502,
          'description': 'Freelance Income',
          'amount': 1000.0,
          'credit': true,
          'date': '2026-05-11T12:00:00Z',
          'book': {'id': 201},
        },
      ];

      final client = MockBackendClient(dataStore: {
        'books_active': serverBooks,
        'expenses': serverExpenses,
      });

      await SyncEngine.syncAll(basicAuth, client: client);

      final localBook = await dbHelper.getLocalBookByServerId(201);
      expect(localBook, isNotNull);
      final localBookId = localBook!['id'] as int;

      final restoredExpenses = await dbHelper.getLocalExpensesByBook(localBookId);
      expect(restoredExpenses.length, 2);

      final flight = restoredExpenses.firstWhere((e) => e['server_id'] == 501);
      expect(flight['description'], 'Flight Ticket');
      expect(flight['amount'], 350.0);
      expect(flight['credit'], false);
      expect(flight['book_id'], localBookId);

      final income = restoredExpenses.firstWhere((e) => e['server_id'] == 502);
      expect(income['description'], 'Freelance Income');
      expect(income['amount'], 1000.0);
      expect(income['credit'], true);
      expect(income['book_id'], localBookId);

      // Verify balance calculation
      final expenseRepo = ExpenseRepository(client: client);
      final balance = await expenseRepo.getBookBalance(localBookId.toString());
      expect(balance, 650.0); // 1000 credit - 350 expense
    });

    test('3. Existing categories restored without duplicate default categories', () async {
      // Initialize default categories
      final initialCategories = await dbHelper.getLocalCategories();
      expect(initialCategories.isNotEmpty, isTrue);
      final defaultCount = initialCategories.length;

      // Server returns one existing default category ("Food") and one custom category
      final serverCategories = [
        {'id': 301, 'name': 'Food', 'icon': 'Fastfood', 'color': '#FF5722'},
        {'id': 302, 'name': 'Crypto Staking', 'icon': 'CurrencyBitcoin', 'color': '#F57C00'},
      ];

      final client = MockBackendClient(dataStore: {
        'categories': serverCategories,
      });

      await SyncEngine.syncAll(basicAuth, client: client);

      final updatedCategories = await dbHelper.getLocalCategories();
      // Should not have duplicated "Food"
      final foodCategories = updatedCategories.where((c) => c['name'].toString().toLowerCase() == 'food').toList();
      expect(foodCategories.length, 1);
      expect(foodCategories.first['server_id'], 301);

      // Custom category should be inserted
      final customCat = updatedCategories.firstWhere((c) => c['name'] == 'Crypto Staking');
      expect(customCat['server_id'], 302);

      // Total count should only increase by 1 (the new custom category)
      expect(updatedCategories.length, defaultCount + 1);
    });

    test('4. Investments restored', () async {
      final serverInvestments = [
        {'id': 401, 'description': 'Index Fund S&P 500', 'amount': 2500.0},
        {'id': 402, 'description': 'Government Bonds', 'amount': 1000.0},
      ];

      final client = MockBackendClient(dataStore: {
        'investments': serverInvestments,
      });

      await SyncEngine.syncAll(basicAuth, client: client);

      final localInvestments = await dbHelper.getLocalInvestments();
      expect(localInvestments.length, 2);
      expect(localInvestments.any((i) => i['server_id'] == 401 && i['amount'] == 2500.0), isTrue);
      expect(localInvestments.any((i) => i['server_id'] == 402 && i['amount'] == 1000.0), isTrue);
    });

    test('5. Archived books handled correctly', () async {
      final activeBooks = [
        {'id': 501, 'name': 'Active Ledger', 'subtitle': 'Active', 'archived': false},
      ];
      final archivedBooks = [
        {'id': 502, 'name': 'Old 2025 Ledger', 'subtitle': 'Archived', 'archived': true},
      ];

      final client = MockBackendClient(dataStore: {
        'books_active': activeBooks,
        'books_archived': archivedBooks,
      });

      await SyncEngine.syncAll(basicAuth, client: client);

      final active = await dbHelper.getLocalBooks(archived: 0);
      final archived = await dbHelper.getLocalBooks(archived: 1);

      expect(active.length, 1);
      expect(active.first['server_id'], 501);
      expect(active.first['archived'], 0);

      expect(archived.length, 1);
      expect(archived.first['server_id'], 502);
      expect(archived.first['archived'], 1);
    });

    test('6. Category API failure does not prevent book restoration', () async {
      final serverBooks = [
        {'id': 601, 'name': 'Resilient Book', 'subtitle': 'Works despite cat error', 'archived': false},
      ];

      final client = MockBackendClient(
        dataStore: {'books_active': serverBooks},
        failCategories: true, // Categories endpoint returns 500
      );

      // syncAll should not throw and should proceed with books
      await SyncEngine.syncAll(basicAuth, client: client);

      final books = await dbHelper.getLocalBooks(archived: 0);
      expect(books.length, 1);
      expect(books.first['server_id'], 601);
      expect(books.first['name'], 'Resilient Book');
    });

    test('7. Network failure preserves unsynced local records', () async {
      // Create local uncommitted records
      final localBookId = await dbHelper.insertLocalBook({
        'name': 'Offline Unsynced Book',
        'subtitle': 'Should not be lost',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'synced': 0,
      });

      final client = MockBackendClient(dataStore: {}, failAll: true);

      // Run sync during total backend outage
      await SyncEngine.syncAll(basicAuth, client: client);

      // Verify local record is still present and unsynced
      final localBook = await dbHelper.getLocalBookById(localBookId);
      expect(localBook, isNotNull);
      expect(localBook!['name'], 'Offline Unsynced Book');
      expect(localBook['server_id'], isNull);
    });

    test('8. Repeated restoration does not create duplicates', () async {
      final serverBooks = [
        {'id': 701, 'name': 'Repeat Book', 'subtitle': 'No dupes', 'archived': false},
      ];
      final serverInvestments = [
        {'id': 702, 'description': 'Repeat Investment', 'amount': 500.0},
      ];

      final client = MockBackendClient(dataStore: {
        'books_active': serverBooks,
        'investments': serverInvestments,
      });

      // First sync
      await SyncEngine.syncAll(basicAuth, client: client);
      expect((await dbHelper.getLocalBooks(archived: 0)).length, 1);
      expect((await dbHelper.getLocalInvestments()).length, 1);

      // Second sync
      await SyncEngine.syncAll(basicAuth, client: client);
      expect((await dbHelper.getLocalBooks(archived: 0)).length, 1);
      expect((await dbHelper.getLocalInvestments()).length, 1);

      // Third sync
      await SyncEngine.syncAll(basicAuth, client: client);
      expect((await dbHelper.getLocalBooks(archived: 0)).length, 1);
      expect((await dbHelper.getLocalInvestments()).length, 1);
    });

    test('9. User A cannot restore User B records (user isolation / token verification)', () async {
      const userBAuth = 'Basic dXNlckJAZXhhbXBsZS5jb206cGFzc3dvcmRC';

      // Insert User A local data
      await dbHelper.insertLocalBook({
        'server_id': 801,
        'name': "User A's Secret Book",
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'synced': 1,
      });

      // User B logs in: simulate isolation clearAllData
      await dbHelper.clearAllData();

      expect((await dbHelper.getLocalBooks(archived: 0)).isEmpty, isTrue);

      // Server requires userBAuth
      final client = MockBackendClient(
        dataStore: {
          'books_active': [
            {'id': 802, 'name': "User B's Book", 'archived': false},
          ],
        },
        expectedAuth: userBAuth,
      );

      // Syncing with userBAuth succeeds and restores only user B data
      await SyncEngine.syncAll(userBAuth, client: client);
      final books = await dbHelper.getLocalBooks(archived: 0);
      expect(books.length, 1);
      expect(books.first['name'], "User B's Book");
      expect(books.any((b) => b['name'] == "User A's Secret Book"), isFalse);
    });

    test('10. Email addresses containing "test" synchronize normally', () async {
      const testUserAuth = 'Basic dGVzdF9hY2NvdW50QHRlc3QuY29tOnBhc3N3b3Jk'; // test_account@test.com
      final serverBooks = [
        {'id': 901, 'name': 'Test Account Book', 'archived': false},
      ];

      final client = MockBackendClient(dataStore: {
        'books_active': serverBooks,
      });

      await SyncEngine.syncAll(testUserAuth, client: client);

      final books = await dbHelper.getLocalBooks(archived: 0);
      expect(books.length, 1);
      expect(books.first['server_id'], 901);
      expect(books.first['name'], 'Test Account Book');
    });

    test('11. Full simulated uninstall/reinstall lifecycle', () async {
      // Step A: App is installed, user creates records and syncs them to backend
      final backendStore = <String, dynamic>{
        'books_active': [
          {'id': 1001, 'name': 'Life Savings Book', 'subtitle': 'Main', 'archived': false},
        ],
        'categories': [
          {'id': 1002, 'name': 'Salary', 'icon': 'AttachMoney', 'color': '#4CAF50'},
        ],
        'expenses': [
          {
            'id': 1003,
            'description': 'Monthly Paycheck',
            'amount': 5000.0,
            'credit': true,
            'date': '2026-06-01T09:00:00Z',
            'book': {'id': 1001},
            'category': {'id': 1002},
          },
        ],
        'investments': [
          {'id': 1004, 'description': 'Mutual Funds', 'amount': 1500.0},
        ],
      };

      final client = MockBackendClient(dataStore: backendStore);

      // Initial state has active book & records
      await SyncEngine.syncAll(basicAuth, client: client);
      expect((await dbHelper.getLocalBooks(archived: 0)).length, 1);
      expect((await dbHelper.getLocalInvestments()).length, 1);

      // Step B: User uninstalls the application (SQLite database deleted completely)
      await resetTestDatabase();
      expect((await dbHelper.getLocalBooks(archived: 0)).isEmpty, isTrue);
      expect((await dbHelper.getLocalInvestments()).isEmpty, isTrue);

      // Step C: User reinstalls the application and logs in -> restoration triggers
      await SyncEngine.syncAll(basicAuth, client: client);

      // Step D: Verify all entities and relationships restored into SQLite
      final restoredBooks = await dbHelper.getLocalBooks(archived: 0);
      expect(restoredBooks.length, 1);
      final restoredBook = restoredBooks.first;
      expect(restoredBook['server_id'], 1001);
      expect(restoredBook['name'], 'Life Savings Book');
      final localBookId = restoredBook['id'] as int;

      final restoredExpenses = await dbHelper.getLocalExpensesByBook(localBookId);
      expect(restoredExpenses.length, 1);
      final restoredExpense = restoredExpenses.first;
      expect(restoredExpense['server_id'], 1003);
      expect(restoredExpense['description'], 'Monthly Paycheck');
      expect(restoredExpense['amount'], 5000.0);
      expect(restoredExpense['credit'], true);
      expect(restoredExpense['book_id'], localBookId);

      final restoredInvestments = await dbHelper.getLocalInvestments();
      expect(restoredInvestments.length, 1);
      expect(restoredInvestments.first['server_id'], 1004);
      expect(restoredInvestments.first['description'], 'Mutual Funds');
      expect(restoredInvestments.first['amount'], 1500.0);
    });
  });
}
