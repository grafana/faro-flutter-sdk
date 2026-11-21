import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dartypod/dartypod.dart';
import 'package:faro/src/configurations/offline_storage_config.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/offline_transport/internet_connectivity_service.dart';
import 'package:faro/src/offline_transport/outbox_retry_policy.dart';
import 'package:faro/src/offline_transport/outbox_store.dart';
import 'package:faro/src/transport/faro_transport.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// The outcome of handing a batch to [CollectorOutbox.send].
enum OutboxHandoff {
  /// The batch is on disk and will be delivered by the outbox.
  saved,

  /// The batch was dropped on purpose, for example because data collection
  /// is disabled. It must not be sent another way.
  discarded,

  /// The batch could not be saved and nothing is on disk, for example after a
  /// storage error or for a batch larger than the byte limit.
  notSaved,
}

final Expando<CollectorOutbox> _attachedOutboxes = Expando<CollectorOutbox>(
  'faro collector outbox',
);

/// Returns the outbox that saves batches for [collector], if any.
///
/// Kept out of the public `FaroTransport` API on purpose: apps never bind an
/// outbox, Faro creates one for the primary collector during init.
CollectorOutbox? collectorOutboxOf(FaroTransport collector) =>
    _attachedOutboxes[collector];

/// Provides the [CollectorOutboxFactory].
///
/// Tests can replace it with `pod.overrideProvider`.
final collectorOutboxFactoryProvider = Provider<CollectorOutboxFactory>(
  (_) => CollectorOutboxFactory(),
);

/// Creates the [CollectorOutbox] for the primary collector.
class CollectorOutboxFactory {
  /// Creates an outbox. See [CollectorOutbox.new].
  CollectorOutbox create({
    required FaroTransport collector,
    required OfflineStorageConfig config,
    required bool acceptsNewBatches,
    InternetConnectivityService? internetConnectivityService,
    String? internetConnectionCheckerUrl,
  }) {
    return CollectorOutbox(
      collector: collector,
      config: config,
      acceptsNewBatches: acceptsNewBatches,
      internetConnectivityService: internetConnectivityService,
      internetConnectionCheckerUrl: internetConnectionCheckerUrl,
    );
  }
}

/// The persistent outbox in front of the primary collector, used on Android
/// and iOS when `FaroConfig.offlineStorage` is enabled.
///
/// Each batch is saved before delivery. Accepted or permanently rejected
/// batches are removed; temporary failures are retried within the configured
/// count, byte and age limits.
///
/// With [acceptsNewBatches] off, the outbox only drains batches left on disk
/// by an earlier launch that had offline storage enabled. It does not attach
/// to the collector, listen to connectivity or create any files.
class CollectorOutbox {
  /// Creates an outbox for [collector].
  ///
  /// [internetConnectivityService] remains caller-owned when supplied.
  CollectorOutbox({
    required FaroTransport collector,
    required OfflineStorageConfig config,
    bool acceptsNewBatches = true,
    InternetConnectivityService? internetConnectivityService,
    String? internetConnectionCheckerUrl,
    Duration initialRetryDelay = const Duration(seconds: 1),
    Duration maxRetryDelay = const Duration(minutes: 1),
    Duration requestTimeout = const Duration(seconds: 30),
  }) : _collector = collector,
       _maxAge = config.maxAge,
       _maxCount = config.maxCount,
       _maxBytes = config.maxBytes,
       _acceptsNewBatches = acceptsNewBatches,
       _initialRetryDelay = initialRetryDelay,
       _maxRetryDelay = maxRetryDelay,
       _requestTimeout = requestTimeout,
       _ownsConnectivityService =
           acceptsNewBatches && internetConnectivityService == null {
    if (config.maxAge <= Duration.zero ||
        config.maxCount <= 0 ||
        config.maxBytes <= 0 ||
        initialRetryDelay.inMilliseconds <= 0 ||
        maxRetryDelay < initialRetryDelay ||
        requestTimeout <= Duration.zero) {
      throw ArgumentError(
        'Offline storage limits and retry durations must be positive.',
      );
    }
    if (!acceptsNewBatches) return;
    _attachedOutboxes[collector] = this;
    final connectivity = _connectivityService =
        internetConnectivityService ??
        InternetConnectivityServiceFactory().create(
          internetConnectionCheckerUrl: internetConnectionCheckerUrl,
        );
    // Connectivity is only a hint that a retry may now succeed.
    _connectivitySubscription = connectivity.onConnectivityChanged.listen((
      online,
    ) {
      if (online) unawaited(replayCachedData());
    });
  }

