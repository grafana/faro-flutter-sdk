import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:faro/src/faro.dart';
import 'package:faro/src/offline_transport/internet_connectivity_service.dart';
import 'package:faro/src/offline_transport/outbox_retry_policy.dart';
import 'package:faro/src/offline_transport/outbox_store.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:faro/src/transport/faro_transport.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Opt-in persistent delivery for the first configured collector transport.
///
/// Add this to `Faro().transports` before initialization. Completed batches are
/// saved before HTTP delivery, including while connectivity appears online.
/// Successful or permanently rejected batches are removed; transient failures
/// are retried within count, byte and age limits. Delivery can be duplicated
/// if the app terminates after acceptance but before deleting the saved copy.
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
  }) : _maxCacheDuration = maxCacheDuration ?? const Duration(days: 3),
       _maxCacheCount = maxCacheCount,
       _maxCacheBytes = maxCacheBytes,
       _initialRetryDelay = initialRetryDelay,
       _maxRetryDelay = maxRetryDelay,
       _requestTimeout = requestTimeout,
       _ownsConnectivityService = internetConnectivityService == null {
    if (_maxCacheDuration <= Duration.zero ||
        maxCacheCount <= 0 ||
        maxCacheBytes <= 0 ||
        initialRetryDelay.inMilliseconds <= 0 ||
        maxRetryDelay < initialRetryDelay ||
        requestTimeout <= Duration.zero) {
      throw ArgumentError(
        'Outbox limits and retry durations must be positive.',
      );
    }
    _connectivityService =
        internetConnectivityService ??
        InternetConnectivityServiceFactory().create(
          internetConnectionCheckerUrl: internetConnectionCheckerUrl,
        );
    _connectivitySubscription = _connectivityService.onConnectivityChanged
        .listen((online) {
          // Faro binds only the primary outbox. An extra instance must not
          // open the shared cache and apply its own retention limits.
          if (online && _collector != null) unawaited(replayCachedData());
        });
  }

  final Duration _maxCacheDuration;
  final int _maxCacheCount;
  final int _maxCacheBytes;
  final Duration _initialRetryDelay;
  final Duration _maxRetryDelay;
  final Duration _requestTimeout;
  late final InternetConnectivityService _connectivityService;
  final bool _ownsConnectivityService;
  StreamSubscription<bool>? _connectivitySubscription;
  Future<OutboxStore>? _store;
  Future<void>? _drain;
  bool _drainRequested = false;
  Future<void>? _purge;
  bool _discardPending = false;
  Timer? _retryTimer;
  DateTime? _retryAt;
  int _failures = 0;
  bool _loadedRetryState = false;
  bool _disposed = false;
  int _generation = 0;
  final Map<String, String?> _freshSessions = {};
  FaroTransport? _collector;

  /// Binds the collector explicitly after Faro configures its destinations.
  /// Custom transports and additional collectors never receive this replay.
  set collector(FaroTransport? collector) {
    _collector = collector;
  }

  Future<OutboxStore> _getStore() {
    return _store ??=
        () async {
          final documents = await getApplicationDocumentsDirectory();
          return OutboxStore(
            directory: Directory('${documents.path}/faro-outbox'),
            legacyFile: File('${documents.path}/rum_log.json'),
            maxCount: _maxCacheCount,
            maxBytes: _maxCacheBytes,
            maxAge: _maxCacheDuration,
          );
        }().catchError((Object error, StackTrace stackTrace) {
          _store = null;
          Error.throwWithStackTrace(error, stackTrace);
        });
  }

  /// Persists a snapshot and completes after durable handoff, before delivery.
  /// Failed handoffs throw so crash recovery can retain its native copy.
  @override
  Future<void> send(Map<String, dynamic> payloadJson) async {
    if (_disposed || !Faro().enableDataCollection) return;
    final generation = _generation;
    // Snapshot synchronously, before the caller can mutate or reuse a batch.
    final encoded = jsonEncode(payloadJson);
    final session = _payloadSession(payloadJson);
    await _purge;
    final store = await _getStore();
    if (_discardPending) await _finishPurge(store);
    if (_disposed ||
        !Faro().enableDataCollection ||
        generation != _generation) {
      return;
    }
    final entry = await store.enqueue(encoded);
    if (entry == null) {
      throw StateError('Payload exceeds outbox retention limits.');
    }
    if (!Faro().enableDataCollection || generation != _generation) {
      await store.remove(entry);
      return;
    }
    while (_freshSessions.length >= _maxCacheCount) {
      _freshSessions.remove(_freshSessions.keys.first);
    }
    _freshSessions[entry.file.path] = session;
    unawaited(replayCachedData());
  }

  /// Drains eligible batches on startup, reconnect, foreground or retry timer.
  /// Concurrent triggers share one drain and never override a retry deadline.
  Future<void> replayCachedData() {
    if (_disposed) return Future<void>.value();
    _drainRequested = true;
    return _drain ??=
        () async {
          do {
            _drainRequested = false;
            await _drainSafely();
          } while (_drainRequested && !_disposed);
        }().whenComplete(() {
          _drain = null;
          if (_drainRequested && !_disposed) unawaited(replayCachedData());
        });
  }

  Future<void> _drainSafely() async {
    final generation = _generation;
    try {
      await _purge;
      final store = await _getStore();
      if (_disposed || generation != _generation) return;
      if (!Faro().enableDataCollection) {
        await discardCachedData();
        return;
      }
      if (_discardPending) await _finishPurge(store);
      if (!_loadedRetryState) {
        final state = await store.readRetryState();
        if (_disposed || generation != _generation) return;
        _retryAt = state.retryAt;
        _failures = state.failures.clamp(0, 30);
        _loadedRetryState = true;
      }
      while (!_disposed &&
          Faro().enableDataCollection &&
          generation == _generation) {
        final entries = await store.pending();
        final paths = entries.map((entry) => entry.file.path).toSet();
        _freshSessions.removeWhere((path, _) => !paths.contains(path));
        if (entries.isEmpty) {
          _retryTimer?.cancel();
          return;
        }
        final retryAt = _retryAt;
        if (retryAt != null && retryAt.isAfter(DateTime.now())) {
          _schedule(retryAt.difference(DateTime.now()));
          return;
        }
        final collector = _collector;
        if (collector == null) {
          _schedule(_maxRetryDelay);
          return;
        }
        final entry = entries.first;
        final Map<String, dynamic> payload;
        try {
          payload = await entry.readPayload();
        } on FormatException {
          await store.remove(entry);
          continue;
        } on PathNotFoundException {
          await store.remove(entry);
          continue;
        }
        final fresh = _freshSessions.containsKey(entry.file.path);
        final session = _freshSessions.remove(entry.file.path);
        final historical =
            !fresh || session == null || session != Faro().meta.session?.id;
        if (_disposed ||
            !Faro().enableDataCollection ||
            generation != _generation) {
          return;
        }
        final result = await collector.sendWithResult(
          payload,
          historical: historical,
          timeout: _requestTimeout,
        );
        if (_disposed || generation != _generation) return;
        if (!Faro().enableDataCollection) {
          await discardCachedData();
          return;
        }
        if (result.isTerminal) {
          await store.remove(entry);
          if (result.accepted) {
            _failures = 0;
            _retryAt = null;
            await store.writeRetryState(null, 0);
          }
          continue;
        }
        _failures = (_failures + 1).clamp(0, 30);
        final next =
            OutboxRetryPolicy(
              initialDelay: _initialRetryDelay,
              maxDelay: _maxRetryDelay,
            ).nextAttempt(
              now: DateTime.now(),
              failures: _failures,
              serverRetryAt: result.retryAt,
            );
        _retryAt = next;
        await store.writeRetryState(next, _failures);
        _schedule(next.difference(DateTime.now()));
        return;
      }
    } catch (error) {
      log('Faro: Outbox operation failed (${error.runtimeType}).');
      if (!_disposed && Faro().enableDataCollection) {
        _schedule(_maxRetryDelay);
      }
    }
  }

  void _schedule(Duration delay) {
    if (_disposed) return;
    _retryTimer?.cancel();
    // Wake periodically to enforce retention during long server retry delays.
    final bounded = delay > _maxRetryDelay ? _maxRetryDelay : delay;
    _retryTimer = Timer(bounded < Duration.zero ? Duration.zero : bounded, () {
      unawaited(replayCachedData());
    });
  }

  /// Stops retries immediately and discards data when collection is disabled.
  Future<void> discardCachedData() {
    _generation++;
    _discardPending = true;
    _retryTimer?.cancel();
    _freshSessions.clear();
    _retryAt = null;
    _failures = 0;
    _loadedRetryState = false;
    final operation = _getStore().then(_finishPurge);
    return _purge = operation.catchError((Object error) {
      log('Faro: Outbox cleanup failed (${error.runtimeType}).');
    });
  }

  Future<void> _finishPurge(OutboxStore store) async {
    final generation = _generation;
    await store.clear();
    if (generation == _generation) _discardPending = false;
  }

  /// Cancels subscriptions and timers, leaving durable batches for next start.
  Future<void> dispose() async {
    _disposed = true;
    _retryTimer?.cancel();
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    if (_ownsConnectivityService) _connectivityService.dispose();
    await _drain;
    await _purge;
  }

  /// Exposes storage for deterministic persistence tests without HTTP delivery.
  @visibleForTesting
  Future<OutboxStore> get storeForTesting => _getStore();

  static String? _payloadSession(Map<String, dynamic> payload) {
    final meta = payload['meta'];
    if (meta is! Map<String, dynamic>) return null;
    final session = meta['session'];
    if (session is! Map<String, dynamic>) return null;
    final id = session['id'];
    return id is String ? id : null;
  }
}
