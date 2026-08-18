// Async file access keeps session persistence off the UI thread.
// ignore_for_file: avoid_slow_async_io

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:faro/src/session/session_manager.dart';
import 'package:path_provider/path_provider.dart';

/// The minimal session state retained between process starts.
class PersistedSessionRecord {
  const PersistedSessionRecord({
    required this.currentSessionId,
    required this.previousSessionId,
    required this.startedAt,
    required this.lastActivityAt,
    required this.isSampled,
  });

  factory PersistedSessionRecord.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported session schema version');
    }

    final currentSessionId = json['currentSessionId'];
    final previousSessionId = json['previousSessionId'];
    final startedAtValue = json['startedAt'];
    final lastActivityAtValue = json['lastActivityAt'];
    final isSampled = json['isSampled'];

    if (currentSessionId is! String || currentSessionId.isEmpty) {
      throw const FormatException('Invalid current session id');
    }
    if (previousSessionId != null &&
        (previousSessionId is! String || previousSessionId.isEmpty)) {
      throw const FormatException('Invalid previous session id');
    }
    if (previousSessionId == currentSessionId) {
      throw const FormatException('Session cannot link to itself');
    }
    if (startedAtValue is! String || lastActivityAtValue is! String) {
      throw const FormatException('Invalid session timestamps');
    }
    if (isSampled is! bool) {
      throw const FormatException('Invalid session sampling decision');
    }

    final startedAt = DateTime.tryParse(startedAtValue)?.toUtc();
    final lastActivityAt = DateTime.tryParse(lastActivityAtValue)?.toUtc();
    if (startedAt == null ||
        lastActivityAt == null ||
        lastActivityAt.isBefore(startedAt)) {
      throw const FormatException('Invalid session timestamp range');
    }

    return PersistedSessionRecord(
      currentSessionId: currentSessionId,
      previousSessionId: previousSessionId as String?,
      startedAt: startedAt,
      lastActivityAt: lastActivityAt,
      isSampled: isSampled,
    );
  }

  static const int schemaVersion = 1;

  final String currentSessionId;
  final String? previousSessionId;
  final DateTime startedAt;
  final DateTime lastActivityAt;
  final bool isSampled;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'currentSessionId': currentSessionId,
    'previousSessionId': previousSessionId,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'lastActivityAt': lastActivityAt.toUtc().toIso8601String(),
    'isSampled': isSampled,
  };
}

/// File operations used by [SessionPersistence].
class SessionFileStore {
  SessionFileStore({required File file}) : _file = file;

  final File _file;

  Future<String?> read() async {
    if (!await _file.exists()) {
      return null;
    }
    return _file.readAsString();
  }

  Future<void> write(String contents) async {
    await _file.parent.create(recursive: true);
    final temporaryFile = File('${_file.path}.tmp');
    try {
      await temporaryFile.writeAsString(contents, flush: true);
      await temporaryFile.rename(_file.path);
    } catch (_) {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      rethrow;
    }
  }

  Future<void> delete() async {
    final temporaryFile = File('${_file.path}.tmp');
    if (await temporaryFile.exists()) {
      await temporaryFile.delete();
    }
    if (await _file.exists()) {
      await _file.delete();
    }
  }
}

/// Persists session state without blocking telemetry ingestion.
///
/// Session starts are queued immediately. Activity-only changes are coalesced
/// to avoid a disk write for every telemetry item. [flush] persists the latest
/// state before the app is suspended or the SDK is reset.
class SessionPersistence {
  SessionPersistence({
    required SessionFileStore store,
    this.activityWriteDelay = const Duration(seconds: 30),
  }) : _store = store;

  final SessionFileStore _store;
  final Duration activityWriteDelay;

  // Android returns at most 15 historical exits. Keep those sessions plus the
  // session that becomes current after recovery.
  static const int _maxHistoryLength = 16;
  static const int _historySchemaVersion = 2;

  Timer? _activityWriteTimer;
  List<PersistedSessionRecord> _history = <PersistedSessionRecord>[];
  List<PersistedSessionRecord>? _pendingHistory;
  List<PersistedSessionRecord>? _enqueuedHistory;
  Future<void> _writeQueue = Future<void>.value();

  Future<PersistedSessionRecord?> load() async {
    final history = await loadHistory();
    return history.isEmpty ? null : history.last;
  }

