import 'package:faro/src/configurations/batch_config.dart';
import 'package:faro/src/configurations/faro_config.dart';
import 'package:faro/src/core/current_time_provider.dart';
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/data_collection_policy.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/integrations/native_integration.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';
import 'package:faro/src/session/app_lifecycle_service.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/transport/faro_transport.dart';
import 'package:faro/src/user_actions/telemetry_router.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFaroTransport extends Mock implements FaroTransport {}

class MockBatchTransport extends Mock implements BatchTransport {}

class MockFaroNativeMethods extends Mock implements FaroNativeMethods {}

class MockDataCollectionPolicy extends Mock implements DataCollectionPolicy {}

void main() {
  group('Session rotation:', () {
    const appName = 'TestApp';
    const appVersion = '2.0.3';
    const appEnv = 'Test';
    const apiKey = 'TestAPIKey';

    late MockFaroTransport mockFaroTransport;
    late MockBatchTransport mockBatchTransport;
    late MockFaroNativeMethods mockFaroNativeMethods;
    late MockDataCollectionPolicy mockDataCollectionPolicy;
    late DateTime now;

    setUpAll(() {
      registerFallbackValue(
        FaroException('test', 'something', {
          'frames': <Map<String, dynamic>>[],
        }),
      );
      registerFallbackValue(Event('test'));
      registerFallbackValue(FaroLog('This is a message'));
      registerFallbackValue(Measurement({'test': 123}, 'test'));
      registerFallbackValue(Payload(Meta()));
      registerFallbackValue(BatchConfig());
      registerFallbackValue(Meta());
    });

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await Faro.resetForTesting();
      BatchTransportFactory().reset();

      SharedPreferences.setMockInitialValues({});
      mockDataCollectionPolicy = MockDataCollectionPolicy();
      when(() => mockDataCollectionPolicy.isEnabled).thenReturn(true);
      when(() => mockDataCollectionPolicy.enable()).thenAnswer((_) async {});
      when(() => mockDataCollectionPolicy.disable()).thenAnswer((_) async {});

      PackageInfo.setMockInitialValues(
        appName: appName,
        packageName: 'com.grafana.example',
        version: appVersion,
        buildNumber: '2',
        buildSignature: 'buildSignature',
      );

      mockFaroTransport = MockFaroTransport();
      mockBatchTransport = MockBatchTransport();
      mockFaroNativeMethods = MockFaroNativeMethods();

      BatchTransportFactory().setInstance(mockBatchTransport);

      Faro().transports = [mockFaroTransport];
      Faro().nativeChannel = mockFaroNativeMethods;
      Faro().batchTransport = mockBatchTransport;

      when(
        () => mockFaroNativeMethods.enableCrashReporter(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockBatchTransport.addExceptions(any()),
      ).thenAnswer((_) async {});
      when(() => mockBatchTransport.addLog(any())).thenAnswer((_) async {});
      when(() => mockBatchTransport.addEvent(any())).thenAnswer((_) async {});
      when(
        () => mockBatchTransport.addMeasurement(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockBatchTransport.updatePayloadMeta(any()),
      ).thenAnswer((_) async {});
      when(() => mockFaroTransport.send(any())).thenAnswer((_) async {});

      now = DateTime(2026, 6, 10, 12);
      pod.overrideProvider(
        currentTimeProvider,
        (_) =>
            () => now,
      );
    });

    tearDown(() async {
      await Faro.resetForTesting();
      BatchTransportFactory().reset();
    });

    Future<void> initFaro() async {
      final config = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
      );
      await Faro().init(optionsConfiguration: config);
    }

    List<String> capturedEventNames() {
      return verify(
        () => mockBatchTransport.addEvent(captureAny()),
      ).captured.map((dynamic event) => (event as Event).name).toList();
    }

    // Simulates the app moving to the background (screen locked or task
    // switched), so passive vitals stop counting as session activity.
    void setAppBackgrounded() {
      pod
          .resolve(appLifecycleServiceProvider)
          .updateFromLifecycleState(AppLifecycleState.paused);
    }

    void ingestVitals() {
      pod
          .resolve(telemetryRouterProvider)
          .ingest(
            TelemetryItem.fromMeasurement(
              Measurement({'mem_usage': 42}, 'app_memory'),
            ),
            activity: SessionActivityKind.foregroundOnly,
          );
    }

    test('emits session_start (not session_extend) for the initial '
        'session on init', () async {
      await initFaro();

      final eventNames = capturedEventNames();
      expect(eventNames, contains('session_start'));
      expect(eventNames, isNot(contains('session_extend')));
    });

    test('keeps the session when activity stays within thresholds', () async {
      await initFaro();
      final initialSessionId = Faro().meta.session?.id;
      expect(initialSessionId, isNotNull);

      now = now.add(const Duration(minutes: 14));
      Faro().pushEvent('some_event');

      expect(Faro().meta.session?.id, initialSessionId);
      expect(
        Faro().meta.session?.attributes?.containsKey('previousSession'),
        isFalse,
      );
    });

    test('rotates the session when inactivity reaches 15 minutes', () async {
      await initFaro();
      final initialSessionId = Faro().meta.session?.id;

      now = now.add(const Duration(minutes: 15));
      Faro().pushEvent('some_event');

      final session = Faro().meta.session;
      expect(session?.id, isNot(initialSessionId));
      expect(session?.attributes?['previousSession'], initialSessionId);
    });

    test('rotates the session when lifetime reaches 4 hours', () async {
      await initFaro();
      final initialSessionId = Faro().meta.session?.id;

      // Stay active every 10 minutes so inactivity never expires.
      for (var i = 0; i < 23; i++) {
        now = now.add(const Duration(minutes: 10));
        Faro().pushEvent('keep_alive');
      }
      expect(Faro().meta.session?.id, initialSessionId);

      now = now.add(const Duration(minutes: 10));
      Faro().pushEvent('after_lifetime');

      final session = Faro().meta.session;
      expect(session?.id, isNot(initialSessionId));
      expect(session?.attributes?['previousSession'], initialSessionId);
    });

    test('emits session_extend for the new session and attributes the '
        'triggering telemetry to it', () async {
      await initFaro();
      clearInteractions(mockBatchTransport);

      now = now.add(const Duration(minutes: 16));
      Faro().pushEvent('trigger_event');

      // Rotation updates the payload meta first, then emits
      // session_extend, then the triggering event follows — so both
      // events belong to the new session.
      final rotatedSessionId = Faro().meta.session?.id;
      verifyInOrder([
        () => mockBatchTransport.updatePayloadMeta(
          any(
            that: isA<Meta>().having(
              (m) => m.session?.id,
              'session.id',
              rotatedSessionId,
            ),
          ),
        ),
        () => mockBatchTransport.addEvent(
          any(
            that: isA<Event>().having((e) => e.name, 'name', 'session_extend'),
          ),
        ),
        () => mockBatchTransport.addEvent(
          any(
            that: isA<Event>().having((e) => e.name, 'name', 'trigger_event'),
          ),
        ),
      ]);
    });

    test('preserves session attributes across rotation', () async {
      await initFaro();
      final initialAttributes = Map<String, dynamic>.from(
        Faro().meta.session?.attributes ?? {},
      );
      expect(initialAttributes, isNotEmpty);

      now = now.add(const Duration(minutes: 20));
      Faro().pushEvent('some_event');

      final rotatedAttributes = Faro().meta.session?.attributes ?? {};
      for (final entry in initialAttributes.entries) {
        expect(rotatedAttributes[entry.key], entry.value);
      }
    });

    test('overwrites previousSession on successive rotations', () async {
      await initFaro();
      final firstSessionId = Faro().meta.session?.id;

      now = now.add(const Duration(minutes: 16));
      Faro().pushEvent('first_rotation');
      final secondSessionId = Faro().meta.session?.id;
      expect(secondSessionId, isNot(firstSessionId));

      now = now.add(const Duration(minutes: 16));
      Faro().pushEvent('second_rotation');
      final session = Faro().meta.session;
      expect(session?.id, isNot(secondSessionId));
      expect(session?.attributes?['previousSession'], secondSessionId);
    });

    test('logs also trigger rotation and belong to the new session', () async {
      await initFaro();
      final initialSessionId = Faro().meta.session?.id;
      clearInteractions(mockBatchTransport);

      now = now.add(const Duration(minutes: 16));
      Faro().pushLog('a log message', level: LogLevel.info);

      expect(Faro().meta.session?.id, isNot(initialSessionId));
      verifyInOrder([
        () => mockBatchTransport.updatePayloadMeta(any()),
        () => mockBatchTransport.addEvent(
          any(
            that: isA<Event>().having((e) => e.name, 'name', 'session_extend'),
          ),
        ),
        () => mockBatchTransport.addLog(any()),
      ]);
    });

    test('background vitals do not extend the session and rotate it '
        'once expired', () async {
      await initFaro();
      final initialSessionId = Faro().meta.session?.id;
      // Backgrounded: vitals must not count as activity.
      setAppBackgrounded();

      // Vitals below the threshold neither rotate nor extend.
      now = now.add(const Duration(minutes: 10));
      ingestVitals();
      now = now.add(const Duration(minutes: 4));
      ingestVitals();
      expect(Faro().meta.session?.id, initialSessionId);

      // 16 minutes since the last ACTIVITY (init); the vitals ingest
      // itself rotates the session even though it is passive.
      now = now.add(const Duration(minutes: 2));
      clearInteractions(mockBatchTransport);
      ingestVitals();

      final session = Faro().meta.session;
      expect(session?.id, isNot(initialSessionId));
      expect(session?.attributes?['previousSession'], initialSessionId);
      verifyInOrder([
        () => mockBatchTransport.updatePayloadMeta(any()),
        () => mockBatchTransport.addEvent(
          any(
            that: isA<Event>().having((e) => e.name, 'name', 'session_extend'),
          ),
        ),
        () => mockBatchTransport.addMeasurement(any()),
      ]);
    });

    test('foreground vitals keep the session alive by extending the '
        'window', () async {
      await initFaro();
      final initialSessionId = Faro().meta.session?.id;

      // App stays in the foreground (default). Vitals every 10 minutes
      // each extend the 15-minute window, so the session never expires
      // even though there is no user interaction (e.g. a user reading
      // a screen). Kept under the 4-hour max lifetime.
      for (var i = 0; i < 6; i++) {
        now = now.add(const Duration(minutes: 10));
        ingestVitals();
        expect(Faro().meta.session?.id, initialSessionId);
      }
      expect(
        Faro().meta.session?.attributes?.containsKey('previousSession'),
        isFalse,
      );
    });

    test('foreground vitals stop extending once the app is '
        'backgrounded', () async {
      await initFaro();
      final initialSessionId = Faro().meta.session?.id;

      // Foreground vitals extend the window past the first threshold.
      now = now.add(const Duration(minutes: 10));
      ingestVitals();
      now = now.add(const Duration(minutes: 10));
      ingestVitals();
      expect(Faro().meta.session?.id, initialSessionId);

      // App goes to the background; from here vitals no longer extend.
      setAppBackgrounded();
      now = now.add(const Duration(minutes: 16));
      ingestVitals();

      final session = Faro().meta.session;
      expect(session?.id, isNot(initialSessionId));
      expect(session?.attributes?['previousSession'], initialSessionId);
    });

    test('vitals pushed by NativeIntegration do not extend the '
        'session', () async {
      when(
        () => mockFaroNativeMethods.getAppStart(),
      ).thenAnswer((_) async => {'appStartDuration': 100});
      await initFaro();
      final initialSessionId = Faro().meta.session?.id;
      // Backgrounded: automatic vitals must not count as activity.
      setAppBackgrounded();

      // An automatic vitals measurement at 14 minutes flows through
      // the passive path: no rotation, no activity recorded.
      now = now.add(const Duration(minutes: 14));
      await pod.resolve(nativeIntegrationProvider).getAppStart();
      expect(Faro().meta.session?.id, initialSessionId);

      // Two minutes later it is 16 minutes since the last real
      // activity (init). If the vitals measurement had recorded
      // activity, this event would NOT rotate.
      now = now.add(const Duration(minutes: 2));
      Faro().pushEvent('user_tap');

      final session = Faro().meta.session;
      expect(session?.id, isNot(initialSessionId));
      expect(session?.attributes?['previousSession'], initialSessionId);
    });

    test('emits a single session_extend on rotation', () async {
      await initFaro();
      clearInteractions(mockBatchTransport);

      now = now.add(const Duration(minutes: 16));
      Faro().pushEvent('trigger_event');

      final sessionExtends = capturedEventNames()
          .where((name) => name == 'session_extend')
          .length;
      expect(sessionExtends, 1);
    });
  });
}
