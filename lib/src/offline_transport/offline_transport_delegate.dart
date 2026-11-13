import 'package:dartypod/dartypod.dart';
import 'package:faro/src/offline_transport/internet_connectivity_service.dart';
import 'package:faro/src/offline_transport/mobile_offline_transport_delegate.dart';

/// The platform-specific part of [OfflineTransport].
///
/// [OfflineTransport] is the public wrapper. It hands its work to the
/// delegate chosen by [OfflineTransportDelegateFactory].
abstract interface class OfflineTransportDelegate {
  /// Caches the payload when the device is offline.
  Future<void> send(Map<String, dynamic> payloadJson);

  /// Attempts to deliver cached data when online.
  Future<void> replayCachedData();
}

/// Provides the [OfflineTransportDelegateFactory].
///
/// Tests can replace it with `pod.overrideProvider`.
final offlineTransportDelegateFactoryProvider =
    Provider<OfflineTransportDelegateFactory>(
      (_) => OfflineTransportDelegateFactory(),
    );

/// Creates the [OfflineTransportDelegate] matching the current platform.
class OfflineTransportDelegateFactory {
  /// Creates the delegate used by [OfflineTransport].
  OfflineTransportDelegate create({
    required Future<void> Function() onReconnected,
    Duration? maxCacheDuration,
    String? internetConnectionCheckerUrl,
    InternetConnectivityService? internetConnectivityService,
  }) {
    return MobileOfflineTransportDelegate(
      onReconnected: onReconnected,
      maxCacheDuration: maxCacheDuration,
      internetConnectionCheckerUrl: internetConnectionCheckerUrl,
      internetConnectivityService: internetConnectivityService,
    );
  }
}
