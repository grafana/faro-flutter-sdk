import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

Map<String, dynamic> _decodeMap(String contents) {
  final value = jsonDecode(contents);
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid outbox object.');
  }
  return value;
}

DateTime _timestamp(Object? value) {
  if (value is! int || value < -8640000000000000 || value > 8640000000000000) {
    throw const FormatException('Invalid outbox timestamp.');
  }
  return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
}

Map<String, dynamic> _payload(Map<String, dynamic> record) {
  final payload = record['payload'];
  if (payload is! Map<String, dynamic>) {
    throw const FormatException('Invalid outbox payload.');
  }
  return payload;
}

/// A saved batch. Payloads are read only when they are ready to be delivered.
class OutboxEntry {
  /// Describes a committed outbox file.
  const OutboxEntry(this.file, this.timestamp, this.bytes);

  /// The committed file, uniquely identifying this batch.
  final File file;

  /// When the batch first entered persistent storage.
  final DateTime timestamp;

  /// The encoded record size, including its envelope.
  final int bytes;

  /// Reads the original payload without rebuilding or changing its metadata.
  Future<Map<String, dynamic>> readPayload() async {
    return _payload(_decodeMap(await file.readAsString()));
  }
}

/// Bounded, serialized storage with one committed file per telemetry batch.
///
/// A temporary file is flushed before it is renamed into the ready queue.
/// Network operations must happen outside this store's operation lock.
class OutboxStore {
  /// Creates storage in [directory], importing [legacyFile] before delivery.
  OutboxStore({
    required this.directory,
    required this.maxCount,
    required this.maxBytes,
    required this.maxAge,
    this.legacyFile,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    if (maxCount <= 0 || maxBytes <= 0 || maxAge <= Duration.zero) {
      throw ArgumentError('Outbox limits must be positive.');
    }
  }

  /// The directory containing this outbox's files.
  final Directory directory;

  /// Maximum number of committed batches.
  final int maxCount;

  /// Maximum aggregate encoded size of committed batches.
  final int maxBytes;

  /// Maximum retention age, measured from initial persistence.
  final Duration maxAge;

  /// The previous newline-delimited offline cache, when upgrading.
  final File? legacyFile;
  final DateTime Function() _clock;
  final List<OutboxEntry> _entries = [];
  Future<void> _operations = Future<void>.value();
  bool _initialized = false;

  Future<T> _locked<T>(Future<T> Function() action) {
    final operation = _operations.then((_) => action());
    _operations = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  /// Saves an immutable, already encoded payload before acknowledging handoff.
  /// Returns null for an oversized batch or one already outside retention.
  Future<OutboxEntry?> enqueue(String payload) => _locked(() async {
    await _initialize();
    await _prune();
    return _append(payload, _clock(), const Uuid().v4());
  });

  /// Lists oldest batches first, enforcing retention even without connectivity.
  Future<List<OutboxEntry>> pending() => _locked(() async {
    await _initialize();
    await _prune();
    return List<OutboxEntry>.of(_entries);
  });

  /// Removes a terminal batch. A failed deletion leaves it eligible for replay.
  Future<void> remove(OutboxEntry entry) => _locked(() async {
    await _delete(entry.file);
    _entries.removeWhere((item) => item.file.uri == entry.file.uri);
  });

  /// Deletes retained telemetry, retry state and the legacy cache.
  Future<void> clear() => _locked(() async {
    await directory.create(recursive: true);
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File &&
          (entity.path.endsWith('.json') || entity.path.endsWith('.tmp'))) {
        await _delete(entity);
      }
    }
    final legacy = legacyFile;
    if (legacy != null) await _delete(legacy);
    _entries.clear();
    _initialized = true;
  });

  /// Loads the persisted collector-wide retry deadline and failure count.
  Future<({DateTime? retryAt, int failures})> readRetryState() =>
      _locked(() async {
        await _initialize();
        try {
          final state = _decodeMap(await _retryFile.readAsString());
          final failures = state['failures'];
          if (failures is! int) {
            throw const FormatException('Invalid retry count.');
          }
          return (retryAt: _timestamp(state['retryAt']), failures: failures);
        } on PathNotFoundException {
          return (retryAt: null, failures: 0);
        } on FormatException {
          return (retryAt: null, failures: 0);
        }
      });

