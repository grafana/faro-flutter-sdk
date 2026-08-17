import 'package:faro/src/configurations/batch_config.dart';
import 'package:faro/src/configurations/faro_config.dart';
import 'package:faro/src/core/current_time_provider.dart';
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/data_collection_policy.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/faro_widgets_binding_observer.dart';
import 'package:faro/src/integrations/native_integration.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_manager.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/transport/faro_transport.dart';
import 'package:faro/src/user_actions/telemetry_router.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

    FaroWidgetsBindingObserver buildLifecycleObserver() {
      return FaroWidgetsBindingObserver(
        nativeIntegration: pod.resolve(nativeIntegrationProvider),
        sessionManager: pod.resolve(sessionManagerProvider),
        onAppBackgrounded: () async {},
      );
    }

    void ingestVitals() {
      pod
          .resolve(telemetryRouterProvider)
          .ingest(
            TelemetryItem.fromMeasurement(
              Measurement({'mem_usage': 42}, 'app_memory'),
            ),
            activity: SessionActivityKind.passive,
          );
    }

    test('emits session_start (not session_extend) for the initial '
        'session on init', () async {
      await initFaro();

      final eventNames = capturedEventNames();
      expect(eventNames, contains('session_start'));
      expect(eventNames, isNot(contains('session_extend')));
    });

    test(
      'explicit reset links a new session and emits session_start',
      () async {
        await initFaro();
        final initialSessionId = Faro().meta.session?.id;
        clearInteractions(mockBatchTransport);

        await Faro().resetSession();

        final session = Faro().meta.session;
        expect(session?.id, isNot(initialSessionId));
        expect(session?.attributes?['previousSession'], initialSessionId);
        expect(capturedEventNames(), <String>['session_start']);
      },
    );

    test('keeps the session when activity stays within thresholds', () async {
      await initFaro();
      final initialSessionId = Faro().meta.session?.id;
      expect(initialSessionId, isNotNull);

      now = now.add(const Duration(minutes: 14));
      Faro().setViewMeta(name: 'checkout');

      expect(Faro().meta.session?.id, initialSessionId);
      expect(
        Faro().meta.session?.attributes?.containsKey('previousSession'),
        isFalse,
      );
    });

    test('repeating the current view does not refresh inactivity', () async {
      await initFaro();
      final initialSessionId = Faro().meta.session?.id;
      final manager = pod.resolve(sessionManagerProvider);

      now = now.add(const Duration(minutes: 5));
      Faro().setViewMeta(name: 'checkout');
      final viewChangedAt = manager.lastActivityAt;

      now = now.add(const Duration(minutes: 10));
      Faro().setViewMeta(name: 'checkout');
      expect(manager.lastActivityAt, viewChangedAt);

      now = now.add(const Duration(minutes: 5));
      Faro().pushEvent('poll_complete');

      final session = Faro().meta.session;
      expect(session?.id, isNot(initialSessionId));
      expect(session?.attributes?['previousSession'], initialSessionId);
    });

    test('repeating an unnamed view does not refresh inactivity', () async {
      await initFaro();
      final initialSessionId = Faro().meta.session?.id;
      final manager = pod.resolve(sessionManagerProvider);

      now = now.add(const Duration(minutes: 5));
      Faro().setViewMeta(name: 'checkout');

      now = now.add(const Duration(minutes: 5));
      Faro().setViewMeta();
      final viewChangedAt = manager.lastActivityAt;

      now = now.add(const Duration(minutes: 10));
      Faro().setViewMeta();
      expect(manager.lastActivityAt, viewChangedAt);

      now = now.add(const Duration(minutes: 5));
      Faro().pushEvent('poll_complete');

      final session = Faro().meta.session;
      expect(session?.id, isNot(initialSessionId));
      expect(session?.attributes?['previousSession'], initialSessionId);
    });

    test('rotates the session when inactivity reaches 15 minutes', () async {
      await initFaro();
      final initialSessionId = Faro().meta.session?.id;
      clearInteractions(mockBatchTransport);

      now = now.add(const Duration(minutes: 15));
      Faro().pushEvent('some_event');

      final session = Faro().meta.session;
      expect(session?.id, isNot(initialSessionId));
      expect(session?.attributes?['previousSession'], initialSessionId);
      expect(capturedEventNames(), contains('session_start'));
    });

    test('rotates the session when lifetime reaches 4 hours', () async {
      await initFaro();
      final initialSessionId = Faro().meta.session?.id;

      // Record meaningful view changes so inactivity never expires.
      for (var i = 0; i < 23; i++) {
        now = now.add(const Duration(minutes: 10));
        Faro().setViewMeta(name: 'view_$i');
      }
      expect(Faro().meta.session?.id, initialSessionId);
      clearInteractions(mockBatchTransport);

      now = now.add(const Duration(minutes: 10));
      Faro().setViewMeta(name: 'after_lifetime');

      final session = Faro().meta.session;
      expect(session?.id, isNot(initialSessionId));
      expect(session?.attributes?['previousSession'], initialSessionId);
      expect(capturedEventNames(), <String>['session_start']);
    });

    test('emits session_start for the new session and attributes the '
        'triggering telemetry to it', () async {
      await initFaro();
      clearInteractions(mockBatchTransport);

      now = now.add(const Duration(minutes: 16));
      Faro().pushEvent('trigger_event');

      // Rotation updates the payload meta first, then emits
      // session_start, then the triggering event follows — so both
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
            that: isA<Event>().having((e) => e.name, 'name', 'session_start'),
          ),
        ),
        () => mockBatchTransport.addEvent(
          any(
            that: isA<Event>().having((e) => e.name, 'name', 'trigger_event'),
          ),
        ),
      ]);
    });

    test(
      'rotates the session when a configured transport reports it invalid',
      () async {
        final client = MockClient((request) async {
          return http.Response(
            '',
            202,
            headers: {'X-Faro-Session-Status': 'invalid'},
          );
        });
        final transport = FaroTransport(
          collectorUrl: 'https://some-url.com',
          apiKey: apiKey,
          sessionIdResolver: () => Faro().meta.session!.id!,
          httpClient: client,
        );
        final config = FaroConfig(
          appName: appName,
          appVersion: appVersion,
          appEnv: appEnv,
          apiKey: apiKey,
          collectorUrl: 'https://some-url.com',
          transports: [transport],
        );

        await Faro().init(optionsConfiguration: config);
        final initialSessionId = Faro().meta.session!.id;
        clearInteractions(mockBatchTransport);

        await transport.send({
          'meta': Faro().meta.toJson(),
          'events': <dynamic>[],
        });

        final session = Faro().meta.session!;
        expect(session.id, isNot(initialSessionId));
        expect(session.attributes?['previousSession'], initialSessionId);
        verifyInOrder([
          () => mockBatchTransport.updatePayloadMeta(
            any(
              that: isA<Meta>().having(
                (meta) => meta.session?.id,
                'session.id',
                session.id,
              ),
            ),
          ),
          () => mockBatchTransport.addEvent(
            any(
              that: isA<Event>().having(
                (event) => event.name,
                'name',
                'session_start',
              ),
            ),
          ),
        ]);
      },
    );

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
            that: isA<Event>().having((e) => e.name, 'name', 'session_start'),
          ),
        ),
        () => mockBatchTransport.addLog(any()),
      ]);
    });

    test(
      'periodic vitals do not extend inactivity while backgrounded',
      () async {
        await initFaro();
        final initialSessionId = Faro().meta.session?.id;
        // Backgrounded: vitals must not count as activity.
        buildLifecycleObserver().didChangeAppLifecycleState(
          AppLifecycleState.paused,
        );

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
              that: isA<Event>().having((e) => e.name, 'name', 'session_start'),
            ),
          ),
          () => mockBatchTransport.addMeasurement(any()),
        ]);
      },
    );

    test(
      'periodic vitals do not extend inactivity while foregrounded',
      () async {
        await initFaro();
        final initialSessionId = Faro().meta.session?.id;

        now = now.add(const Duration(minutes: 10));
        ingestVitals();
        now = now.add(const Duration(minutes: 4, seconds: 59));
        ingestVitals();
        expect(Faro().meta.session?.id, initialSessionId);

        now = now.add(const Duration(seconds: 1));
        ingestVitals();

        final session = Faro().meta.session;
        expect(session?.id, isNot(initialSessionId));
        expect(session?.attributes?['previousSession'], initialSessionId);
      },
    );

    test(
      'explicit user actions refresh inactivity while backgrounded',
      () async {
        await initFaro();
        final initialSessionId = Faro().meta.session?.id;
        buildLifecycleObserver().didChangeAppLifecycleState(
          AppLifecycleState.paused,
        );

        now = now.add(const Duration(minutes: 10));
        final action = Faro().startUserAction('background_sync');
        expect(action, isNotNull);
        expect(pod.resolve(sessionManagerProvider).lastActivityAt, now);

        now = now.add(const Duration(minutes: 10));
        Faro().pushEvent('poll_complete');

        expect(Faro().meta.session?.id, initialSessionId);
      },
    );

    test(
      'foreground return rotates before lifecycle telemetry attribution',
      () async {
        await initFaro();
        final initialSessionId = Faro().meta.session?.id;
        final observer = buildLifecycleObserver();

        observer.didChangeAppLifecycleState(AppLifecycleState.paused);
        now = now.add(const Duration(minutes: 15));
        clearInteractions(mockBatchTransport);
        observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

        final rotatedSessionId = Faro().meta.session?.id;
        expect(rotatedSessionId, isNot(initialSessionId));
        verifyInOrder([
          () => mockBatchTransport.updatePayloadMeta(
            any(
              that: isA<Meta>().having(
                (meta) => meta.session?.id,
                'session.id',
                rotatedSessionId,
              ),
            ),
          ),
          () => mockBatchTransport.addEvent(
            any(
              that: isA<Event>().having(
                (event) => event.name,
                'name',
                'session_start',
              ),
            ),
          ),
          () => mockBatchTransport.addEvent(
            any(
              that: isA<Event>().having(
                (event) => event.name,
                'name',
                'app_lifecycle_changed',
              ),
            ),
          ),
        ]);
      },
    );

    test('generic telemetry remains passive before the timeout', () async {
      await initFaro();
      final manager = pod.resolve(sessionManagerProvider);
      final initialActivityAt = manager.lastActivityAt;

      now = now.add(const Duration(minutes: 1));
      Faro().pushEvent('poll_complete');
      now = now.add(const Duration(minutes: 1));
      Faro().pushLog('poll log', level: LogLevel.info);
      now = now.add(const Duration(minutes: 1));
      Faro().pushError(type: 'poll_error', value: 'retrying');
      now = now.add(const Duration(minutes: 1));
      Faro().pushMeasurement({'items': 1}, 'poll_result');

      expect(manager.lastActivityAt, initialActivityAt);
    });

    test('vitals pushed by NativeIntegration do not extend the '
        'session', () async {
      when(() => mockFaroNativeMethods.getAppStart()).thenAnswer(
        (_) async => {
          'appStartDurationMillis': 100,
          'isUserVisibleColdStart': true,
          'prewarmed': false,
        },
      );
      await initFaro();
      final initialSessionId = Faro().meta.session?.id;
      // An automatic vitals measurement at 14 minutes flows through
      // the passive path: no rotation, no activity recorded.
      now = now.add(const Duration(minutes: 14));
      clearInteractions(mockBatchTransport);
      await pod.resolve(nativeIntegrationProvider).getAppStart();
      // Guards against the stub silently ceasing to produce a measurement,
      // which would leave the rest of this test asserting nothing.
      verify(() => mockBatchTransport.addMeasurement(any())).called(1);
      expect(Faro().meta.session?.id, initialSessionId);

      // Two minutes later it is 16 minutes since the last meaningful work.
      // If the vitals measurement had recorded activity, this view update
      // would not rotate.
      now = now.add(const Duration(minutes: 2));
      Faro().setViewMeta(name: 'checkout');

      final session = Faro().meta.session;
      expect(session?.id, isNot(initialSessionId));
      expect(session?.attributes?['previousSession'], initialSessionId);
    });

    test('emits a single session_start on rotation', () async {
      await initFaro();
      clearInteractions(mockBatchTransport);

      now = now.add(const Duration(minutes: 16));
      Faro().pushEvent('trigger_event');

      final eventNames = capturedEventNames();
      final sessionStarts = eventNames
          .where((name) => name == 'session_start')
          .length;
      expect(sessionStarts, 1);
      expect(eventNames, isNot(contains('session_extend')));
    });
  });
}
