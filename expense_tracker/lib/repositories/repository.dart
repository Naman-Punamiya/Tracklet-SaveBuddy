import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:expense_tracker/constant.dart';
import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/services/connectivity_service.dart';

class BookRepository {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;

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
        final res = await http.post(
          url,
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode({'name': name, 'subtitle': subtitle}),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          final serverId = data['id'];
          // 3. Mark synced
          await dbHelper.updateSyncStatus('books', localId, serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? nowStr);
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
        final res = await http.put(
          url,
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode({'name': name, 'subtitle': subtitle}),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          // 3. Mark synced
          await dbHelper.updateSyncStatus('books', localId, serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? nowStr);
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
        final res = await http.patch(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
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
        final res = await http.patch(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          await dbHelper.updateSyncStatus('books', localId, serverId, updatedAt: nowStr);
        }
      } catch (e) {
        debugPrint("API Book restore failed: $e");
      }
    }
  }

  Future<void> deleteBook(String id, String basicAuth) async {
    final localId = int.parse(id);
    final localBook = await dbHelper.getLocalBookById(localId);
    final serverId = localBook?['server_id'];

    // 1. SQLite local delete
    await dbHelper.deleteLocalBook(localId);

    // 2. If it had server ID, queue pending delete
    if (serverId != null) {
      await dbHelper.logPendingDelete('books', serverId);

      // 3. Call API if online
      if (await ConnectivityService.isOnline()) {
        try {
          final url = Uri.parse("${bookUrl}delete/$serverId");
          final res = await http.delete(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
          if (res.statusCode == 200) {
            // Remove from pending deletions
            final pending = await dbHelper.getPendingDeletes();
            final row = pending.firstWhere((p) => p['table_name'] == 'books' && p['server_id'] == serverId);
            await dbHelper.removePendingSync(row['id']);
          }
        } catch (e) {
          debugPrint("API Book delete failed: $e");
        }
      }
    }
  }

  Future<void> syncBooks(String basicAuth) async {
    // A. Flush pending deletes
    final pending = await dbHelper.getPendingDeletes();
    for (final p in pending) {
      if (p['table_name'] != 'books') continue;
      final serverId = p['server_id'];
      try {
        final url = Uri.parse("${bookUrl}delete/$serverId");
        final res = await http.delete(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 404) {
          await dbHelper.removePendingSync(p['id']);
        }
      } catch (_) {}
    }

    // B. Get elements from Server
    List<dynamic> serverBooks = [];
    try {
      final activeRes = await http.get(Uri.parse("${bookUrl}readAll"), headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
      if (activeRes.statusCode == 200) {
        serverBooks.addAll(jsonDecode(activeRes.body) as List);
      }
      final archRes = await http.get(Uri.parse("${bookUrl}readAllArchived"), headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
      if (archRes.statusCode == 200) {
        serverBooks.addAll(jsonDecode(archRes.body) as List);
      }
    } catch (e) {
      debugPrint("Failed to load server books during sync: $e");
      return;
    }

    // C. Get elements from SQLite
    final localBooksActive = await dbHelper.getLocalBooks(archived: 0);
    final localBooksArch = await dbHelper.getLocalBooks(archived: 1);
    final localBooks = [...localBooksActive, ...localBooksArch];

    // D. Process server books (Sync & LWW)
    for (final sb in serverBooks) {
      final int serverId = sb['id'];
      final serverUpdatedAt = sb['updatedAt'] ?? sb['updated_at'] ?? DateTime.fromMillisecondsSinceEpoch(0).toIso8601String();
      final name = sb['name'] ?? "";
      final subtitle = sb['subtitle'] ?? "";
      final isArchived = sb['archived'] == true ? 1 : 0;

      // Check if it exists locally
      final matchIndex = localBooks.indexWhere((lb) => lb['server_id'] == serverId);

      if (matchIndex != -1) {
        // Exists locally, apply Last Write Wins
        final lb = localBooks[matchIndex];
        final localUpdatedAt = lb['updated_at'];
        final localDate = DateTime.tryParse(localUpdatedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final serverDate = DateTime.tryParse(serverUpdatedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);

        if (serverDate.isAfter(localDate)) {
          // Download Server
          await dbHelper.updateLocalBook(lb['id'], {
            'name': name,
            'subtitle': subtitle,
            'archived': isArchived,
            'updated_at': serverUpdatedAt,
            'synced': 1,
          });
        } else if (localDate.isAfter(serverDate) && lb['synced'] == 0) {
          // Upload Local
          try {
            final res = await http.put(
              Uri.parse("${bookUrl}edit/$serverId"),
              headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
              body: jsonEncode({'name': lb['name'], 'subtitle': lb['subtitle']}),
            ).timeout(const Duration(seconds: 15));
            if (res.statusCode == 200 || res.statusCode == 201) {
              await dbHelper.updateSyncStatus('books', lb['id'], serverId, updatedAt: localUpdatedAt);
            }
          } catch (_) {}
        } else {
          // Match but aligned
          if (lb['synced'] == 0) {
            await dbHelper.updateSyncStatus('books', lb['id'], serverId);
          }
        }
      } else {
        // Does not exist locally. Check if it was deleted local-only
        final isDeletedLocally = pending.any((p) => p['table_name'] == 'books' && p['server_id'] == serverId);
        if (!isDeletedLocally) {
          // Insert sqlite
          final now = DateTime.now().toIso8601String();
          await dbHelper.insertLocalBook({
            'server_id': serverId,
            'name': name,
            'subtitle': subtitle,
            'archived': isArchived,
            'created_at': sb['createdAt'] ?? sb['created_at'] ?? now,
            'updated_at': serverUpdatedAt,
            'synced': 1,
          });
        }
      }
    }

    // E. Upload local-only books (created offline)
    final unsynced = await dbHelper.getUnsyncedRecords('books');
    for (final book in unsynced) {
      if (book['server_id'] != null) continue; // Handled in LWW loop, or has server_id
      try {
        final res = await http.post(
          Uri.parse("${bookUrl}create"),
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode({'name': book['name'], 'subtitle': book['subtitle']}),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          final serverId = data['id'];
          await dbHelper.updateSyncStatus('books', book['id'], serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? book['updated_at']);
        }
      } catch (_) {}
    }
  }
}

class CategoryRepository {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;

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
        final res = await http.post(
          url,
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode({'name': name, 'icon': icon, 'color': '#000000'}),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          final serverId = data['id'];
          await dbHelper.updateSyncStatus('categories', localId, serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? nowStr);
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
        final res = await http.put(
          url,
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode({'name': name, 'icon': icon, 'color': '#000000'}),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          await dbHelper.updateSyncStatus('categories', localId, serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? nowStr);
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
          final res = await http.delete(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
          if (res.statusCode == 200) {
            final pending = await dbHelper.getPendingDeletes();
            final row = pending.firstWhere((p) => p['table_name'] == 'categories' && p['server_id'] == serverId);
            await dbHelper.removePendingSync(row['id']);
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
        final res = await http.delete(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 404) {
          await dbHelper.removePendingSync(p['id']);
        }
      } catch (_) {}
    }

    List<dynamic> serverCategories = [];
    try {
      final res = await http.get(Uri.parse("${categoryUrl}readAll"), headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        serverCategories = jsonDecode(res.body) as List;
      }
    } catch (e) {
      debugPrint("Failed to sync server categories: $e");
      return;
    }

    final localCategories = await dbHelper.getLocalCategories();

    for (final sc in serverCategories) {
      final int serverId = sc['id'];
      final serverUpdatedAt = sc['updatedAt'] ?? sc['updated_at'] ?? DateTime.fromMillisecondsSinceEpoch(0).toIso8601String();
      final name = sc['name'] ?? "";
      final icon = sc['icon'] ?? "";
      final color = sc['color'] ?? "#000000";

      final matchIndex = localCategories.indexWhere((lc) => lc['server_id'] == serverId);

      if (matchIndex != -1) {
        final lc = localCategories[matchIndex];
        final localUpdatedAt = lc['updated_at'];
        final localDate = DateTime.tryParse(localUpdatedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final serverDate = DateTime.tryParse(serverUpdatedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);

        if (serverDate.isAfter(localDate)) {
          await dbHelper.updateLocalCategory(lc['id'], {
            'name': name,
            'icon': icon,
            'color': color,
            'updated_at': serverUpdatedAt,
            'synced': 1,
          });
        } else if (localDate.isAfter(serverDate) && lc['synced'] == 0) {
          try {
            final res = await http.put(
              Uri.parse("${categoryUrl}edit/$serverId"),
              headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
              body: jsonEncode({'name': lc['name'], 'icon': lc['icon'], 'color': lc['color']}),
            ).timeout(const Duration(seconds: 15));
            if (res.statusCode == 200 || res.statusCode == 201) {
              await dbHelper.updateSyncStatus('categories', lc['id'], serverId, updatedAt: localUpdatedAt);
            }
          } catch (_) {}
        } else {
          if (lc['synced'] == 0) {
            await dbHelper.updateSyncStatus('categories', lc['id'], serverId);
          }
        }
      } else {
        final isDeletedLocally = pending.any((p) => p['table_name'] == 'categories' && p['server_id'] == serverId);
        if (!isDeletedLocally) {
          final now = DateTime.now().toIso8601String();
          await dbHelper.insertLocalCategory({
            'server_id': serverId,
            'name': name,
            'icon': icon,
            'color': color,
            'created_at': sc['createdAt'] ?? sc['created_at'] ?? now,
            'updated_at': serverUpdatedAt,
            'synced': 1,
          });
        }
      }
    }

    final unsynced = await dbHelper.getUnsyncedRecords('categories');
    for (final category in unsynced) {
      if (category['server_id'] != null) continue;
      try {
        final res = await http.post(
          Uri.parse("${categoryUrl}create"),
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode({'name': category['name'], 'icon': category['icon'], 'color': category['color']}),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          final serverId = data['id'];
          await dbHelper.updateSyncStatus('categories', category['id'], serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? category['updated_at']);
        }
      } catch (_) {}
    }
  }
}

class ExpenseRepository {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;

  Future<List<Map<String, dynamic>>> getExpenses(String bookId) async {
    final localBookId = int.parse(bookId);
    return await dbHelper.getLocalExpensesByBook(localBookId);
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
          final res = await http.post(
            url,
            headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
            body: jsonEncode(body),
          ).timeout(const Duration(seconds: 15));
          if (res.statusCode == 200 || res.statusCode == 201) {
            final data = jsonDecode(res.body);
            final serverId = data['id'];
            await dbHelper.updateSyncStatus('expenses', localId, serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? nowStr);
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

        final res = await http.put(
          url,
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          await dbHelper.updateSyncStatus('expenses', localId, serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? nowStr);
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
          final res = await http.delete(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
          if (res.statusCode == 200) {
            final pending = await dbHelper.getPendingDeletes();
            final row = pending.firstWhere((p) => p['table_name'] == 'expenses' && p['server_id'] == serverId);
            await dbHelper.removePendingSync(row['id']);
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
        final res = await http.delete(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 404) {
          await dbHelper.removePendingSync(p['id']);
        }
      } catch (_) {}
    }

    // B. Sync expenses for each book
    final activeBooks = await dbHelper.getLocalBooks(archived: 0);
    final archivedBooks = await dbHelper.getLocalBooks(archived: 1);
    final allBooks = [...activeBooks, ...archivedBooks];

    for (final book in allBooks) {
      final serverBookId = book['server_id'];
      final localBookId = book['id'];
      if (serverBookId == null) {
        // Cannot sync expenses for a book that hasn'tSynced to server yet, wait next sync cycle
        continue;
      }

      List<dynamic> serverExpenses = [];
      try {
        final url = Uri.parse("${expenseUrl}book/$serverBookId");
        final res = await http.get(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          serverExpenses = jsonDecode(res.body) as List;
        }
      } catch (e) {
        debugPrint("Failed to sync server expenses for book $serverBookId: $e");
        continue;
      }

      final localExpenses = await dbHelper.getLocalExpensesByBook(localBookId);

      for (final se in serverExpenses) {
        final int serverId = se['id'];
        final serverUpdatedAt = se['updatedAt'] ?? se['updated_at'] ?? se['date'] ?? DateTime.fromMillisecondsSinceEpoch(0).toIso8601String();
        final description = se['description'] ?? "";
        final amount = (se['amount'] as num?)?.toDouble() ?? 0.0;
        final isCredit = se['credit'] == true || se['credit'] == 1 || se['credit'].toString().toLowerCase() == "true";
        final date = se['date'] ?? DateTime.now().toIso8601String();
        final serverCatId = se['category']?['id'];

        // Get local category ID corresponding to server classification ID
        int? localCatId;
        if (serverCatId != null) {
          localCatId = await _findLocalCategoryIdByServerId(serverCatId);
        }

        final matchIndex = localExpenses.indexWhere((le) => le['server_id'] == serverId);

        if (matchIndex != -1) {
          final le = localExpenses[matchIndex];
          final localUpdatedAt = le['updated_at'];
          final localDate = DateTime.tryParse(localUpdatedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final serverDate = DateTime.tryParse(serverUpdatedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);

          if (serverDate.isAfter(localDate)) {
            // Download Server
            await dbHelper.updateLocalExpense(le['id'], {
              'description': description,
              'amount': amount,
              'credit': isCredit ? 1 : 0,
              'date': date,
              'category_id': localCatId,
              'updated_at': serverUpdatedAt,
              'synced': 1,
            });
          } else if (localDate.isAfter(serverDate) && (le['synced'] == 0 || le['synced'] == 2)) {
            // Upload Local
            try {
              final url = Uri.parse("${expenseUrl}edit/$serverId");
              final Map<String, dynamic> body = {
                'description': le['description'],
                'amount': le['amount'],
                'credit': le['credit'],
                'date': le['date'],
              };
              if (serverCatId != null) {
                body['category'] = {'id': serverCatId};
              }
              final res = await http.put(
                url,
                headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
                body: jsonEncode(body),
              );
              if (res.statusCode == 200 || res.statusCode == 201) {
                await dbHelper.updateSyncStatus('expenses', le['id'], serverId, updatedAt: localUpdatedAt);
              } else {
                await dbHelper.updateLocalExpense(le['id'], {'synced': 2});
              }
            } catch (_) {
              await dbHelper.updateLocalExpense(le['id'], {'synced': 2});
            }
          } else {
            if (le['synced'] == 0 || le['synced'] == 2) {
              await dbHelper.updateSyncStatus('expenses', le['id'], serverId);
            }
          }
        } else {
          // Check if it was deleted local-only
          final isDeletedLocally = pending.any((p) => p['table_name'] == 'expenses' && p['server_id'] == serverId);
          if (!isDeletedLocally) {
            final now = DateTime.now().toIso8601String();
            await dbHelper.insertLocalExpense({
              'server_id': serverId,
              'description': description,
              'amount': amount,
              'credit': isCredit ? 1 : 0,
              'date': date,
              'book_id': localBookId,
              'category_id': localCatId,
              'created_at': se['createdAt'] ?? se['created_at'] ?? now,
              'updated_at': serverUpdatedAt,
              'synced': 1,
            });
          }
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

        final res = await http.post(
          Uri.parse("${expenseUrl}create"),
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          final serverId = data['id'];
          await dbHelper.updateSyncStatus('expenses', exp['id'], serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? exp['updated_at']);
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

  Future<int?> _findServerCategoryId(int localCategoryId) async {
    final cat = await dbHelper.getLocalCategoryById(localCategoryId);
    return cat?['server_id'];
  }

  Future<int?> _findLocalCategoryIdByServerId(int serverCatId) async {
    final db = await dbHelper.database;
    final list = await db.query('categories', where: 'server_id = ?', whereArgs: [serverCatId]);
    return list.isNotEmpty ? list.first['id'] as int : null;
  }
}

class InvestmentRepository {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;

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
        final res = await http.post(
          url,
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode({'description': description, 'amount': amount}),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          final serverId = data['id'];
          await dbHelper.updateSyncStatus('investments', localId, serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? nowStr);
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
        final res = await http.put(
          url,
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode({'description': description, 'amount': amount}),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          await dbHelper.updateSyncStatus('investments', localId, serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? nowStr);
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
          final res = await http.delete(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
          if (res.statusCode == 200) {
            final pending = await dbHelper.getPendingDeletes();
            final row = pending.firstWhere((p) => p['table_name'] == 'investments' && p['server_id'] == serverId);
            await dbHelper.removePendingSync(row['id']);
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
        final res = await http.delete(url, headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 404) {
          await dbHelper.removePendingSync(p['id']);
        }
      } catch (_) {}
    }

    // B. Get from Server
    List<dynamic> serverInvestments = [];
    try {
      final res = await http.get(Uri.parse("${investmentUrl}readAll"), headers: {'Authorization': basicAuth}).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        serverInvestments = jsonDecode(res.body) as List;
      }
    } catch (e) {
      debugPrint("Failed to sync server investments: $e");
      return;
    }

    // C. Get from SQLite
    final localInvestments = await dbHelper.getLocalInvestments();

    // D. Check matching & LWW
    for (final si in serverInvestments) {
      final int serverId = si['id'];
      final serverUpdatedAt = si['updatedAt'] ?? si['updated_at'] ?? DateTime.fromMillisecondsSinceEpoch(0).toIso8601String();
      final description = si['description'] ?? "";
      final amount = (si['amount'] as num?)?.toDouble() ?? 0.0;

      final matchIndex = localInvestments.indexWhere((li) => li['server_id'] == serverId);

      if (matchIndex != -1) {
        final li = localInvestments[matchIndex];
        final localUpdatedAt = li['updated_at'];
        final localDate = DateTime.tryParse(localUpdatedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final serverDate = DateTime.tryParse(serverUpdatedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);

        if (serverDate.isAfter(localDate)) {
          // Download
          await dbHelper.updateLocalInvestment(li['id'], {
            'description': description,
            'amount': amount,
            'updated_at': serverUpdatedAt,
            'synced': 1,
          });
        } else if (localDate.isAfter(serverDate) && li['synced'] == 0) {
          // Upload
          try {
            final res = await http.put(
              Uri.parse("${investmentUrl}edit/$serverId"),
              headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
              body: jsonEncode({'description': li['description'], 'amount': li['amount']}),
            ).timeout(const Duration(seconds: 15));
            if (res.statusCode == 200 || res.statusCode == 201) {
              await dbHelper.updateSyncStatus('investments', li['id'], serverId, updatedAt: localUpdatedAt);
            }
          } catch (_) {}
        } else {
          if (li['synced'] == 0) {
            await dbHelper.updateSyncStatus('investments', li['id'], serverId);
          }
        }
      } else {
        // Check if deleted local-only
        final isDeletedLocally = pending.any((p) => p['table_name'] == 'investments' && p['server_id'] == serverId);
        if (!isDeletedLocally) {
          final now = DateTime.now().toIso8601String();
          await dbHelper.insertLocalInvestment({
            'server_id': serverId,
            'description': description,
            'amount': amount,
            'created_at': si['createdAt'] ?? si['created_at'] ?? now,
            'updated_at': serverUpdatedAt,
            'synced': 1,
          });
        }
      }
    }

    // E. Upload local-only
    final unsynced = await dbHelper.getUnsyncedRecords('investments');
    for (final inv in unsynced) {
      if (inv['server_id'] != null) continue;
      try {
        final res = await http.post(
          Uri.parse("${investmentUrl}create"),
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode({'description': inv['description'], 'amount': inv['amount']}),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          final serverId = data['id'];
          await dbHelper.updateSyncStatus('investments', inv['id'], serverId, updatedAt: data['updatedAt'] ?? data['updated_at'] ?? inv['updated_at']);
        }
      } catch (_) {}
    }
  }
}

class SyncEngine {
  static final BookRepository _bookRepo = BookRepository();
  static final CategoryRepository _categoryRepo = CategoryRepository();
  static final ExpenseRepository _expenseRepo = ExpenseRepository();
  static final InvestmentRepository _investmentRepo = InvestmentRepository();

  static bool _isSyncing = false;

  static Future<void> syncAll(String basicAuth) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      debugPrint("Starting synchronizer session...");
      // Execution order keeps foreign key integrity: Categories -> Books -> Expenses -> Investments
      await _categoryRepo.syncCategories(basicAuth);
      await _bookRepo.syncBooks(basicAuth);
      await _expenseRepo.syncExpenses(basicAuth);
      await _investmentRepo.syncInvestments(basicAuth);
      debugPrint("Synchronizer session finished successfully.");
    } catch (e) {
      debugPrint("Synchronizer session aborted with error: $e");
    } finally {
      _isSyncing = false;
    }
  }
}