  final FaroTransport _collector;
  final Duration _maxAge;
  final int _maxCount;
  final int _maxBytes;
  final bool _acceptsNewBatches;
  final Duration _initialRetryDelay;
  final Duration _maxRetryDelay;
  final Duration _requestTimeout;
  InternetConnectivityService? _connectivityService;
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

  /// Whether the collector asked to wait, or recent failures put delivery in
  /// backoff. A batch that could not be saved is not sent directly meanwhile.
  bool get isThrottled {
    final retryAt = _retryAt;
    return retryAt != null && retryAt.isAfter(DateTime.now());
  }

  /// Whether [payload] belongs to a session other than the live one, so its
  /// delivery must not invalidate the live session.
  static bool isHistorical(Map<String, dynamic> payload) {
    final session = _payloadSession(payload);
    return session == null || session != Faro().meta.session?.id;
  }

  Future<({Directory directory, File legacy})> _locations() async {
    // Every batch is saved before delivery and can hold user, session and
    // stack trace data. Application Support is never shown to the user,
    // unlike Documents with iOS file sharing enabled.
    final support = await getApplicationSupportDirectory();
    // Earlier releases cached offline batches in Documents.
    final documents = await getApplicationDocumentsDirectory();
    return (
      directory: Directory('${support.path}/faro-outbox'),
      legacy: File('${documents.path}/rum_log.json'),
    );
  }

  Future<OutboxStore> _getStore() {
    return _store ??=
        () async {
          final locations = await _locations();
          return OutboxStore(
            directory: locations.directory,
            legacyFile: locations.legacy,
            maxCount: _maxCount,
            maxBytes: _maxBytes,
            maxAge: _maxAge,
          );
        }().catchError((Object error, StackTrace stackTrace) {
          _store = null;
          Error.throwWithStackTrace(error, stackTrace);
        });
  }

  /// Whether a drain-only outbox has anything left from an earlier launch.
  /// Checked before creating the store, which would create its directory.
  Future<bool> _hasSavedData() async {
    if (_store != null) return true;
    final locations = await _locations();
    // ignore: avoid_slow_async_io
    return await locations.directory.exists() ||
        // ignore: avoid_slow_async_io
        await locations.legacy.exists();
  }

