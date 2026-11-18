import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../pages/Auth/reset_password_page.dart';

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    if (_initialized) return;
    _initialized = true;

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri, navigatorKey);
      }
    } catch (e) {
      debugPrint('DeepLinkService: failed to get initial link: $e');
    }

    _sub = _appLinks.uriLinkStream.listen(
      (uri) => _handleUri(uri, navigatorKey),
      onError: (e) => debugPrint('DeepLinkService: link stream error: $e'),
    );
  }

  void _handleUri(Uri uri, GlobalKey<NavigatorState> navigatorKey) {
    try {
      final token = _extractResetToken(uri);
      if (token == null || token.isEmpty) return;

      final nav = navigatorKey.currentState;
      if (nav == null) return;

      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => ResetPasswordPage(token: token)),
        (route) => false,
      );
    } catch (e) {
      debugPrint('DeepLinkService: failed to handle uri: $e');
    }
  }

  String? _extractResetToken(Uri uri) {
    // Expected formats:
    // https://<configured-host>/reset-password?token=...
    // https://<host>/.../reset-password?token=...
    final token = uri.queryParameters['token'];
    if (token != null && token.trim().isNotEmpty) {
      final path = uri.path.toLowerCase();
      if (path.contains('reset-password') || path.contains('reset_password') || path.endsWith('/reset')) {
        return token.trim();
      }
      // If token is present, accept it to be resilient to configured path variations.
      return token.trim();
    }
    return null;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _initialized = false;
  }
}
