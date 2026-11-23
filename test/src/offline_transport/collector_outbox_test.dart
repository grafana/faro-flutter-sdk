import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:faro/src/configurations/batch_config.dart';
import 'package:faro/src/configurations/offline_storage_config.dart';
import 'package:faro/src/data_collection_policy.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/offline_transport/collector_outbox.dart';
import 'package:faro/src/offline_transport/internet_connectivity_service.dart';
import 'package:faro/src/offline_transport/outbox_retry_policy.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:faro/src/transport/faro_transport.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

class MockInternetConnectivityService extends Mock
    implements InternetConnectivityService {}

class MockDataCollectionPolicy extends Mock implements DataCollectionPolicy {}

final class _ReadFailures extends IOOverrides {
  bool blocked = false;
  String? blockedPath;

  @override
  File createFile(String path) {
    final file = super.createFile(path);
    if (!path.endsWith('.batch.json')) return file;
    final wrapped = _MockFile();
    when(() => wrapped.path).thenReturn(path);
    when(() => wrapped.uri).thenReturn(file.uri);
    when(wrapped.delete).thenAnswer((_) => file.delete());
    when(wrapped.readAsString).thenAnswer((_) {
      if (blocked && path == blockedPath) {
        throw const FileSystemException('Injected read failure');
      }
      return file.readAsString();
    });
    return wrapped;
  }
}

class _MockFile extends Mock implements File {}

class _RecordingTransport extends BaseTransport {
  final List<Map<String, dynamic>> payloads = [];

