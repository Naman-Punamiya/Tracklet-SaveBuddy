import 'package:expense_tracker/services/connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConnectivityService Status Tests', () {
    test('getConnectivityStatus returns valid enum value', () async {
      final status = await ConnectivityService.getConnectivityStatus();
      expect(status, isA<ConnectivityStatus>());
    });

    test('isOnline returns boolean', () async {
      final online = await ConnectivityService.isOnline();
      expect(online, isA<bool>());
    });
  });
}
