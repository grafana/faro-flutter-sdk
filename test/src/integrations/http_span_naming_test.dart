import 'dart:async';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/integrations/http_tracking_client.dart';
import 'package:faro/src/integrations/http_tracking_filter.dart';
import 'package:faro/src/models/span_record.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_id_provider.dart';
import 'package:faro/src/tracing/faro_exporter.dart';
import 'package:faro/src/tracing/faro_tracer.dart';
import 'package:faro/src/user_actions/telemetry_router.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements HttpClient {}

class _MockRequest extends Mock implements HttpClientRequest {}

class _MockResponse extends Mock implements HttpClientResponse {}

class _MockHeaders extends Mock implements HttpHeaders {}

class _RecordingProcessor implements otel.SpanProcessor {
  final ended = <otel.Span>[];
  final started = <otel.Span>[];

  @override
  Future<void> onStart(otel.Span span, otel.Context? parentContext) async =>
      started.add(span);
  @override
  Future<void> onEnd(otel.Span span) async => ended.add(span);
  @override
  Future<void> onNameUpdate(otel.Span span, String newName) async {}
  @override
  Future<void> shutdown() async {}
  @override
  Future<void> forceFlush() async {}
}

class _RecordingRouter implements TelemetryRouter {
  final items = <TelemetryItem>[];

  @override
  void ingest(
    TelemetryItem item, {
    required SessionActivityKind activity,
    bool skipBuffer = false,
  }) {
    items.add(item);
  }
}

