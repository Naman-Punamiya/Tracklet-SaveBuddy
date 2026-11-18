import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:expense_tracker/constant.dart';
import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/services/connectivity_service.dart';

class BookRepository {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  final http.Client client;

  BookRepository({http.Client? client}) : client = client ?? http.Client();

  Future<List<Map<String, dynamic>>> getBooks({required int archived}) async {
    return await dbHelper.getLocalBooks(archived: archived);
  }

  Future<List<Map<String, dynamic>>> searchBooks(String query, int archived) async {
    return await dbHelper.searchLocalBooks(query, archived);
  }

  Future<void> addBook(String name, String subtitle, String basicAuth) async {
    final nowStr = DateTime.now().toIso8601String();
    
    // 1. Save SQLite local
    final Map<String, dynamic> row = {
      'name': name,
      'subtitle': subtitle,
      'archived': 0,
      'created_at': nowStr,
      'updated_at': nowStr,
      'synced': 0,
    };
    
    final localId = await dbHelper.insertLocalBook(row);

    // 2. Call API if online
    if (await ConnectivityService.isOnline()) {
      try {
        final url = Uri.parse("${bookUrl}create");
        final res = await client.post(
          url,
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode({'name': name, 'subtitle': subtitle}),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = safeJsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            final serverId = data['id'];
            if (serverId != null) {
              await dbHelper.updateSyncStatus('books', localId, serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? nowStr);
            }
          }
        }
      } catch (e) {
        debugPrint("API Book create failed (offline mode): $e");
      }
    }
  }

  Future<void> updateBook(String id, String name, String subtitle, String basicAuth) async {
    final nowStr = DateTime.now().toIso8601String();
    final localId = int.parse(id);
    
    // Fetch local book to check server id
    final localBook = await dbHelper.getLocalBookById(localId);
    final serverId = localBook?['server_id'];

    // 1. Update SQLite local
    final Map<String, dynamic> row = {
      'name': name,
      'subtitle': subtitle,
      'updated_at': nowStr,
      'synced': 0,
    };
    await dbHelper.updateLocalBook(localId, row);

    // 2. Call API if online
    if (await ConnectivityService.isOnline() && serverId != null) {
      try {
        final url = Uri.parse("${bookUrl}edit/$serverId");
        final res = await client.put(
          url,
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode({'name': name, 'subtitle': subtitle}),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = safeJsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            await dbHelper.updateSyncStatus('books', localId, serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? nowStr);
          }
        }
      } catch (e) {
        debugPrint("API Book edit failed: $e");
      }
    }
  }

  Future<void> archiveBook(String id, String basicAuth) async {
    final nowStr = DateTime.now().toIso8601String();
    final localId = int.parse(id);
    final localBook = await dbHelper.getLocalBookById(localId);
    final serverId = localBook?['server_id'];

    // 1. SQLite local
    await dbHelper.updateLocalBook(localId, {
      'archived': 1,
      'updated_at': nowStr,
      'synced': 0,
    });

    // 2. Call API
    if (await ConnectivityService.isOnline() && serverId != null) {
      try {
        final url = Uri.parse("${bookUrl}archive/$serverId");
        final res = await client.patch(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          await dbHelper.updateSyncStatus('books', localId, serverId, updatedAt: nowStr);
        }
      } catch (e) {
        debugPrint("API Book archive failed: $e");
      }
    }
  }

  Future<void> restoreBook(String id, String basicAuth) async {
    final nowStr = DateTime.now().toIso8601String();
    final localId = int.parse(id);
    final localBook = await dbHelper.getLocalBookById(localId);
    final serverId = localBook?['server_id'];

    // 1. SQLite local
    await dbHelper.updateLocalBook(localId, {
      'archived': 0,
      'updated_at': nowStr,
      'synced': 0,
    });

    // 2. Call API
    if (await ConnectivityService.isOnline() && serverId != null) {
      try {
        final url = Uri.parse("${bookUrl}restore/$serverId");
        final res = await client.patch(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          await dbHelper.updateSyncStatus('books', localId, serverId, updatedAt: nowStr);
        }
      } catch (e) {
        debugPrint("API Book restore failed: $e");
      }
    }
  }

  Future<bool> deleteBook(String id, String basicAuth) async {
    final localId = int.parse(id);
    final localBook = await dbHelper.getLocalBookById(localId);
    final serverId = localBook?['server_id'];

    bool cloudDeleted = false;

    // 1. If it had server ID, persist pending delete BEFORE deleting local book
    if (serverId != null) {
      await dbHelper.logPendingDelete('books', serverId);

      // 2. SQLite local delete (removes local book and its child expenses)
      await dbHelper.deleteLocalBook(localId);

      // 3. Attempt cloud deletion if online
      if (await ConnectivityService.isOnline()) {
        try {
          final url = Uri.parse("${bookUrl}delete/$serverId");
          final res = await client.delete(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
          if (res.statusCode == 200 || res.statusCode == 404) {
            cloudDeleted = true;
            // Remove from pending deletions on confirmed success or 404
            final pending = await dbHelper.getPendingDeletes();
            final row = pending.where((p) => p['table_name'] == 'books' && p['server_id'] == serverId).firstOrNull;
            if (row != null) {
              await dbHelper.removePendingSync(row['id']);
            }
          }
        } catch (e) {
          debugPrint("API Book delete failed: $e");
        }
      }
    } else {
      // Local-only book: no backend record exists, delete local book directly
      await dbHelper.deleteLocalBook(localId);
      cloudDeleted = true;
    }

    return cloudDeleted;
  }

  Future<int> getPendingDeletionsCount() async {
    final pending = await dbHelper.getPendingDeletes();
    return pending.where((p) => p['table_name'] == 'books').length;
  }

  Future<void> syncBooks(String basicAuth) async {
    // A. Flush pending deletes
    final pending = await dbHelper.getPendingDeletes();
    for (final p in pending) {
      if (p['table_name'] != 'books') continue;
      final serverId = p['server_id'];
      try {
        final url = Uri.parse("${bookUrl}delete/$serverId");
        final res = await client.delete(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 404) {
          await dbHelper.removePendingSync(p['id']);
        }
      } catch (_) {}
    }

    // B. Get elements from Server
    List<dynamic> serverBooks = [];
    try {
      final activeRes = await client.get(Uri.parse("${bookUrl}readAll"), headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
      if (activeRes.statusCode == 200) {
        final decoded = safeJsonDecode(activeRes.body);
        if (decoded is List) {
          serverBooks.addAll(decoded);
        }
      }
      final archRes = await client.get(Uri.parse("${bookUrl}readAllArchived"), headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
      if (archRes.statusCode == 200) {
        final decoded = safeJsonDecode(archRes.body);
        if (decoded is List) {
          serverBooks.addAll(decoded);
        }
      }
    } catch (e) {
      debugPrint("Failed to load server books during sync: $e");
      return;
    }

    // C. Get elements from SQLite
    final localBooksActive = await dbHelper.getLocalBooks(archived: 0);
    final localBooksArch = await dbHelper.getLocalBooks(archived: 1);
    final localBooks = [...localBooksActive, ...localBooksArch];

    // D. Process server books
    for (final sb in serverBooks) {
      if (sb is! Map<String, dynamic>) continue;
      final int? serverId = (sb['id'] as num?)?.toInt();
      if (serverId == null) continue;

      final name = sb['name']?.toString() ?? "";
      final subtitle = sb['subtitle']?.toString() ?? "";
      final isArchived = (sb['archived'] == true) ? 1 : 0;
      final serverUpdatedAt = sb['updatedAt'] ?? sb['updated_at'] ?? DateTime.now().toIso8601String();

      // Check if it exists locally by server_id
      final matchIndex = localBooks.indexWhere((lb) => lb['server_id'] == serverId);

      if (matchIndex != -1) {
        final lb = localBooks[matchIndex];
        if (lb['synced'] == 1) {
          await dbHelper.updateLocalBook(lb['id'] as int, {
            'name': name,
            'subtitle': subtitle,
            'archived': isArchived,
            'updated_at': serverUpdatedAt,
            'synced': 1,
          });
        } else if (lb['synced'] == 0) {
          try {
            final res = await client.put(
              Uri.parse("${bookUrl}edit/$serverId"),
              headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
              body: jsonEncode({'name': lb['name'], 'subtitle': lb['subtitle']}),
            ).timeout(const Duration(seconds: 15));
            if (res.statusCode == 200 || res.statusCode == 201) {
              await dbHelper.updateSyncStatus('books', lb['id'] as int, serverId);
            }
          } catch (_) {}
        }
      } else {
        final isDeletedLocally = pending.any((p) => p['table_name'] == 'books' && p['server_id'] == serverId);
        if (!isDeletedLocally) {
          // Check if an unlinked local book matches by name & subtitle (prevent duplicate on restore)
          final unlinkedMatchIndex = localBooks.indexWhere(
            (lb) => lb['server_id'] == null && lb['name'] == name && lb['subtitle'] == subtitle,
          );
          if (unlinkedMatchIndex != -1) {
            final lb = localBooks[unlinkedMatchIndex];
            await dbHelper.updateSyncStatus('books', lb['id'] as int, serverId, updatedAt: serverUpdatedAt);
            await dbHelper.updateLocalBook(lb['id'] as int, {'archived': isArchived});
          } else {
            await dbHelper.insertLocalBook({
              'server_id': serverId,
              'name': name,
              'subtitle': subtitle,
              'archived': isArchived,
              'created_at': sb['createdAt'] ?? sb['created_at'] ?? DateTime.now().toIso8601String(),
              'updated_at': serverUpdatedAt,
              'synced': 1,
            });
          }
        }
      }
    }

    // E. Upload local-only books (created offline)
    final unsynced = await dbHelper.getUnsyncedRecords('books');
    for (final book in unsynced) {
      if (book['server_id'] != null) continue;
      try {
        final res = await client.post(
          Uri.parse("${bookUrl}create"),
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode({'name': book['name'], 'subtitle': book['subtitle']}),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = safeJsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            final serverId = data['id'];
            if (serverId != null) {
              await dbHelper.updateSyncStatus('books', book['id'] as int, serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? book['updated_at']);
            }
          }
        } else {
          await dbHelper.updateLocalBook(book['id'] as int, {'synced': 2});
        }
      } catch (_) {
        await dbHelper.updateLocalBook(book['id'] as int, {'synced': 2});
      }
    }
  }
}

class CategoryRepository {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  final http.Client client;

  CategoryRepository({http.Client? client}) : client = client ?? http.Client();

  Future<List<Map<String, dynamic>>> getCategories() async {
    return await dbHelper.getLocalCategories();
  }

  Future<List<Map<String, dynamic>>> searchCategories(String query) async {
    return await dbHelper.searchLocalCategories(query);
  }

  Future<void> addCategory(String name, String icon, String basicAuth) async {
    final nowStr = DateTime.now().toIso8601String();
    
    final Map<String, dynamic> row = {
      'name': name,
      'icon': icon,
      'color': '#000000',
      'created_at': nowStr,
      'updated_at': nowStr,
      'synced': 0,
    };
    
    final localId = await dbHelper.insertLocalCategory(row);

    if (await ConnectivityService.isOnline()) {
      try {
        final url = Uri.parse("${categoryUrl}create");
        final res = await client.post(
          url,
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode({'name': name, 'icon': icon, 'color': '#000000'}),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = safeJsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            final serverId = data['id'];
            if (serverId != null) {
              await dbHelper.updateSyncStatus('categories', localId, serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? nowStr);
            }
          }
        }
      } catch (e) {
        debugPrint("API Category create failed: $e");
      }
    }
  }

  Future<void> updateCategory(String id, String name, String icon, String basicAuth) async {
    final nowStr = DateTime.now().toIso8601String();
    final localId = int.parse(id);

    final localCategory = await dbHelper.getLocalCategoryById(localId);
    final serverId = localCategory?['server_id'];

    final Map<String, dynamic> row = {
      'name': name,
      'icon': icon,
      'updated_at': nowStr,
      'synced': 0,
    };
    await dbHelper.updateLocalCategory(localId, row);

    if (await ConnectivityService.isOnline() && serverId != null) {
      try {
        final url = Uri.parse("${categoryUrl}edit/$serverId");
        final res = await client.put(
          url,
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode({'name': name, 'icon': icon, 'color': '#000000'}),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = safeJsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            await dbHelper.updateSyncStatus('categories', localId, serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? nowStr);
          }
        }
      } catch (e) {
        debugPrint("API Category edit failed: $e");
      }
    }
  }

  Future<void> deleteCategory(String id, String basicAuth) async {
    final localId = int.parse(id);
    final localCategory = await dbHelper.getLocalCategoryById(localId);
    final serverId = localCategory?['server_id'];

    await dbHelper.deleteLocalCategory(localId);

    if (serverId != null) {
      await dbHelper.logPendingDelete('categories', serverId);

      if (await ConnectivityService.isOnline()) {
        try {
          final url = Uri.parse("${categoryUrl}delete/$serverId");
          final res = await client.delete(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
          if (res.statusCode == 200) {
            final pending = await dbHelper.getPendingDeletes();
            final row = pending.where((p) => p['table_name'] == 'categories' && p['server_id'] == serverId).firstOrNull;
            if (row != null) {
              await dbHelper.removePendingSync(row['id']);
            }
          }
        } catch (e) {
          debugPrint("API Category delete failed: $e");
        }
      }
    }
  }

  Future<void> syncCategories(String basicAuth) async {
    final pending = await dbHelper.getPendingDeletes();
    for (final p in pending) {
      if (p['table_name'] != 'categories') continue;
      final serverId = p['server_id'];
      try {
        final url = Uri.parse("${categoryUrl}delete/$serverId");
        final res = await client.delete(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 404) {
          await dbHelper.removePendingSync(p['id']);
        }
      } catch (_) {}
    }

    List<dynamic> serverCategories = [];
    try {
      final res = await client.get(Uri.parse("${categoryUrl}readAll"), headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final decoded = safeJsonDecode(res.body);
        if (decoded is List) {
          serverCategories = decoded;
        }
      }
    } catch (e) {
      debugPrint("Failed to sync server categories: $e");
      return;
    }

    final localCategories = await dbHelper.getLocalCategories();

    for (final sc in serverCategories) {
      if (sc is! Map<String, dynamic>) continue;
      final int? serverId = (sc['id'] as num?)?.toInt();
      if (serverId == null) continue;

      final name = sc['name']?.toString() ?? "";
      final icon = sc['icon']?.toString() ?? "More";
      final color = sc['color']?.toString() ?? "#000000";
      final serverUpdatedAt = sc['updatedAt'] ?? sc['updated_at'] ?? DateTime.now().toIso8601String();

      final matchIndex = localCategories.indexWhere((lc) => lc['server_id'] == serverId);

      if (matchIndex != -1) {
        final lc = localCategories[matchIndex];
        if (lc['synced'] == 1) {
          await dbHelper.updateLocalCategory(lc['id'] as int, {
            'name': name,
            'icon': icon,
            'color': color,
            'updated_at': serverUpdatedAt,
            'synced': 1,
          });
        } else if (lc['synced'] == 0) {
          try {
            final res = await client.put(
              Uri.parse("${categoryUrl}edit/$serverId"),
              headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
              body: jsonEncode({'name': lc['name'], 'icon': lc['icon'], 'color': lc['color']}),
            ).timeout(const Duration(seconds: 15));
            if (res.statusCode == 200 || res.statusCode == 201) {
              await dbHelper.updateSyncStatus('categories', lc['id'] as int, serverId);
            }
          } catch (_) {}
        }
      } else {
        final isDeletedLocally = pending.any((p) => p['table_name'] == 'categories' && p['server_id'] == serverId);
        if (!isDeletedLocally) {
          // Check if an unlinked local category (e.g. from default seeding) has the same name
          final nameMatchIndex = localCategories.indexWhere(
            (lc) => lc['server_id'] == null && lc['name'].toString().trim().toLowerCase() == name.trim().toLowerCase(),
          );
          if (nameMatchIndex != -1) {
            final lc = localCategories[nameMatchIndex];
            await dbHelper.updateSyncStatus('categories', lc['id'] as int, serverId, updatedAt: serverUpdatedAt);
            await dbHelper.updateLocalCategory(lc['id'] as int, {'icon': icon, 'color': color, 'synced': 1});
          } else {
            await dbHelper.insertLocalCategory({
              'server_id': serverId,
              'name': name,
              'icon': icon,
              'color': color,
              'created_at': sc['createdAt'] ?? sc['created_at'] ?? DateTime.now().toIso8601String(),
              'updated_at': serverUpdatedAt,
              'synced': 1,
            });
          }
        }
      }
    }

    // Upload unsynced user-created categories (where server_id is NULL)
    final unsynced = await dbHelper.getUnsyncedRecords('categories');
    for (final category in unsynced) {
      if (category['server_id'] != null) continue;
      try {
        final res = await client.post(
          Uri.parse("${categoryUrl}create"),
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode({'name': category['name'], 'icon': category['icon'], 'color': category['color']}),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = safeJsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            final serverId = data['id'];
            if (serverId != null) {
              await dbHelper.updateSyncStatus('categories', category['id'] as int, serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? category['updated_at']);
            }
          }
        } else {
          await dbHelper.updateLocalCategory(category['id'] as int, {'synced': 2});
        }
      } catch (_) {
        await dbHelper.updateLocalCategory(category['id'] as int, {'synced': 2});
      }
    }
  }
}

