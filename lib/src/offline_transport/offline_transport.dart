import 'package:faro/src/core/pod.dart';
import 'package:faro/src/offline_transport/internet_connectivity_service.dart';
import 'package:faro/src/offline_transport/offline_transport_delegate.dart';
import 'package:faro/src/transport/faro_base_transport.dart';

/// Caches payloads while the device is offline and sends them again once the
/// connection is back.
class OfflineTransport extends BaseTransport {
  /// Creates an [OfflineTransport].
  OfflineTransport({
    Duration? maxCacheDuration,
    String? internetConnectionCheckerUrl,
    InternetConnectivityService? internetConnectivityService,
  }) {
    // Created in the body, since the initializer list can't use `this`.
    _delegate = pod
        .resolve(offlineTransportDelegateFactoryProvider)
        .create(
          onReconnected: replayCachedData,
          maxCacheDuration: maxCacheDuration,
          internetConnectionCheckerUrl: internetConnectionCheckerUrl,
          internetConnectivityService: internetConnectivityService,
        );
  }

  late final OfflineTransportDelegate _delegate;

  @override
  Future<void> send(Map<String, dynamic> payloadJson) =>
      _delegate.send(payloadJson);

  /// Attempts to deliver cached data when online, or discards it if
  /// collection is disabled. Faro calls this after initialization and on
  /// reconnection.
  Future<void> replayCachedData() => _delegate.replayCachedData();
}
