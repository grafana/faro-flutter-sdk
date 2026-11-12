import 'package:dartypod/dartypod.dart';
import 'package:faro/src/device_info/platform_info_provider.dart';
import 'package:faro/src/offline_transport/internet_connectivity_service.dart';
import 'package:faro/src/offline_transport/mobile_offline_transport_delegate.dart';
import 'package:faro/src/offline_transport/no_op_offline_transport_delegate.dart';
import 'package:faro/src/transport/faro_transport.dart';

/// The platform-specific part of [OfflineTransport].
///
/// [OfflineTransport] is the public wrapper. It hands its work to the
/// delegate chosen by [OfflineTransportDelegateFactory].
abstract interface class OfflineTransportDelegate {
  /// The collector that receives replayed batches.
  set collector(FaroTransport? collector);

  /// Persists the payload for delivery.
  Future<void> send(Map<String, dynamic> payloadJson);

  /// Attempts to deliver persisted data.
  Future<void> replayCachedData();

  /// Discards persisted data and stops retries.
  Future<void> discardCachedData();

  /// Releases subscriptions and timers.
  Future<void> dispose();
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
  ///
  /// The delegate calls [onReplayRequested] whenever it wants a replay, so
  /// overrides of [OfflineTransport.replayCachedData] see every trigger.
  OfflineTransportDelegate create({
    required Future<void> Function() onReplayRequested,
    Duration maxCacheDuration = const Duration(days: 3),
    int maxCacheCount = 1000,
    int maxCacheBytes = 10 * 1024 * 1024,
    String? internetConnectionCheckerUrl,
    InternetConnectivityService? internetConnectivityService,
    Duration initialRetryDelay = const Duration(seconds: 1),
    Duration maxRetryDelay = const Duration(minutes: 1),
    Duration requestTimeout = const Duration(seconds: 30),
  }) {
    if (_platformInfoProvider.isWeb) {
      return NoOpOfflineTransportDelegate();
    }
    return MobileOfflineTransportDelegate(
      onReplayRequested: onReplayRequested,
      maxCacheDuration: maxCacheDuration,
      maxCacheCount: maxCacheCount,
      maxCacheBytes: maxCacheBytes,
      internetConnectionCheckerUrl: internetConnectionCheckerUrl,
      internetConnectivityService: internetConnectivityService,
      initialRetryDelay: initialRetryDelay,
      maxRetryDelay: maxRetryDelay,
      requestTimeout: requestTimeout,
    );
  }
}
