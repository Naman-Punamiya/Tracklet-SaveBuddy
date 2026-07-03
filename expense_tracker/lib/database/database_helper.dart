import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'expense_tracker.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          description TEXT,
          amount REAL,
          credit INTEGER,
          date TEXT,
          book_id INTEGER,
          category_id INTEGER,
          synced INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

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
    await db.insert('expenses', {
      'description': description,
      'amount': amount,
      'credit': credit ? 1 : 0,
      'date': date,
      'category_id': categoryId,
      'book_id': bookId,
      'synced': 0,
    });
    print("Expense inserted locally");
  }

  Future<List<Map<String, dynamic>>> getAllExpenses() async {
    final db = await database;
    return await db.query('expenses', orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedExpenses() async {
    final db = await database;
    return await db.query('expenses', where: 'synced = ?', whereArgs: [0]);
  }

  Future<void> markExpenseAsSynced(int id) async {
    final db = await database;
    await db.update(
      'expenses',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    print("Expense with id $id marked as synced");
  }
  
}