  Future<List<PersistedSessionRecord>> loadHistory() async {
    try {
      final persistedValue = await _store.read();
      if (persistedValue == null) {
        _history = <PersistedSessionRecord>[];
        return const <PersistedSessionRecord>[];
      }
      final decoded = jsonDecode(persistedValue);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Session record must be an object');
      }
      final history = _decodeHistory(decoded);
      _history = List<PersistedSessionRecord>.of(history);
      return List<PersistedSessionRecord>.unmodifiable(history);
    } catch (error) {
      log('Faro: Ignoring invalid persisted session state: $error');
      await _deleteSafely();
      _history = <PersistedSessionRecord>[];
      return const <PersistedSessionRecord>[];
    }
  }

  void record(
    SessionState state, {
    required bool isSampled,
    required bool immediate,
  }) {
    final lastActivityAt = state.lastActivityAt.isBefore(state.startedAt)
        ? state.startedAt
        : state.lastActivityAt;
    final record = PersistedSessionRecord(
      currentSessionId: state.currentSessionId,
      previousSessionId: state.previousSessionId,
      startedAt: state.startedAt,
      lastActivityAt: lastActivityAt,
      isSampled: isSampled,
    );
    final existingIndex = _history.indexWhere(
      (item) => item.currentSessionId == record.currentSessionId,
    );
    if (existingIndex != -1) {
      _history.removeAt(existingIndex);
    }
    _history.add(record);
    if (_history.length > _maxHistoryLength) {
      _history.removeRange(0, _history.length - _maxHistoryLength);
    }
    _pendingHistory = List<PersistedSessionRecord>.unmodifiable(_history);

    if (immediate) {
      _activityWriteTimer?.cancel();
      _activityWriteTimer = null;
      _enqueuePendingWrite();
      return;
    }

    _activityWriteTimer ??= Timer(activityWriteDelay, () {
      _activityWriteTimer = null;
      _enqueuePendingWrite();
    });
  }

  Future<void> clear() async {
    _activityWriteTimer?.cancel();
    _activityWriteTimer = null;
    _history = <PersistedSessionRecord>[];
    _pendingHistory = null;
    _writeQueue = _writeQueue.then((_) => _deleteSafely());
    await _writeQueue;
  }

  Future<void> flush() async {
    _activityWriteTimer?.cancel();
    _activityWriteTimer = null;
    _enqueuePendingWrite();
    await _writeQueue;
  }

  void _enqueuePendingWrite() {
    final history = _pendingHistory;
    if (history == null || identical(history, _enqueuedHistory)) {
      return;
    }
    _enqueuedHistory = history;
    _writeQueue = _writeQueue.then((_) async {
      final writeSucceeded = await _writeSafely(history);
      if (identical(_enqueuedHistory, history)) {
        _enqueuedHistory = null;
      }
      if (writeSucceeded && identical(_pendingHistory, history)) {
        _pendingHistory = null;
      }
    });
  }

  Future<bool> _writeSafely(List<PersistedSessionRecord> history) async {
    try {
      await _store.write(
        jsonEncode(<String, dynamic>{
          'schemaVersion': _historySchemaVersion,
          'records': history.map((record) => record.toJson()).toList(),
        }),
      );
      return true;
    } catch (error) {
      log('Faro: Failed to persist session state: $error');
      return false;
    }
  }

  Future<void> _deleteSafely() async {
    try {
      await _store.delete();
    } catch (error) {
      log('Faro: Failed to clear persisted session state: $error');
    }
  }

  List<PersistedSessionRecord> _decodeHistory(Map<String, dynamic> json) {
    if (json['schemaVersion'] == PersistedSessionRecord.schemaVersion) {
      return <PersistedSessionRecord>[PersistedSessionRecord.fromJson(json)];
    }
    if (json['schemaVersion'] != _historySchemaVersion) {
      throw const FormatException('Unsupported session schema version');
    }

    final encodedRecords = json['records'];
    if (encodedRecords is! List) {
      throw const FormatException('Session history must contain records');
    }
    final records = encodedRecords.map((encodedRecord) {
      if (encodedRecord is! Map<String, dynamic>) {
        throw const FormatException('Session history record must be an object');
      }
      return PersistedSessionRecord.fromJson(encodedRecord);
    }).toList();
    if (records.length <= _maxHistoryLength) {
      return records;
    }
    return records.sublist(records.length - _maxHistoryLength);
  }
}

class SessionPersistenceFactory {
  SessionPersistenceFactory({
    Future<Directory> Function()? applicationSupportDirectory,
  }) : _applicationSupportDirectory =
           applicationSupportDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _applicationSupportDirectory;

  Future<SessionPersistence> create({required String processIdentifier}) async {
    final supportDirectory = await _applicationSupportDirectory();
    final storageKey = _stableStorageKey(processIdentifier);
    final file = File(
      '${supportDirectory.path}${Platform.pathSeparator}'
      'faro${Platform.pathSeparator}sessions${Platform.pathSeparator}'
      '$storageKey.json',
    );
    return SessionPersistence(store: SessionFileStore(file: file));
  }

  String _stableStorageKey(String value) {
    final offsetBasis = BigInt.parse('cbf29ce484222325', radix: 16);
    final prime = BigInt.parse('100000001b3', radix: 16);
    final mask = BigInt.parse('ffffffffffffffff', radix: 16);
    var hash = offsetBasis;
    for (final byte in utf8.encode(value)) {
      hash = ((hash ^ BigInt.from(byte)) * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
