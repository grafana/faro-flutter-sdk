import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:faro/src/data_collection_policy.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/offline_transport/internet_connectivity_service.dart';
import 'package:faro/src/offline_transport/offline_transport.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:faro/src/transport/faro_transport.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

class MockInternetConnectivityService extends Mock
    implements InternetConnectivityService {}

class MockTransport extends Mock implements BaseTransport {}

class MockFaroTransport extends Mock implements FaroTransport {}

class MockDataCollectionPolicy extends Mock implements DataCollectionPolicy {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory tempDir;
  late MockInternetConnectivityService mockConnectivityService;
  late StreamController<bool> connectivityController;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('faro_offline_test');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return tempDir.path;
          }
          return null;
        });

    connectivityController = StreamController<bool>.broadcast();
    mockConnectivityService = MockInternetConnectivityService();
    when(() => mockConnectivityService.isOnline).thenReturn(false);
    when(
      () => mockConnectivityService.onConnectivityChanged,
    ).thenAnswer((_) => connectivityController.stream);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await connectivityController.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
    await Faro.resetForTesting();
  });

  OfflineTransport createTransport({Duration? maxCacheDuration}) {
    return OfflineTransport(
      internetConnectivityService: mockConnectivityService,
      maxCacheDuration: maxCacheDuration,
    );
  }

  File cacheFile() {
    return File('${tempDir.path}/rum_log.json');
  }

  Future<void> waitForCache(String expected) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      if (cacheFile().readAsStringSync() == expected) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(cacheFile().readAsStringSync(), expected);
  }

  String cachedLine(Map<String, dynamic> payload) {
    return jsonEncode({
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'payload': payload,
    });
  }

  Future<OfflineTransport> replay(List<String> lines, String expected) async {
    // Removing this corrupt entry proves replay finished even when all valid
    // entries must remain cached.
    await cacheFile().writeAsString('not-json\n${lines.join('\n')}\n');
    final transport = createTransport();
    connectivityController.add(true);
    await waitForCache(expected);
    return transport;
  }

  FaroTransport collector(
    Future<http.Response> Function(http.Request) respond, {
    int? maxBufferLimit,
  }) {
    final client = MockClient(respond);
    addTearDown(client.close);
    return FaroTransport(
      collectorUrl: 'https://collector.example/collect',
      apiKey: 'test-key',
      sessionIdResolver: () => 'live-session',
      httpClient: client,
      maxBufferLimit: maxBufferLimit,
    );
  }

  Map<String, dynamic> buildEventPayloadJson({
    Map<String, dynamic>? attributes,
  }) {
    return <String, dynamic>{
      'events': [
        <String, dynamic>{
          'name': 'test_event',
          'domain': 'flutter',
          'timestamp': '2026-01-01T00:00:00.000Z',
          'attributes': attributes ?? <String, dynamic>{'key': 'value'},
        },
      ],
    };
  }

  group('OfflineTransport write path:', () {
    test('caches valid payload when offline', () async {
      final transport = createTransport();

      await transport.send(buildEventPayloadJson());

      final lines = await cacheFile().readAsLines();
      expect(lines, hasLength(1));
      final cachedJson = jsonDecode(lines.first) as Map<String, dynamic>;
      expect(cachedJson['timestamp'], isA<int>());
      final cachedPayload = cachedJson['payload'] as Map<String, dynamic>;
      final cachedEvents = cachedPayload['events'] as List<dynamic>;
      expect(cachedEvents, hasLength(1));
      final cachedEvent = cachedEvents.first as Map<String, dynamic>;
      expect(cachedEvent['name'], 'test_event');
    });

    test(
      'does not crash and drops payload with non-encodable attribute',
      () async {
        final transport = createTransport();
        final payloadJson = buildEventPayloadJson(
          attributes: <String, dynamic>{'when': DateTime.now()},
        );

        await expectLater(transport.send(payloadJson), completes);

        // Nothing should be persisted for the dropped payload, and the
        // cache file should not even be created for it.
        expect(cacheFile().existsSync(), isFalse);
      },
    );

    test('does not crash and drops payload with non-finite double', () async {
      final transport = createTransport();
      final payloadJson = buildEventPayloadJson(
        attributes: <String, dynamic>{'value': double.nan},
      );

      await expectLater(transport.send(payloadJson), completes);

      expect(cacheFile().existsSync(), isFalse);
    });

    test(
      'keeps caching valid payloads after a non-encodable payload',
      () async {
        final transport = createTransport();
        final badPayloadJson = buildEventPayloadJson(
          attributes: <String, dynamic>{'object': Object()},
        );

        await transport.send(badPayloadJson);
        await transport.send(buildEventPayloadJson());

        final lines = await cacheFile().readAsLines();
        expect(lines, hasLength(1));
        final cachedJson = jsonDecode(lines.first) as Map<String, dynamic>;
        expect(cachedJson['payload'], isNotNull);
      },
    );
  });

  group('OfflineTransport read path:', () {
    setUp(() {
      when(() => mockConnectivityService.isOnline).thenReturn(true);
    });

    test('skips corrupt cached lines and still sends valid ones when '
        'back online', () async {
      final validLine = jsonEncode(<String, dynamic>{
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'payload': buildEventPayloadJson(),
      });
      final corruptLines = [
        // Not JSON at all.
        'not-json-at-all',
        // Valid JSON but the payload cannot be parsed.
        jsonEncode(<String, dynamic>{
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'payload': 'garbage',
        }),
        // Valid JSON but the timestamp has the wrong type.
        jsonEncode(<String, dynamic>{
          'timestamp': 'not-an-int',
          'payload': buildEventPayloadJson(),
        }),
      ];
      await cacheFile().writeAsString(
        '${corruptLines.join('\n')}\n$validLine\n',
      );

      final mockTransport = MockFaroTransport();
      when(
        () => mockTransport.sendHistoricalAcknowledged(any()),
      ).thenAnswer((_) async => true);
      Faro().transports = [mockTransport];

      createTransport();
      connectivityController.add(true);

      await untilCalled(() => mockTransport.sendHistoricalAcknowledged(any()));
      verify(() => mockTransport.sendHistoricalAcknowledged(any())).called(1);

      // Wait for the cache file rewrite: all corrupt lines are dropped
      // and the successfully sent line is removed.
      const maxAttempts = 100;
      var attempts = 0;
      while (cacheFile().readAsStringSync().isNotEmpty &&
          attempts < maxAttempts) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        attempts++;
      }
      expect(cacheFile().readAsStringSync(), isEmpty);
    });

    test('retains valid lines whose send fails and still drops corrupt '
        'lines', () async {
      final validLine = jsonEncode(<String, dynamic>{
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'payload': buildEventPayloadJson(),
      });
      // A corrupt line must be dropped regardless of send outcome.
      const corruptLine = 'not-json-at-all';
      await cacheFile().writeAsString('$corruptLine\n$validLine\n');

      final mockTransport = MockFaroTransport();
      when(
        () => mockTransport.sendHistoricalAcknowledged(any()),
      ).thenAnswer((_) async => throw Exception('network failure'));
      Faro().transports = [mockTransport];

      createTransport();
      connectivityController.add(true);

      await untilCalled(() => mockTransport.sendHistoricalAcknowledged(any()));

      // The failed-but-valid line is written back; the corrupt line is gone.
      const maxAttempts = 100;
      var attempts = 0;
      while (cacheFile().readAsStringSync() != '$validLine\n' &&
          attempts < maxAttempts) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        attempts++;
      }
      expect(cacheFile().readAsStringSync(), '$validLine\n');
    });

    for (final status in [400, 401, 429, 500, 503]) {
      test('retains payload after HTTP $status', () async {
        var requests = 0;
        Faro().transports = [
          collector((_) async {
            requests++;
            return http.Response('rejected', status);
          }),
        ];
        final line = cachedLine(buildEventPayloadJson());

        await replay([line], '$line\n');

        expect(requests, 1);
      });
    }

    test('retains payload after a network failure', () async {
      var requests = 0;
      Faro().transports = [
        collector((_) async {
          requests++;
          throw http.ClientException('collector unavailable');
        }),
      ];
      final line = cachedLine(buildEventPayloadJson());

      await replay([line], '$line\n');

      expect(requests, 1);
    });

    test('retains payload when the task buffer rejects it', () async {
      var requests = 0;
      Faro().transports = [
        collector((_) async {
          requests++;
          return http.Response('', 200);
        }, maxBufferLimit: 0),
      ];
      final line = cachedLine(buildEventPayloadJson());

      await replay([line], '$line\n');

      expect(requests, 0);
    });

    test('discards payload while data collection is disabled', () async {
      final policy = MockDataCollectionPolicy();
      when(() => policy.isEnabled).thenReturn(false);
      Faro().dataCollectionPolicy = policy;
      var requests = 0;
      Faro().transports = [
        collector((_) async {
          requests++;
          return http.Response('', 200);
        }),
      ];
      final line = cachedLine(buildEventPayloadJson());

      final transport = await replay([line], '');

      when(() => policy.isEnabled).thenReturn(true);
      await transport.replayCachedData();

      expect(requests, 0);
      expect(cacheFile().readAsStringSync(), isEmpty);
    });

    test('discards opted-out payload without a collector', () async {
      final policy = MockDataCollectionPolicy();
      when(() => policy.isEnabled).thenReturn(false);
      Faro().dataCollectionPolicy = policy;
      Faro().transports = [];

      await replay([cachedLine(buildEventPayloadJson())], '');
    });

    test(
      'discards the whole cache if collection stops during replay',
      () async {
        final policy = MockDataCollectionPolicy();
        when(() => policy.isEnabled).thenReturn(true);
        Faro().dataCollectionPolicy = policy;
        final response = Completer<http.Response>();
        final requested = Completer<void>();
        var requests = 0;
        Faro().transports = [
          collector((_) async {
            requests++;
            if (requests == 1) return http.Response('', 503);
            requested.complete();
            return response.future;
          }),
        ];
        final line = cachedLine(buildEventPayloadJson());
        await cacheFile().writeAsString('$line\n$line\n$line\n');
        final transport = createTransport();
        final replaying = transport.replayCachedData();
        try {
          await requested.future.timeout(const Duration(seconds: 2));
          when(() => policy.isEnabled).thenReturn(false);
          when(() => mockConnectivityService.isOnline).thenReturn(false);
          final queuedWrite = transport.send(buildEventPayloadJson());
          response.complete(http.Response('', 503));
          await replaying;
          await queuedWrite;
          expect(cacheFile().readAsStringSync(), isEmpty);

          when(() => policy.isEnabled).thenReturn(true);
          when(() => mockConnectivityService.isOnline).thenReturn(true);
          await transport.replayCachedData();
          expect(requests, 2);
        } finally {
          if (!response.isCompleted) response.complete(http.Response('', 503));
          await replaying;
        }
      },
    );

    test('serializes overlapping replays and a queued write', () async {
      final response = Completer<http.Response>();
      final requested = Completer<void>();
      final names = <String>[];
      Faro().transports = [
        collector((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          names.add(body['events'][0]['attributes']['key'] as String);
          if (names.length == 1) {
            requested.complete();
            return response.future;
          }
          return http.Response('', 200);
        }),
      ];
      final line = cachedLine(buildEventPayloadJson());
      await cacheFile().writeAsString('$line\n');
      final transport = createTransport();
      final first = transport.replayCachedData();
      try {
        await requested.future.timeout(const Duration(seconds: 2));
        final second = transport.replayCachedData();
        when(() => mockConnectivityService.isOnline).thenReturn(false);
        final write = transport.send(
          buildEventPayloadJson(attributes: {'key': 'queued'}),
        );
        when(() => mockConnectivityService.isOnline).thenReturn(true);
        final third = transport.replayCachedData();
        response.complete(http.Response('', 200));
        await Future.wait([
          first,
          second,
          write,
          third,
        ]).timeout(const Duration(seconds: 2));
        expect(names, ['value', 'queued']);
        expect(cacheFile().readAsStringSync(), isEmpty);
      } finally {
        if (!response.isCompleted) response.complete(http.Response('', 200));
        await first;
      }
    });

    test('releases the file lock after a failed cache lookup', () async {
      final line = cachedLine(buildEventPayloadJson());
      await cacheFile().writeAsString('$line\n');
      var attempts = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (_) async {
            if (attempts++ == 0) throw PlatformException(code: 'unavailable');
            return tempDir.path;
          });
      var requests = 0;
      Faro().transports = [
        collector((_) async {
          requests++;
          return http.Response('', 200);
        }),
      ];
      final transport = createTransport();

      await expectLater(transport.replayCachedData(), completes);
      expect(cacheFile().readAsStringSync(), '$line\n');
      await transport.replayCachedData().timeout(const Duration(seconds: 2));

      expect(requests, 1);
      expect(cacheFile().readAsStringSync(), isEmpty);
    });

    test('retains payload without a collector transport', () async {
      Faro().transports = [];
      final line = cachedLine(buildEventPayloadJson());

      await replay([line], '$line\n');
    });

    test(
      'does not treat a custom transport as a collector acknowledgement',
      () async {
        final customTransport = MockTransport();
        when(() => customTransport.send(any())).thenAnswer((_) async {});
        Faro().transports = [customTransport];
        final line = cachedLine(buildEventPayloadJson());

        await replay([line], '$line\n');

        verifyNever(() => customTransport.send(any()));
      },
    );

    test(
      'uses only the first collector, not other replay destinations',
      () async {
        final customTransport = MockTransport();
        final firstCollector = MockFaroTransport();
        final secondCollector = MockFaroTransport();
        when(
          () => firstCollector.sendHistoricalAcknowledged(any()),
        ).thenAnswer((_) async => false);
        Faro().transports = [customTransport, firstCollector, secondCollector];
        final line = cachedLine(buildEventPayloadJson());

        await replay([line], '$line\n');

        verify(
          () => firstCollector.sendHistoricalAcknowledged(any()),
        ).called(1);
        verifyZeroInteractions(customTransport);
        verifyZeroInteractions(secondCollector);
      },
    );

    test('keeps the cache until the collector responds', () async {
      final response = Completer<http.Response>();
      final requested = Completer<void>();
      Faro().transports = [
        collector((_) {
          requested.complete();
          return response.future;
        }),
      ];
      final line = cachedLine(buildEventPayloadJson());
      await cacheFile().writeAsString('$line\n');
      createTransport();
      connectivityController.add(true);

      try {
        await requested.future.timeout(const Duration(seconds: 2));
        expect(cacheFile().readAsStringSync(), '$line\n');
      } finally {
        response.complete(http.Response('', 200));
        await waitForCache('');
      }
    });

    test('still discards expired entries when delivery fails', () async {
      var requests = 0;
      Faro().transports = [
        collector((_) async {
          requests++;
          return http.Response('', 503);
        }),
      ];
      final expired = jsonEncode({
        'timestamp': DateTime.now()
            .subtract(const Duration(days: 2))
            .millisecondsSinceEpoch,
        'payload': buildEventPayloadJson(),
      });
      final valid = cachedLine(buildEventPayloadJson());
      await cacheFile().writeAsString('$expired\n$valid\n');
      createTransport(maxCacheDuration: const Duration(days: 1));

      connectivityController.add(true);
      await waitForCache('$valid\n');

      expect(requests, 1);
    });

    for (final status in [200, 202, 204]) {
      test(
        'removes payload after HTTP $status without invalidating the session',
        () async {
          final requests = <http.Request>[];
          final invalidated = <String>[];
          final transport = collector((request) async {
            requests.add(request);
            return http.Response(
              '',
              status,
              headers: {'x-faro-session-status': 'invalid'},
            );
          })..sessionInvalidatedHandler = invalidated.add;
          Faro().transports = [transport];
          final payload = buildEventPayloadJson()
            ..['meta'] = {
              'session': {'id': 'cached-session'},
            };

          await replay([cachedLine(payload)], '');

          expect(requests, hasLength(1));
          final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
          expect(body['meta']['session']['id'], 'cached-session');
          expect(requests.single.headers['x-faro-session-id'], 'live-session');
          expect(invalidated, isEmpty);
        },
      );
    }

    test(
      'keeps only failed payloads and retries them on the next reconnect',
      () async {
        final names = <String>[];
        Faro().transports = [
          collector((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            names.add(body['events'][0]['attributes']['key'] as String);
            return http.Response('', names.length == 1 ? 503 : 200);
          }),
        ];
        final failed = cachedLine(buildEventPayloadJson());
        final accepted = cachedLine(
          buildEventPayloadJson(attributes: {'key': 'accepted'}),
        );

        await replay([failed, accepted], '$failed\n');
        expect(names, ['value', 'accepted']);

        connectivityController.add(false);
        connectivityController.add(true);
        await waitForCache('');

        expect(names, ['value', 'accepted', 'value']);
      },
    );
  });
}
