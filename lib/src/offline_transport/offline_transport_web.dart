import 'package:faro/src/offline_transport/internet_connectivity_service.dart';
import 'package:faro/src/transport/faro_base_transport.dart';

class OfflineTransport extends BaseTransport {
  /// Constructor signature matches mobile for API compatibility.
  OfflineTransport({
    Duration? maxCacheDuration,
    String? internetConnectionCheckerUrl,
    InternetConnectivityService? internetConnectivityService,
  }) {
    throw UnsupportedError(
      'OfflineTransport is not supported on Flutter web in this beta.',
    );
  }

  @override
  Future<void> send(Map<String, dynamic> payloadJson) async {}
}
