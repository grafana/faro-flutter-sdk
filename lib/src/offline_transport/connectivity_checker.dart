import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityChecker {
  final _connectivity = Connectivity();

  Future<List<ConnectivityResult>> checkConnectivity() {
    return _connectivity.checkConnectivity();
  }

  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged;
  }
}

class ConnectivityCheckerFactory {
  ConnectivityChecker create() {
    return ConnectivityChecker();
  }
}
