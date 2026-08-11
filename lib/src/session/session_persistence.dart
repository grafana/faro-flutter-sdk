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

  Timer? _activityWriteTimer;
  PersistedSessionRecord? _pendingRecord;
  Future<void> _writeQueue = Future<void>.value();

  Future<PersistedSessionRecord?> load() async {
    try {
      final persistedValue = await _store.read();
      if (persistedValue == null) {
        return null;
      }
      final decoded = jsonDecode(persistedValue);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Session record must be an object');
      }
      return PersistedSessionRecord.fromJson(decoded);
    } catch (error) {
      log('Faro: Ignoring invalid persisted session state: $error');
      await _deleteSafely();
      return null;
    }
  }

  void record(
    SessionState state, {
    required bool isSampled,
    required bool immediate,
  }) {
    _pendingRecord = PersistedSessionRecord(
      currentSessionId: state.currentSessionId,
      previousSessionId: state.previousSessionId,
      startedAt: state.startedAt,
      lastActivityAt: state.lastActivityAt,
      isSampled: isSampled,
    );

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
    _pendingRecord = null;
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
    final record = _pendingRecord;
    if (record == null) {
      return;
    }
    _pendingRecord = null;
    _writeQueue = _writeQueue.then((_) => _writeSafely(record));
  }

  Future<void> _writeSafely(PersistedSessionRecord record) async {
    try {
      await _store.write(jsonEncode(record.toJson()));
    } catch (error) {
      log('Faro: Failed to persist session state: $error');
    }
  }

  Future<void> _deleteSafely() async {
    try {
      await _store.delete();
    } catch (error) {
      log('Faro: Failed to clear persisted session state: $error');
    }
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
    const offsetBasis = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    const mask = 0xffffffffffffffff;
    var hash = offsetBasis;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