dynamic safeJsonDecode(String body) {
  if (body.trim().isEmpty) return null;
  try {
    return jsonDecode(body);
  } catch (e) {
    debugPrint("Failed to parse JSON response body (non-JSON or HTML returned): $e");
    return null;
  }
}

bool isTransactionCredit(dynamic creditValue) {
  if (creditValue == null) return false;
  if (creditValue is bool) return creditValue;
  if (creditValue is num) return creditValue != 0;
  final str = creditValue.toString().trim().toLowerCase();
  return str == 'true' || str == '1' || str == 'credit' || str == 'income';
}

class ExpenseRepository {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  final http.Client client;

  ExpenseRepository({http.Client? client}) : client = client ?? http.Client();

  Future<List<Map<String, dynamic>>> getExpenses(String bookId) async {
    final localBookId = int.parse(bookId);
    return await dbHelper.getLocalExpensesByBook(localBookId);
  }

  Future<double> getBookBalance(String bookId) async {
    try {
      final localBookId = int.tryParse(bookId);
      if (localBookId == null) return 0.0;
      final expenses = await dbHelper.getLocalExpensesByBook(localBookId);
      double balance = 0.0;
      for (final exp in expenses) {
        final amt = (exp['amount'] as num?)?.toDouble() ?? 0.0;
        final isCredit = isTransactionCredit(exp['credit']);
        if (isCredit) {
          balance += amt;
        } else {
          balance -= amt;
        }
      }
      return balance;
    } catch (_) {
      return 0.0;
    }
  }

