import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectivityStatus {
  wifi,
  mobile,
  offline
}

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();

  static Future<ConnectivityStatus> getConnectivityStatus() async {
    final result = await _connectivity.checkConnectivity();
    return _mapResult(result);
  }

  static Future<bool> isOnline() async {
    final status = await getConnectivityStatus();
    return status != ConnectivityStatus.offline;
  }

  static ConnectivityStatus _mapSingleResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.ethernet:
      case ConnectivityResult.vpn:
        return ConnectivityStatus.wifi;
      case ConnectivityResult.mobile:
        return ConnectivityStatus.mobile;
      case ConnectivityResult.none:
      default:
        return ConnectivityStatus.offline;
    }
  }

  static ConnectivityStatus _mapResult(dynamic event) {
    if (event is List) {
      if (event.isEmpty) return ConnectivityStatus.offline;
      // Check if list contains wifi/ethernet/vpn
      if (event.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn)) {
        return ConnectivityStatus.wifi;
      }
      if (event.any((r) => r == ConnectivityResult.mobile)) {
        return ConnectivityStatus.mobile;
      }
      return ConnectivityStatus.offline;
    } else if (event is ConnectivityResult) {
      return _mapSingleResult(event);
    }
    return ConnectivityStatus.offline;
  }

  static Stream<ConnectivityStatus> get connectivityStream {
    return _connectivity.onConnectivityChanged.map((event) {
      return _mapResult(event);
    });
  }
}
