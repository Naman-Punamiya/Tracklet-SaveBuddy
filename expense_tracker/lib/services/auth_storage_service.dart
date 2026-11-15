import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized service for secure credential storage backed by Android Keystore
/// (EncryptedSharedPreferences) and iOS Keychain.
///
/// Prevents plaintext credential leakage in SharedPreferences while maintaining
/// 100% compatibility with the backend's HTTP Basic Auth protocol.
class AuthStorageService {
  AuthStorageService._internal({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                resetOnError: true,
              ),
            );

  /// Default singleton instance
  static final AuthStorageService instance = AuthStorageService._internal();

  /// Constructor allowing dependency injection (primarily for unit testing)
  factory AuthStorageService.withStorage(FlutterSecureStorage storage) {
    return AuthStorageService._internal(storage: storage);
  }

  final FlutterSecureStorage _storage;

  static const String keyAuthToken = 'auth_token';
  static const String keyPassword = 'auth_password';
  static const String keyEmail = 'auth_email';

  // Fast in-memory caching to prevent asynchronous delay on UI thread or widget build
  String? _cachedAuthToken;
  String? _cachedPassword;
  String? _cachedEmail;

  /// Synchronous getter for current Basic Auth token: `Basic <base64(email:password)>`
  String get currentAuthToken => _cachedAuthToken ?? '';

  /// Synchronous getter for current user password (used when updating password)
  String get currentPassword => _cachedPassword ?? '';

  /// Synchronous getter for active user email
  String get currentEmail => _cachedEmail ?? '';

  /// Builds a standard HTTP Basic Auth header value without exposing credentials in logs.
  static String buildBasicAuthToken(String email, String password) {
    return 'Basic ${base64Encode(utf8.encode('$email:$password'))}';
  }

  /// Initializes the service on app launch:
  /// 1. Migrates existing plaintext credentials from [SharedPreferences] if present.
  /// 2. Reads encrypted credentials into in-memory cache for seamless session restoration.
  Future<void> init({SharedPreferences? prefs}) async {
    try {
      final SharedPreferences sp = prefs ?? await SharedPreferences.getInstance();
      await migrateFromSharedPreferences(sp);

      _cachedAuthToken = await _storage.read(key: keyAuthToken);
      _cachedPassword = await _storage.read(key: keyPassword);
      _cachedEmail = await _storage.read(key: keyEmail);

      // If token is missing in secure storage but email and password are saved, derive and save it
      if ((_cachedAuthToken == null || _cachedAuthToken!.isEmpty) &&
          _cachedEmail != null &&
          _cachedEmail!.isNotEmpty &&
          _cachedPassword != null &&
          _cachedPassword!.isNotEmpty) {
        final token = buildBasicAuthToken(_cachedEmail!, _cachedPassword!);
        await _storage.write(key: keyAuthToken, value: token);
        _cachedAuthToken = token;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AuthStorageService: Initialization warning: $e');
      }
    }
  }

  /// Securely saves user credentials into Android Keystore-backed storage.
  /// Computes and stores the HTTP Basic Auth token alongside the encrypted password.
  Future<bool> saveCredentials({
    required String email,
    required String password,
  }) async {
    final token = buildBasicAuthToken(email, password);
    try {
      await _storage.write(key: keyAuthToken, value: token);
      await _storage.write(key: keyPassword, value: password);
      await _storage.write(key: keyEmail, value: email);

      _cachedAuthToken = token;
      _cachedPassword = password;
      _cachedEmail = email;
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AuthStorageService: Failed to write to secure storage: $e');
      }
      // Keep in-memory cache populated for active session continuity
      _cachedAuthToken = token;
      _cachedPassword = password;
      _cachedEmail = email;
      return false;
    }
  }

  /// Safely migrates existing plaintext credentials from [SharedPreferences].
  ///
  /// CRITICAL REQUIREMENT: Never removes the legacy password from SharedPreferences
  /// until secure storage has successfully written and VERIFIED the saved credentials
  /// via read-back.
  Future<bool> migrateFromSharedPreferences(SharedPreferences prefs) async {
    try {
      if (!prefs.containsKey('password')) {
        return false;
      }

      final legacyPassword = prefs.getString('password') ?? '';
      final email = prefs.getString('email') ?? '';

      // If legacy password is empty string, remove safely
      if (legacyPassword.isEmpty) {
        await prefs.remove('password');
        return false;
      }

      // If email is missing, leave legacy key untouched until login completes
      if (email.isEmpty) {
        return false;
      }

      final expectedToken = buildBasicAuthToken(email, legacyPassword);

      // Step 1: Write to secure storage
      await _storage.write(key: keyAuthToken, value: expectedToken);
      await _storage.write(key: keyPassword, value: legacyPassword);
      await _storage.write(key: keyEmail, value: email);

      // Step 2: Verification read-back
      final verifiedToken = await _storage.read(key: keyAuthToken);
      final verifiedPassword = await _storage.read(key: keyPassword);

      if (verifiedToken == expectedToken && verifiedPassword == legacyPassword) {
        // Step 3: Verified! Safe to delete unencrypted plaintext password from disk
        await prefs.remove('password');
        _cachedAuthToken = verifiedToken;
        _cachedPassword = verifiedPassword;
        _cachedEmail = email;
        return true;
      } else {
        if (kDebugMode) {
          debugPrint('AuthStorageService: Migration verification failed. Preserving legacy password.');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AuthStorageService: Migration error: $e');
      }
      return false;
    }
  }

  /// Updates user password in secure storage and recalculates the authorization token.
  Future<bool> updatePassword(String newPassword) async {
    final activeEmail = _cachedEmail ?? await _storage.read(key: keyEmail) ?? '';
    if (activeEmail.isEmpty) {
      return false;
    }
    return await saveCredentials(email: activeEmail, password: newPassword);
  }

  /// Retrieves the active Basic Auth token.
  Future<String> getAuthToken() async {
    if (_cachedAuthToken != null && _cachedAuthToken!.isNotEmpty) {
      return _cachedAuthToken!;
    }
    try {
      final token = await _storage.read(key: keyAuthToken);
      if (token != null && token.isNotEmpty) {
        _cachedAuthToken = token;
        return token;
      }
    } catch (_) {}
    return '';
  }

  /// Retrieves the user password (used exclusively for backend password change requests).
  Future<String> getPassword() async {
    if (_cachedPassword != null && _cachedPassword!.isNotEmpty) {
      return _cachedPassword!;
    }
    try {
      final pass = await _storage.read(key: keyPassword);
      if (pass != null && pass.isNotEmpty) {
        _cachedPassword = pass;
        return pass;
      }
    } catch (_) {}
    return '';
  }

  /// Completely wipes all secure credentials and in-memory cache.
  /// Called upon user logout and permanent account deletion.
  Future<void> clearAll() async {
    _cachedAuthToken = null;
    _cachedPassword = null;
    _cachedEmail = null;
    try {
      await _storage.deleteAll();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AuthStorageService: Failed to clear secure storage: $e');
      }
    }
  }
}
