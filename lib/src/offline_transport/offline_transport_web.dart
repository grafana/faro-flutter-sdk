import 'package:faro/src/offline_transport/internet_connectivity_service.dart';
import 'package:faro/src/transport/faro_base_transport.dart';

class OfflineTransport extends BaseTransport {
  OfflineTransport({
    Duration? maxCacheDuration,
    String? internetConnectionCheckerUrl,
    InternetConnectivityService? internetConnectivityService,
  }) {
    // Keep the public constructor signature aligned with mobile even though
    // the web beta does not support offline transport yet.
    final _ = (
      maxCacheDuration,
      internetConnectionCheckerUrl,
      internetConnectivityService,
    );
    throw UnsupportedError(
      'OfflineTransport is not supported on Flutter web in this beta.',
    );
  }

  @override
  Future<void> send(Map<String, dynamic> payloadJson) async {}
}
