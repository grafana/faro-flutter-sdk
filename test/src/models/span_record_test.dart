// ignore_for_file: avoid_redundant_argument_values

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/models/span_record.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoOpProcessor implements otel.SpanProcessor {
  @override
  Future<void> onStart(otel.Span span, otel.Context? parentContext) async {}
  @override
  Future<void> onEnd(otel.Span span) async {}
  @override
  Future<void> onNameUpdate(otel.Span span, String newName) async {}
  @override
  Future<void> shutdown() async {}
  @override
  Future<void> forceFlush() async {}
}

void main() {
  late otel.Tracer tracer;

  setUpAll(() async {
    await otel.OTel.initialize(
      serviceName: 'test-service',
      spanProcessor: _NoOpProcessor(),
      detectPlatformResources: false,
      enableMetrics: false,
      enableLogs: false,
    );
    tracer = otel.OTel.tracer();
  });

  tearDownAll(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    await otel.OTel.reset();
  });

  otel.Span makeEndedSpan(
    String name, {
    Map<String, Object> attributes = const {},
    Duration? duration,
  }) {
    final span = tracer.startSpan(
      name,
      attributes:
          attributes.isEmpty ? null : otel.OTel.attributesFromMap(attributes),
    );
    if (duration != null) {
      // Best-effort: real wall-clock duration in test.
      // We can't deterministically force startTime/endTime, but we ensure
      // endTime is at least `duration` after startTime via a delay isn't
      // practical in a unit test; instead, we just end the span and trust
      // wall-clock has advanced (the span will report a non-zero duration).
    }
    span.end();
    return span;
  }

  group('SpanRecord:', () {
    group('getFaroEventName:', () {
      test('returns "faro.tracing.fetch" for HTTP spans with http.scheme', () {
        final span = makeEndedSpan(
          'HTTP GET',
          attributes: const {'http.scheme': 'https'},
        );
        final spanRecord = SpanRecord(otelReadOnlySpan: span);

        expect(spanRecord.getFaroEventName(), 'faro.tracing.fetch');
      });

      test('returns "faro.tracing.fetch" for HTTP spans with http.method', () {
        final span = makeEndedSpan(
          'HTTP POST',
          attributes: const {'http.method': 'POST'},
        );
        final spanRecord = SpanRecord(otelReadOnlySpan: span);

        expect(spanRecord.getFaroEventName(), 'faro.tracing.fetch');
      });

      test(
        'returns "faro.tracing.fetch" for HTTP spans with both attributes',
        () {
          final span = makeEndedSpan(
            'HTTP GET',
            attributes: const {'http.scheme': 'https', 'http.method': 'GET'},
          );
          final spanRecord = SpanRecord(otelReadOnlySpan: span);

          expect(spanRecord.getFaroEventName(), 'faro.tracing.fetch');
        },
      );

      test('returns "span.{name}" for non-HTTP spans', () {
        const spanName = 'database-query';
        final span = makeEndedSpan(spanName);
        final spanRecord = SpanRecord(otelReadOnlySpan: span);

        expect(spanRecord.getFaroEventName(), 'span.$spanName');
      });

      test('handles complex span names correctly', () {
        const spanName =
            'my-service.complex-operation-with-dashes_and_underscores';
        final span = makeEndedSpan(spanName);
        final spanRecord = SpanRecord(otelReadOnlySpan: span);

        expect(spanRecord.getFaroEventName(), 'span.$spanName');
      });
    });

    group('name:', () {
      test('returns the span name from OpenTelemetry span', () {
        const expectedName = 'test-span-name';
        final span = makeEndedSpan(expectedName);
        final spanRecord = SpanRecord(otelReadOnlySpan: span);

        expect(spanRecord.name(), expectedName);
      });
    });

    group('getFaroEventAttributes:', () {
      test('sanitizes attribute values by removing surrounding quotes', () {
        final span = makeEndedSpan(
          'test',
          attributes: const {
            'url': '"https://example.com"',
            'method': 'GET',
            'status': '"200"',
          },
        );
        final spanRecord = SpanRecord(otelReadOnlySpan: span);

        final result = spanRecord.getFaroEventAttributes();

        expect(result['url'], 'https://example.com');
        expect(result['method'], 'GET');
        expect(result['status'], '200');
      });

      test('preserves values without quotes', () {
        final span = makeEndedSpan(
          'test',
          attributes: const {'count': '42', 'enabled': 'true'},
        );
        final spanRecord = SpanRecord(otelReadOnlySpan: span);

        final result = spanRecord.getFaroEventAttributes();

        expect(result['count'], '42');
        expect(result['enabled'], 'true');
      });

      test('handles single quote correctly', () {
        // Empty strings aren't allowed by dartastic Attributes; use a value
        // that is just a single quote character.
        final span = makeEndedSpan(
          'test',
          attributes: const {'single_quote': '"'},
        );
        final spanRecord = SpanRecord(otelReadOnlySpan: span);

        final result = spanRecord.getFaroEventAttributes();

        expect(result['single_quote'], '"');
      });

      test('includes duration when span has ended', () {
        final span = makeEndedSpan(
          'test',
          attributes: const {'test.key': 'test.value'},
        );
        final spanRecord = SpanRecord(otelReadOnlySpan: span);

        final result = spanRecord.getFaroEventAttributes();

        expect(result.containsKey('duration_ns'), isTrue);
        final durationNs = int.parse(result['duration_ns']!);
        expect(durationNs, greaterThanOrEqualTo(0));
        expect(result['test.key'], 'test.value');
      });

      test('includes all original attributes plus duration', () {
        final span = makeEndedSpan(
          'test',
          attributes: const {'attr1': 'value1', 'attr2': 42, 'attr3': true},
        );
        final spanRecord = SpanRecord(otelReadOnlySpan: span);

        final result = spanRecord.getFaroEventAttributes();

        expect(result['attr1'], 'value1');
        expect(result['attr2'], '42');
        expect(result['attr3'], 'true');
        expect(result.containsKey('duration_ns'), isTrue);
        expect(result.length, 4);
      });

      test('does not include duration for an unended span', () {
        final span = tracer.startSpan(
          'open',
          attributes: otel.OTel.attributesFromMap(const {
            'test.key': 'test.value',
          }),
        );
        // intentionally not ended
        final spanRecord = SpanRecord(otelReadOnlySpan: span);

        final result = spanRecord.getFaroEventAttributes();

        expect(result.containsKey('duration_ns'), isFalse);
        expect(result['test.key'], 'test.value');

        span.end();
      });
    });
  });
}
