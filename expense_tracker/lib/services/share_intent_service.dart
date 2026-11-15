import 'package:flutter/services.dart';

class ShareIntentService {
  static const MethodChannel _channel =
      MethodChannel('expense_tracker/share');

  static Future<String?> getSharedText() async {
    try {
      return await _channel.invokeMethod<String>('getSharedText');
    } catch (_) {
      return null;
    }
  }
}