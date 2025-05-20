import 'package:faro/src/offline_transport/network_reachability_checker/network_reachability_checker.dart';
import 'package:http/http.dart' as http;

class WebNetworkReachabilityChecker implements NetworkReachabilityChecker {
  @override
  Future<bool> isConnectedToInternet(String host) async {
    try {
      // Just try to establish a connection without waiting for a full response
      final uri = Uri.https(host);
      final client = http.Client();
      try {
        // Start the request but don't wait for the full response
        final request = http.Request('HEAD', uri);
        // ignore: unused_local_variable
        final streamedResponse = await client.send(request)
            .timeout(const Duration(seconds: 2));
        
        // If we get here, DNS resolution worked and we got a response
        // We don't care about the status code, just that we connected
        // This mirrors the behaviour for native the closest
        return true;
      } finally {
        client.close();
      }
    } catch (_) {
      return false;
    }
  }
}

NetworkReachabilityChecker createNetworkReachabilityChecker() {
  return WebNetworkReachabilityChecker();
}
