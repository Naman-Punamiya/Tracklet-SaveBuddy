import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/services/connectivity_service.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void setupTestDatabase() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.testDatabasePath = inMemoryDatabasePath;
  ConnectivityService.mockStatus = ConnectivityStatus.offline;
  GoogleFonts.config.allowRuntimeFetching = false;
  setupTestSecureStorage();
}

void setupTestSecureStorage([Map<String, String>? initialValues]) {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(initialValues ?? {});
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
  setupTestSecureStorage();
}
