import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/services/connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void setupTestDatabase() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.testDatabasePath = inMemoryDatabasePath;
  ConnectivityService.mockStatus = ConnectivityStatus.offline;
}

Future<void> resetTestDatabase() async {
  DatabaseHelper.resetDatabase();
  final db = await DatabaseHelper.instance.database;
  await db.delete('expenses');
  await db.delete('books');
  await db.delete('categories');
  await db.delete('investments');
  await db.delete('pending_sync');
}

void setupTestSharedPreferences({Map<String, Object> initialValues = const {}}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(initialValues);
}
