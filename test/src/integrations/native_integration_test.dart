import 'package:fake_async/fake_async.dart';
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/integrations/native_integration.dart';
import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/user_actions/telemetry_router.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFaro extends Mock implements Faro {}

class MockNativeChannel extends Mock implements FaroNativeMethods {}

class _RecordingRouter implements TelemetryRouter {
  final List<TelemetryItem> ingested = [];
  final List<SessionActivityKind> activities = [];

  @override
  void ingest(
    TelemetryItem item, {
    bool skipBuffer = false,
    SessionActivityKind activity = SessionActivityKind.active,
  }) {
    ingested.add(item);
    activities.add(activity);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFaro mockFaro;
  late MockNativeChannel mockNativeChannel;
  late NativeIntegration nativeIntegration;
  late _RecordingRouter router;

  setUp(() {
    mockFaro = MockFaro();
    mockNativeChannel = MockNativeChannel();
    router = _RecordingRouter();
    nativeIntegration = NativeIntegration(telemetryRouter: router);

    when(() => mockFaro.nativeChannel).thenReturn(mockNativeChannel);
    when(
      () => mockNativeChannel.getMemoryUsage(),
    ).thenAnswer((_) async => 50.0);
    when(() => mockNativeChannel.initRefreshRate()).thenAnswer((_) async {});

    Faro.instance = mockFaro;
  });

  tearDown(() {
    // Undo any pod mutations made by the scope-teardown test.
    pod.removeOverride(telemetryRouterProvider);
    pod.clearScope(faroInitScope);
  });

  group('NativeIntegration', () {
    test('init initializes refresh rate and method channel', () async {
      nativeIntegration.init(
        memusage: true,
        cpuusage: true,
        anr: true,
        refreshrate: true,
        setSendUsageInterval: const Duration(seconds: 60),
      );

      verify(() => mockNativeChannel.initRefreshRate()).called(1);
    });

    test('getWarmStart correctly pushes warm start measurement', () async {
      nativeIntegration.setWarmStart();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      nativeIntegration.getWarmStart();

      expect(router.ingested, hasLength(1));
      final measurement = router.ingested.single.asMeasurement;
      expect(measurement?.type, 'app_startup');
    });

    test(
      'vitals measurements are ingested as foreground-gated telemetry',
      () async {
        nativeIntegration.setWarmStart();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        nativeIntegration.getWarmStart();

        // Automatic vitals use foregroundOnly; SessionActivityPolicy decides
        // whether they extend the session based on foreground state.
        expect(router.activities, [SessionActivityKind.foregroundOnly]);
      },
    );

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
