import 'dart:async';
import 'package:http/http.dart' as http;

class KeepAliveService {
  static Timer? _timer;

  static void start() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 40), (_) async {
      try {
        final response = await http.get(
          Uri.parse("https://tracklet-savebuddy-1.onrender.com/health"),
        );
        print("Health Ping: ${response.statusCode}");
      } catch (e) {
        print("Ping Failed: $e");
      }
    });
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }
}