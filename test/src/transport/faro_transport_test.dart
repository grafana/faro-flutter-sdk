import 'package:faro/src/data_collection_policy.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/transport/faro_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

class _MockDataCollectionPolicy extends Mock implements DataCollectionPolicy {}

void main() {
  group('FaroTransport:', () {
    late List<http.Request> captured;
    late MockClient client;

    setUp(() {
      captured = [];
      client = MockClient((request) async {
        captured.add(request);
        return http.Response('', 200);
      });
    });

    tearDown(() {
      // The data-collection gate reads the global Faro singleton; reset it so
      // tests stay isolated.
      Faro().dataCollectionPolicy = null;
    });

    FaroTransport buildTransport({
      SessionIdResolver? sessionIdResolver,
      Map<String, String>? headers,
    }) {
      return FaroTransport(
        collectorUrl: 'https://collector.example/collect',
        apiKey: 'test-key',
        sessionIdResolver: sessionIdResolver ?? () => 'session-id',
        headers: headers,
        httpClient: client,
      );
    }

    Map<String, dynamic> payload() => {
      'meta': {
        'session': {'id': 'body-id'},
      },
      'events': <dynamic>[],
    };

    group('request:', () {
      test('posts the encoded payload to the collector url', () async {
        await buildTransport().send(payload());

        final request = captured.single;
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://collector.example/collect');
        expect(
          request.body,
          '{"meta":{"session":{"id":"body-id"}},"events":[]}',
        );
      });

      test('sends content type, api key and merges custom headers', () async {
        await buildTransport(
          headers: {'x-custom': 'custom-value'},
        ).send(payload());

        final headers = captured.single.headers;
        expect(headers['x-api-key'], 'test-key');
        expect(headers['content-type'], contains('application/json'));
        expect(headers['x-custom'], 'custom-value');
      });
    });

    group('x-faro-session-id header:', () {
      // The payload body always carries a fixed session id; the header should
      // follow the live resolver instead, not this value.
      test('uses the live resolver id, not the payload body', () async {
        final transport = buildTransport(sessionIdResolver: () => 'live-id');
        await transport.send(payload());

        expect(captured.single.headers['x-faro-session-id'], 'live-id');
      });

      test('reflects a rotated session id on subsequent sends', () async {
        var current = 'session-1';
        final transport = buildTransport(sessionIdResolver: () => current);

        await transport.send(payload());
        current = 'session-2';
        await transport.send(payload());

        expect(captured.map((r) => r.headers['x-faro-session-id']).toList(), [
          'session-1',
          'session-2',
        ]);
      });
    });

    group('data collection:', () {
      test('does not send when data collection is disabled', () async {
        final policy = _MockDataCollectionPolicy();
        when(() => policy.isEnabled).thenReturn(false);
        Faro().dataCollectionPolicy = policy;

        await buildTransport().send(payload());

        expect(captured, isEmpty);
      });
    });
  });
}