  Future<List<Map<String, dynamic>>> searchExpenses(String bookId, String query) async {
    final localBookId = int.parse(bookId);
    return await dbHelper.searchLocalExpenses(localBookId, query);
  }

  Future<void> addExpense(
    String description,
    String amount,
    String bookId,
    bool isCredit,
    String? categoryId,
    String? categoryName,
    String basicAuth,
  ) async {
    final nowStr = DateTime.now().toIso8601String();
    final localBookId = int.parse(bookId);
    final localCategoryId = categoryId != null ? int.parse(categoryId) : null;
    final parsedAmount = double.tryParse(amount) ?? 0.0;

    // 1. Save SQLite local
    final Map<String, dynamic> row = {
      'description': description,
      'amount': parsedAmount,
      'credit': isCredit ? 1 : 0,
      'date': nowStr,
      'book_id': localBookId,
      'category_id': localCategoryId,
      'created_at': nowStr,
      'updated_at': nowStr,
      'synced': 0,
    };
    final localId = await dbHelper.insertLocalExpense(row);

    // 2. Call API if online
    if (await ConnectivityService.isOnline()) {
      try {
        // We need server IDs for book and category to upload
        final serverBookId = await _findServerBookId(localBookId);
        final serverCategoryId = localCategoryId != null ? await _findServerCategoryId(localCategoryId) : null;

        if (serverBookId != null) {
          final url = Uri.parse("${expenseUrl}create");
          final Map<String, dynamic> body = {
            'description': description,
            'amount': parsedAmount,
            'credit': isCredit,
            'date': nowStr,
            'book': {'id': serverBookId},
          };
          if (serverCategoryId != null) {
            body['category'] = {'id': serverCategoryId};
          }
          final res = await client.post(
            url,
            headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
            body: jsonEncode(body),
          ).timeout(const Duration(seconds: 15));
          if (res.statusCode == 200 || res.statusCode == 201) {
            final data = safeJsonDecode(res.body);
            if (data is Map<String, dynamic>) {
              final serverId = data['id'];
              if (serverId != null) {
                await dbHelper.updateSyncStatus('expenses', localId, serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? nowStr);
              }
            }
          } else {
            await dbHelper.updateLocalExpense(localId, {'synced': 2});
          }
        }
      } catch (e) {
        debugPrint("API Expense create failed: $e");
        await dbHelper.updateLocalExpense(localId, {'synced': 2});
      }
    }
  }

