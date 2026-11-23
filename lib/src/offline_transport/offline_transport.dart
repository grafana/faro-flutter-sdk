import 'package:faro/src/configurations/offline_storage_config.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/offline_transport/collector_outbox.dart';
import 'package:faro/src/offline_transport/internet_connectivity_service.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:faro/src/transport/faro_transport.dart';

/// Turns on offline storage for the primary collector.
///
/// Adding this to `Faro().transports` before initialization has the same
/// effect as `FaroConfig(offlineStorage: OfflineStorageConfig(enabled: true))`
/// with [maxCacheDuration] as the maximum age. It is not a transport anymore:
/// batches are saved and delivered by the primary collector itself.
@Deprecated(
  'Use FaroConfig(offlineStorage: OfflineStorageConfig(enabled: true)) '
  'instead. OfflineTransport will be removed in a future release.',
)
class OfflineTransport extends BaseTransport {
  /// Enables offline storage, keeping batches for [maxCacheDuration]
  /// (three days by default).
  OfflineTransport({
    Duration? maxCacheDuration,
    String? internetConnectionCheckerUrl,
    InternetConnectivityService? internetConnectivityService,
  }) : _maxCacheDuration = maxCacheDuration,
       _internetConnectionCheckerUrl = internetConnectionCheckerUrl,
       _internetConnectivityService = internetConnectivityService;

  final Duration? _maxCacheDuration;
  final String? _internetConnectionCheckerUrl;
  final InternetConnectivityService? _internetConnectivityService;

  /// Does nothing. The primary collector saves and delivers each batch.
  @override
  Future<void> send(Map<String, dynamic> payloadJson) async {}

  /// Attempts to deliver saved batches now. Faro already does this after
  /// initialization, on reconnection and when the app returns to foreground.
  Future<void> replayCachedData() async {
    final collector = Faro().transports.whereType<FaroTransport>().firstOrNull;
    if (collector == null) return;
    await collectorOutboxOf(collector)?.replayCachedData();
  }
}

/// The offline storage settings when [transport] is configured next to
/// [configured]. An explicitly enabled [configured] wins over the limits of
/// the deprecated transport; its connectivity settings still apply.
({
  OfflineStorageConfig config,
  String? internetConnectionCheckerUrl,
  InternetConnectivityService? internetConnectivityService,
})
legacyOfflineStorageSettings(
  // ignore: deprecated_member_use_from_same_package
  OfflineTransport transport,
  OfflineStorageConfig configured,
) {
  return (
    config: configured.enabled
        ? configured
        : OfflineStorageConfig(
            enabled: true,
            maxAge: transport._maxCacheDuration ?? const Duration(days: 3),
            maxCount: configured.maxCount,
            maxBytes: configured.maxBytes,
          ),
    internetConnectionCheckerUrl: transport._internetConnectionCheckerUrl,
    internetConnectivityService: transport._internetConnectivityService,
  );
}
