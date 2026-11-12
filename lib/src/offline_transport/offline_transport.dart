import 'package:faro/src/core/pod.dart';
import 'package:faro/src/offline_transport/internet_connectivity_service.dart';
import 'package:faro/src/offline_transport/mobile_offline_transport_delegate.dart';
import 'package:faro/src/offline_transport/offline_transport_delegate.dart';
import 'package:faro/src/offline_transport/outbox_store.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:faro/src/transport/faro_transport.dart';
import 'package:flutter/foundation.dart';

/// Opt-in persistent delivery for the first configured collector transport.
///
/// Add this to `Faro().transports` before initialization. Completed batches are
/// saved before HTTP delivery, including while connectivity appears online.
/// Successful or permanently rejected batches are removed; transient failures
/// are retried within count, byte and age limits. Delivery can be duplicated
/// if the app terminates after acceptance but before deleting the saved copy.
///
/// On web, which has no file system, this transport does nothing.
class OfflineTransport extends BaseTransport {
  /// Creates an outbox with finite retention and automatic retry scheduling.
  ///
  /// [maxCacheDuration] defaults to three days, including when null is passed.
  /// [internetConnectivityService] remains caller-owned when supplied.
  OfflineTransport({
    Duration? maxCacheDuration,
    int maxCacheCount = 1000,
    int maxCacheBytes = 10 * 1024 * 1024,
    String? internetConnectionCheckerUrl,
    InternetConnectivityService? internetConnectivityService,
    Duration initialRetryDelay = const Duration(seconds: 1),
    Duration maxRetryDelay = const Duration(minutes: 1),
    Duration requestTimeout = const Duration(seconds: 30),
  }) {
    final cacheDuration = maxCacheDuration ?? const Duration(days: 3);
    if (cacheDuration <= Duration.zero ||
        maxCacheCount <= 0 ||
        maxCacheBytes <= 0 ||
        initialRetryDelay.inMilliseconds <= 0 ||
        maxRetryDelay < initialRetryDelay ||
        requestTimeout <= Duration.zero) {
      throw ArgumentError(
        'Outbox limits and retry durations must be positive.',
      );
    }
    // Created in the body, since the initializer list can't use `this`.
    _delegate = pod
        .resolve(offlineTransportDelegateFactoryProvider)
        .create(
          onReplayRequested: replayCachedData,
          maxCacheDuration: cacheDuration,
          maxCacheCount: maxCacheCount,
          maxCacheBytes: maxCacheBytes,
          internetConnectionCheckerUrl: internetConnectionCheckerUrl,
          internetConnectivityService: internetConnectivityService,
          initialRetryDelay: initialRetryDelay,
          maxRetryDelay: maxRetryDelay,
          requestTimeout: requestTimeout,
        );
  }

  late final OfflineTransportDelegate _delegate;

  /// Binds the collector explicitly after Faro configures its destinations.
  /// Custom transports and additional collectors never receive this replay.
  set collector(FaroTransport? collector) {
    _delegate.collector = collector;
  }

  /// Persists a snapshot and completes after durable handoff, before delivery.
  /// Failed handoffs throw so crash recovery can retain its native copy.
  @override
  Future<void> send(Map<String, dynamic> payloadJson) =>
      _delegate.send(payloadJson);

  /// Drains eligible batches on startup, reconnect, foreground or retry timer.
  /// Concurrent triggers share one drain and never override a retry deadline.
  Future<void> replayCachedData() => _delegate.replayCachedData();

  /// Stops retries immediately and discards data when collection is disabled.
  Future<void> discardCachedData() => _delegate.discardCachedData();

  /// Cancels subscriptions and timers, leaving durable batches for next start.
  Future<void> dispose() => _delegate.dispose();

  /// Exposes storage for deterministic persistence tests without HTTP delivery.
  @visibleForTesting
  Future<OutboxStore> get storeForTesting {
    final delegate = _delegate;
    if (delegate is! MobileOfflineTransportDelegate) {
      throw StateError('The outbox has no storage on this platform.');
    }
    return delegate.storeForTesting;
  }
}