  Future<void> updateExpense(
    String id,
    String description,
    String amount,
    bool isCredit,
    String? categoryId,
    String basicAuth,
  ) async {
    final nowStr = DateTime.now().toIso8601String();
    final localId = int.parse(id);
    final localCategoryId = categoryId != null ? int.parse(categoryId) : null;
    final parsedAmount = double.tryParse(amount) ?? 0.0;

    final localExpense = await dbHelper.getLocalExpenseById(localId);
    final serverId = localExpense?['server_id'];

    // 1. Update SQLite local
    final Map<String, dynamic> row = {
      'description': description,
      'amount': parsedAmount,
      'credit': isCredit ? 1 : 0,
      'category_id': localCategoryId,
      'updated_at': nowStr,
      'synced': 0,
    };
    await dbHelper.updateLocalExpense(localId, row);

    // 2. Call API if online
    if (await ConnectivityService.isOnline() && serverId != null) {
      try {
        final serverCategoryId = localCategoryId != null ? await _findServerCategoryId(localCategoryId) : null;

        final url = Uri.parse("${expenseUrl}edit/$serverId");
        final Map<String, dynamic> body = {
          'description': description,
          'amount': parsedAmount,
          'credit': isCredit,
          'date': localExpense?['date'] ?? nowStr,
        };
        if (serverCategoryId != null) {
          body['category'] = {'id': serverCategoryId};
        }

        final res = await client.put(
          url,
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = safeJsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            await dbHelper.updateSyncStatus('expenses', localId, serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? nowStr);
          }
        } else {
          await dbHelper.updateLocalExpense(localId, {'synced': 2});
        }
      } catch (e) {
        debugPrint("API Expense edit failed: $e");
        await dbHelper.updateLocalExpense(localId, {'synced': 2});
      }
    }
  }

  Future<void> deleteExpense(String id, String basicAuth) async {
    final localId = int.parse(id);
    final localExpense = await dbHelper.getLocalExpenseById(localId);
    final serverId = localExpense?['server_id'];

    // 1. SQLite local
    await dbHelper.deleteLocalExpense(localId);

    // 2. Queue pending delete
    if (serverId != null) {
      await dbHelper.logPendingDelete('expenses', serverId);

      // 3. Call API
      if (await ConnectivityService.isOnline()) {
        try {
          final url = Uri.parse("${expenseUrl}delete/$serverId");
          final res = await client.delete(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
          if (res.statusCode == 200) {
            final pending = await dbHelper.getPendingDeletes();
            final row = pending.where((p) => p['table_name'] == 'expenses' && p['server_id'] == serverId).firstOrNull;
            if (row != null) {
              await dbHelper.removePendingSync(row['id']);
            }
          }
        } catch (e) {
          debugPrint("API Expense delete failed: $e");
        }
      }
    }
  }

  Future<void> syncExpenses(String basicAuth) async {
    // A. Flush pending deletes
    final pending = await dbHelper.getPendingDeletes();
    for (final p in pending) {
      if (p['table_name'] != 'expenses') continue;
      final serverId = p['server_id'];
      try {
        final url = Uri.parse("${expenseUrl}delete/$serverId");
        final res = await client.delete(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 404) {
          await dbHelper.removePendingSync(p['id']);
        }
      } catch (_) {}
    }

    // B. Fetch server expenses using /expenses/readAll first
    List<dynamic> serverExpenses = [];
    bool fetchedBulk = false;
    try {
      final res = await client.get(Uri.parse("${expenseUrl}readAll"), headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final decoded = safeJsonDecode(res.body);
        if (decoded is List) {
          serverExpenses = decoded;
          fetchedBulk = true;
        }
      }
    } catch (e) {
      debugPrint("Failed bulk readAll expenses, falling back to per-book: $e");
    }

    // Fallback to per-book read if bulk endpoint failed or returned non-200
    if (!fetchedBulk) {
      final activeBooks = await dbHelper.getLocalBooks(archived: 0);
      final archivedBooks = await dbHelper.getLocalBooks(archived: 1);
      final allBooks = [...activeBooks, ...archivedBooks];

      for (final book in allBooks) {
        final serverBookId = book['server_id'];
        if (serverBookId == null) continue;

        try {
          final url = Uri.parse("${expenseUrl}book/$serverBookId");
          final res = await client.get(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
          if (res.statusCode == 200) {
            final decoded = safeJsonDecode(res.body);
            if (decoded is List) {
              serverExpenses.addAll(decoded);
            }
          }
        } catch (_) {}
      }
    }

    // Process server expenses
    for (final se in serverExpenses) {
      if (se is! Map<String, dynamic>) continue;
      final int? serverId = (se['id'] as num?)?.toInt();
      if (serverId == null) continue;

      final description = se['description']?.toString() ?? "";
      final amount = (se['amount'] as num?)?.toDouble() ?? 0.0;
      final isCredit = isTransactionCredit(se['credit'] ?? se['isCredit']);
      final date = se['date']?.toString() ?? DateTime.now().toIso8601String();

      // Resolve book mapping
      final serverBookId = se['book']?['id'] is num ? (se['book']['id'] as num).toInt() : null;
      int? localBookId;
      if (serverBookId != null) {
        localBookId = await _findLocalBookIdByServerId(serverBookId);
      }

      // If book cannot be mapped locally, skip to preserve foreign key integrity
      if (localBookId == null) continue;

      // Resolve category mapping
      final serverCatId = se['category']?['id'] is num ? (se['category']['id'] as num).toInt() : null;
      int? localCatId;
      if (serverCatId != null) {
        localCatId = await _findLocalCategoryIdByServerId(serverCatId);
      }

      // Check if expense exists in SQLite by server_id
      final existingExpense = await dbHelper.getLocalExpenseByServerId(serverId);

      if (existingExpense != null) {
        final int localExpenseId = existingExpense['id'];
        if (existingExpense['synced'] == 1) {
          await dbHelper.updateLocalExpense(localExpenseId, {
            'description': description,
            'amount': amount,
            'credit': isCredit ? 1 : 0,
            'date': date,
            'book_id': localBookId,
            'category_id': localCatId,
            'updated_at': date,
            'synced': 1,
          });
        } else if (existingExpense['synced'] == 0 || existingExpense['synced'] == 2) {
          try {
            final url = Uri.parse("${expenseUrl}edit/$serverId");
            final Map<String, dynamic> body = {
              'description': existingExpense['description'],
              'amount': existingExpense['amount'],
              'credit': existingExpense['credit'] == 1,
              'date': existingExpense['date'],
            };
            if (serverCatId != null) {
              body['category'] = {'id': serverCatId};
            }
            final res = await client.put(
              url,
              headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
              body: jsonEncode(body),
            ).timeout(const Duration(seconds: 15));
            if (res.statusCode == 200 || res.statusCode == 201) {
              await dbHelper.updateSyncStatus('expenses', localExpenseId, serverId);
            }
          } catch (_) {}
        }
      } else {
        final isDeletedLocally = pending.any((p) => p['table_name'] == 'expenses' && p['server_id'] == serverId);
        if (!isDeletedLocally) {
          await dbHelper.insertLocalExpense({
            'server_id': serverId,
            'description': description,
            'amount': amount,
            'credit': isCredit ? 1 : 0,
            'date': date,
            'book_id': localBookId,
            'category_id': localCatId,
            'created_at': se['createdAt'] ?? se['created_at'] ?? date,
            'updated_at': date,
            'synced': 1,
          });
        }
      }
    }

    // C. Upload local-only expenses (where server_id is NULL)
    final unsynced = await dbHelper.getUnsyncedRecords('expenses');
    for (final exp in unsynced) {
      if (exp['server_id'] != null) continue;
      try {
        final serverBookId = await _findServerBookId(exp['book_id']);
        if (serverBookId == null) continue; // Wait until book syncs

        final serverCatId = exp['category_id'] != null ? await _findServerCategoryId(exp['category_id']) : null;

        final Map<String, dynamic> body = {
          'description': exp['description'],
          'amount': exp['amount'],
          'credit': exp['credit'] == 1,
          'date': exp['date'],
          'book': {'id': serverBookId},
        };
        if (serverCatId != null) {
          body['category'] = {'id': serverCatId};
        }

        final res = await client.post(
          Uri.parse("${expenseUrl}create"),
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = safeJsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            final serverId = data['id'];
            if (serverId != null) {
              await dbHelper.updateSyncStatus('expenses', exp['id'], serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? exp['updated_at']);
            }
          }
        } else {
          await dbHelper.updateLocalExpense(exp['id'], {'synced': 2});
        }
      } catch (_) {
        await dbHelper.updateLocalExpense(exp['id'], {'synced': 2});
      }
    }
  }

  // Helper ID lookup methods
  Future<int?> _findServerBookId(int localBookId) async {
    final book = await dbHelper.getLocalBookById(localBookId);
    return book?['server_id'];
  }

  Future<int?> _findLocalBookIdByServerId(int serverBookId) async {
    final book = await dbHelper.getLocalBookByServerId(serverBookId);
    return book?['id'];
  }

  Future<int?> _findServerCategoryId(int localCategoryId) async {
    final cat = await dbHelper.getLocalCategoryById(localCategoryId);
    return cat?['server_id'];
  }

  Future<int?> _findLocalCategoryIdByServerId(int serverCatId) async {
    final cat = await dbHelper.getLocalCategoryByServerId(serverCatId);
    return cat?['id'];
  }
}

