import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:faro/src/configurations/batch_config.dart';
import 'package:faro/src/data_collection_policy.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/offline_transport/internet_connectivity_service.dart';
import 'package:faro/src/offline_transport/offline_transport.dart';
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

class _TrackedOutbox extends OfflineTransport {
  _TrackedOutbox({required super.internetConnectivityService})
    : super(maxCacheCount: 1);

  final List<Future<void>> replays = [];

  @override
  Future<void> replayCachedData() {
    final replay = super.replayCachedData();
    replays.add(replay);
    return replay;
  }
}

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
  late List<OfflineTransport> outboxes;
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

  OfflineTransport outbox({
    FaroTransport? destination,
    Duration initialRetryDelay = const Duration(seconds: 10),
    Duration maxRetryDelay = const Duration(seconds: 10),
    Duration requestTimeout = const Duration(seconds: 30),
  }) {
    final transport = OfflineTransport(
      internetConnectivityService: connectivity,
      initialRetryDelay: initialRetryDelay,
      maxRetryDelay: maxRetryDelay,
      requestTimeout: requestTimeout,
    )..collector = destination;
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

  Future<void> waitUntil(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue);
  }

  group('OfflineTransport outbox:', () {
    test('an unreadable oldest file does not stall later delivery', () async {
      final faults = _ReadFailures();
      await IOOverrides.runWithIOOverrides(() async {
        final transport = outbox();
        await transport.send(payload(session: 'unreadable'));
        await Future<void>.delayed(const Duration(milliseconds: 2));
        await transport.send(payload(session: 'readable'));
        await transport.replayCachedData();
        final store = await transport.storeForTesting;
        faults.blockedPath = (await store.pending()).first.file.path;
        faults.blocked = true;
        transport.collector = collector((_) async => http.Response('', 202));
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

    test('an unbound extra outbox cannot prune the primary cache', () async {
      final primary = outbox(
        destination: collector((_) async => http.Response('', 503)),
      );
      for (final session in ['first', 'second', 'third']) {
        await primary.send(payload(session: session));
      }
      await primary.replayCachedData();
      final extra = _TrackedOutbox(internetConnectivityService: connectivity);
      outboxes.add(extra);
      Faro().transports = [primary, extra];

      changes.add(true);
      await Future<void>.delayed(Duration.zero);
      await Future.wait(extra.replays);
      await primary.replayCachedData();

      final files = await Directory(
        '${directory.path}/faro-outbox',
      ).list().where((entity) => entity.path.endsWith('.batch.json')).toList();
      expect(files, hasLength(3));
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
        await transport.send(payload());
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
      final transport = outbox();
      final original = payload();
      final handoff = transport.send(original);
      (original['meta'] as Map<String, dynamic>)['session'] = {'id': 'changed'};
      await handoff;
      final store = await transport.storeForTesting;
      final entries = await store.pending();
      expect(await entries.single.readPayload(), payload());
    });

    test('connectivity is only a hint and cannot prevent delivery', () async {
      when(() => connectivity.isOnline).thenReturn(false);
      final transport = outbox(
        destination: collector((_) async => http.Response('', 202)),
      );
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

    test('startup sends the saved copy after interrupted delivery', () async {
      final held = Completer<http.Response>();
      final first = outbox(destination: collector((_) => held.future));
      await first.send(payload());
      await waitUntil(() => requests.isNotEmpty);
      final stopping = first.dispose();
      held.complete(http.Response('', 503));
      await stopping;
      final restarted = outbox(
        destination: collector((_) async => http.Response('', 202)),
      );
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
      await transport.send(payload());
      final policy = MockDataCollectionPolicy();
      when(() => policy.isEnabled).thenReturn(false);
      Faro().dataCollectionPolicy = policy;
      transport.collector = collector((_) async => http.Response('', 202));
      await transport.replayCachedData();
      expect(requests, isEmpty);
      expect(await (await transport.storeForTesting).pending(), isEmpty);
    });

    test(
      'serialization failure does not acknowledge durable handoff',
      () async {
        final transport = outbox();
        await expectLater(
          transport.send({'invalid': DateTime.now()}),
          throwsA(isA<JsonUnsupportedObjectError>()),
        );
        expect(await (await transport.storeForTesting).pending(), isEmpty);
      },
    );

    test(
      'batching routes only the primary collector through the outbox',
      () async {
        final primary = collector((_) async => http.Response('', 202));
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
          transports: [primary, custom, transport, secondary],
        );
        final data = Payload(Meta())..events.add(Event('test'));
        await batch.flush(data);
        await transport.replayCachedData();
        expect(requests, hasLength(2));
        expect(secondaryRequests, 1);
        expect(custom.payloads, hasLength(1));
        await transport.replayCachedData();
        expect(custom.payloads, hasLength(1));
        batch.dispose();
      },
    );
  });
}
