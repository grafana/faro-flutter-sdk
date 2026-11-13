import 'dart:developer';

import 'package:faro/src/offline_transport/offline_transport_delegate.dart';

/// Used on web, which has no file system to cache payloads in.
class NoOpOfflineTransportDelegate implements OfflineTransportDelegate {
  /// Creates a delegate that does nothing, and logs that it does so.
  NoOpOfflineTransportDelegate() {
    log('Faro: OfflineTransport is not supported on web and does nothing.');
  }

  @override
  Future<void> send(Map<String, dynamic> payloadJson) async {}

  @override
  Future<void> replayCachedData() async {}
}
