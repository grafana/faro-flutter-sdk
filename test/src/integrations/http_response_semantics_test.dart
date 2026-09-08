import 'dart:async';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/integrations/http_tracking_client.dart';
import 'package:faro/src/models/span_record.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/tracing/faro_exporter.dart';
import 'package:faro/src/tracing/span.dart';
import 'package:faro/src/user_actions/telemetry_router.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRequest extends Mock implements HttpClientRequest {}

class _MockResponse extends Mock implements HttpClientResponse {}

class _MockHeaders extends Mock implements HttpHeaders {}

class _RecordingProcessor implements otel.SpanProcessor {
  final ended = <otel.Span>[];

  @override
  Future<void> onStart(otel.Span span, otel.Context? parentContext) async {}
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
  late otel.Tracer tracer;

  setUpAll(() async {
    await otel.OTel.initialize(
      serviceName: 'http-response-test',
      spanProcessor: processor,
      detectPlatformResources: false,
      enableMetrics: false,
      enableLogs: false,
    );
    tracer = otel.OTel.tracer();
  });

  setUp(processor.ended.clear);

  tearDownAll(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    await otel.OTel.reset();
  });

  Future<otel.Span> completeResponse(
    int statusCode, {
    required bool useDone,
    bool existingError = false,
  }) async {
    final recordingSpan = tracer.startSpan(
      'HTTP GET',
      kind: otel.SpanKind.client,
      attributes: otel.OTel.attributesFromMap({'http.method': 'GET'}),
    );
    final span = SpanProvider().getSpan(recordingSpan, otel.Context.current);
    if (existingError) {
      span.setStatus(SpanStatusCode.error, message: 'previous failure');
      span.setAttribute('error.type', 'previous_failure');
    }

    final request = _MockRequest();
    final response = _MockResponse();
    final requestHeaders = _MockHeaders();
    final responseHeaders = _MockHeaders();
    when(() => request.headers).thenReturn(requestHeaders);
    when(() => request.method).thenReturn('GET');
    when(() => request.uri).thenReturn(Uri.parse('https://example.com/test'));
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

    final tracked = FaroTrackingHttpClientRequest(request, httpSpan: span);
    final trackedResponse = useDone
        ? await tracked.done
        : await tracked.close();
    expect(recordingSpan.isEnded, isFalse);
    await trackedResponse.drain<void>();
    expect(processor.ended, [same(recordingSpan)]);
    return recordingSpan;
  }

  Map<String, dynamic> attributesOf(Map<String, dynamic> json) => {
    for (final attribute in json['attributes'] as List<dynamic>)
      attribute['key'] as String: attribute['value'],
  };

  for (final useDone in [false, true]) {
    group(useDone ? 'done' : 'close', () {
      for (final statusCode in [200, 204, 302, 400, 404, 499, 500, 599]) {
        test('serializes HTTP $statusCode status and error type', () async {
          final span = await completeResponse(statusCode, useDone: useDone);
          final json = SpanRecord(otelReadOnlySpan: span).getSpan().toJson();
          final attributes = attributesOf(json);

          expect(json['status'], {'code': statusCode >= 400 ? 2 : 0});
          expect(attributes['http.status_code'], {'intValue': statusCode});
          if (statusCode >= 400) {
            expect(attributes['error.type'], {'stringValue': '$statusCode'});
          } else {
            expect(attributes, isNot(contains('error.type')));
          }
        });
      }

      for (final statusCode in [200, 404, 500]) {
        test(
          'HTTP $statusCode preserves a previously recorded error',
          () async {
            final span = await completeResponse(
              statusCode,
              useDone: useDone,
              existingError: true,
            );
            final json = SpanRecord(otelReadOnlySpan: span).getSpan().toJson();

            expect(json['status'], {'code': 2, 'message': 'previous failure'});
            expect(attributesOf(json)['error.type'], {
              'stringValue': 'previous_failure',
            });
          },
        );
      }
    });
  }

  for (final statusCode in [200, 404, 500]) {
    test('exports correlated HTTP $statusCode event and span', () async {
      final span = await completeResponse(statusCode, useDone: false);
      final router = _RecordingRouter();
      await FaroExporter(telemetryRouter: router).export([span]);

      final event = router.items
          .singleWhere((item) => item.asEvent != null)
          .asEvent!;
      final record = SpanRecord(otelReadOnlySpan: span);
      expect(event.name, 'faro.tracing.fetch');
      expect(event.trace, record.getFaroSpanContext());
      expect(
        int.parse(event.attributes!['duration_ns']!),
        greaterThanOrEqualTo(0),
      );
      if (statusCode >= 400) {
        expect(event.attributes!['error.type'], '$statusCode');
      } else {
        expect(event.attributes, isNot(contains('error.type')));
      }
      expect(router.items, hasLength(2));
    });
  }
}
