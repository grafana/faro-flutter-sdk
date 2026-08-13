// Tests intentionally exercise the asynchronous storage API.
// ignore_for_file: avoid_slow_async_io

import 'dart:convert';
import 'dart:io';

import 'package:faro/src/session/app_lifecycle_service.dart';
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

  test('round-trips only the versioned minimal session record', () async {
    final sut = persistence();
    sut.record(state(), isSampled: true, immediate: true);
    await sut.flush();

    final decoded = jsonDecode(await stateFile.readAsString());
    expect((decoded as Map<String, dynamic>).keys, <String>{
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

  test('missing state starts an unlinked session', () async {
    final sut = persistence();
    final manager = SessionManager(
      sessionIdProvider: SessionIdProvider(),
      activityPolicy: SessionActivityPolicy(AppLifecycleService()),
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
        activityPolicy: SessionActivityPolicy(AppLifecycleService()),
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
