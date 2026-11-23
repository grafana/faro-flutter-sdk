import 'package:fake_async/fake_async.dart';
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/integrations/native_integration.dart';
import 'package:faro/src/integrations/process_vitals.dart';
import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/user_actions/telemetry_router.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFaro extends Mock implements Faro {}

class MockNativeChannel extends Mock implements FaroNativeMethods {}

class _RecordingRouter implements TelemetryRouter {
  final List<TelemetryItem> ingested = [];
  final List<SessionActivityKind> activities = [];
  final List<bool> skipBuffers = [];

  @override
  void ingest(
    TelemetryItem item, {
    required SessionActivityKind activity,
    bool skipBuffer = false,
  }) {
    ingested.add(item);
    activities.add(activity);
    skipBuffers.add(skipBuffer);
  }
}

/// Delivers a method call from the native side to the Dart handler.
Future<void> _sendFromNative(String method, Object? arguments) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        'faro',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, arguments),
        ),
        (_) {},
      );
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late MockFaro mockFaro;
  late MockNativeChannel mockNativeChannel;
  late NativeIntegration nativeIntegration;
  late _RecordingRouter router;
  var monotonicNanos = 0;
  var wallClock = DateTime.now;
  var cpuTimeSeconds = 0.0;

  setUp(() {
    mockFaro = MockFaro();
    mockNativeChannel = MockNativeChannel();
    router = _RecordingRouter();
    nativeIntegration = NativeIntegration(telemetryRouter: router);

    when(() => mockFaro.nativeChannel).thenReturn(mockNativeChannel);
    when(
      () => mockNativeChannel.getProcessVitals(
        cpu: any(named: 'cpu'),
        memory: any(named: 'memory'),
      ),
    ).thenAnswer(
      (invocation) async => {
        'monotonicNanos': monotonicNanos,
        'timestampMillis': wallClock().millisecondsSinceEpoch,
        if (invocation.namedArguments[#cpu] == true) ...{
          'cpuTimeSeconds': cpuTimeSeconds,
          'cpuCount': 4,
        },
        if (invocation.namedArguments[#memory] == true) ...{
          'memoryBytes': 222715904,
          'memoryBasis': 'rss',
        },
      },
    );
    when(
      () => mockNativeChannel.initFrameMonitoring(),
    ).thenAnswer((_) async {});

    Faro.instance = mockFaro;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  tearDown(() {
    wallClock = DateTime.now;
    nativeIntegration.dispose();
    // Undo any pod mutations made by the scope-teardown test.
    pod.removeOverride(telemetryRouterProvider);
    pod.clearScope(faroInitScope);
  });

  group('NativeIntegration', () {
    test('init starts the Android frame sampler', () async {
      nativeIntegration = NativeIntegration(
        telemetryRouter: router,
        isAndroid: true,
      );
      await nativeIntegration.init(
        memusage: true,
        cpuusage: true,
        anr: true,
        refreshrate: true,
        setSendUsageInterval: const Duration(seconds: 60),
      );

      verify(() => mockNativeChannel.initFrameMonitoring()).called(1);
    });

    test('init starts no frame sampler on iOS', () async {
      nativeIntegration = NativeIntegration(
        telemetryRouter: router,
        isAndroid: false,
      );
      await nativeIntegration.init(
        memusage: true,
        cpuusage: true,
        refreshrate: true,
        setSendUsageInterval: const Duration(seconds: 60),
      );

      verifyNever(() => mockNativeChannel.initFrameMonitoring());
    });

    group('app CPU and memory', () {
      final epoch = DateTime.utc(2026, 11, 17, 12);

      test(
        'are sent as app.cpu_usage and app.memory events, not measurements',
        () {
          fakeAsync((async) {
            monotonicNanos = 0;
            cpuTimeSeconds = 0;
            nativeIntegration = NativeIntegration(
              telemetryRouter: router,
              isAndroid: false,
            );
            wallClock = () => epoch.add(async.elapsed);
            nativeIntegration.init(
              memusage: true,
              cpuusage: true,
              setSendUsageInterval: const Duration(seconds: 30),
            );
            async.flushMicrotasks();

            monotonicNanos = 30 * 1000 * 1000 * 1000;
            cpuTimeSeconds = 12;
            async.elapse(const Duration(seconds: 30));

            expect(router.ingested.map((item) => item.asMeasurement), [
              isNull,
              isNull,
              isNull,
            ]);
            final events = router.ingested
                .map((item) => item.asEvent!)
                .toList();
            expect(events.map((event) => event.name), [
              appMemoryEventName,
              appCpuUsageEventName,
              appMemoryEventName,
            ]);
            expect(events[1].attributes, {
              'value': '10',
              'unit': 'percent',
              'cpu.logical_count': '4',
              'window_ms': '30000',
              'cpu.basis': 'process_utilization',
            });
            expect(events[1].timestamp, '2026-11-17T12:00:30.000Z');
            expect(events[2].attributes, {
              'value': '212.4',
              'unit': 'MB',
              'memory.basis': 'rss',
            });
            expect(events[0].timestamp, '2026-11-17T12:00:02.000Z');
            expect(router.activities.toSet(), {SessionActivityKind.passive});
            // Process samples must not be held by, or attributed to, an
            // in-progress user action.
            expect(router.skipBuffers, [true, true, true]);
          });
        },
      );

      test('stop while the app is hidden', () {
        fakeAsync((async) {
          nativeIntegration = NativeIntegration(
            telemetryRouter: router,
            isAndroid: false,
          );
          nativeIntegration.init(
            memusage: true,
            cpuusage: true,
            setSendUsageInterval: const Duration(seconds: 30),
          );
          async.flushMicrotasks();
          binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          async.elapse(const Duration(minutes: 5));

          expect(router.ingested, isEmpty);
          expect(nativeIntegration.processVitalsSampler?.isVisible, isFalse);

          binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          async.elapse(const Duration(seconds: 2));
          expect(router.ingested.single.asEvent?.name, appMemoryEventName);
        });
      });

      test('are not sampled when both options are off', () {
        fakeAsync((async) {
          nativeIntegration.init(
            setSendUsageInterval: const Duration(seconds: 30),
          );
          async.elapse(const Duration(minutes: 2));

          expect(nativeIntegration.processVitalsSampler, isNull);
          verifyNever(
            () => mockNativeChannel.getProcessVitals(
              cpu: any(named: 'cpu'),
              memory: any(named: 'memory'),
            ),
          );
        });
      });
    });

    group('frame callbacks from native', () {
      setUp(() {
        nativeIntegration.initializeMethodChannel();
      });

      test('ignore a refresh rate', () async {
        await _sendFromNative('onRefreshRate', 59.8);

        expect(router.ingested, isEmpty);
      });

      test('still report slow and frozen frames', () async {
        await _sendFromNative('onSlowFrames', 3);
        await _sendFromNative('onFrozenFrame', 1);

        final measurements = router.ingested
            .map((item) => item.asMeasurement)
            .toList();
        expect(measurements.map((m) => m?.type), [
          'app_frames_rate',
          'app_frozen_frame',
        ]);
        expect(measurements[0]?.values, {'slow_frames': 3});
        expect(measurements[1]?.values, {'frozen_frames': 1});
      });
    });

    test('getWarmStart correctly pushes warm start measurement', () async {
      nativeIntegration.setWarmStart();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      nativeIntegration.getWarmStart();

      expect(router.ingested, hasLength(1));
      final measurement = router.ingested.single.asMeasurement;
      expect(measurement?.type, 'app_startup');
    });

    test('vitals measurements are ingested as passive telemetry', () async {
      nativeIntegration.setWarmStart();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      nativeIntegration.getWarmStart();

      expect(router.activities, [SessionActivityKind.passive]);
    });

    group('getAppStart', () {
      void stubAppStart(Map<String, dynamic>? value) {
        when(() => mockNativeChannel.getAppStart()).thenAnswer((_) async {
          return value;
        });
      }

      test(
        'pushes a cold start measurement for a user-visible launch',
        () async {
          stubAppStart({
            'appStartDurationMillis': 1234,
            'isUserVisibleColdStart': true,
            'prewarmed': false,
          });

          await nativeIntegration.getAppStart();

          final measurement = router.ingested.single.asMeasurement;
          expect(measurement?.type, 'app_startup');
          expect(measurement?.values, {
            'appStartDuration': 1234,
            'coldStart': 1,
            'prewarmed': 0,
          });
        },
      );

      test('marks a prewarmed launch so it can be separated later', () async {
        stubAppStart({
          'appStartDurationMillis': 300,
          'isUserVisibleColdStart': true,
          'prewarmed': true,
        });

        await nativeIntegration.getAppStart();

        expect(router.ingested.single.asMeasurement?.values?['prewarmed'], 1);
      });

      // The process was forked for a push, a job or a broadcast, so the time
      // since it started is idle time, not a launch anyone waited for.
      test(
        'discards a start the platform says was not user-initiated',
        () async {
          stubAppStart({
            'appStartDurationMillis': 1234,
            'isUserVisibleColdStart': false,
            'prewarmed': false,
          });

          await nativeIntegration.getAppStart();

          expect(router.ingested, isEmpty);
        },
      );

      test('discards a duration beyond the plausible bound', () async {
        stubAppStart({
          'appStartDurationMillis':
              NativeIntegration.maxColdStartDuration.inMilliseconds + 1,
          'isUserVisibleColdStart': true,
          'prewarmed': false,
        });

        await nativeIntegration.getAppStart();

        expect(router.ingested, isEmpty);
      });

      test('keeps a duration exactly at the plausible bound', () async {
        stubAppStart({
          'appStartDurationMillis':
              NativeIntegration.maxColdStartDuration.inMilliseconds,
          'isUserVisibleColdStart': true,
          'prewarmed': false,
        });

        await nativeIntegration.getAppStart();

        expect(router.ingested, hasLength(1));
      });

      // Android reports -1 below API 24, and a backwards clock correction on
      // iOS can invert the wall-clock subtraction.
      test('discards a negative duration', () async {
        stubAppStart({
          'appStartDurationMillis': -1,
          'isUserVisibleColdStart': true,
          'prewarmed': false,
        });

        await nativeIntegration.getAppStart();

        expect(router.ingested, isEmpty);
      });

      test('discards a zero duration', () async {
        stubAppStart({
          'appStartDurationMillis': 0,
          'isUserVisibleColdStart': true,
          'prewarmed': false,
        });

        await nativeIntegration.getAppStart();

        expect(router.ingested, isEmpty);
      });

      // Both platforms send a real boolean here. Anything else is a native
      // change we did not intend, and labelling it as not prewarmed keeps a
      // stray value from being reported as a prewarmed launch.
      test('treats a non-boolean prewarmed value as not prewarmed', () async {
        stubAppStart({
          'appStartDurationMillis': 300,
          'isUserVisibleColdStart': true,
          'prewarmed': 1,
        });

        await nativeIntegration.getAppStart();

        expect(router.ingested.single.asMeasurement?.values?['prewarmed'], 0);
      });

      test('ignores a missing or malformed native response', () async {
        stubAppStart(null);
        await nativeIntegration.getAppStart();

        stubAppStart({'isUserVisibleColdStart': true});
        await nativeIntegration.getAppStart();

        expect(router.ingested, isEmpty);
      });
    });

    test('clearing faroInitScope stops the vitals timer', () {
      fakeAsync((async) {
        // Resolve the provider-built instance (as Faro.init does) wired to a
        // router we can observe.
        pod.overrideProvider(telemetryRouterProvider, (_) => router);
        final integration = pod.resolve(nativeIntegrationProvider);

        integration.init(
          memusage: true,
          setSendUsageInterval: const Duration(seconds: 10),
        );
        async.flushMicrotasks();
        monotonicNanos = 10 * 1000 * 1000 * 1000;

        async.elapse(const Duration(seconds: 10));
        final countBeforeClear = router.ingested.length;
        expect(countBeforeClear, greaterThan(0));

        // Simulate Faro.resetForTesting()/re-init: evict the per-init
        // instance from its scope.
        pod.clearScope(faroInitScope);

        // The evicted instance's timer must stop; otherwise it keeps
        // ingesting into the stale router and session manager.
        async.elapse(const Duration(seconds: 30));
        expect(
          router.ingested.length,
          countBeforeClear,
          reason: 'timer from the evicted instance must not keep firing',
        );
      });
    });
  });
}