void main() {
  final processor = _RecordingProcessor();

  setUpAll(() async {
    registerFallbackValue(Uri.parse('https://example.com'));
    await otel.OTel.initialize(
      serviceName: 'http-naming-test',
      spanProcessor: processor,
      detectPlatformResources: false,
      enableMetrics: false,
      enableLogs: false,
    );
  });

  setUp(() {
    pod.clearScope(tracerScope);
    processor.started.clear();
    processor.ended.clear();
  });

  tearDownAll(() async {
    pod.clearScope(tracerScope);
    // ignore: invalid_use_of_visible_for_testing_member
    await otel.OTel.reset();
  });

  Future<void> verifyRequest(
    String method,
    Future<HttpClientRequest> Function(FaroHttpTrackingClient, Uri) open, {
    String path = '/users/123?view=details',
    int statusCode = 200,
    bool known = true,
  }) async {
    final url = Uri.parse('http://example.com$path');
    final innerClient = _MockClient();
    final filter = HttpTrackingFilter()
      ..configure(collectorUrl: null, ignoreUrls: null);
    final client = FaroHttpTrackingClient(innerClient, trackingFilter: filter);
    final request = _MockRequest();
    final response = _MockResponse();
    final requestHeaders = _MockHeaders();
    final responseHeaders = _MockHeaders();
    when(() => request.headers).thenReturn(requestHeaders);
    when(() => request.method).thenReturn(method);
    when(() => request.uri).thenReturn(url);
    when(() => request.contentLength).thenReturn(0);
    when(request.close).thenAnswer((_) async => response);
    when(() => request.done).thenAnswer((_) async => response);
    when(() => response.statusCode).thenReturn(statusCode);
    when(() => response.headers).thenReturn(responseHeaders);
    when(() => responseHeaders.contentLength).thenReturn(0);
    when(() => responseHeaders.contentType).thenReturn(null);
    when(
      () => response.listen(
        any(),
        onError: any(named: 'onError'),
        onDone: any(named: 'onDone'),
        cancelOnError: any(named: 'cancelOnError'),
      ),
    ).thenAnswer((invocation) {
      return const Stream<List<int>>.empty().listen(
        invocation.positionalArguments[0] as void Function(List<int>)?,
        onError: invocation.namedArguments[#onError] as Function?,
        onDone: invocation.namedArguments[#onDone] as void Function()?,
        cancelOnError: invocation.namedArguments[#cancelOnError] as bool?,
      );
    });

    when(
      () => innerClient.openUrl(any(), any()),
    ).thenAnswer((_) async => request);

    await Faro().startSpan('application-operation', (parent) async {
      final tracked = await open(client, url);
      final span = processor.started.last;
      final record = SpanRecord(otelReadOnlySpan: span);
      final expectedName = known ? method : 'HTTP $method';
      // Inspect before response completion: naming and method are request data.
      expect(span.name, expectedName);
      expect(
        record.getFaroEventAttributes()['http.request.method'],
        known ? method : isNull,
      );
      verify(() => innerClient.openUrl(method, url)).called(1);
      verify(
        () => requestHeaders.add(
          'traceparent',
          '00-${span.spanContext.traceId}-${span.spanContext.spanId}-01',
        ),
      ).called(1);
      expect(span.isEnded, isFalse);

      final response = await tracked.close();
      await response.drain<void>();
      expect(processor.ended, [same(span)]);

      final router = _RecordingRouter();
      await FaroExporter(telemetryRouter: router).export([span]);
      final exported = router.items
          .singleWhere((item) => item.asSpan != null)
          .asSpan!
          .getSpan()
          .toJson();
      final attributes = <String, dynamic>{
        for (final attribute in exported['attributes'] as List<dynamic>)
          attribute['key'] as String: attribute['value'],
      };
      expect(exported['name'], expectedName);
      expect(exported['kind'], 3);
      expect(exported['traceId'], parent.traceId);
      expect(exported['parentSpanId'], parent.spanId);
      expect(exported['spanId'], isNot(parent.spanId));
      expect(
        attributes['http.request.method'],
        known ? {'stringValue': method} : isNull,
      );
      expect(attributes['http.method'], {'stringValue': method});
      expect(attributes['http.url'], {'stringValue': url.toString()});
      expect(attributes, isNot(contains('url.template')));
      expect(exported['status'], {'code': statusCode >= 400 ? 2 : 0});
      expect(
        attributes['error.type'],
        statusCode >= 400 ? {'stringValue': '$statusCode'} : isNull,
      );

      final event = router.items
          .singleWhere((item) => item.asEvent != null)
          .asEvent!;
      final sessionId = pod.resolve(sessionIdProviderProvider).sessionId;
      expect(event.name, 'faro.tracing.fetch');
      expect(event.trace, {
        'trace_id': exported['traceId'],
        'span_id': exported['spanId'],
      });
      expect(event.attributes!['http.request.method'], known ? method : isNull);
      expect(event.attributes!['http.method'], method);
      expect(event.attributes!['session.id'], sessionId);
      expect(attributes['session.id'], {'stringValue': sessionId});
      final duration =
          BigInt.parse(exported['endTimeUnixNano'] as String) -
          BigInt.parse(exported['startTimeUnixNano'] as String);
      expect(BigInt.parse(event.attributes!['duration_ns']!), duration);
      expect(duration >= BigInt.zero, isTrue);
      expect(router.items, hasLength(2));
    });
  }

  for (final method in [
    'GET',
    'HEAD',
    'POST',
    'PUT',
    'DELETE',
    'CONNECT',
    'OPTIONS',
    'TRACE',
    'PATCH',
    'QUERY',
  ]) {
    test('openUrl exports $method without a target', () async {
      await verifyRequest(method, (client, url) => client.openUrl(method, url));
    });
    test('open exports $method without a target', () async {
      await verifyRequest(
        method,
        (client, url) =>
            client.open(method, url.host, url.port, '${url.path}?${url.query}'),
      );
    });
  }

  final wrappers =
      <String, Future<HttpClientRequest> Function(FaroHttpTrackingClient, Uri)>{
        'get': (c, u) => c.get(u.host, u.port, '${u.path}?${u.query}'),
        'getUrl': (c, u) => c.getUrl(u),
        'post': (c, u) => c.post(u.host, u.port, '${u.path}?${u.query}'),
        'postUrl': (c, u) => c.postUrl(u),
        'head': (c, u) => c.head(u.host, u.port, '${u.path}?${u.query}'),
        'headUrl': (c, u) => c.headUrl(u),
        'put': (c, u) => c.put(u.host, u.port, '${u.path}?${u.query}'),
        'putUrl': (c, u) => c.putUrl(u),
        'delete': (c, u) => c.delete(u.host, u.port, '${u.path}?${u.query}'),
        'deleteUrl': (c, u) => c.deleteUrl(u),
        'patch': (c, u) => c.patch(u.host, u.port, '${u.path}?${u.query}'),
        'patchUrl': (c, u) => c.patchUrl(u),
      };
  for (final entry in wrappers.entries) {
    test('${entry.key} uses a canonical method', () async {
      await verifyRequest(
        entry.key.replaceAll('Url', '').toUpperCase(),
        entry.value,
      );
    });
  }

  for (final method in ['GET', 'POST']) {
    for (final status in [200, 404, 500]) {
      test('$method name ignores URL and response $status', () async {
        await verifyRequest(
          method,
          (c, u) => c.openUrl(method, u),
          path: '/orders/another-id?sort=recent',
          statusCode: status,
        );
      });
    }
  }

  // This scoped change must not normalize arbitrary caller-provided methods.
  for (final method in ['CUSTOM', 'get', 'GeT']) {
    test('preserves existing behavior for caller method $method', () async {
      await verifyRequest(method, (c, u) => c.openUrl(method, u), known: false);
    });
  }
}
