import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:faro/src/faro.dart';
import 'package:faro/src/offline_transport/internet_connectivity_service.dart';
import 'package:faro/src/offline_transport/offline_transport.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockInternetConnectivityService extends Mock
    implements InternetConnectivityService {}

class MockTransport extends Mock implements BaseTransport {}

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

  OfflineTransport createTransport() {
    return OfflineTransport(
      internetConnectivityService: mockConnectivityService,
    );
  }

  File cacheFile() {
    return File('${tempDir.path}/rum_log.json');
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

      final mockTransport = MockTransport();
      when(() => mockTransport.send(any())).thenAnswer((_) async {});
      Faro().transports = [mockTransport];

      createTransport();
      connectivityController.add(true);

      await untilCalled(() => mockTransport.send(any()));
      verify(() => mockTransport.send(any())).called(1);

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

      final mockTransport = MockTransport();
      when(
        () => mockTransport.send(any()),
      ).thenAnswer((_) async => throw Exception('network failure'));
      Faro().transports = [mockTransport];

      createTransport();
      connectivityController.add(true);

      await untilCalled(() => mockTransport.send(any()));

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
  });
}
