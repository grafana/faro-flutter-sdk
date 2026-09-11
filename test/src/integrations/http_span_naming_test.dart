import 'dart:async';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/integrations/http_tracking_client.dart';
import 'package:faro/src/integrations/http_tracking_filter.dart';
import 'package:faro/src/models/span_record.dart';
import 'package:faro/src/models/trace/trace_resource_spans.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_id_provider.dart';
import 'package:faro/src/tracing/faro_exporter.dart';
import 'package:faro/src/tracing/faro_tracer.dart';
import 'package:faro/src/user_actions/telemetry_router.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:faro/src/util/constants.dart';
import 'package:faro/src/webview/faro_webview_bridge.dart';
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

  test(
    'serializes application parent and HTTP child in separate scopes',
    () async {
      await Faro().startSpan('checkout', (parent) {
        final child = pod
            .resolve(faroHttpTracerProvider)
            .startSpanManual('GET');
        child.end();
      });
      await Future<void>.delayed(Duration.zero);
      final batch = TraceResourceSpans();
      for (final span in processor.ended) {
        batch.addSpan(SpanRecord(otelReadOnlySpan: span));
      }
      final scopes = batch.toJson()['scopeSpans'] as List;
      final http = scopes.singleWhere(
        (s) => s['scope']['name'] == 'faro-mobile-flutter.http',
      );
      final application = scopes.singleWhere(
        (s) => s['scope']['name'] == 'faro-mobile-flutter',
      );
      expect(scopes, hasLength(2));
      expect(http['scope']['version'], FaroConstants.sdkVersion);
      expect(application['scope']['version'], FaroConstants.sdkVersion);
      final child = http['spans'].single;
      final parent = application['spans'].single;
      expect(child['traceId'], parent['traceId']);
      expect(child['parentSpanId'], parent['spanId']);
    },
  );

  for (final name in ['WebView', 'CustomWebView']) {
    test('exports $name lifetime as a custom event', () async {
      final bridge = FaroWebViewBridge();
      bridge.instrumentedUrl(Uri.parse('https://example.com'), spanName: name);
      bridge.end();
      await Future<void>.delayed(Duration.zero);
      final router = _RecordingRouter();
      await FaroExporter(telemetryRouter: router).export(processor.ended);
      final record = router.items.singleWhere((i) => i.asSpan != null).asSpan!;
      final event = router.items.singleWhere((i) => i.asEvent != null).asEvent!;
      expect(record.getScope().toJson()['name'], 'faro-mobile-flutter');
      expect(record.name(), name);
      expect(event.name, 'span.$name');
      expect(event.attributes!['http.request.method'], 'GET');
      expect(event.attributes!['component'], 'webview');
      expect(event.attributes, contains('duration_ns'));
      expect(event.trace, record.getFaroSpanContext());
    });
  }

  Future<void> verifyRequest(
    String method,
    Future<HttpClientRequest> Function(FaroHttpTrackingClient, Uri) open, {
    String path = '/users/123?view=details',
    int statusCode = 200,
    bool known = true,
    String? normalizedMethod,
    String? fullUrl,
    String? sanitizedUrl,
  }) async {
    final url = Uri.parse(fullUrl ?? 'http://example.com$path');
    final innerClient = _MockClient();
    final filter = HttpTrackingFilter()
      ..configure(collectorUrl: null, ignoreUrls: null);
    final client = FaroHttpTrackingClient(
      innerClient,
      trackingFilter: filter,
      startHttpSpan: pod.resolve(faroHttpTracerProvider).startSpanManual,
    );
    final request = _MockRequest();
    final response = _MockResponse();
    final requestHeaders = _MockHeaders();
    final responseHeaders = _MockHeaders();
    when(() => request.headers).thenReturn(requestHeaders);
    when(() => request.method).thenReturn(method);
    when(() => request.uri).thenReturn(url);
    when(() => innerClient.userAgent).thenReturn('compatibility-test-agent');
    when(() => request.contentLength).thenReturn(123);
    when(request.close).thenAnswer((_) async => response);
    when(() => request.done).thenAnswer((_) async => response);
    when(() => response.statusCode).thenReturn(statusCode);
    when(() => response.headers).thenReturn(responseHeaders);
    when(() => responseHeaders.contentLength).thenReturn(456);
    when(() => responseHeaders.contentType).thenReturn(ContentType.json);
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
      final recordedMethod = normalizedMethod ?? method;
      final expectedName = known ? recordedMethod : 'HTTP $method';
      // Inspect before response completion: naming and method are request data.
      expect(span.name, expectedName);
      expect(
        record.getFaroEventAttributes()['http.request.method'],
        known ? recordedMethod : isNull,
      );
      verify(() => innerClient.openUrl(method, url)).called(1);
      verify(
        () => requestHeaders.add(
          'traceparent',
          '00-${span.spanContext.traceId}-${span.spanContext.spanId}-01',
        ),
      ).called(1);
      expect(span.isEnded, isFalse);
      final initial = record.getFaroEventAttributes();
      expect(initial['http.url'], sanitizedUrl ?? url.toString());
      expect(initial['http.host'], url.host);
      expect(initial['http.scheme'], url.scheme);
      expect(initial, isNot(contains('http.status_code')));
      expect(initial, isNot(contains('http.response.status_code')));
      initial['http.url'] = 'mutated-by-consumer';
      expect(
        record.getFaroEventAttributes()['http.url'],
        sanitizedUrl ?? url.toString(),
      );

      final response = await tracked.close();
      expect(
        (response as FaroTrackingHttpResponse).userAttributes['url'],
        sanitizedUrl ?? url.toString(),
      );
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
      expect(record.getScope().toJson()['name'], 'faro-mobile-flutter.http');
      expect(record.getScope().toJson()['version'], FaroConstants.sdkVersion);
      expect(exported['kind'], 3);
      expect(exported['traceId'], parent.traceId);
      expect(exported['parentSpanId'], parent.spanId);
      expect(exported['spanId'], isNot(parent.spanId));
      expect(attributes['http.request.method'], {
        'stringValue': recordedMethod,
      });
      expect(attributes, isNot(contains('http.method')));
      expect(
        attributes['http.request.method_original'],
        normalizedMethod != null ? {'stringValue': method} : isNull,
      );
      expect(attributes['url.full'], {
        'stringValue': sanitizedUrl ?? url.toString(),
      });
      expect(attributes['server.address'], {'stringValue': url.host});
      expect(attributes['server.port'], {'intValue': url.port});
      expect(attributes['http.response.status_code'], {'intValue': statusCode});
      for (final key in [
        'http.url',
        'http.host',
        'http.scheme',
        'http.status_code',
        'http.user_agent',
        'http.request_size',
        'http.response_size',
        'http.content_type',
      ]) {
        expect(attributes, isNot(contains(key)));
      }
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
      expect(
        event.attributes!['http.request.method'],
        known ? recordedMethod : isNull,
      );
      expect(event.attributes!['http.method'], recordedMethod);
      expect(event.attributes!['http.url'], sanitizedUrl ?? url.toString());
      expect(event.attributes!['http.host'], url.host);
      expect(event.attributes!['http.scheme'], url.scheme);
      expect(event.attributes!['http.status_code'], '$statusCode');
      expect(event.attributes!['http.user_agent'], 'compatibility-test-agent');
      expect(event.attributes!['http.request_size'], '123');
      expect(event.attributes!['http.response_size'], '456');
      expect(event.attributes!['http.content_type'], '${ContentType.json}');
      for (final key in [
        'url.full',
        'server.address',
        'server.port',
        'http.response.status_code',
      ]) {
        expect(event.attributes, isNot(contains(key)));
      }
      expect(event.attributes!.values, everyElement(isA<String>()));
      expect(
        event.attributes!['http.request.method_original'],
        normalizedMethod != null ? method : isNull,
      );
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

  for (final url in [
    'http://example.com/path',
    'https://example.com/path',
    'https://example.com:8443/path',
    'http://127.0.0.1:8080/path',
    'https://[::1]:8443/path',
  ]) {
    test('exports stable authority for $url', () async {
      await verifyRequest('GET', (c, u) => c.getUrl(u), fullUrl: url);
    });
  }

  test('redacts span and event URLs without changing the request', () async {
    await verifyRequest(
      'GET',
      (c, u) => c.getUrl(u),
      fullUrl:
          'https://alice:example-password@example.com/path?'
          'sig=example-signature&token=example-token&password=example-password'
          '&api_key=example-key&color=blue#section',
      sanitizedUrl:
          'https://REDACTED:REDACTED@example.com/path?'
          'sig=REDACTED&token=REDACTED&password=REDACTED&api_key=REDACTED'
          '&color=blue#section',
    );
  });

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
  for (final method in ['CUSTOM', 'custom', 'CuStOm']) {
    test('preserves existing behavior for caller method $method', () async {
      await verifyRequest(method, (c, u) => c.openUrl(method, u), known: false);
    });
  }
  for (final pair in [
    ('get', 'GET'),
    ('GeT', 'GET'),
    ('post', 'POST'),
    ('PoSt', 'POST'),
    ('head', 'HEAD'),
    ('put', 'PUT'),
    ('delete', 'DELETE'),
    ('connect', 'CONNECT'),
    ('options', 'OPTIONS'),
    ('trace', 'TRACE'),
    ('patch', 'PATCH'),
    ('query', 'QUERY'),
  ]) {
    final (input, canonical) = pair;
    for (final useOpenUrl in [true, false]) {
      test('${useOpenUrl ? 'openUrl' : 'open'} normalizes $input', () async {
        await verifyRequest(
          input,
          (client, url) => useOpenUrl
              ? client.openUrl(input, url)
              : client.open(
                  input,
                  url.host,
                  url.port,
                  '${url.path}?${url.query}',
                ),
          normalizedMethod: canonical,
        );
      });
    }
  }

  for (final input in ['get', 'GeT', 'post', 'PoSt']) {
    test('records the actual wire method for $input', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = FaroHttpTrackingClient(
        HttpClient()..findProxy = (_) => 'DIRECT',
        startHttpSpan: pod.resolve(faroHttpTracerProvider).startSpanManual,
        trackingFilter: HttpTrackingFilter()
          ..configure(collectorUrl: null, ignoreUrls: null),
      );
      addTearDown(() async {
        client.close(force: true);
        await server.close(force: true);
      });
      final received = Completer<String>();
      server.listen((request) async {
        received.complete(request.method);
        await request.drain<void>();
        request.response.statusCode = 200;
        await request.response.close();
      });
      final request = await client.openUrl(
        input,
        Uri.parse('http://127.0.0.1:${server.port}/users/123'),
      );
      final response = await request.close();
      await response.drain<void>();
      final wireMethod = await received.future;
      expect(wireMethod, input.toUpperCase());
      final record = SpanRecord(otelReadOnlySpan: processor.ended.single);
      expect(record.name(), wireMethod);
      expect(
        record.getFaroEventAttributes()['http.request.method'],
        wireMethod,
      );
      expect(record.getFaroEventAttributes()['http.method'], wireMethod);
      expect(
        record.getFaroEventAttributes()['http.request.method_original'],
        input,
      );
    });
  }
}