class InvestmentRepository {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  final http.Client client;

  InvestmentRepository({http.Client? client}) : client = client ?? http.Client();

  Future<List<Map<String, dynamic>>> getInvestments() async {
    return await dbHelper.getLocalInvestments();
  }

  Future<List<Map<String, dynamic>>> searchInvestments(String query) async {
    return await dbHelper.searchLocalInvestments(query);
  }

  Future<void> addInvestment(String description, double amount, String basicAuth) async {
    final nowStr = DateTime.now().toIso8601String();

    // 1. SQLite local
    final Map<String, dynamic> row = {
      'description': description,
      'amount': amount,
      'created_at': nowStr,
      'updated_at': nowStr,
      'synced': 0,
    };
    final localId = await dbHelper.insertLocalInvestment(row);

    // 2. Call API if online
    if (await ConnectivityService.isOnline()) {
      try {
        final url = Uri.parse("${investmentUrl}create");
        final res = await client.post(
          url,
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode({'description': description, 'amount': amount}),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = safeJsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            final serverId = data['id'];
            if (serverId != null) {
              await dbHelper.updateSyncStatus('investments', localId, serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? nowStr);
            }
          }
        }
      } catch (e) {
        debugPrint("API Investment create failed: $e");
      }
    }
  }

  Future<void> updateInvestment(String id, String description, double amount, String basicAuth) async {
    final nowStr = DateTime.now().toIso8601String();
    final localId = int.parse(id);
    final localInvest = await dbHelper.getLocalInvestmentById(localId);
    final serverId = localInvest?['server_id'];

    // 1. SQLite local
    final Map<String, dynamic> row = {
      'description': description,
      'amount': amount,
      'updated_at': nowStr,
      'synced': 0,
    };
    await dbHelper.updateLocalInvestment(localId, row);

    // 2. Call API if online
    if (await ConnectivityService.isOnline() && serverId != null) {
      try {
        final url = Uri.parse("${investmentUrl}edit/$serverId");
        final res = await client.put(
          url,
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode({'description': description, 'amount': amount}),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = safeJsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            await dbHelper.updateSyncStatus('investments', localId, serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? nowStr);
          }
        }
      } catch (e) {
        debugPrint("API Investment edit failed: $e");
      }
    }
  }

  Future<void> deleteInvestment(String id, String basicAuth) async {
    final localId = int.parse(id);
    final localInvest = await dbHelper.getLocalInvestmentById(localId);
    final serverId = localInvest?['server_id'];

    // 1. SQLite local
    await dbHelper.deleteLocalInvestment(localId);

    // 2. Queue pending
    if (serverId != null) {
      await dbHelper.logPendingDelete('investments', serverId);

      // 3. Call API if online
      if (await ConnectivityService.isOnline()) {
        try {
          final url = Uri.parse("${investmentUrl}delete/$serverId");
          final res = await client.delete(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
          if (res.statusCode == 200) {
            final pending = await dbHelper.getPendingDeletes();
            final row = pending.where((p) => p['table_name'] == 'investments' && p['server_id'] == serverId).firstOrNull;
            if (row != null) {
              await dbHelper.removePendingSync(row['id']);
            }
          }
        } catch (e) {
          debugPrint("API Investment delete failed: $e");
        }
      }
    }
  }

  Future<void> syncInvestments(String basicAuth) async {
    // A. Flush pending deletes
    final pending = await dbHelper.getPendingDeletes();
    for (final p in pending) {
      if (p['table_name'] != 'investments') continue;
      final serverId = p['server_id'];
      try {
        final url = Uri.parse("${investmentUrl}delete/$serverId");
        final res = await client.delete(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 404) {
          await dbHelper.removePendingSync(p['id']);
        }
      } catch (_) {}
    }

    // B. Get from Server
    List<dynamic> serverInvestments = [];
    try {
      final res = await client.get(Uri.parse("${investmentUrl}readAll"), headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final decoded = safeJsonDecode(res.body);
        if (decoded is List) {
          serverInvestments = decoded;
        }
      }
    } catch (e) {
      debugPrint("Failed to sync server investments: $e");
      return;
    }

    // C. Get from SQLite
    final localInvestments = await dbHelper.getLocalInvestments();

    // D. Process server investments
    for (final si in serverInvestments) {
      if (si is! Map<String, dynamic>) continue;
      final int? serverId = (si['id'] as num?)?.toInt();
      if (serverId == null) continue;

      final description = si['description']?.toString() ?? "";
      final amount = (si['amount'] as num?)?.toDouble() ?? 0.0;
      final serverUpdatedAt = si['updatedAt'] ?? si['updated_at'] ?? DateTime.now().toIso8601String();

      final matchIndex = localInvestments.indexWhere((li) => li['server_id'] == serverId);

      if (matchIndex != -1) {
        final li = localInvestments[matchIndex];
        if (li['synced'] == 1) {
          await dbHelper.updateLocalInvestment(li['id'] as int, {
            'description': description,
            'amount': amount,
            'updated_at': serverUpdatedAt,
            'synced': 1,
          });
        } else if (li['synced'] == 0) {
          try {
            final res = await client.put(
              Uri.parse("${investmentUrl}edit/$serverId"),
              headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
              body: jsonEncode({'description': li['description'], 'amount': li['amount']}),
            ).timeout(const Duration(seconds: 15));
            if (res.statusCode == 200 || res.statusCode == 201) {
              await dbHelper.updateSyncStatus('investments', li['id'] as int, serverId);
            }
          } catch (_) {}
        }
      } else {
        final isDeletedLocally = pending.any((p) => p['table_name'] == 'investments' && p['server_id'] == serverId);
        if (!isDeletedLocally) {
          // Check if an unlinked local investment matches by description & amount
          final unlinkedMatchIndex = localInvestments.indexWhere(
            (li) => li['server_id'] == null && li['description'] == description && (li['amount'] as num?)?.toDouble() == amount,
          );
          if (unlinkedMatchIndex != -1) {
            final li = localInvestments[unlinkedMatchIndex];
            await dbHelper.updateSyncStatus('investments', li['id'] as int, serverId, updatedAt: serverUpdatedAt);
          } else {
            await dbHelper.insertLocalInvestment({
              'server_id': serverId,
              'description': description,
              'amount': amount,
              'created_at': si['createdAt'] ?? si['created_at'] ?? DateTime.now().toIso8601String(),
              'updated_at': serverUpdatedAt,
              'synced': 1,
            });
          }
        }
      }
    }

    // E. Upload local-only
    final unsynced = await dbHelper.getUnsyncedRecords('investments');
    for (final inv in unsynced) {
      if (inv['server_id'] != null) continue;
      try {
        final res = await client.post(
          Uri.parse("${investmentUrl}create"),
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode({'description': inv['description'], 'amount': inv['amount']}),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = safeJsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            final serverId = data['id'];
            if (serverId != null) {
              await dbHelper.updateSyncStatus('investments', inv['id'] as int, serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? inv['updated_at']);
            }
          }
        } else {
          await dbHelper.updateLocalInvestment(inv['id'] as int, {'synced': 2});
        }
      } catch (_) {
        await dbHelper.updateLocalInvestment(inv['id'] as int, {'synced': 2});
      }
    }
  }
}

