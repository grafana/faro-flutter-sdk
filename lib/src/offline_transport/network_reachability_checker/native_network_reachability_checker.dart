import 'dart:io';
import 'package:faro/src/offline_transport/network_reachability_checker/network_reachability_checker.dart';

class NativeNetworkReachabilityChecker implements NetworkReachabilityChecker {
  @override
  Future<bool> isConnectedToInternet(String host) async {
    try {
      final result = await InternetAddress.lookup(host);
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}

NetworkReachabilityChecker createNetworkReachabilityChecker() {
  return NativeNetworkReachabilityChecker();
}