  /// Persists throttling so reconnects and restarts respect server hints.
  Future<void> writeRetryState(DateTime? retryAt, int failures) =>
      _locked(() async {
        await _initialize();
        if (retryAt == null) {
          await _delete(_retryFile);
        } else {
          await _atomicWrite(
            _retryFile,
            jsonEncode({
              'retryAt': retryAt.millisecondsSinceEpoch,
              'failures': failures,
            }),
          );
        }
      });

  File get _retryFile => File('${directory.path}/retry.json');

  Future<void> _initialize() async {
    if (_initialized) return;
    await directory.create(recursive: true);
    _entries.clear();
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith('.tmp')) {
        await _delete(entity);
        continue;
      }
      if (entity is! File || !entity.path.endsWith('.batch.json')) continue;
      try {
        final size = await entity.length();
        if (size > maxBytes) {
          await _delete(entity);
          continue;
        }
        final record = _decodeMap(await entity.readAsString());
        if (record['version'] != 1 ||
            record['payload'] is! Map<String, dynamic>) {
          throw const FormatException('Invalid outbox record.');
        }
        _entries.add(
          OutboxEntry(entity, _timestamp(record['timestamp']), size),
        );
      } on FormatException {
        await _delete(entity);
      }
    }
    _sort();
    await _prune();
    await _importLegacy();
    _initialized = true;
  }

  Future<OutboxEntry?> _append(
    String payload,
    DateTime timestamp,
    String id,
  ) async {
    if (_clock().difference(timestamp) > maxAge) return null;
    final contents =
        '{"version":1,"timestamp":'
        '${timestamp.millisecondsSinceEpoch},"payload":$payload}';
    final bytes = utf8.encode(contents).length;
    if (bytes > maxBytes) return null;
    final filename =
        '${timestamp.millisecondsSinceEpoch.toString().padLeft(16, '0')}'
        '-$id.batch.json';
    final file = File('${directory.path}/$filename');
    if (_entries.any((entry) => entry.file.uri == file.uri)) return null;
    // Evict before committing so the committed queue stays within its limits.
    while (_entries.isNotEmpty &&
        (_entries.length >= maxCount || _totalBytes + bytes > maxBytes)) {
      await _delete(_entries.first.file);
      _entries.removeAt(0);
    }
    await _atomicWrite(file, contents);
    final entry = OutboxEntry(file, timestamp, bytes);
    _entries.add(entry);
    _sort();
    return entry;
  }

  Future<void> _importLegacy() async {
    final legacy = legacyFile;
    if (legacy == null) return;
    // ignore: avoid_slow_async_io
    if (!await legacy.exists()) return;
    var index = 0;
    await for (final line
        in legacy
            .openRead()
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter())) {
      final id = 'legacy-${index++}';
      if (line.trim().isEmpty) continue;
      try {
        final record = _decodeMap(line);
        final timestamp = _timestamp(record['timestamp']);
        final payload = _payload(record);
        // Deterministic names make an interrupted import safe to repeat.
        await _append(jsonEncode(payload), timestamp, id);
      } on FormatException {
        // A malformed legacy entry must not block valid entries.
      }
    }
    // No delivery starts until migration completes and the old file is removed.
    await _delete(legacy);
  }

  int get _totalBytes => _entries.fold(0, (sum, entry) => sum + entry.bytes);

  void _sort() {
    _entries.sort((left, right) {
      final order = left.timestamp.compareTo(right.timestamp);
      return order == 0 ? left.file.path.compareTo(right.file.path) : order;
    });
  }

  Future<void> _prune() async {
    final now = _clock();
    while (_entries.isNotEmpty &&
        (now.difference(_entries.first.timestamp) > maxAge ||
            _entries.length > maxCount ||
            _totalBytes > maxBytes)) {
      await _delete(_entries.first.file);
      _entries.removeAt(0);
    }
  }

  Future<void> _atomicWrite(File file, String contents) async {
    final temporary = File('${file.path}.tmp');
    try {
      await temporary.writeAsString(contents, flush: true);
      await temporary.rename(file.path);
    } finally {
      await _delete(temporary);
    }
  }

  Future<void> _delete(File file) async {
    try {
      await file.delete();
    } on PathNotFoundException {
      // An entry already removed by cleanup needs no further work.
    }
  }
}
