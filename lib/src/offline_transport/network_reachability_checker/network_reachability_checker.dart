import 'package:faro/src/offline_transport/network_reachability_checker/native_network_reachability_checker.dart'
    if (dart.library.js) 'package:faro/src/offline_transport/network_reachability_checker/web_network_reachability_checker.dart';

abstract class NetworkReachabilityChecker {
  Future<bool> isConnectedToInternet(String host);
}

class NetworkReachabilityCheckerFactory {
  NetworkReachabilityChecker create() {
    // Picking the right Checker is solved with the conditional imports
    return createNetworkReachabilityChecker();
  }
}