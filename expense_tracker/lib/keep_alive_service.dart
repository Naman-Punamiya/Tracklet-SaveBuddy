import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:expense_tracker/constant.dart';

class KeepAliveService {
  static Timer? _timer;

  static void start() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 40), (_) async {
      try {
        final response = await http.get(
          Uri.parse("$baseUrl/health"),
        );
        debugPrint("Health Ping: ${response.statusCode}");
      } catch (e) {
        debugPrint("Ping Failed: $e");
      }
    });
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }
}