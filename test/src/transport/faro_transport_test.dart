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
      SessionInvalidatedHandler? onSessionInvalidated,
      Map<String, String>? headers,
    }) {
      final transport = FaroTransport(
        collectorUrl: 'https://collector.example/collect',
        apiKey: 'test-key',
        sessionIdResolver: sessionIdResolver ?? () => 'session-id',
        headers: headers,
        httpClient: client,
      );
      if (onSessionInvalidated != null) {
        transport.sessionInvalidatedHandler = onSessionInvalidated;
      }
      return transport;
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

    group('session invalidation response:', () {
      test('reports an invalid session from an accepted response', () async {
        client = MockClient((request) async {
          captured.add(request);
          return http.Response(
            '',
            202,
            headers: {'X-Faro-Session-Status': 'invalid'},
          );
        });
        final invalidatedSessionIds = <String>[];

        await buildTransport(
          sessionIdResolver: () => 'session-1',
          onSessionInvalidated: invalidatedSessionIds.add,
        ).send(payload());

        expect(invalidatedSessionIds, ['session-1']);
      });

      test('historical sends do not invalidate the live session', () async {
        client = MockClient((request) async {
          captured.add(request);
          return http.Response(
            '',
            202,
            headers: {'X-Faro-Session-Status': 'invalid'},
          );
        });
        final invalidatedSessionIds = <String>[];

        await buildTransport(
          sessionIdResolver: () => 'live-session',
          onSessionInvalidated: invalidatedSessionIds.add,
        ).sendHistorical(payload());

        expect(captured, hasLength(1));
        expect(invalidatedSessionIds, isEmpty);
      });

      test('reports the session id used by the request', () async {
        var currentSessionId = 'session-1';
        client = MockClient((request) async {
          captured.add(request);
          currentSessionId = 'session-2';
          return http.Response(
            '',
            202,
            headers: {'x-faro-session-status': 'invalid'},
          );
        });
        final invalidatedSessionIds = <String>[];

        await buildTransport(
          sessionIdResolver: () => currentSessionId,
          onSessionInvalidated: invalidatedSessionIds.add,
        ).send(payload());

        expect(captured.single.headers['x-faro-session-id'], 'session-1');
        expect(invalidatedSessionIds, ['session-1']);
      });

      test('reports an overridden request session id', () async {
        client = MockClient((request) async {
          captured.add(request);
          return http.Response(
            '',
            202,
            headers: {'X-Faro-Session-Status': 'invalid'},
          );
        });
        final invalidatedSessionIds = <String>[];

        await buildTransport(
          sessionIdResolver: () => 'resolver-session',
          headers: {'X-Faro-Session-Id': 'header-session'},
          onSessionInvalidated: invalidatedSessionIds.add,
        ).send(payload());

        expect(captured.single.headers['x-faro-session-id'], 'header-session');
        expect(invalidatedSessionIds, ['header-session']);
      });

      test('ignores the header on a non-accepted response', () async {
        client = MockClient((request) async {
          captured.add(request);
          return http.Response(
            '',
            200,
            headers: {'X-Faro-Session-Status': 'invalid'},
          );
        });
        final invalidatedSessionIds = <String>[];

        await buildTransport(
          onSessionInvalidated: invalidatedSessionIds.add,
        ).send(payload());

        expect(invalidatedSessionIds, isEmpty);
      });

      test('ignores accepted responses without an invalid status', () async {
        client = MockClient((request) async {
          captured.add(request);
          return http.Response(
            '',
            202,
            headers: {'X-Faro-Session-Status': 'valid'},
          );
        });
        final invalidatedSessionIds = <String>[];

        await buildTransport(
          onSessionInvalidated: invalidatedSessionIds.add,
        ).send(payload());

        expect(invalidatedSessionIds, isEmpty);
      });

      test('ignores accepted responses without the status header', () async {
        client = MockClient((request) async {
          captured.add(request);
          return http.Response('', 202);
        });
        final invalidatedSessionIds = <String>[];

        await buildTransport(
          onSessionInvalidated: invalidatedSessionIds.add,
        ).send(payload());

        expect(invalidatedSessionIds, isEmpty);
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