  /// Saves a snapshot of [payloadJson] and starts delivery in the background.
  ///
  /// Never throws. [OutboxHandoff.notSaved] means nothing is on disk, so the
  /// caller may send the batch directly without creating a duplicate.
  Future<OutboxHandoff> send(Map<String, dynamic> payloadJson) async {
    if (_disposed || !_acceptsNewBatches) return OutboxHandoff.notSaved;
    if (!Faro().enableDataCollection) return OutboxHandoff.discarded;
    final generation = _generation;
    try {
      // Snapshot synchronously, before the caller can mutate or reuse a batch.
      final encoded = jsonEncode(payloadJson);
      final session = _payloadSession(payloadJson);
      await _purge;
      final store = await _getStore();
      if (_discardPending) await _finishPurge(store);
      if (_disposed) return OutboxHandoff.notSaved;
      if (!Faro().enableDataCollection || generation != _generation) {
        return OutboxHandoff.discarded;
      }
      // Throws only when nothing was committed.
      final entry = await store.enqueue(encoded);
      if (entry == null) {
        log('Faro: Batch exceeds offline storage limits; not saved.');
        return OutboxHandoff.notSaved;
      }
      if (!Faro().enableDataCollection || generation != _generation) {
        try {
          await store.remove(entry);
        } on FileSystemException {
          // The pending purge or the next drain removes it.
          log('Faro: Outbox could not remove an opted-out batch.');
        }
        return OutboxHandoff.discarded;
      }
      while (_freshSessions.length >= _maxCount) {
        _freshSessions.remove(_freshSessions.keys.first);
      }
      _freshSessions[entry.file.path] = session;
      unawaited(replayCachedData());
      return OutboxHandoff.saved;
    } catch (error) {
      log('Faro: Batch could not be saved (${error.runtimeType}).');
      return OutboxHandoff.notSaved;
    }
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
    final unreadable = <String>{};
    try {
      await _purge;
      if (!_acceptsNewBatches) {
        // Runs on every launch with offline storage off, so it must stay
        // cheap: a failed lookup is not retried until the next launch.
        final bool hasSavedData;
        try {
          hasSavedData = await _hasSavedData();
        } catch (error) {
          log('Faro: Outbox lookup failed (${error.runtimeType}).');
          return;
        }
        if (!hasSavedData) return;
      }
      final store = await _getStore();
      if (_disposed || generation != _generation) return;
      if (!Faro().enableDataCollection) {
        await discardCachedData();
        return;
      }
      if (_discardPending) await _finishPurge(store);
      await store.retryUnreadableFiles();
      if (!_loadedRetryState) {
        final state = await store.readRetryState();
        if (_disposed || generation != _generation) return;
        _failures = state.failures.clamp(0, 30);
        final saved = state.retryAt;
        final retryAt = saved == null
            ? null
            : OutboxRetryPolicy.clampServerDeadline(saved, now: DateTime.now());
        _retryAt = retryAt;
        if (retryAt != saved) {
          // Save the bound so the next restart does not start a new wait.
          await store.writeRetryState(retryAt, _failures);
          if (_disposed || generation != _generation) return;
        }
        _loadedRetryState = true;
      }
      while (!_disposed &&
          Faro().enableDataCollection &&
          generation == _generation) {
        final entries = await store.pending();
        final paths = entries.map((entry) => entry.file.path).toSet();
        _freshSessions.removeWhere((path, _) => !paths.contains(path));
        if (entries.isEmpty) {
          if (store.hasUnreadableFiles) {
            _schedule(_maxRetryDelay);
          } else {
            _retryTimer?.cancel();
            if (!_acceptsNewBatches) await _removeDrainedStore(store);
          }
          return;
        }
        final retryAt = _retryAt;
        if (retryAt != null && retryAt.isAfter(DateTime.now())) {
          _schedule(retryAt.difference(DateTime.now()));
          return;
        }
        final entry = entries
            .where((entry) => !unreadable.contains(entry.file.path))
            .firstOrNull;
        if (entry == null) {
          _schedule(_maxRetryDelay);
          return;
        }
        final Map<String, dynamic> payload;
        try {
          payload = await entry.readPayload();
        } on FormatException {
          await store.remove(entry);
          continue;
        } on PathNotFoundException {
          await store.remove(entry);
          continue;
        } on FileSystemException {
          // Retry this file on a later pass while delivering readable batches.
          unreadable.add(entry.file.path);
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
        final result = await _collector.sendWithResult(
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

  /// A drain-only outbox removes its empty directory, so later launches with
  /// offline storage off skip the outbox entirely.
  Future<void> _removeDrainedStore(OutboxStore store) async {
    try {
      await store.directory.delete(recursive: true);
    } on FileSystemException {
      // Checked again on the next launch.
    }
    _store = null;
    _loadedRetryState = false;
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

  /// Stops retries immediately and discards saved data, including the legacy
  /// cache. Sends and drains wait for the removal to finish.
  Future<void> discardCachedData() {
    _generation++;
    _discardPending = true;
    _retryTimer?.cancel();
    _freshSessions.clear();
    _retryAt = null;
    _failures = 0;
    _loadedRetryState = false;
    final operation = () async {
      if (!_acceptsNewBatches && !await _hasSavedData()) {
        _discardPending = false;
        return;
      }
      await _finishPurge(await _getStore());
    }();
    return _purge = operation.catchError((Object error) {
      log('Faro: Outbox cleanup failed (${error.runtimeType}).');
    });
  }

  Future<void> _finishPurge(OutboxStore store) async {
    final generation = _generation;
    await store.clear();
    if (generation == _generation) _discardPending = false;
  }

  /// Cancels subscriptions and timers, leaving saved batches for next start.
  Future<void> dispose() async {
    _disposed = true;
    _retryTimer?.cancel();
    if (identical(_attachedOutboxes[_collector], this)) {
      _attachedOutboxes[_collector] = null;
    }
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    if (_ownsConnectivityService) _connectivityService?.dispose();
    // A drain-only outbox never writes new batches and stops once disposed,
    // so there is nothing to wait for. Its startup lookup can also outlive
    // the caller, for example in widget tests with fake time.
    if (!_acceptsNewBatches) return;
    await _drain;
    await _purge;
  }

  /// Exposes storage for deterministic persistence tests.
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