class SyncEngine {
  static final BookRepository _bookRepo = BookRepository();
  static final CategoryRepository _categoryRepo = CategoryRepository();
  static final ExpenseRepository _expenseRepo = ExpenseRepository();
  static final InvestmentRepository _investmentRepo = InvestmentRepository();

  static bool _isSyncing = false;
  static bool get isSyncing => _isSyncing;
  static final ValueNotifier<bool> syncingNotifier = ValueNotifier<bool>(false);
  static Completer<void>? _syncCompleter;

  static bool _initialSyncStarted = false;
  static bool get initialSyncStarted => _initialSyncStarted;

  static void markInitialSyncStarted() {
    _initialSyncStarted = true;
  }

  static void resetInitialSync() {
    _initialSyncStarted = false;
  }

  @visibleForTesting
  static Future<void> Function(String basicAuth, {http.Client? client})? syncAllHandler;

  @visibleForTesting
  static void resetForTesting() {
    _isSyncing = false;
    syncingNotifier.value = false;
    _syncCompleter = null;
    syncAllHandler = null;
    _initialSyncStarted = false;
  }

  static Future<void> syncAll(String basicAuth, {http.Client? client}) {
    // If a sync is already in flight, synchronously join the existing completer future
    if (_syncCompleter != null) {
      return _syncCompleter!.future;
    }

    final completer = Completer<void>();
    _syncCompleter = completer;
    _isSyncing = true;
    syncingNotifier.value = true;

    if (syncAllHandler != null) {
      Future.sync(() => syncAllHandler!(basicAuth, client: client)).catchError((e) {
        debugPrint("SyncEngine syncAllHandler error: $e");
      }).whenComplete(() {
        _isSyncing = false;
        syncingNotifier.value = false;
        _syncCompleter = null;
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
      return completer.future;
    }

    _runSync(completer, basicAuth, client: client);
    return completer.future;
  }

  static Future<void> _runSync(Completer<void> completer, String basicAuth, {http.Client? client}) async {
    try {
      if (!await ConnectivityService.isOnline()) {
        debugPrint("SyncEngine: Device is offline, skipping sync.");
        return;
      }

      debugPrint("Starting synchronizer session...");
      final categoryRepo = client != null ? CategoryRepository(client: client) : _categoryRepo;
      final bookRepo = client != null ? BookRepository(client: client) : _bookRepo;
      final expenseRepo = client != null ? ExpenseRepository(client: client) : _expenseRepo;
      final investmentRepo = client != null ? InvestmentRepository(client: client) : _investmentRepo;

      // Execution order keeps foreign key integrity: Categories -> Books -> Expenses -> Investments
      try {
        await categoryRepo.syncCategories(basicAuth);
      } catch (e) {
        debugPrint("Category sync error (isolated): $e");
      }

      try {
        await bookRepo.syncBooks(basicAuth);
      } catch (e) {
        debugPrint("Book sync error (isolated): $e");
      }

      try {
        await expenseRepo.syncExpenses(basicAuth);
      } catch (e) {
        debugPrint("Expense sync error (isolated): $e");
      }

      try {
        await investmentRepo.syncInvestments(basicAuth);
      } catch (e) {
        debugPrint("Investment sync error (isolated): $e");
      }

      debugPrint("Synchronizer session finished successfully.");
    } catch (e) {
      debugPrint("Synchronizer session aborted with error: $e");
    } finally {
      _isSyncing = false;
      syncingNotifier.value = false;
      _syncCompleter = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }
}

class UserRepository {
  final http.Client client;

  UserRepository({http.Client? client}) : client = client ?? http.Client();

  Future<bool> updatePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
    required String basicAuth,
  }) async {
    if (!await ConnectivityService.isOnline()) {
      debugPrint("API updatePassword aborted: device is offline");
      return false;
    }

    try {
      final url = Uri.parse("${userUrl}update-password");
      final response = await http
          .put(
            url,
            headers: {
              'Authorization': basicAuth,
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'email': email,
              'currentPassword': currentPassword,
              'newPassword': newPassword,
              'password': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }

      final fallbackUrl = Uri.parse("${userUrl}change-password");
      final res2 = await http
          .post(
            fallbackUrl,
            headers: {
              'Authorization': basicAuth,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'email': email,
              'currentPassword': currentPassword,
              'newPassword': newPassword,
              'password': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return res2.statusCode == 200 || res2.statusCode == 201;
    } catch (e) {
      debugPrint("API updatePassword exception: $e");
      return false;
    }
  }

  /// Permanently deletes the user account and associated cloud data.
  /// Satisfies Google Play Account Deletion Policy requirement.
  Future<bool> deleteAccount({
    required String email,
    required String basicAuth,
  }) async {
    if (!await ConnectivityService.isOnline()) {
      debugPrint("API deleteAccount aborted: device is offline");
      return false;
    }

    try {
      final url = Uri.parse("${userUrl}delete-account");
      final response = await client
          .delete(
            url,
            headers: {
              'Authorization': basicAuth,
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      }

      final fallbackUrl = Uri.parse("${userUrl}delete");
      final res2 = await client
          .delete(
            fallbackUrl,
            headers: {
              'Authorization': basicAuth,
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 10));

      return res2.statusCode == 200 || res2.statusCode == 204;
    } catch (e) {
      debugPrint("API deleteAccount exception: $e");
      return false;
    }
  }

  /// Requests a password reset email. Always returns a generic success message
  /// when the request is accepted to avoid account enumeration.
  Future<({bool success, String message})> forgotPassword({
    required String email,
  }) async {
    const genericMessage =
        "If an account exists with this email address, you will receive password reset instructions shortly.";
    if (!await ConnectivityService.isOnline()) {
      return (success: false, message: "No internet connection. Please try again.");
    }
    try {
      final response = await client
          .post(
            Uri.parse("${userUrl}forgot-password"),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = safeJsonDecode(response.body);
        final msg = data is Map<String, dynamic> ? (data['message']?.toString() ?? genericMessage) : genericMessage;
        return (success: true, message: msg);
      }
      return (success: false, message: "Unable to request password reset. Please try again.");
    } catch (e) {
      debugPrint("API forgotPassword exception: $e");
      return (success: false, message: "Network error. Please try again.");
    }
  }

  /// Resets password using a one-time reset token.
  Future<({bool success, String message})> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    if (!await ConnectivityService.isOnline()) {
      return (success: false, message: "No internet connection. Please try again.");
    }
    try {
      final response = await client
          .post(
            Uri.parse("${userUrl}reset-password"),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'token': token, 'newPassword': newPassword}),
          )
          .timeout(const Duration(seconds: 15));

      final data = safeJsonDecode(response.body);
      final msg = data is Map<String, dynamic> ? data['message']?.toString() : null;

      if (response.statusCode == 200) {
        return (success: true, message: msg ?? "Password has been reset successfully. You can now log in.");
      }

      final lower = (msg ?? '').toLowerCase();
      if (response.statusCode == 400 || response.statusCode == 404) {
        if (lower.contains('expired')) {
          return (success: false, message: "This reset link has expired. Please request a new one.");
        }
        if (lower.contains('used')) {
          return (success: false, message: "This reset link has already been used. Please request a new one.");
        }
        if (lower.contains('invalid')) {
          return (success: false, message: "This reset link is invalid. Please request a new one.");
        }
        if (lower.contains('password')) {
          return (success: false, message: msg ?? "Please choose a stronger password.");
        }
        return (success: false, message: msg ?? "This reset link is invalid or has expired. Please request a new one.");
      }

      return (success: false, message: "Unable to reset password. Please try again.");
    } catch (e) {
      debugPrint("API resetPassword exception: $e");
      return (success: false, message: "Network error. Please try again.");
    }
  }
}
