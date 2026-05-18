// ignore_for_file: lines_longer_than_80_chars

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/tracing/span.dart';
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

  group('Span.noParent sentinel:', () {
    test('should be a const singleton', () {
      const a = Span.noParent;
      const b = Span.noParent;

      expect(identical(a, b), isTrue);
      expect(a == b, isTrue);
    });

    test('should throw UnsupportedError when traceId is accessed', () {
      expect(() => Span.noParent.traceId, throwsA(isA<UnsupportedError>()));
    });

    test('should throw UnsupportedError when spanId is accessed', () {
      expect(() => Span.noParent.spanId, throwsA(isA<UnsupportedError>()));
    });

    test('should throw UnsupportedError when wasEnded is accessed', () {
      expect(() => Span.noParent.wasEnded, throwsA(isA<UnsupportedError>()));
    });

    test('should throw UnsupportedError when status is accessed', () {
      expect(() => Span.noParent.status, throwsA(isA<UnsupportedError>()));
    });

    test('should throw UnsupportedError when statusHasBeenSet is accessed', () {
      expect(
        () => Span.noParent.statusHasBeenSet,
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should throw UnsupportedError when setStatus is called', () {
      expect(
        () => Span.noParent.setStatus(SpanStatusCode.ok),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should throw UnsupportedError when addEvent is called', () {
      expect(
        () => Span.noParent.addEvent('test'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should throw UnsupportedError when setAttributes is called', () {
      expect(
        () => Span.noParent.setAttributes({'key': 'value'}),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should throw UnsupportedError when setAttribute is called', () {
      expect(
        () => Span.noParent.setAttribute('key', 'value'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should throw UnsupportedError when recordException is called', () {
      expect(
        () => Span.noParent.recordException(Exception('test')),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should throw UnsupportedError when traceparent is accessed', () {
      expect(() => Span.noParent.traceparent, throwsA(isA<UnsupportedError>()));
    });

    test('should throw UnsupportedError when end is called', () {
      expect(() => Span.noParent.end(), throwsA(isA<UnsupportedError>()));
    });

    test('should have descriptive error message', () {
      expect(
        () => Span.noParent.traceId,
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Span.noParent'),
              contains('sentinel'),
              contains('parentSpan'),
            ),
          ),
        ),
      );
    });
  });

  group('InternalSpan:', () {
    Span makeFaroSpan({otel.TraceFlags? traceFlags}) {
      final apiSpan = tracer.startSpan(
        'test-span',
        kind: otel.SpanKind.client,
        spanContext: traceFlags == null
            ? null
            : otel.OTel.spanContext(
                traceId: otel.OTel.traceId(),
                spanId: otel.OTel.spanId(),
                traceFlags: traceFlags,
              ),
      );
      return SpanProvider().getSpan(apiSpan, otel.Context.current);
    }

    group('traceparent:', () {
      test('should return W3C formatted traceparent string', () {
        final span = makeFaroSpan(traceFlags: otel.TraceFlags.sampled);

        final tp = span.traceparent;
        // 00-<32 hex>-<16 hex>-01
        expect(tp, matches(RegExp(r'^00-[0-9a-f]{32}-[0-9a-f]{16}-01$')));
        expect(tp, contains(span.traceId));
        expect(tp, contains(span.spanId));
      });

      test('should format trace flags as two-digit hex', () {
        final span = makeFaroSpan(traceFlags: otel.TraceFlags.sampled);

        // The sampler controls the actual flag value; we just verify the
        // format is a two-character hex byte.
        expect(span.traceparent, matches(RegExp(r'-[0-9a-f]{2}$')));
      });
    });

    group('setAttributes with typed values:', () {
      Span makeSpan() => makeFaroSpan(traceFlags: otel.TraceFlags.sampled);

      test('should pass string attributes to OTel span', () {
        final span = makeSpan();

        span.setAttributes({'name': 'test'});

        final internal = span as InternalSpan;
        // ignore: invalid_use_of_visible_for_testing_member
        expect(internal.otelSpan.attributes.getString('name'), 'test');
      });

      test('should pass int attributes to OTel span', () {
        final span = makeSpan();

        span.setAttributes({'count': 42});

        final internal = span as InternalSpan;
        // ignore: invalid_use_of_visible_for_testing_member
        expect(internal.otelSpan.attributes.getInt('count'), 42);
      });

      test('should pass double attributes to OTel span', () {
        final span = makeSpan();

        span.setAttributes({'score': 99.5});

        final internal = span as InternalSpan;
        // ignore: invalid_use_of_visible_for_testing_member
        expect(internal.otelSpan.attributes.getDouble('score'), 99.5);
      });

      test('should pass bool attributes to OTel span', () {
        final span = makeSpan();

        span.setAttributes({'enabled': true});

        final internal = span as InternalSpan;
        // ignore: invalid_use_of_visible_for_testing_member
        expect(internal.otelSpan.attributes.getBool('enabled'), true);
      });

      test('should pass mixed type attributes to OTel span', () {
        final span = makeSpan();

        span.setAttributes({
          'name': 'test',
          'count': 42,
          'score': 99.5,
          'enabled': true,
        });

        final internal = span as InternalSpan;
        // ignore: invalid_use_of_visible_for_testing_member
        final attrs = internal.otelSpan.attributes;
        expect(attrs.getString('name'), 'test');
        expect(attrs.getInt('count'), 42);
        expect(attrs.getDouble('score'), 99.5);
        expect(attrs.getBool('enabled'), true);
      });
    });

    group('addEvent with typed attributes:', () {
      test('should pass typed attributes to event', () {
        final span = makeFaroSpan(traceFlags: otel.TraceFlags.sampled);

        span.addEvent(
          'test event',
          attributes: {
            'message': 'hello',
            'count': 5,
            'duration': 1.5,
            'success': true,
          },
        );

        final internal = span as InternalSpan;
        final events = internal.otelSpan.spanEvents;
        expect(events, isNotNull);
        expect(events!.length, 1);

        final event = events.first;
        expect(event.name, 'test event');
        final attrs = event.attributes!;
        expect(attrs.getString('message'), 'hello');
        expect(attrs.getInt('count'), 5);
        expect(attrs.getDouble('duration'), 1.5);
        expect(attrs.getBool('success'), true);
      });
    });

    group('setAttribute with typed value:', () {
      Span makeSpan() => makeFaroSpan(traceFlags: otel.TraceFlags.sampled);

      test('should pass string value to OTel span', () {
        final span = makeSpan();
        span.setAttribute('name', 'test');

        final internal = span as InternalSpan;
        // ignore: invalid_use_of_visible_for_testing_member
        expect(internal.otelSpan.attributes.getString('name'), 'test');
      });

      test('should pass int value to OTel span via setAttribute', () {
        final span = makeSpan();
        span.setAttribute('count', 42);

        final internal = span as InternalSpan;
        // ignore: invalid_use_of_visible_for_testing_member
        expect(internal.otelSpan.attributes.getInt('count'), 42);
      });

      test('should pass double value to OTel span via setAttribute', () {
        final span = makeSpan();
        span.setAttribute('score', 99.5);

        final internal = span as InternalSpan;
        // ignore: invalid_use_of_visible_for_testing_member
        expect(internal.otelSpan.attributes.getDouble('score'), 99.5);
      });

      test('should pass bool value to OTel span via setAttribute', () {
        final span = makeSpan();
        span.setAttribute('enabled', true);

        final internal = span as InternalSpan;
        // ignore: invalid_use_of_visible_for_testing_member
        expect(internal.otelSpan.attributes.getBool('enabled'), true);
      });
    });
  });
}
