import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/tracing/faro_user_action_span_processor.dart';
import 'package:faro/src/user_actions/user_action.dart';
import 'package:faro/src/user_actions/user_action_lifecycle_signal_channel.dart';
import 'package:faro/src/user_actions/user_action_signal.dart';
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

class _RecordingProcessor implements otel.SpanProcessor {
  final List<otel.Span> startedSpans = [];
  final List<otel.Span> endedSpans = [];
  int shutdownCount = 0;
  int forceFlushCount = 0;

  @override
  Future<void> onStart(otel.Span span, otel.Context? parentContext) async {
    startedSpans.add(span);
  }

  @override
  Future<void> onEnd(otel.Span span) async {
    endedSpans.add(span);
  }

  @override
  Future<void> onNameUpdate(otel.Span span, String newName) async {}

  @override
  Future<void> shutdown() async {
    shutdownCount++;
  }

  @override
  Future<void> forceFlush() async {
    forceFlushCount++;
  }
}

void main() {
  late UserActionLifecycleSignalChannel lifecycleSignalChannel;
  late otel.Tracer tracer;
  late _RecordingProcessor recordingDelegate;

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

  setUp(() {
    recordingDelegate = _RecordingProcessor();
    lifecycleSignalChannel = UserActionLifecycleSignalChannel();
  });

  tearDown(() {
    lifecycleSignalChannel.dispose();
  });

  otel.Span newSpan({Map<String, Object>? attributes}) {
    final span = tracer.startSpan(
      'test-span',
      attributes:
          attributes == null ? null : otel.OTel.attributesFromMap(attributes),
    );
    return span;
  }

  group('FaroUserActionSpanProcessor:', () {
    group('onStart:', () {
      test('should set action attributes on span '
          'when action is in started state', () async {
        final action = UserAction(name: 'checkout');
        final processor = FaroUserActionSpanProcessor(
          delegate: recordingDelegate,
          activeUserActionResolver: () => action,
          lifecycleSignalChannel: lifecycleSignalChannel,
        );

        final span = newSpan();
        await processor.onStart(span, null);

        // ignore: invalid_use_of_visible_for_testing_member
        expect(
          span.attributes.getString('faro.action.user.name'),
          equals('checkout'),
        );
        // ignore: invalid_use_of_visible_for_testing_member
        expect(
          span.attributes.getString('faro.action.user.parentId'),
          equals(action.id),
        );

        action.dispose();
        span.end();
      });

      test('should NOT set attributes when no active action', () async {
        final processor = FaroUserActionSpanProcessor(
          delegate: recordingDelegate,
          activeUserActionResolver: () => null,
          lifecycleSignalChannel: lifecycleSignalChannel,
        );

        final span = newSpan();
        await processor.onStart(span, null);

        // ignore: invalid_use_of_visible_for_testing_member
        expect(span.attributes.getString('faro.action.user.name'), isNull);
        // ignore: invalid_use_of_visible_for_testing_member
        expect(span.attributes.getString('faro.action.user.parentId'), isNull);

        span.end();
      });

      test(
        'should NOT set attributes when action is in halted state',
        () async {
          final action = UserAction(name: 'checkout')..halt();

          final processor = FaroUserActionSpanProcessor(
            delegate: recordingDelegate,
            activeUserActionResolver: () => action,
            lifecycleSignalChannel: lifecycleSignalChannel,
          );

          final span = newSpan();
          await processor.onStart(span, null);

          // ignore: invalid_use_of_visible_for_testing_member
          expect(span.attributes.getString('faro.action.user.name'), isNull);

          action.dispose();
          span.end();
        },
      );

      test('should NOT set attributes when action is in ended state', () async {
        final action = UserAction(name: 'checkout')..end();

        final processor = FaroUserActionSpanProcessor(
          delegate: recordingDelegate,
          activeUserActionResolver: () => action,
          lifecycleSignalChannel: lifecycleSignalChannel,
        );

        final span = newSpan();
        await processor.onStart(span, null);

        // ignore: invalid_use_of_visible_for_testing_member
        expect(span.attributes.getString('faro.action.user.name'), isNull);

        action.dispose();
        span.end();
      });

      test(
        'should NOT set attributes when action is in cancelled state',
        () async {
          final action = UserAction(name: 'checkout')..cancel();

          final processor = FaroUserActionSpanProcessor(
            delegate: recordingDelegate,
            activeUserActionResolver: () => action,
            lifecycleSignalChannel: lifecycleSignalChannel,
          );

          final span = newSpan();
          await processor.onStart(span, null);

          // ignore: invalid_use_of_visible_for_testing_member
          expect(span.attributes.getString('faro.action.user.name'), isNull);

          action.dispose();
          span.end();
        },
      );

      test('should always delegate onStart to wrapped processor', () async {
        final processor = FaroUserActionSpanProcessor(
          delegate: recordingDelegate,
          activeUserActionResolver: () => null,
          lifecycleSignalChannel: lifecycleSignalChannel,
        );

        final span = newSpan();
        await processor.onStart(span, null);

        expect(recordingDelegate.startedSpans, hasLength(1));
        expect(recordingDelegate.startedSpans.first, same(span));

        span.end();
      });
    });

    group('delegation:', () {
      test('should delegate onEnd to wrapped processor', () async {
        final processor = FaroUserActionSpanProcessor(
          delegate: recordingDelegate,
          activeUserActionResolver: () => null,
          lifecycleSignalChannel: lifecycleSignalChannel,
        );

        final span = newSpan();
        await processor.onEnd(span);

        expect(recordingDelegate.endedSpans, hasLength(1));
        expect(recordingDelegate.endedSpans.first, same(span));

        span.end();
      });

      test('should delegate shutdown to wrapped processor', () async {
        final processor = FaroUserActionSpanProcessor(
          delegate: recordingDelegate,
          activeUserActionResolver: () => null,
          lifecycleSignalChannel: lifecycleSignalChannel,
        );

        await processor.shutdown();

        expect(recordingDelegate.shutdownCount, equals(1));
      });

      test('should delegate forceFlush to wrapped processor', () async {
        final processor = FaroUserActionSpanProcessor(
          delegate: recordingDelegate,
          activeUserActionResolver: () => null,
          lifecycleSignalChannel: lifecycleSignalChannel,
        );

        await processor.forceFlush();

        expect(recordingDelegate.forceFlushCount, equals(1));
      });

      test(
        'should emit pendingStart and pendingEnd when marker is true',
        () async {
          final span = newSpan(
            attributes: const {'faro.action.user.pending': true},
          );

          final processor = FaroUserActionSpanProcessor(
            delegate: recordingDelegate,
            activeUserActionResolver: () => null,
            lifecycleSignalChannel: lifecycleSignalChannel,
          );

          final emitted = <UserActionSignal>[];
          final subscription = lifecycleSignalChannel.stream.listen(
            emitted.add,
          );

          await processor.onStart(span, null);
          await Future<void>.delayed(Duration.zero);
          await processor.onEnd(span);
          await Future<void>.delayed(Duration.zero);

          expect(emitted.length, 2);
          expect(emitted[0].type, UserActionSignalType.pendingStart);
          expect(emitted[1].type, UserActionSignalType.pendingEnd);
          expect(emitted[0].operationId, equals(emitted[1].operationId));

          await subscription.cancel();
          span.end();
        },
      );

      test('should not emit pending signals when marker is absent', () async {
        final span = newSpan();

        final processor = FaroUserActionSpanProcessor(
          delegate: recordingDelegate,
          activeUserActionResolver: () => null,
          lifecycleSignalChannel: lifecycleSignalChannel,
        );

        final emitted = <UserActionSignal>[];
        final subscription = lifecycleSignalChannel.stream.listen(emitted.add);

        await processor.onStart(span, null);
        await processor.onEnd(span);
        await Future<void>.delayed(Duration.zero);

        expect(emitted, isEmpty);

        await subscription.cancel();
        span.end();
      });
    });
  });
}
