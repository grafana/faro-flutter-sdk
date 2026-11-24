// Tests intentionally exercise the asynchronous storage API.
// ignore_for_file: avoid_slow_async_io

import 'dart:convert';
import 'dart:io';

import 'package:faro/src/session/session_activity_policy.dart';
import 'package:faro/src/session/session_id_provider.dart';
import 'package:faro/src/session/session_manager.dart';
import 'package:faro/src/session/session_persistence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  late File stateFile;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'faro-session-persistence-',
    );
    stateFile = File('${temporaryDirectory.path}/session.json');
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  SessionState state({
    String currentSessionId = 'current-session',
    String? previousSessionId = 'previous-session',
    DateTime? startedAt,
    DateTime? lastActivityAt,
  }) {
    final start = startedAt ?? DateTime.utc(2026, 8, 11, 12);
    return SessionState(
      currentSessionId: currentSessionId,
      previousSessionId: previousSessionId,
      startedAt: start,
      lastActivityAt: lastActivityAt ?? start,
    );
  }

  SessionPersistence persistence({Duration? activityWriteDelay}) {
    return SessionPersistence(
      store: SessionFileStore(file: stateFile),
      activityWriteDelay: activityWriteDelay ?? const Duration(seconds: 30),
    );
  }

  Future<void> writeRecordFile({Map<String, dynamic>? extra}) async {
    final start = DateTime.utc(2026, 8, 11, 12).toIso8601String();
    await stateFile.writeAsString(
      jsonEncode({
        'schemaVersion': 2,
        'records': [
          {
            'schemaVersion': 1,
            'currentSessionId': 'current-session',
            'previousSessionId': null,
            'startedAt': start,
            'lastActivityAt': start,
            'isSampled': true,
            ...?extra,
          },
        ],
      }),
    );
  }

  test('round-trips a versioned history of minimal session records', () async {
    final sut = persistence();
    sut.record(state(), isSampled: true, immediate: true);
    await sut.flush();

    final decoded = jsonDecode(await stateFile.readAsString());
    expect((decoded as Map<String, dynamic>).keys, <String>{
      'schemaVersion',
      'records',
    });
    expect(decoded['schemaVersion'], 2);
    final records = decoded['records'] as List<dynamic>;
    expect(records, hasLength(1));
    expect((records.single as Map<String, dynamic>).keys, <String>{
      'schemaVersion',
      'currentSessionId',
      'previousSessionId',
      'startedAt',
      'lastActivityAt',
      'isSampled',
    });

    final loaded = await sut.load();
    expect(loaded?.currentSessionId, 'current-session');
    expect(loaded?.previousSessionId, 'previous-session');
    expect(loaded?.isSampled, isTrue);
  });

  test('loads a legacy single-record file', () async {
    await stateFile.writeAsString(
      jsonEncode(
        PersistedSessionRecord(
          currentSessionId: 'legacy-session',
          previousSessionId: null,
          startedAt: DateTime.utc(2026, 8, 11, 12),
          lastActivityAt: DateTime.utc(2026, 8, 11, 12, 5),
          isSampled: true,
        ).toJson(),
      ),
    );

    final history = await persistence().loadHistory();

    expect(history, hasLength(1));
    expect(history.single.currentSessionId, 'legacy-session');
  });

  test('missing state starts an unlinked session', () async {
    final sut = persistence();
    final manager = SessionManager(
      sessionIdProvider: SessionIdProvider(),
      activityPolicy: SessionActivityPolicy(),
      currentTimeProvider: () => DateTime.utc(2026, 8, 11, 13),
    );

    manager.start(previousSessionId: (await sut.load())?.currentSessionId);

    expect(manager.currentSessionId, isNotEmpty);
    expect(manager.previousSessionId, isNull);
  });

  test('corrupt state is removed and treated as missing', () async {
    await stateFile.writeAsString('{not-json');
    final sut = persistence();

    expect(await sut.load(), isNull);
    expect(await stateFile.exists(), isFalse);
  });

  for (final unsupportedVersion in <int>[0, 99]) {
    test(
      'schema version $unsupportedVersion is removed and treated as missing',
      () async {
        await stateFile.writeAsString(
          jsonEncode(<String, dynamic>{
            'schemaVersion': unsupportedVersion,
            'currentSessionId': 'old-session',
          }),
        );
        final sut = persistence();

        expect(await sut.load(), isNull);
        expect(await stateFile.exists(), isFalse);
      },
    );
  }

  test('invalid timing state is removed and treated as missing', () async {
    await stateFile.writeAsString(
      jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'currentSessionId': 'old-session',
        'previousSessionId': null,
        'startedAt': '2026-08-11T12:01:00.000Z',
        'lastActivityAt': '2026-08-11T12:00:00.000Z',
        'isSampled': true,
      }),
    );
    final sut = persistence();

    expect(await sut.load(), isNull);
    expect(await stateFile.exists(), isFalse);
  });

  test('activity writes are coalesced until flush', () async {
    final sut = persistence(activityWriteDelay: const Duration(hours: 1));
    final start = DateTime.utc(2026, 8, 11, 12);

    sut.record(
      state(startedAt: start, lastActivityAt: start),
      isSampled: true,
      immediate: false,
    );
    sut.record(
      state(
        startedAt: start,
        lastActivityAt: start.add(const Duration(minutes: 1)),
      ),
      isSampled: true,
      immediate: false,
    );
    expect(await stateFile.exists(), isFalse);

    await sut.flush();

    expect(
      (await sut.load())?.lastActivityAt,
      start.add(const Duration(minutes: 1)),
    );
    expect(await sut.loadHistory(), hasLength(1));
  });

  test('backward clock changes are clamped before persistence', () async {
    final sut = persistence();
    final start = DateTime.utc(2026, 8, 11, 12);

    sut.record(
      state(
        startedAt: start,
        lastActivityAt: start.subtract(const Duration(minutes: 1)),
      ),
      isSampled: true,
      immediate: true,
    );
    await sut.flush();

    final loaded = await sut.load();
    expect(loaded?.startedAt, start);
    expect(loaded?.lastActivityAt, start);
  });

  test('a newer state wins while an earlier write is queued', () async {
    final sut = persistence();

    sut.record(
      state(currentSessionId: 'first', previousSessionId: null),
      isSampled: false,
      immediate: true,
    );
    sut.record(
      state(currentSessionId: 'second', previousSessionId: 'first'),
      isSampled: true,
      immediate: true,
    );
    await sut.flush();

    final loaded = await sut.load();
    expect(loaded?.currentSessionId, 'second');
    expect(loaded?.previousSessionId, 'first');
    expect(loaded?.isSampled, isTrue);
    expect(
      (await sut.loadHistory()).map((record) => record.currentSessionId),
      <String>['first', 'second'],
    );
  });

  test('keeps a bounded session history', () async {
    const maxHistoryLength = 16;
    final sut = persistence();
    final start = DateTime.utc(2026, 8, 11, 12);
    for (var index = 0; index <= maxHistoryLength; index++) {
      sut.record(
        state(
          currentSessionId: 'session-$index',
          previousSessionId: index == 0 ? null : 'session-${index - 1}',
          startedAt: start.add(Duration(minutes: index)),
        ),
        isSampled: true,
        immediate: true,
      );
    }
    await sut.flush();

    final history = await sut.loadHistory();
    expect(history, hasLength(maxHistoryLength));
    expect(history.first.currentSessionId, 'session-1');
    expect(history.last.currentSessionId, 'session-$maxHistoryLength');
  });

  test('a failed write remains pending for the next flush', () async {
    final store = _FailingSessionFileStore(file: stateFile, failures: 1);
    final sut = SessionPersistence(store: store);

    sut.record(state(), isSampled: true, immediate: true);
    await sut.flush();

    expect(store.writeAttempts, 1);
    expect(await stateFile.exists(), isFalse);

    await sut.flush();

    expect(store.writeAttempts, 2);
    expect((await sut.load())?.currentSessionId, 'current-session');
  });

  test('a newer queued state supersedes an earlier failed write', () async {
    final store = _FailingSessionFileStore(file: stateFile, failures: 1);
    final sut = SessionPersistence(store: store);

    sut.record(
      state(currentSessionId: 'first', previousSessionId: null),
      isSampled: false,
      immediate: true,
    );
    sut.record(
      state(currentSessionId: 'second', previousSessionId: 'first'),
      isSampled: true,
      immediate: true,
    );
    await sut.flush();

    expect(store.writeAttempts, 2);
    final loaded = await sut.load();
    expect(loaded?.currentSessionId, 'second');
    expect(loaded?.previousSessionId, 'first');
    expect(loaded?.isSampled, isTrue);

    await sut.flush();
    expect(store.writeAttempts, 2);
  });

  test('process-specific factories keep separate session chains', () async {
    final factory = SessionPersistenceFactory(
      applicationSupportDirectory: () async => temporaryDirectory,
    );
    final first = await factory.create(processIdentifier: 'app:main');
    final second = await factory.create(processIdentifier: 'app:background');

    first.record(
      state(currentSessionId: 'main-session', previousSessionId: null),
      isSampled: true,
      immediate: true,
    );
    second.record(
      state(currentSessionId: 'background-session', previousSessionId: null),
      isSampled: false,
      immediate: true,
    );
    await Future.wait(<Future<void>>[first.flush(), second.flush()]);

    expect((await first.load())?.currentSessionId, 'main-session');
    expect((await second.load())?.currentSessionId, 'background-session');

    final sessionDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}'
      'faro${Platform.pathSeparator}sessions',
    );
    final fileNames = await sessionDirectory
        .list()
        .where((entry) => entry is File)
        .map((entry) => entry.uri.pathSegments.last)
        .toList();
    expect(
      fileNames,
      unorderedEquals(<String>[
        '9cb83f56ad0412ab.json',
        'e69ec7cdc5b6a332.json',
      ]),
    );
  });

  test(
    'a cold start creates a new session linked to persisted state',
    () async {
      final sut = persistence();
      sut.record(
        state(currentSessionId: 'persisted-session', previousSessionId: null),
        isSampled: true,
        immediate: true,
      );
      await sut.flush();

      final previousSessionId = (await sut.load())?.currentSessionId;
      final manager = SessionManager(
        sessionIdProvider: SessionIdProvider(),
        activityPolicy: SessionActivityPolicy(),
        currentTimeProvider: () => DateTime.utc(2026, 8, 11, 13),
      )..start(previousSessionId: previousSessionId);

      expect(manager.currentSessionId, isNot('persisted-session'));
      expect(manager.previousSessionId, 'persisted-session');
    },
  );

  test('clear removes persisted and pending state', () async {
    final sut = persistence(activityWriteDelay: const Duration(hours: 1));
    sut.record(state(), isSampled: true, immediate: true);
    await sut.flush();
    sut.record(
      state(currentSessionId: 'pending', previousSessionId: null),
      isSampled: true,
      immediate: false,
    );

    await sut.clear();

    expect(await sut.load(), isNull);
    expect(await stateFile.exists(), isFalse);
  });

  group('dynamic device state', () {
    const stored = <String, dynamic>{
      'batteryLevel': 12,
      'isCharging': false,
      'thermalState': 'serious',
      'connectionType': 'cell',
    };

    test('round-trips with the session record', () async {
      final sut = persistence();
      sut.record(
        state(),
        isSampled: true,
        immediate: true,
        dynamicDeviceState: stored,
      );
      await sut.flush();

      expect((await sut.load())?.dynamicDeviceState, stored);
    });

    test('a record without values writes no key for them', () async {
      final sut = persistence();
      sut.record(state(), isSampled: true, immediate: true);
      await sut.flush();

      final decoded = jsonDecode(await stateFile.readAsString());
      final record = (decoded['records'] as List).single as Map;
      expect(record, isNot(contains('dynamicDeviceState')));
    });

    test('activity records keep the stored values', () async {
      final sut = persistence();
      sut.record(
        state(),
        isSampled: true,
        immediate: true,
        dynamicDeviceState: stored,
      );
      sut.record(
        state(lastActivityAt: DateTime.utc(2026, 8, 11, 12, 5)),
        isSampled: true,
        immediate: false,
      );
      await sut.flush();

      expect((await sut.load())?.dynamicDeviceState, stored);
    });

    test('a change is stored on the current session', () async {
      final sut = persistence();
      sut.record(state(), isSampled: true, immediate: true);
      sut.recordDynamicDeviceState(stored);
      await sut.flush();

      expect((await sut.load())?.dynamicDeviceState, stored);
    });

    test('a change before any session record is ignored', () async {
      final sut = persistence();
      sut.recordDynamicDeviceState(stored);
      await sut.flush();

      expect(await stateFile.exists(), isFalse);
    });

    test('changes are coalesced until the write delay ends', () async {
      final sut = persistence(activityWriteDelay: const Duration(hours: 1));
      sut.record(state(), isSampled: true, immediate: true);
      await sut.flush();

      sut
        ..recordDynamicDeviceState({'batteryLevel': 50})
        ..recordDynamicDeviceState({'batteryLevel': 49});

      final onDisk = jsonDecode(await stateFile.readAsString());
      expect(
        (onDisk['records'] as List).single,
        isNot(contains('dynamicDeviceState')),
      );

      await sut.flush();
      expect((await sut.load())?.dynamicDeviceState, {'batteryLevel': 49});
    });

    test('a change goes to the current session, not an older one', () async {
      final sut = persistence();
      sut.record(
        state(currentSessionId: 'older', previousSessionId: null),
        isSampled: true,
        immediate: true,
      );
      sut.record(
        state(currentSessionId: 'newer', previousSessionId: 'older'),
        isSampled: true,
        immediate: true,
      );
      sut.recordDynamicDeviceState(stored);
      await sut.flush();

      final history = await sut.loadHistory();
      expect(history.first.dynamicDeviceState, isNull);
      expect(history.last.dynamicDeviceState, stored);
    });

    test('discard removes the values of one session only', () async {
      final sut = persistence();
      sut.record(
        state(currentSessionId: 'older', previousSessionId: null),
        isSampled: true,
        immediate: true,
        dynamicDeviceState: stored,
      );
      sut.record(
        state(currentSessionId: 'newer', previousSessionId: 'older'),
        isSampled: true,
        immediate: true,
        dynamicDeviceState: stored,
      );
      sut.discardDynamicDeviceState('older');
      await sut.flush();

      final history = await sut.loadHistory();
      expect(history.first.dynamicDeviceState, isNull);
      expect(history.last.dynamicDeviceState, stored);
    });

    test('an unreadable value drops the values, not the record', () async {
      final start = DateTime.utc(2026, 8, 11, 12).toIso8601String();
      await stateFile.writeAsString(
        jsonEncode({
          'schemaVersion': 2,
          'records': [
            {
              'schemaVersion': 1,
              'currentSessionId': 'current-session',
              'previousSessionId': null,
              'startedAt': start,
              'lastActivityAt': start,
              'isSampled': true,
              'dynamicDeviceState': 'not a map',
            },
          ],
        }),
      );

      final loaded = await persistence().load();

      expect(loaded?.currentSessionId, 'current-session');
      expect(loaded?.dynamicDeviceState, isNull);
    });
  });

  group('meta snapshot', () {
    const snapshot = <String, dynamic>{
      'app': {'name': 'Example', 'version': '1.0.0'},
      'os': {'name': 'Android', 'version': '13'},
    };

    test('round-trips with the session record', () async {
      final sut = persistence();
      sut.record(
        state(),
        isSampled: true,
        immediate: true,
        metaSnapshot: snapshot,
      );
      await sut.flush();

      expect((await sut.load())?.metaSnapshot, snapshot);
    });

    test('activity records keep the snapshot', () async {
      final sut = persistence();
      sut.record(
        state(),
        isSampled: true,
        immediate: true,
        metaSnapshot: snapshot,
      );
      sut.record(
        state(lastActivityAt: DateTime.utc(2026, 8, 11, 12, 5)),
        isSampled: true,
        immediate: false,
      );
      await sut.flush();

      expect((await sut.load())?.metaSnapshot, snapshot);
    });

    test('a dynamic value change keeps the snapshot', () async {
      final sut = persistence();
      sut.record(
        state(),
        isSampled: true,
        immediate: true,
        metaSnapshot: snapshot,
      );
      sut.recordDynamicDeviceState({'batteryLevel': 12});
      await sut.flush();

      final loaded = await sut.load();
      expect(loaded?.metaSnapshot, snapshot);
      expect(loaded?.dynamicDeviceState, {'batteryLevel': 12});
    });

    test('a record from an older SDK loads without one', () async {
      await writeRecordFile();

      expect((await persistence().load())?.metaSnapshot, isNull);
    });

    test('an unreadable snapshot drops the snapshot, not the record', () async {
      await writeRecordFile(extra: {'metaSnapshot': 'not a map'});

      final loaded = await persistence().load();

      expect(loaded?.currentSessionId, 'current-session');
      expect(loaded?.metaSnapshot, isNull);
    });
  });
}

class _FailingSessionFileStore extends SessionFileStore {
  _FailingSessionFileStore({required super.file, required this.failures});

  final int failures;
  int writeAttempts = 0;

  @override
  Future<void> write(String contents) async {
    writeAttempts += 1;
    if (writeAttempts <= failures) {
      throw const FileSystemException('simulated write failure');
    }
    await super.write(contents);
  }
}