  @override
  Future<void> send(Map<String, dynamic> payloadJson) async {
    payloads.add(payloadJson);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory directory;
  late MockInternetConnectivityService connectivity;
  late StreamController<bool> changes;
  late List<CollectorOutbox> outboxes;
  late List<http.Request> requests;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('faro_outbox_transport_');
    changes = StreamController<bool>.broadcast();
    connectivity = MockInternetConnectivityService();
    when(() => connectivity.isOnline).thenReturn(true);
    when(
      () => connectivity.onConnectivityChanged,
    ).thenAnswer((_) => changes.stream);
    outboxes = [];
    requests = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => directory.path);
  });

  tearDown(() async {
    for (final outbox in outboxes) {
      await outbox.dispose();
    }
    Faro().transports = [];
    Faro().dataCollectionPolicy = null;
    await changes.close();
    await Faro.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });

  FaroTransport collector(
    Future<http.Response> Function(http.Request) respond, {
    int? maxBufferLimit,
  }) {
    final client = MockClient((request) async {
      requests.add(request);
      return respond(request);
    });
    addTearDown(client.close);
    return FaroTransport(
      collectorUrl: 'https://collector.example/collect',
      apiKey: 'test-key',
      sessionIdResolver: () => 'live-session',
      maxBufferLimit: maxBufferLimit,
      httpClient: client,
    );
  }

  FaroTransport accepting() => collector((_) async => http.Response('', 202));

  CollectorOutbox outbox({
    FaroTransport? destination,
    OfflineStorageConfig config = const OfflineStorageConfig(enabled: true),
    bool acceptsNewBatches = true,
    Duration initialRetryDelay = const Duration(seconds: 10),
    Duration maxRetryDelay = const Duration(seconds: 10),
    Duration requestTimeout = const Duration(seconds: 30),
  }) {
    final transport = CollectorOutbox(
      collector: destination ?? accepting(),
      config: config,
      acceptsNewBatches: acceptsNewBatches,
      internetConnectivityService: connectivity,
      initialRetryDelay: initialRetryDelay,
      maxRetryDelay: maxRetryDelay,
      requestTimeout: requestTimeout,
    );
    outboxes.add(transport);
    return transport;
  }

  Map<String, dynamic> payload({String session = 'original-session'}) => {
    'meta': {
      'session': {'id': session},
    },
    'events': [
      {'name': 'test_event', 'timestamp': '2026-11-12T00:00:00Z'},
    ],
  };

  /// Saves a batch without starting delivery, like an earlier launch did.
  Future<void> saveEarlier(
    CollectorOutbox transport,
    Map<String, dynamic> batch,
  ) async {
    final store = await transport.storeForTesting;
    expect(await store.enqueue(jsonEncode(batch)), isNotNull);
  }

  Future<void> waitUntil(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue);
  }

  group('CollectorOutbox:', () {
    test('an unreadable oldest file does not stall later delivery', () async {
      final faults = _ReadFailures();
      await IOOverrides.runWithIOOverrides(() async {
        final transport = outbox();
        await saveEarlier(transport, payload(session: 'unreadable'));
        await Future<void>.delayed(const Duration(milliseconds: 2));
        await saveEarlier(transport, payload(session: 'readable'));
        final store = await transport.storeForTesting;
        faults.blockedPath = (await store.pending()).first.file.path;
        faults.blocked = true;
        await transport.replayCachedData();
        expect(requests, hasLength(1));
        expect(jsonDecode(requests.single.body), payload(session: 'readable'));
        expect(await store.pending(), hasLength(1));
        faults.blocked = false;
        await transport.replayCachedData();
        expect(requests, hasLength(2));
        expect(await store.pending(), isEmpty);
      }, faults);
    });

    test(
      'new batches persist while an older HTTP request is pending',
      () async {
        final held = Completer<http.Response>();
        var attempts = 0;
        final transport = outbox(
          destination: collector((_) {
            attempts++;
            return attempts == 1
                ? held.future
                : Future.value(http.Response('', 202));
          }),
        );
        try {
          await transport.send(payload(session: 'first'));
          await waitUntil(() => requests.isNotEmpty);
          await transport
              .send(payload(session: 'second'))
              .timeout(const Duration(seconds: 2));
          expect(
            await (await transport.storeForTesting).pending(),
            hasLength(2),
          );
        } finally {
          held.complete(http.Response('', 202));
        }
        await transport.replayCachedData();
        expect(requests, hasLength(2));
      },
    );

    test('opt-out during delivery cannot resurrect an old batch', () async {
      final held = Completer<http.Response>();
      var attempts = 0;
      final transport = outbox(
        destination: collector((_) {
          attempts++;
          return attempts == 1
              ? held.future
              : Future.value(http.Response('', 202));
        }),
      );
      try {
        await transport.send(payload(session: 'discard-me'));
        await waitUntil(() => requests.isNotEmpty);
        final policy = MockDataCollectionPolicy();
        var enabled = false;
        when(() => policy.isEnabled).thenAnswer((_) => enabled);
        Faro().dataCollectionPolicy = policy;
        await transport.discardCachedData();
        enabled = true;
        await transport.send(payload(session: 'keep-me'));
      } finally {
        held.complete(http.Response('', 503));
      }
      await transport.replayCachedData();
      expect(requests, hasLength(2));
      expect(jsonDecode(requests.last.body), payload(session: 'keep-me'));
      expect(await (await transport.storeForTesting).pending(), isEmpty);
    });

    test('persists online payload before collector delivery', () async {
      final response = Completer<http.Response>();
      final transport = outbox(destination: collector((_) => response.future));
      try {
        expect(await transport.send(payload()), OutboxHandoff.saved);
        final store = await transport.storeForTesting;
        await waitUntil(() => requests.isNotEmpty);
        expect(await store.pending(), hasLength(1));
        response.complete(http.Response('unavailable', 503));
        await transport.replayCachedData();
        expect(await store.pending(), hasLength(1));
      } finally {
        if (!response.isCompleted) response.complete(http.Response('', 503));
      }
    });

    test('snapshots nested payloads before awaiting storage', () async {
      final held = Completer<http.Response>();
      final transport = outbox(destination: collector((_) => held.future));
      try {
        final original = payload();
        final handoff = transport.send(original);
        (original['meta'] as Map<String, dynamic>)['session'] = {
          'id': 'changed',
        };
        await handoff;
        final store = await transport.storeForTesting;
        final entries = await store.pending();
        expect(await entries.single.readPayload(), payload());
      } finally {
        held.complete(http.Response('', 503));
      }
    });

    test('connectivity is only a hint and cannot prevent delivery', () async {
      when(() => connectivity.isOnline).thenReturn(false);
      final transport = outbox();
      await transport.send(payload());
      await transport.replayCachedData();
      expect(requests, hasLength(1));
      expect(await (await transport.storeForTesting).pending(), isEmpty);
    });

    for (final status in [200, 202, 204, 400, 401, 403, 413, 422]) {
      test('removes terminal HTTP $status', () async {
        final transport = outbox(
          destination: collector((_) async => http.Response('', status)),
        );
        await transport.send(payload());
        await transport.replayCachedData();
        expect(requests, hasLength(1));
        expect(await (await transport.storeForTesting).pending(), isEmpty);
      });
    }

    for (final status in [408, 429, 500, 503]) {
      test(
        'retains retryable HTTP $status without overlapping replays',
        () async {
          final transport = outbox(
            destination: collector((_) async => http.Response('', status)),
          );
          await transport.send(payload());
          await Future.wait(
            List.generate(5, (_) => transport.replayCachedData()),
          );
          expect(requests, hasLength(1));
          expect(
            await (await transport.storeForTesting).pending(),
            hasLength(1),
          );
        },
      );
    }

    test('retains network failures', () async {
      final transport = outbox(
        destination: collector((_) async {
          throw http.ClientException('unavailable');
        }),
      );
      await transport.send(payload());
      await transport.replayCachedData();
      expect(await (await transport.storeForTesting).pending(), hasLength(1));
    });

    test('retains payloads rejected by a full task buffer', () async {
      final transport = outbox(
        destination: collector(
          (_) async => http.Response('', 202),
          maxBufferLimit: 0,
        ),
      );
      await transport.send(payload());
      await transport.replayCachedData();
      expect(requests, isEmpty);
      expect(await (await transport.storeForTesting).pending(), hasLength(1));
    });

    test('timer retries without any connectivity transition', () async {
      final delivered = Completer<void>();
      var attempts = 0;
      final transport = outbox(
        initialRetryDelay: const Duration(milliseconds: 30),
        maxRetryDelay: const Duration(milliseconds: 30),
        destination: collector((_) async {
          attempts++;
          if (attempts == 1) return http.Response('', 503);
          if (!delivered.isCompleted) delivered.complete();
          return http.Response('', 202);
        }),
      );
      await transport.send(payload());
      await delivered.future.timeout(const Duration(seconds: 5));
      await transport.replayCachedData();
      expect(attempts, 2);
      expect(await (await transport.storeForTesting).pending(), isEmpty);
    });

    test('new batches and reconnects respect persisted Retry-After', () async {
      final destination = collector(
        (_) async => http.Response('', 429, headers: {'Retry-After': '120'}),
      );
      final first = outbox(destination: destination);
      await first.send(payload());
      await first.replayCachedData();
      await first.dispose();
      final restarted = outbox(destination: destination);
      await restarted.send(payload());
      changes.add(true);
      await restarted.replayCachedData();
      expect(requests, hasLength(1));
      expect(await (await restarted.storeForTesting).pending(), hasLength(2));
      final retry = await (await restarted.storeForTesting).readRetryState();
      expect(
        retry.retryAt?.isAfter(
          DateTime.now().add(const Duration(seconds: 110)),
        ),
        isTrue,
      );
    });

    test(
      'stores in Application Support and migrates the Documents cache',
      () async {
        final support = await Directory('${directory.path}/support').create();
        final documents = await Directory(
          '${directory.path}/documents',
        ).create();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              channel,
              (call) async => switch (call.method) {
                'getApplicationSupportDirectory' => support.path,
                'getApplicationDocumentsDirectory' => documents.path,
                _ => null,
              },
            );
        await File('${documents.path}/rum_log.json').writeAsString(
          jsonEncode({
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'payload': payload(session: 'legacy-session'),
          }),
        );
        final held = Completer<http.Response>();
        final transport = outbox(destination: collector((_) => held.future));
        try {
          await transport.send(payload());
          final store = await transport.storeForTesting;
          expect(store.directory.path, '${support.path}/faro-outbox');
          expect(await store.pending(), hasLength(2));
          expect(File('${documents.path}/rum_log.json').existsSync(), isFalse);
          expect(
            Directory('${documents.path}/faro-outbox').existsSync(),
            isFalse,
          );
        } finally {
          held.complete(http.Response('', 503));
        }
      },
    );

    test('caps a huge Retry-After before saving the deadline', () async {
      final transport = outbox(
        destination: collector(
          (_) async =>
              http.Response('', 503, headers: {'Retry-After': '99999999'}),
        ),
      );
      await transport.send(payload());
      await transport.replayCachedData();
      final retry = await (await transport.storeForTesting).readRetryState();
      final latest = DateTime.now().add(OutboxRetryPolicy.maxServerDelay);
      expect(retry.retryAt, isNotNull);
      expect(retry.retryAt!.isAfter(latest), isFalse);
      expect(
        retry.retryAt!.isAfter(DateTime.now().add(const Duration(minutes: 59))),
        isTrue,
      );
    });

    test('caps and rewrites a far-future deadline loaded from disk', () async {
      final retryFile = File('${directory.path}/faro-outbox/retry.json');
      await retryFile.parent.create(recursive: true);
      await retryFile.writeAsString(
        jsonEncode({
          'retryAt': DateTime.now()
              .add(const Duration(days: 1000))
              .millisecondsSinceEpoch,
          'failures': 3,
        }),
      );
      final transport = outbox();
      await transport.send(payload());
      await transport.replayCachedData();
      expect(requests, isEmpty);
      final retry = await (await transport.storeForTesting).readRetryState();
      final latest = DateTime.now().add(OutboxRetryPolicy.maxServerDelay);
      expect(retry.retryAt, isNotNull);
      expect(retry.retryAt!.isAfter(latest), isFalse);
      expect(retry.failures, 3);
    });

    test('startup sends the saved copy after interrupted delivery', () async {
      final held = Completer<http.Response>();
      final first = outbox(destination: collector((_) => held.future));
      await first.send(payload());
      await waitUntil(() => requests.isNotEmpty);
      final stopping = first.dispose();
      held.complete(http.Response('', 503));
      await stopping;
      final restarted = outbox();
      await restarted.replayCachedData();
      expect(requests, hasLength(2));
      expect(jsonDecode(requests.last.body), payload());
      expect(await (await restarted.storeForTesting).pending(), isEmpty);
    });

    test(
      'bounded request timeout releases delivery for later retries',
      () async {
        final held = Completer<http.Response>();
        final transport = outbox(
          destination: collector((_) => held.future),
          requestTimeout: const Duration(milliseconds: 20),
        );
        await transport.send(payload());
        await transport.replayCachedData();
        expect(await (await transport.storeForTesting).pending(), hasLength(1));
        held.complete(http.Response('', 202));
      },
    );

    test('historical replay does not invalidate the current session', () async {
      final invalidated = <String>[];
      final destination = collector(
        (_) async => http.Response(
          '',
          202,
          headers: {'x-faro-session-status': 'invalid'},
        ),
      );
      destination.sessionInvalidatedHandler = invalidated.add;
      final transport = outbox(destination: destination);
      Faro().meta.session = Session('new-session');
      await transport.send(payload(session: 'old-session'));
      await transport.replayCachedData();
      expect(invalidated, isEmpty);
      expect(jsonDecode(requests.single.body), payload(session: 'old-session'));
    });

    test(
      'a fresh live batch still processes receiver session invalidation',
      () async {
        final invalidated = <String>[];
        final destination = collector(
          (_) async => http.Response(
            '',
            202,
            headers: {'x-faro-session-status': 'invalid'},
          ),
        );
        destination.sessionInvalidatedHandler = invalidated.add;
        final transport = outbox(destination: destination);
        Faro().meta.session = Session('live-session');
        await transport.send(payload(session: 'live-session'));
        await transport.replayCachedData();
        expect(invalidated, ['live-session']);
      },
    );

    test('disabled collection purges cache without delivering it', () async {
      final transport = outbox();
      await saveEarlier(transport, payload());
      final policy = MockDataCollectionPolicy();
      when(() => policy.isEnabled).thenReturn(false);
      Faro().dataCollectionPolicy = policy;
      await transport.replayCachedData();
      expect(requests, isEmpty);
      expect(await (await transport.storeForTesting).pending(), isEmpty);
    });

    test('a disabled collection discards a new batch on purpose', () async {
      final policy = MockDataCollectionPolicy();
      when(() => policy.isEnabled).thenReturn(false);
      Faro().dataCollectionPolicy = policy;
      final transport = outbox();
      expect(await transport.send(payload()), OutboxHandoff.discarded);
    });

    test('serialization failure is reported as not saved', () async {
      final transport = outbox();
      expect(
        await transport.send({'invalid': DateTime.now()}),
        OutboxHandoff.notSaved,
      );
      expect(await (await transport.storeForTesting).pending(), isEmpty);
    });

    test('dispose detaches the outbox from its collector', () async {
      final destination = accepting();
      final transport = outbox(destination: destination);
      expect(collectorOutboxOf(destination), same(transport));
      await transport.dispose();
      expect(collectorOutboxOf(destination), isNull);
    });
  });

  group('FaroTransport with an outbox:', () {
    test('saves a batch and delivers it through the outbox', () async {
      final destination = accepting();
      final transport = outbox(destination: destination);
      await destination.send(payload());
      await transport.replayCachedData();
      expect(requests, hasLength(1));
      expect(await (await transport.storeForTesting).pending(), isEmpty);
    });

    test('a failed save gets one direct attempt', () async {
      // The outbox folder cannot be created below a regular file.
      final blocker = await File('${directory.path}/blocker').create();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => blocker.path);
      final destination = accepting();
      final transport = outbox(destination: destination);
      expect(await transport.send(payload()), OutboxHandoff.notSaved);
      expect(requests, isEmpty);
      await destination.send(payload());
      expect(requests, hasLength(1));
      expect(jsonDecode(requests.single.body), payload());
    });

    test('an oversized batch gets one direct attempt', () async {
      final destination = accepting();
      final transport = outbox(
        destination: destination,
        config: const OfflineStorageConfig(enabled: true, maxBytes: 64),
      );
      await destination.send(payload());
      expect(requests, hasLength(1));
      expect(await (await transport.storeForTesting).pending(), isEmpty);
    });

    test('a failed save is not sent while the collector throttles', () async {
      final destination = collector(
        (_) async => http.Response('', 503, headers: {'Retry-After': '120'}),
      );
      final transport = outbox(
        destination: destination,
        config: const OfflineStorageConfig(enabled: true, maxBytes: 400),
      );
      await destination.send(payload());
      await transport.replayCachedData();
      expect(transport.isThrottled, isTrue);
      final oversized = payload()..['logs'] = [List.filled(100, 'x').join()];
      await destination.send(oversized);
      expect(requests, hasLength(1));
    });

    test('a discarded batch is not sent directly', () async {
      final policy = MockDataCollectionPolicy();
      when(() => policy.isEnabled).thenReturn(false);
      Faro().dataCollectionPolicy = policy;
      final destination = accepting();
      outbox(destination: destination);
      await destination.send(payload());
      expect(requests, isEmpty);
    });

    test('batching sends the primary collector through the outbox', () async {
      final primary = accepting();
      var secondaryRequests = 0;
      final secondary = collector((_) async {
        secondaryRequests++;
        return http.Response('', 202);
      });
      final transport = outbox(destination: primary);
      final custom = _RecordingTransport();
      final batch = BatchTransport(
        payload: Payload(Meta()),
        batchConfig: BatchConfig(enabled: false),
        transports: [primary, custom, secondary],
      );
      final data = Payload(Meta())..events.add(Event('test'));
      await batch.flush(data);
      await transport.replayCachedData();
      // One request through the outbox and one live for the secondary.
      expect(requests, hasLength(2));
      expect(secondaryRequests, 1);
      expect(custom.payloads, hasLength(1));
      expect(await (await transport.storeForTesting).pending(), isEmpty);
      await transport.replayCachedData();
      expect(requests, hasLength(2));
      batch.dispose();
    });
  });

  group('CollectorOutbox drain-only:', () {
    CollectorOutbox drainOnly({FaroTransport? destination}) => outbox(
      destination: destination,
      config: const OfflineStorageConfig(),
      acceptsNewBatches: false,
    );

    test('creates no files when nothing was saved earlier', () async {
      final transport = drainOnly();
      await transport.replayCachedData();
      await transport.discardCachedData();
      expect(Directory('${directory.path}/faro-outbox').existsSync(), isFalse);
      expect(requests, isEmpty);
    });

    test('delivers an earlier backlog, then removes the folder', () async {
      final earlier = outbox(
        destination: collector((_) async => http.Response('', 503)),
      );
      await saveEarlier(earlier, payload(session: 'earlier'));
      await earlier.dispose();
      final transport = drainOnly();
      await transport.replayCachedData();
      expect(requests, hasLength(1));
      expect(jsonDecode(requests.single.body), payload(session: 'earlier'));
      expect(Directory('${directory.path}/faro-outbox').existsSync(), isFalse);
    });

    test('delivers a legacy rum_log.json backlog', () async {
      await File('${directory.path}/rum_log.json').writeAsString(
        jsonEncode({
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'payload': payload(session: 'legacy'),
        }),
      );
      final transport = drainOnly();
      await transport.replayCachedData();
      expect(jsonDecode(requests.single.body), payload(session: 'legacy'));
      expect(File('${directory.path}/rum_log.json').existsSync(), isFalse);
    });

    test('does not save new batches or attach to the collector', () async {
      final destination = accepting();
      final transport = drainOnly(destination: destination);
      expect(collectorOutboxOf(destination), isNull);
      expect(await transport.send(payload()), OutboxHandoff.notSaved);
      await destination.send(payload());
      expect(requests, hasLength(1));
      expect(Directory('${directory.path}/faro-outbox').existsSync(), isFalse);
    });
  });
}
