import 'package:expense_tracker/services/auth_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeFlutterSecureStorage extends FlutterSecureStorage {
  final Map<String, String> data = {};
  bool failVerification = false;
  bool throwError = false;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (throwError) {
      throw Exception('Simulated secure storage write failure');
    }
    if (value != null) {
      data[key] = value;
    } else {
      data.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (throwError) {
      throw Exception('Simulated secure storage read failure');
    }
    if (failVerification && (key == AuthStorageService.keyAuthToken || key == AuthStorageService.keyPassword)) {
      return 'mismatched_corrupted_value';
    }
    return data[key];
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (throwError) {
      throw Exception('Simulated secure storage deleteAll failure');
    }
    data.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFlutterSecureStorage fakeStorage;
  late AuthStorageService service;

  setUp(() {
    fakeStorage = FakeFlutterSecureStorage();
    service = AuthStorageService.withStorage(fakeStorage);
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthStorageService Core Token & Credential Operations', () {
    test('buildBasicAuthToken creates accurate RFC compliant Basic Auth header', () {
      final token = AuthStorageService.buildBasicAuthToken('user@test.com', 'password123');
      // base64("user@test.com:password123") is dXNlckB0ZXN0LmNvbTpwYXNzd29yZDEyMw==
      expect(token, 'Basic dXNlckB0ZXN0LmNvbTpwYXNzd29yZDEyMw==');
    });

    test('saveCredentials stores token, password, and email in secure storage and cache', () async {
      final success = await service.saveCredentials(
        email: 'test@domain.com',
        password: 'mySecretPassword',
      );

      expect(success, isTrue);
      expect(service.currentEmail, 'test@domain.com');
      expect(service.currentPassword, 'mySecretPassword');
      expect(service.currentAuthToken, isNotEmpty);
      expect(fakeStorage.data[AuthStorageService.keyPassword], 'mySecretPassword');
      expect(fakeStorage.data[AuthStorageService.keyEmail], 'test@domain.com');
      expect(fakeStorage.data[AuthStorageService.keyAuthToken], service.currentAuthToken);
    });

    test('getAuthToken and getPassword fetch from secure storage if cache was empty', () async {
      fakeStorage.data[AuthStorageService.keyAuthToken] = 'Basic YWJjOmRlZg==';
      fakeStorage.data[AuthStorageService.keyPassword] = 'storedPassword';
      fakeStorage.data[AuthStorageService.keyEmail] = 'abc';

      final token = await service.getAuthToken();
      final pwd = await service.getPassword();

      expect(token, 'Basic YWJjOmRlZg==');
      expect(pwd, 'storedPassword');
      expect(service.currentAuthToken, 'Basic YWJjOmRlZg==');
      expect(service.currentPassword, 'storedPassword');
    });

    test('updatePassword updates encrypted password and recalculates auth token', () async {
      await service.saveCredentials(email: 'user@finance.app', password: 'oldPassword');
      final initialToken = service.currentAuthToken;

      final updated = await service.updatePassword('newSecurePassword');

      expect(updated, isTrue);
      expect(service.currentPassword, 'newSecurePassword');
      expect(service.currentAuthToken, isNot(equals(initialToken)));
      expect(fakeStorage.data[AuthStorageService.keyPassword], 'newSecurePassword');
      expect(
        fakeStorage.data[AuthStorageService.keyAuthToken],
        AuthStorageService.buildBasicAuthToken('user@finance.app', 'newSecurePassword'),
      );
    });

    test('clearAll wipes in-memory cache and encrypted storage', () async {
      await service.saveCredentials(email: 'user@finance.app', password: 'password');
      expect(service.currentAuthToken, isNotEmpty);

      await service.clearAll();

      expect(service.currentAuthToken, isEmpty);
      expect(service.currentPassword, isEmpty);
      expect(service.currentEmail, isEmpty);
      expect(fakeStorage.data, isEmpty);
    });

    test('handles secure storage write errors gracefully without crashing', () async {
      fakeStorage.throwError = true;

      final success = await service.saveCredentials(email: 'err@test.com', password: 'pwd');

      // Returns false due to hardware/OS exception, but fallback cache keeps session alive
      expect(success, isFalse);
      expect(service.currentAuthToken, isNotEmpty);
    });
  });

  group('Backward-Compatible Migration from SharedPreferences', () {
    test('successfully migrates legacy password, verifies read-back, and removes from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'isLoggedIn': true,
        'email': 'existing_user@tracklet.app',
        'password': 'legacyPlainPassword',
        'userId': 42,
      });
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.containsKey('password'), isTrue);

      final migrated = await service.migrateFromSharedPreferences(prefs);

      expect(migrated, isTrue);
      // Legacy plaintext password removed from SharedPreferences XML
      expect(prefs.containsKey('password'), isFalse);
      // Non-sensitive keys retained
      expect(prefs.getString('email'), 'existing_user@tracklet.app');
      expect(prefs.getInt('userId'), 42);

      // Successfully transferred to secure storage
      expect(fakeStorage.data[AuthStorageService.keyPassword], 'legacyPlainPassword');
      expect(
        fakeStorage.data[AuthStorageService.keyAuthToken],
        AuthStorageService.buildBasicAuthToken('existing_user@tracklet.app', 'legacyPlainPassword'),
      );
      expect(service.currentAuthToken, isNotEmpty);
    });

    test('NEVER removes legacy password if secure storage verification fails', () async {
      SharedPreferences.setMockInitialValues({
        'isLoggedIn': true,
        'email': 'existing_user@tracklet.app',
        'password': 'legacyPlainPassword',
        'userId': 42,
      });
      final prefs = await SharedPreferences.getInstance();

      // Simulate verification read-back failure (e.g. corruption or Keystore write glitch)
      fakeStorage.failVerification = true;

      final migrated = await service.migrateFromSharedPreferences(prefs);

      expect(migrated, isFalse);
      // CRITICAL POLICY REQUIREMENT: Legacy password must NOT be deleted
      expect(prefs.containsKey('password'), isTrue);
      expect(prefs.getString('password'), 'legacyPlainPassword');
    });

    test('returns false when no legacy password exists in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'isLoggedIn': true,
        'email': 'clean_user@tracklet.app',
      });
      final prefs = await SharedPreferences.getInstance();

      final migrated = await service.migrateFromSharedPreferences(prefs);

      expect(migrated, isFalse);
      expect(fakeStorage.data, isEmpty);
    });

    test('safely cleans up empty legacy password string', () async {
      SharedPreferences.setMockInitialValues({
        'password': '',
      });
      final prefs = await SharedPreferences.getInstance();

      final migrated = await service.migrateFromSharedPreferences(prefs);

      expect(migrated, isFalse);
      expect(prefs.containsKey('password'), isFalse);
    });

    test('init runs migration and warms in-memory cache', () async {
      SharedPreferences.setMockInitialValues({
        'email': 'init_test@tracklet.app',
        'password': 'initPassword999',
      });
      final prefs = await SharedPreferences.getInstance();

      await service.init(prefs: prefs);

      expect(prefs.containsKey('password'), isFalse);
      expect(service.currentPassword, 'initPassword999');
      expect(service.currentEmail, 'init_test@tracklet.app');
      expect(service.currentAuthToken, isNotEmpty);
    });
  });
}
