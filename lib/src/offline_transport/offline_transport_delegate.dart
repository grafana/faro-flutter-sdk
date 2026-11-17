import 'package:dartypod/dartypod.dart';
import 'package:faro/src/device_info/platform_info_provider.dart';
import 'package:faro/src/offline_transport/internet_connectivity_service.dart';
import 'package:faro/src/offline_transport/mobile_offline_transport_delegate.dart';
import 'package:faro/src/offline_transport/no_op_offline_transport_delegate.dart';

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
      (_) => OfflineTransportDelegateFactory(
        platformInfoProvider: PlatformInfoProviderFactory().create(),
      ),
    );

/// Creates the [OfflineTransportDelegate] matching the current platform.
class OfflineTransportDelegateFactory {
  /// Creates a factory that decides based on [platformInfoProvider].
  OfflineTransportDelegateFactory({
    required PlatformInfoProvider platformInfoProvider,
  }) : _platformInfoProvider = platformInfoProvider;

  final PlatformInfoProvider _platformInfoProvider;

  /// Creates the delegate used by [OfflineTransport].
  OfflineTransportDelegate create({
    required Future<void> Function() onReconnected,
    Duration? maxCacheDuration,
    String? internetConnectionCheckerUrl,
    InternetConnectivityService? internetConnectivityService,
  }) {
    if (_platformInfoProvider.isWeb) {
      return NoOpOfflineTransportDelegate();
    }
    return MobileOfflineTransportDelegate(
      onReconnected: onReconnected,
      maxCacheDuration: maxCacheDuration,
      internetConnectionCheckerUrl: internetConnectionCheckerUrl,
      internetConnectivityService: internetConnectivityService,
    );
  }
}
