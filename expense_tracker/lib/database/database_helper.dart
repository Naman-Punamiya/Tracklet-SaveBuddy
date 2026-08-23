import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._init();

  static final DatabaseHelper instance = DatabaseHelper._init();

  factory DatabaseHelper() => instance;

  static String? testDatabasePath;
  static Database? _database;
  static set mockDatabase(Database? db) => _database = db;
  static void resetDatabase() => _database = null;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = testDatabasePath ?? join(await getDatabasesPath(), 'expense_tracker.db');
    return await openDatabase(
      path,
      version: 3,
      onConfigure: (db) async {
        await db.execute("PRAGMA foreign_keys = ON");
      },
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Upgrade migration: recreate database tables for clean state transition
        await db.execute("DROP TABLE IF EXISTS expenses");
        await db.execute("DROP TABLE IF EXISTS books");
        await db.execute("DROP TABLE IF EXISTS categories");
        await db.execute("DROP TABLE IF EXISTS investments");
        await db.execute("DROP TABLE IF EXISTS pending_sync");
        await _createTables(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    // 1. Books Table
    // Stores Book modules that organize transactions. Supports offline server_id and synchronization updates.
    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER UNIQUE,
        name TEXT NOT NULL,
        subtitle TEXT,
        archived INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    // 2. Categories Table
    // Stores category information, including selectable icon and color parameters.
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER UNIQUE,
        name TEXT NOT NULL,
        icon TEXT,
        color TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    // 3. Expenses Table
    // Stores credit/debit records associated with a book and category (using proper foreign keys).
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER UNIQUE,
        description TEXT,
        amount REAL,
        credit INTEGER,
        date TEXT NOT NULL,
        book_id INTEGER,
        category_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE,
        FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');

    // 4. Investments Table
    // Stores self-contained investment records for offline finance checks.
    await db.execute('''
      CREATE TABLE investments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER UNIQUE,
        description TEXT NOT NULL,
        amount REAL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    // 5. Pending Sync Table
    // Queue logs actions like DELETEs performed offline that must be replicated to the remote database when online.
    await db.execute('''
      CREATE TABLE pending_sync (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        server_id INTEGER,
        action TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  // ==========================================
  // BACKLOG COMPATIBILITY METHODS (For v2 endpoints if called by other files)
  // ==========================================

  Future<void> insertExpense({
    required String description,
    required double amount,
    required bool credit,
    required String date,
    required int categoryId,
    required String categoryName,
    required int bookId,
  }) async {
    final db = await database;
    final nowStr = DateTime.now().toIso8601String();
    
    // Ensure category exists locally first
    final catCheck = await db.query('categories', where: 'id = ?', whereArgs: [categoryId]);
    if (catCheck.isEmpty) {
      await db.insert('categories', {
        'id': categoryId,
        'name': categoryName,
        'icon': 'More',
        'color': '#000000',
        'created_at': nowStr,
        'updated_at': nowStr,
        'synced': 1, // Treat as static/mock sync
      });
    }

    await db.insert('expenses', {
      'description': description,
      'amount': amount,
      'credit': credit ? 1 : 0,
      'date': date,
      'category_id': categoryId,
      'book_id': bookId,
      'created_at': nowStr,
      'updated_at': nowStr,
      'synced': 0,
    });
    debugPrint("Expense inserted locally via compat");
  }

  Future<List<Map<String, dynamic>>> getAllExpenses() async {
    final db = await database;
    final list = await db.rawQuery('''
      SELECT e.*, c.name as category_name, c.icon as category_icon, c.color as category_color
      FROM expenses e
      LEFT JOIN categories c ON e.category_id = c.id
      ORDER BY e.date DESC
    ''');
    return list.map((row) => _formatExpenseRow(row)).toList();
  }

  Future<List<Map<String, dynamic>>> getUnsyncedExpenses() async {
    final db = await database;
    final list = await db.rawQuery('''
      SELECT e.*, c.name as category_name, c.icon as category_icon, c.color as category_color
      FROM expenses e
      LEFT JOIN categories c ON e.category_id = c.id
      WHERE e.synced = 0 OR e.synced = 2
    ''');
    return list.map((row) => _formatExpenseRow(row)).toList();
  }

  Future<void> markExpenseAsSynced(int id) async {
    final db = await database;
    await db.update(
      'expenses',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Helper to format flat SQLite rows into the nested structure the UI code consumes
  Map<String, dynamic> _formatExpenseRow(Map<String, dynamic> row) {
    final Map<String, dynamic> formatted = Map<String, dynamic>.from(row);
    // Support integer mapping for credit
    formatted['credit'] = row['credit'] == 1;
    formatted['synced'] = row['synced'];
    // Map category
    if (row['category_id'] != null) {
      formatted['category'] = {
        'id': row['category_id'],
        'name': row['category_name'] ?? "Others",
        'icon': row['category_icon'] ?? "More",
        'color': row['category_color'] ?? "#000000",
      };
    } else {
      formatted['category'] = null;
    }
    return formatted;
  }

  // ==========================================
  // GENERAL LOCAL CRUD: BOOKS
  // ==========================================

  Future<int> insertLocalBook(Map<String, dynamic> book) async {
    final db = await database;
    return await db.insert('books', book);
  }

  Future<int> updateLocalBook(int localId, Map<String, dynamic> book) async {
    final db = await database;
    return await db.update('books', book, where: 'id = ?', whereArgs: [localId]);
  }

  Future<int> deleteLocalBook(int localId) async {
    final db = await database;
    return await db.delete('books', where: 'id = ?', whereArgs: [localId]);
  }

  Future<Map<String, dynamic>?> getLocalBookById(int localId) async {
    final db = await database;
    final list = await db.query('books', where: 'id = ?', whereArgs: [localId]);
    return list.isNotEmpty ? list.first : null;
  }

  Future<List<Map<String, dynamic>>> getLocalBooks({required int archived}) async {
    final db = await database;
    return await db.query('books', where: 'archived = ?', whereArgs: [archived], orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> searchLocalBooks(String query, int archived) async {
    final db = await database;
    final trimmed = query.trim();
    return await db.query(
      'books',
      where: 'archived = ? AND (name LIKE ? OR subtitle LIKE ?)',
      whereArgs: [archived, '%$trimmed%', '%$trimmed%'],
      orderBy: 'created_at DESC'
    );
  }

  // ==========================================
  // GENERAL LOCAL CRUD: CATEGORIES
  // ==========================================

  Future<int> insertLocalCategory(Map<String, dynamic> category) async {
    final db = await database;
    return await db.insert('categories', category);
  }

  Future<int> updateLocalCategory(int localId, Map<String, dynamic> category) async {
    final db = await database;
    return await db.update('categories', category, where: 'id = ?', whereArgs: [localId]);
  }

  Future<int> deleteLocalCategory(int localId) async {
    final db = await database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [localId]);
  }

  Future<Map<String, dynamic>?> getLocalCategoryById(int localId) async {
    final db = await database;
    final list = await db.query('categories', where: 'id = ?', whereArgs: [localId]);
    return list.isNotEmpty ? list.first : null;
  }

  Future<List<Map<String, dynamic>>> getLocalCategories() async {
    final db = await database;
    final list = await db.query('categories', orderBy: 'name ASC');
    if (list.isEmpty) {
      await seedDefaultCategories(db);
      return await db.query('categories', orderBy: 'name ASC');
    }
    return list;
  }

  Future<void> seedDefaultCategories(Database db) async {
    final nowStr = DateTime.now().toIso8601String();
    final defaultCategories = [
      {'name': 'Food', 'icon': 'Food', 'color': '#000000'},
      {'name': 'Transportation', 'icon': 'Transportation', 'color': '#000000'},
      {'name': 'Shopping', 'icon': 'Shopping', 'color': '#000000'},
      {'name': 'Home', 'icon': 'Home', 'color': '#000000'},
      {'name': 'Utilities', 'icon': 'Utilities', 'color': '#000000'},
      {'name': 'Healthcare', 'icon': 'Healthcare', 'color': '#000000'},
      {'name': 'Travel', 'icon': 'Travel', 'color': '#000000'},
      {'name': 'Education', 'icon': 'Education', 'color': '#000000'},
      {'name': 'Savings', 'icon': 'Savings', 'color': '#000000'},
      {'name': 'Investment', 'icon': 'Investment', 'color': '#000000'},
      {'name': 'Receipt', 'icon': 'Receipt', 'color': '#000000'},
      {'name': 'Other', 'icon': 'More', 'color': '#000000'},
    ];

    for (final cat in defaultCategories) {
      await db.insert('categories', {
        'name': cat['name'],
        'icon': cat['icon'],
        'color': cat['color'],
        'created_at': nowStr,
        'updated_at': nowStr,
        'synced': 0,
      });
    }
  }

  Future<List<Map<String, dynamic>>> searchLocalCategories(String query) async {
    final db = await database;
    final trimmed = query.trim();
    return await db.query('categories', where: 'name LIKE ?', whereArgs: ['%$trimmed%'], orderBy: 'name ASC');
  }

  // ==========================================
  // GENERAL LOCAL CRUD: EXPENSES
  // ==========================================

  Future<int> insertLocalExpense(Map<String, dynamic> expense) async {
    final db = await database;
    return await db.insert('expenses', expense);
  }

  Future<int> updateLocalExpense(int localId, Map<String, dynamic> expense) async {
    final db = await database;
    return await db.update('expenses', expense, where: 'id = ?', whereArgs: [localId]);
  }

  Future<int> deleteLocalExpense(int localId) async {
    final db = await database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [localId]);
  }

  Future<Map<String, dynamic>?> getLocalExpenseById(int localId) async {
    final db = await database;
    final list = await db.rawQuery('''
      SELECT e.*, c.name as category_name, c.icon as category_icon, c.color as category_color
      FROM expenses e
      LEFT JOIN categories c ON e.category_id = c.id
      WHERE e.id = ?
    ''', [localId]);
    return list.isNotEmpty ? _formatExpenseRow(list.first) : null;
  }

  Future<List<Map<String, dynamic>>> getLocalExpensesByBook(int localBookId) async {
    final db = await database;
    final list = await db.rawQuery('''
      SELECT e.*, c.name as category_name, c.icon as category_icon, c.color as category_color
      FROM expenses e
      LEFT JOIN categories c ON e.category_id = c.id
      WHERE e.book_id = ?
      ORDER BY e.date DESC
    ''', [localBookId]);
    return list.map((row) => _formatExpenseRow(row)).toList();
  }

  Future<List<Map<String, dynamic>>> searchLocalExpenses(int localBookId, String query) async {
    final db = await database;
    final trimmed = query.trim();
    final list = await db.rawQuery('''
      SELECT e.*, c.name as category_name, c.icon as category_icon, c.color as category_color
      FROM expenses e
      LEFT JOIN categories c ON e.category_id = c.id
      WHERE e.book_id = ? AND (e.description LIKE ? OR c.name LIKE ?)
      ORDER BY e.date DESC
    ''', [localBookId, '%$trimmed%', '%$trimmed%']);
    return list.map((row) => _formatExpenseRow(row)).toList();
  }

  // ==========================================
  // GENERAL LOCAL CRUD: INVESTMENTS
  // ==========================================

  Future<int> insertLocalInvestment(Map<String, dynamic> investment) async {
    final db = await database;
    return await db.insert('investments', investment);
  }

  Future<int> updateLocalInvestment(int localId, Map<String, dynamic> investment) async {
    final db = await database;
    return await db.update('investments', investment, where: 'id = ?', whereArgs: [localId]);
  }

  Future<int> deleteLocalInvestment(int localId) async {
    final db = await database;
    return await db.delete('investments', where: 'id = ?', whereArgs: [localId]);
  }

  Future<Map<String, dynamic>?> getLocalInvestmentById(int localId) async {
    final db = await database;
    final list = await db.query('investments', where: 'id = ?', whereArgs: [localId]);
    return list.isNotEmpty ? list.first : null;
  }

  Future<List<Map<String, dynamic>>> getLocalInvestments() async {
    final db = await database;
    return await db.query('investments', orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> searchLocalInvestments(String query) async {
    final db = await database;
    final trimmed = query.trim();
    return await db.query(
      'investments',
      where: 'description LIKE ?',
      whereArgs: ['%$trimmed%'],
      orderBy: 'created_at DESC'
    );
  }

  // ==========================================
  // SYNCHRONIZATION HELPERS
  // ==========================================

  Future<List<Map<String, dynamic>>> getUnsyncedRecords(String tableName) async {
    final db = await database;
    final list = await db.query(tableName, where: 'synced = 0 OR synced = 2');
    return list;
  }

  Future<void> updateSyncStatus(String tableName, int localId, int serverId, {String? updatedAt}) async {
    final db = await database;
    final Map<String, dynamic> updateData = {
      'server_id': serverId,
      'synced': 1,
    };
    if (updatedAt != null) {
      updateData['updated_at'] = updatedAt;
    }
    await db.update(
      tableName,
      updateData,
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // ==========================================
  // PENDING SYNC QUEUE OPERATIONS
  // ==========================================

  Future<void> logPendingDelete(String tableName, int serverId) async {
    final db = await database;
    await db.insert('pending_sync', {
      'table_name': tableName,
      'server_id': serverId,
      'action': 'DELETE',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingDeletes() async {
    final db = await database;
    return await db.query('pending_sync', where: 'action = ?', whereArgs: ['DELETE']);
  }

  Future<void> removePendingSync(int id) async {
    final db = await database;
    await db.delete('pending_sync', where: 'id = ?', whereArgs: [id]);
  }
}
