import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/configurations/batch_config.dart';
import 'package:faro/src/configurations/faro_config.dart';
import 'package:faro/src/data_collection_policy.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';
import 'package:faro/src/session/session_manager.dart';
import 'package:faro/src/session/session_persistence.dart';
import 'package:faro/src/tracing/faro_span_context.dart';
import 'package:faro/src/tracing/span.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:faro/src/transport/faro_transport.dart';
import 'package:faro/src/util/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFaroTransport extends Mock implements FaroTransport {}

class MockBatchTransport extends Mock implements BatchTransport {}

class MockBaseTransport extends Mock implements BaseTransport {}

class MockFaroNativeMethods extends Mock implements FaroNativeMethods {}

class MockDataCollectionPolicy extends Mock implements DataCollectionPolicy {}

void main() {
  group('RUM Flutter initialization', () {
    const appName = 'TestApp';
    const appVersion = '2.0.3';
    const appEnv = 'Test';
    const apiKey = 'TestAPIKey';
    const appNamespace = 'FlutterApp';

    late MockFaroTransport mockFaroTransport;
    late MockBatchTransport mockBatchTransport;
    late MockBaseTransport mockBaseTransport;
    late MockFaroNativeMethods mockFaroNativeMethods;
    late MockDataCollectionPolicy mockDataCollectionPolicy;

    setUpAll(() {
      registerFallbackValue(
        FaroException('test', 'something', {
          'frames': <Map<String, dynamic>>[],
        }),
      );
      registerFallbackValue(Event('test', attributes: {'test': 'test'}));
      registerFallbackValue(FaroLog('This is a message'));
      registerFallbackValue(Measurement({'test': 123}, 'test'));
      registerFallbackValue(Payload(Meta()));
      registerFallbackValue(BatchConfig());
      registerFallbackValue(Meta());
    });

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await Faro.resetForTesting();

      // Reset the BatchTransportFactory singleton state
      BatchTransportFactory().reset();

      // Mock SharedPreferences
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
      mockBaseTransport = MockBaseTransport();
      mockFaroNativeMethods = MockFaroNativeMethods();

      BatchTransportFactory().setInstance(mockBatchTransport);

      Faro().transports = [mockFaroTransport];
      Faro().nativeChannel = mockFaroNativeMethods;
      Faro().batchTransport = mockBatchTransport;

      when(
        () => mockFaroNativeMethods.enableCrashReporter(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockFaroNativeMethods.getCrashReport(),
      ).thenAnswer((_) async => null);
      when(
        () => mockFaroNativeMethods.purgeCrashReport(),
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
      when(() => mockBaseTransport.send(any())).thenAnswer((_) async {});
      when(
        () => mockFaroTransport.sendHistoricalAcknowledged(any()),
      ).thenAnswer((_) async => true);
    });

    tearDown(() async {
      await Faro.resetForTesting();

      // Clean up the singleton state after each test
      BatchTransportFactory().reset();
    });

    test('init called with no error', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({
        'device_id': 'test-installation-id',
      });
      final rumConfig = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        anrTracking: true,
        cpuUsageVitals: false,
        memoryUsageVitals: false,
        collectorUrl: 'https://some-url.com',
      );

      await Faro().init(optionsConfiguration: rumConfig);

      final app = Faro().meta.app;
      expect(app?.name, rumConfig.appName);
      expect(app?.version, rumConfig.appVersion);
      expect(app?.environment, rumConfig.appEnv);
      expect(app?.installationId, 'test-installation-id');
      expect(Faro().meta.device?.manufacturer, isNotNull);
      expect(Faro().meta.device?.modelIdentifier, isNotNull);
      expect(Faro().meta.device?.modelName, isNotNull);
      expect(Faro().meta.device?.brand, isNotNull);
      expect(Faro().meta.device?.isPhysical, isNotNull);
      expect(Faro().meta.os?.name, isNotNull);
      expect(Faro().meta.os?.version, isNotNull);
      expect(Faro().meta.os?.detail, isNotNull);
      expect(
        Faro().meta.session?.attributes?['device_id'],
        'test-installation-id',
      );
      verify(() => mockBatchTransport.addEvent(any())).called(1);
    });

    group('session persistence integration', () {
      late Directory temporaryDirectory;
      late SessionPersistenceFactory persistenceFactory;

      FaroConfig createConfig({
        bool persistSession = true,
        bool enableCrashReporting = false,
      }) {
        return FaroConfig(
          appName: appName,
          appVersion: appVersion,
          appEnv: appEnv,
          apiKey: apiKey,
          collectorUrl: 'https://some-url.com',
          persistSession: persistSession,
          enableCrashReporting: enableCrashReporting,
          transports: const <FaroTransport>[],
        );
      }

      Future<void> seedPersistedSession(String sessionId) async {
        final persistence = await persistenceFactory.create(
          processIdentifier: 'com.example.app',
        );
        final startedAt = DateTime.utc(2026, 8, 11, 12);
        persistence.record(
          SessionState(
            currentSessionId: sessionId,
            previousSessionId: null,
            startedAt: startedAt,
            lastActivityAt: startedAt,
          ),
          isSampled: true,
          immediate: true,
        );
        await persistence.flush();
      }

      void stubRuntimeInfo({required bool ownsPersistence}) {
        when(
          () => mockFaroNativeMethods.getSessionRuntimeInfo(
            claimSessionPersistence: true,
          ),
        ).thenAnswer(
          (_) async => <String, dynamic>{
            'processIdentifier': 'com.example.app',
            'ownsSessionPersistence': ownsPersistence,
          },
        );
      }

      setUp(() async {
        temporaryDirectory = await Directory.systemTemp.createTemp(
          'faro-init-session-persistence-',
        );
        persistenceFactory = SessionPersistenceFactory(
          applicationSupportDirectory: () async => temporaryDirectory,
        );
        Faro().mobilePlatformResolver = () => true;
        Faro().sessionPersistenceFactory = persistenceFactory;
      });

      tearDown(() {
        if (temporaryDirectory.existsSync()) {
          temporaryDirectory.deleteSync(recursive: true);
        }
      });

      test('loads, links, and replaces the prior cold-start record', () async {
        await seedPersistedSession('persisted-session');
        stubRuntimeInfo(ownsPersistence: true);

        await Faro().init(optionsConfiguration: createConfig());

        final currentSessionId = Faro().meta.session?.id;
        expect(currentSessionId, isNot('persisted-session'));
        expect(
          Faro().meta.session?.attributes?['previousSession'],
          'persisted-session',
        );
        expect(
          Faro().meta.session?.attributes?['process_name'],
          'com.example.app',
        );
        expect(Faro().meta.session?.attributes?['dart_isolate_name'], 'main');

        final persistence = await persistenceFactory.create(
          processIdentifier: 'com.example.app',
        );
        final stored = await persistence.load();
        expect(stored?.currentSessionId, currentSessionId);
        expect(stored?.previousSessionId, 'persisted-session');
        expect(stored?.isSampled, isTrue);
      });

      test('explicit reset replaces the persisted session record', () async {
        stubRuntimeInfo(ownsPersistence: true);
        await Faro().init(optionsConfiguration: createConfig());
        final initialSessionId = Faro().meta.session?.id;

        await Faro().resetSession();

        final currentSessionId = Faro().meta.session?.id;
        final persistence = await persistenceFactory.create(
          processIdentifier: 'com.example.app',
        );
        final stored = await persistence.load();
        expect(currentSessionId, isNot(initialSessionId));
        expect(stored?.currentSessionId, currentSessionId);
        expect(stored?.previousSessionId, initialSessionId);
        expect(stored?.isSampled, Faro().isSampled);
      });

      test('disabling persistence clears the owned record', () async {
        await seedPersistedSession('persisted-session');
        stubRuntimeInfo(ownsPersistence: true);

        await Faro().init(
          optionsConfiguration: createConfig(persistSession: false),
        );

        final persistence = await persistenceFactory.create(
          processIdentifier: 'com.example.app',
        );
        expect(await persistence.load(), isNull);
        expect(
          Faro().meta.session?.attributes?.containsKey('previousSession'),
          isFalse,
        );
      });

      test(
        'iOS skips an unmatched crash when session persistence is active',
        () async {
          stubRuntimeInfo(ownsPersistence: true);
          Faro().iosPlatformResolver = () => true;
          Faro().androidPlatformResolver = () => false;
          when(() => mockFaroNativeMethods.getCrashReport()).thenAnswer(
            (_) async => <String>[
              json.encode({
                'type': 'SIGSEGV',
                'value': 'Application crash',
                'timestamp': '2026-08-14T12:03:00.000Z',
              }),
            ],
          );

          await Faro().init(
            optionsConfiguration: createConfig(enableCrashReporting: true),
          );

          final config = verify(
            () => mockFaroNativeMethods.enableCrashReporter(captureAny()),
          ).captured.single;
          expect(config, isEmpty);
          verify(() => mockFaroNativeMethods.getCrashReport()).called(1);
          await untilCalled(() => mockFaroNativeMethods.purgeCrashReport());
          verify(() => mockFaroNativeMethods.purgeCrashReport()).called(1);
          verifyNever(
            () => mockFaroTransport.sendHistoricalAcknowledged(any()),
          );
          verifyNever(() => mockBatchTransport.addExceptions(any()));
        },
      );

      test(
        'iOS keeps the crash fallback when persistence is disabled',
        () async {
          stubRuntimeInfo(ownsPersistence: true);
          Faro().iosPlatformResolver = () => true;
          Faro().androidPlatformResolver = () => false;
          when(() => mockFaroNativeMethods.getCrashReport()).thenAnswer(
            (_) async => <String>[
              json.encode({
                'type': 'SIGABRT',
                'value': 'Application crash',
                'timestamp': '2026-08-14T12:03:00.000Z',
              }),
            ],
          );

          await Faro().init(
            optionsConfiguration: createConfig(
              persistSession: false,
              enableCrashReporting: true,
            ),
          );

          final config = verify(
            () => mockFaroNativeMethods.enableCrashReporter(captureAny()),
          ).captured.single;
          expect(config, isEmpty);
          verify(() => mockFaroNativeMethods.getCrashReport()).called(1);
          verify(
            () => mockFaroTransport.sendHistoricalAcknowledged(any()),
          ).called(1);
          verifyNever(() => mockBatchTransport.addExceptions(any()));
          await untilCalled(() => mockFaroNativeMethods.purgeCrashReport());
          verify(() => mockFaroNativeMethods.purgeCrashReport()).called(1);
        },
      );

      test('iOS retains the pending crash when delivery is rejected', () async {
        final deliveryStarted = Completer<void>();
        final deliveryResult = Completer<bool>();
        stubRuntimeInfo(ownsPersistence: true);
        Faro().iosPlatformResolver = () => true;
        Faro().androidPlatformResolver = () => false;
        when(() => mockFaroNativeMethods.getCrashReport()).thenAnswer(
          (_) async => <String>[
            json.encode({
              'type': 'SIGABRT',
              'value': 'Application crash',
              'timestamp': '2026-08-14T12:03:00.000Z',
            }),
          ],
        );
        when(
          () => mockFaroTransport.sendHistoricalAcknowledged(any()),
        ).thenAnswer((_) {
          deliveryStarted.complete();
          return deliveryResult.future;
        });

        await Faro().init(
          optionsConfiguration: createConfig(
            persistSession: false,
            enableCrashReporting: true,
          ),
        );

        await deliveryStarted.future;
        deliveryResult.complete(false);
        await Future<void>.delayed(Duration.zero);
        verifyNever(() => mockFaroNativeMethods.purgeCrashReport());
      });

      test('iOS non-owner does not consume the pending crash', () async {
        stubRuntimeInfo(ownsPersistence: false);
        Faro().iosPlatformResolver = () => true;
        Faro().androidPlatformResolver = () => false;

        await Faro().init(
          optionsConfiguration: createConfig(enableCrashReporting: true),
        );

        verify(
          () => mockFaroNativeMethods.enableCrashReporter(any()),
        ).called(1);
        verifyNever(() => mockFaroNativeMethods.getCrashReport());
        verifyNever(() => mockFaroNativeMethods.purgeCrashReport());
      });

      test(
        'iOS recovery falls back when runtime info is unavailable',
        () async {
          when(
            () => mockFaroNativeMethods.getSessionRuntimeInfo(
              claimSessionPersistence: true,
            ),
          ).thenAnswer((_) async => null);
          Faro().iosPlatformResolver = () => true;
          Faro().androidPlatformResolver = () => false;
          when(() => mockFaroNativeMethods.getCrashReport()).thenAnswer(
            (_) async => <String>[
              json.encode({
                'type': 'SIGABRT',
                'value': 'Application crash',
                'timestamp': '2026-08-14T12:03:00.000Z',
              }),
            ],
          );

          await Faro().init(
            optionsConfiguration: createConfig(enableCrashReporting: true),
          );

          verify(() => mockFaroNativeMethods.getCrashReport()).called(1);
          await untilCalled(() => mockFaroNativeMethods.purgeCrashReport());
          verify(() => mockFaroNativeMethods.purgeCrashReport()).called(1);
        },
      );

      test('iOS leaves a pending crash while collection is disabled', () async {
        SharedPreferences.setMockInitialValues({
          'faro_enable_data_collection': false,
        });
        stubRuntimeInfo(ownsPersistence: true);
        Faro().iosPlatformResolver = () => true;
        Faro().androidPlatformResolver = () => false;

        await Faro().init(
          optionsConfiguration: createConfig(enableCrashReporting: true),
        );

        verifyNever(() => mockFaroNativeMethods.getCrashReport());
        verifyNever(() => mockFaroNativeMethods.purgeCrashReport());
      });

      test(
        'a non-owner stays in memory and preserves the owned record',
        () async {
          await seedPersistedSession('persisted-session');
          stubRuntimeInfo(ownsPersistence: false);

          await Faro().init(optionsConfiguration: createConfig());

          final persistence = await persistenceFactory.create(
            processIdentifier: 'com.example.app',
          );
          expect(
            (await persistence.load())?.currentSessionId,
            'persisted-session',
          );
          expect(
            Faro().meta.session?.attributes?.containsKey('previousSession'),
            isFalse,
          );
        },
      );

      test('storage failures fall back to an unlinked session', () async {
        stubRuntimeInfo(ownsPersistence: true);
        Faro().iosPlatformResolver = () => true;
        Faro().androidPlatformResolver = () => false;
        Faro().sessionPersistenceFactory = SessionPersistenceFactory(
          applicationSupportDirectory: () =>
              Future<Directory>.error(StateError('storage unavailable')),
        );

        await Faro().init(
          optionsConfiguration: createConfig(enableCrashReporting: true),
        );

        expect(Faro().meta.session?.id, isNotEmpty);
        expect(
          Faro().meta.session?.attributes?.containsKey('previousSession'),
          isFalse,
        );
        verify(
          () => mockFaroNativeMethods.enableCrashReporter(any()),
        ).called(1);
        verify(() => mockFaroNativeMethods.getCrashReport()).called(1);
      });
    });

    test('pre-init no-op tracing does not prevent later init', () async {
      Faro().startSpanManual('preinit-span').end();

      await Faro().init(
        optionsConfiguration: FaroConfig(
          appName: appName,
          appVersion: appVersion,
          appEnv: appEnv,
          apiKey: apiKey,
          collectorUrl: 'https://some-url.com',
        ),
      );

      final app = Faro().meta.app;
      expect(app?.name, appName);
      verify(() => mockBatchTransport.addEvent(any())).called(1);
    });

    test('resetSession before init leaves the session unchanged', () async {
      final initialSessionId = Faro().meta.session?.id;

      await Faro().resetSession();

      expect(Faro().meta.session?.id, initialSessionId);
      verifyNever(() => mockBatchTransport.addEvent(any()));
    });

    test('resetForTesting clears OpenTelemetry global state', () async {
      await Faro().init(
        optionsConfiguration: FaroConfig(
          appName: appName,
          appVersion: appVersion,
          appEnv: appEnv,
          apiKey: apiKey,
          collectorUrl: 'https://some-url.com',
        ),
      );
      expect(otel.OTelFactory.otelFactory, isNotNull);

      await Faro.resetForTesting();

      expect(otel.OTelFactory.otelFactory, isNull);
    });

    test('uses Faro instrumentation scope for spans', () async {
      await Faro().init(
        optionsConfiguration: FaroConfig(
          appName: appName,
          appVersion: appVersion,
          appEnv: appEnv,
          apiKey: apiKey,
          collectorUrl: 'https://some-url.com',
        ),
      );

      final span = Faro().startSpanManual('scope-test') as InternalSpan;
      addTearDown(span.end);

      final instrumentationScope = span.otelSpan.instrumentationScope;
      expect(instrumentationScope.name, FaroConstants.sdkName);
      expect(instrumentationScope.version, FaroConstants.sdkVersion);
    });

    test('subsequent init calls are ignored', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final initialConfig = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
      );
      final secondConfig = FaroConfig(
        appName: 'SecondApp',
        appVersion: '9.9.9',
        appEnv: 'SecondEnv',
        apiKey: 'SecondKey',
        collectorUrl: 'https://other-url.com',
      );

      await Faro().init(optionsConfiguration: initialConfig);
      clearInteractions(mockBatchTransport);

      await Faro().init(optionsConfiguration: secondConfig);

      final app = Faro().meta.app;
      expect(app?.name, initialConfig.appName);
      expect(app?.version, initialConfig.appVersion);
      expect(app?.environment, initialConfig.appEnv);
      verifyNever(() => mockBatchTransport.addEvent(any()));
    });

    test('set App Meta data', () {
      Faro().setAppMeta(
        appName: appName,
        appEnv: appEnv,
        appVersion: appVersion,
        namespace: appNamespace,
      );
      expect(Faro().meta.app?.name, appName);
      expect(Faro().meta.app?.environment, appEnv);
      expect(Faro().meta.app?.version, appVersion);
    });

    test('set App Meta data preserves installationId', () {
      Faro().setAppMeta(
        appName: appName,
        appEnv: appEnv,
        appVersion: appVersion,
        namespace: appNamespace,
        installationId: 'install-id',
      );

      Faro().setAppMeta(
        appName: 'UpdatedApp',
        appEnv: appEnv,
        appVersion: appVersion,
        namespace: appNamespace,
      );

      expect(Faro().meta.app?.name, 'UpdatedApp');
      expect(Faro().meta.app?.installationId, 'install-id');
    });

    test('set user meta data ', () async {
      await Faro().init(
        optionsConfiguration: FaroConfig(
          appName: appName,
          appVersion: appVersion,
          appEnv: appEnv,
          apiKey: apiKey,
          collectorUrl: 'https://some-url.com',
        ),
      );
      // ignore: deprecated_member_use_from_same_package
      Faro().setUserMeta(
        userId: 'testuserid',
        userName: 'testusername',
        userEmail: 'testusermail@example.com',
      );
      await Future<void>.delayed(Duration.zero);
      expect(Faro().meta.user?.id, 'testuserid');
      expect(Faro().meta.user?.username, 'testusername');
      expect(Faro().meta.user?.email, 'testusermail@example.com');
    });

    test('set user with setUser', () async {
      await Faro().init(
        optionsConfiguration: FaroConfig(
          appName: appName,
          appVersion: appVersion,
          appEnv: appEnv,
          apiKey: apiKey,
          collectorUrl: 'https://some-url.com',
        ),
      );
      await Faro().setUser(
        const FaroUser(
          id: 'testuserid2',
          username: 'testusername2',
          email: 'testusermail2@example.com',
        ),
      );
      expect(Faro().meta.user?.id, 'testuserid2');
      expect(Faro().meta.user?.username, 'testusername2');
      expect(Faro().meta.user?.email, 'testusermail2@example.com');
    });

    test('set view meta data ', () {
      Faro().setViewMeta(name: 'Testview');
      expect(Faro().meta.view?.name, 'Testview');
    });

    test('send custom event', () {
      const eventName = 'TestEvent';
      const eventAttributes = {'testkey': 'testvalue'};
      Faro().pushEvent(eventName, attributes: eventAttributes);
      verify(() => mockBatchTransport.addEvent(any())).called(1);
    });

    test('send custom log', () {
      const logMessage = 'Log Message';
      const logContext = {'testkey': 'testvalue'};
      const spanContext = FaroSpanContext(
        traceId: 'testtraceid',
        spanId: 'testspanid',
      );
      Faro().pushLog(
        logMessage,
        level: LogLevel.info,
        context: logContext,
        spanContext: spanContext,
      );
      verify(() => mockBatchTransport.addLog(any())).called(1);
    });

    test('send Error Logs', () {
      final flutterErrorDetails = FlutterErrorDetails(
        exception: FlutterError('Test Error'),
      );
      const errorType = 'flutter_error';
      Faro().pushError(
        type: errorType,
        value: flutterErrorDetails.exception.toString(),
        stacktrace: flutterErrorDetails.stack,
      );
      final capturedException =
          verify(
                () => mockBatchTransport.addExceptions(captureAny()),
              ).captured.single
              as FaroException;
      expect(capturedException.fatal, isFalse);
    });

    test('send fatal Error Logs', () {
      Faro().pushError(type: 'crash', value: 'Native crash', fatal: true);
      final capturedException =
          verify(
                () => mockBatchTransport.addExceptions(captureAny()),
              ).captured.single
              as FaroException;
      expect(capturedException.fatal, isTrue);
    });

    test('native Android crash forwards the captured trace', () async {
      const nativeTrace = '''
java.lang.NullPointerException: test crash
    at com.example.MainActivity.crash(MainActivity.kt:42)
''';
      final crashReport = json.encode({
        'reason': 'CRASH',
        'status': 0,
        'description': 'Native crash',
        'trace': nativeTrace,
        'timestamp': '1749080960296',
        'importance': 100,
        'processName': 'com.example.app',
      });

      await Faro().reportAndroidCrashesForTesting([crashReport]);

      final capturedException =
          verify(
                () => mockBatchTransport.addExceptions(captureAny()),
              ).captured.single
              as FaroException;
      expect(capturedException.fatal, isTrue);
      expect(capturedException.context?['stacktrace'], nativeTrace);
    });

    test('native Android crash accepts the legacy stacktrace key', () async {
      const nativeTrace = 'legacy native trace';
      final crashReport = json.encode({
        'reason': 'CRASH',
        'status': 0,
        'description': 'Native crash',
        'stacktrace': nativeTrace,
        'timestamp': '1749080960296',
        'importance': 100,
        'processName': 'com.example.app',
      });

      await Faro().reportAndroidCrashesForTesting([crashReport]);

      final capturedException =
          verify(
                () => mockBatchTransport.addExceptions(captureAny()),
              ).captured.single
              as FaroException;
      expect(capturedException.context?['stacktrace'], nativeTrace);
    });

    test('native Android crash keeps the missing trace fallback', () async {
      final crashReport = json.encode({
        'reason': 'CRASH',
        'status': 0,
        'description': 'Native crash',
        'timestamp': '1749080960296',
        'importance': 100,
        'processName': 'com.example.app',
      });

      await Faro().reportAndroidCrashesForTesting([crashReport]);

      final capturedException =
          verify(
                () => mockBatchTransport.addExceptions(captureAny()),
              ).captured.single
              as FaroException;
      expect(capturedException.context?['stacktrace'], 'No stacktrace');
    });

    test('recovered crash is sent with the crashed session metadata', () async {
      final currentSessionId = Faro().meta.session?.id;
      final recoveredSession = PersistedSessionRecord(
        currentSessionId: 'crashed-session',
        previousSessionId: 'older-session',
        startedAt: DateTime.utc(2026, 8, 14, 12),
        lastActivityAt: DateTime.utc(2026, 8, 14, 12, 5),
        isSampled: true,
      );
      final crashReport = json.encode({
        'reason': 'CRASH',
        'status': 0,
        'description': 'Native crash',
        'timestamp': '1786710000000',
        'importance': 100,
        'processName': 'com.example.app',
      });

      await Faro().reportAndroidCrashesForTesting([
        crashReport,
      ], recoveredSession: recoveredSession);

      final payload =
          verify(
                () =>
                    mockFaroTransport.sendHistoricalAcknowledged(captureAny()),
              ).captured.single
              as Map<String, dynamic>;
      expect(payload['meta']['session']['id'], 'crashed-session');
      expect(
        payload['meta']['session']['attributes'],
        containsPair('previousSession', 'older-session'),
      );
      expect(
        payload['meta']['session']['attributes'],
        containsPair('crashedSessionId', 'crashed-session'),
      );
      expect(
        payload['meta']['session']['attributes'],
        containsPair('isSampled', 'true'),
      );
      expect(payload['meta'], isNot(contains('view')));
      expect(payload['meta'], isNot(contains('user')));
      expect(payload['meta'], isNot(contains('page')));
      expect(
        payload['exceptions'][0]['context']['crashedSessionId'],
        'crashed-session',
      );
      expect(
        payload['exceptions'][0]['timestamp'],
        DateTime.fromMillisecondsSinceEpoch(
          1786710000000,
          isUtc: true,
        ).toIso8601String(),
      );
      expect(Faro().meta.session?.id, currentSessionId);
      verifyNever(() => mockBatchTransport.addExceptions(any()));
    });

    test(
      'recovered iOS crash uses the original session and normal type',
      () async {
        Faro().meta.user = const FaroUser(id: 'current-user');
        Faro().meta.view = ViewMeta('current-view');
        Faro().meta.page = Page('https://example.com/current');
        final recoveredSession = PersistedSessionRecord(
          currentSessionId: 'crashed-session',
          previousSessionId: 'older-session',
          startedAt: DateTime.utc(2026, 8, 14, 12),
          lastActivityAt: DateTime.utc(2026, 8, 14, 12, 5),
          isSampled: true,
        );
        final crashReport = json.encode({
          'type': 'SIGSEGV (SEGV_MAPERR)',
          'value': 'Application crash: SIGSEGV',
          'stacktrace': {
            'frames': [
              {'filename': 'Runner', 'function': 'crash', 'lineno': 42},
            ],
          },
          'timestamp': '2026-08-14T12:03:00.000Z',
          'fatal': true,
        });

        await Faro().reportIOSCrashesForTesting([
          crashReport,
        ], recoveredSession: recoveredSession);

        final payload =
            verify(
                  () => mockFaroTransport.sendHistoricalAcknowledged(
                    captureAny(),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        final exception = payload['exceptions'][0] as Map<String, dynamic>;
        expect(payload['meta']['session']['id'], 'crashed-session');
        expect(
          payload['meta']['session']['attributes'],
          containsPair('isSampled', 'true'),
        );
        expect(payload['meta']['user']['id'], 'current-user');
        expect(payload['meta']['view']['name'], 'current-view');
        expect(payload['meta']['page']['url'], 'https://example.com/current');
        expect(exception['type'], 'crash');
        expect(exception['fatal'], isTrue);
        expect(exception['context']['nativeType'], 'SIGSEGV (SEGV_MAPERR)');
        expect(exception['context']['crashedSessionId'], 'crashed-session');
        expect(exception['stacktrace']['frames'], hasLength(1));
        verifyNever(() => mockBatchTransport.addExceptions(any()));
      },
    );

    test('recovered iOS crash reaches custom transports', () async {
      Faro().transports = <BaseTransport>[mockFaroTransport, mockBaseTransport];
      final recoveredSession = PersistedSessionRecord(
        currentSessionId: 'crashed-session',
        previousSessionId: null,
        startedAt: DateTime.utc(2026, 8, 14, 12),
        lastActivityAt: DateTime.utc(2026, 8, 14, 12, 5),
        isSampled: true,
      );
      final crashReport = json.encode({
        'type': 'SIGSEGV',
        'value': 'Application crash',
        'timestamp': '2026-08-14T12:03:00.000Z',
      });

      await Faro().reportIOSCrashesForTesting([
        crashReport,
      ], recoveredSession: recoveredSession);

      verify(
        () => mockFaroTransport.sendHistoricalAcknowledged(any()),
      ).called(1);
      verify(() => mockBaseTransport.send(any())).called(1);
    });

    test('iOS live-session fallback preserves the structured stack', () async {
      final crashReport = json.encode({
        'type': 'SIGABRT',
        'value': 'Application crash: SIGABRT',
        'stacktrace': {
          'frames': [
            {'filename': 'Runner', 'function': 'abort'},
          ],
        },
        'timestamp': '2026-08-14T12:03:00.000Z',
      });

      await Faro().reportIOSCrashesForTesting([crashReport]);

      final payload =
          verify(
                () =>
                    mockFaroTransport.sendHistoricalAcknowledged(captureAny()),
              ).captured.single
              as Map<String, dynamic>;
      final exception = payload['exceptions'][0] as Map<String, dynamic>;
      expect(exception['type'], 'crash');
      expect(exception['fatal'], isTrue);
      expect(exception['context']['nativeType'], 'SIGABRT');
      expect(exception['stacktrace']['frames'], hasLength(1));
      verifyNever(() => mockBatchTransport.addExceptions(any()));
    });

    test('malformed iOS crash does not block the next report', () async {
      final validCrash = json.encode({
        'type': 'SIGABRT',
        'value': 'Application crash',
        'timestamp': '2026-08-14T12:03:00.000Z',
      });

      await Faro().reportIOSCrashesForTesting(['[]', validCrash]);

      verify(
        () => mockFaroTransport.sendHistoricalAcknowledged(any()),
      ).called(1);
    });

    test('iOS crash without a timestamp is ignored', () async {
      final recoveredSession = PersistedSessionRecord(
        currentSessionId: 'crashed-session',
        previousSessionId: null,
        startedAt: DateTime.utc(2026, 8, 14, 12),
        lastActivityAt: DateTime.utc(2026, 8, 14, 12, 5),
        isSampled: true,
      );
      final crashReport = json.encode({
        'type': 'SIGSEGV',
        'value': 'Application crash',
      });

      final accepted = await Faro().reportIOSCrashesForTesting([
        crashReport,
      ], recoveredSession: recoveredSession);

      expect(accepted, isTrue);
      verifyNever(() => mockFaroTransport.sendHistoricalAcknowledged(any()));
      verifyNever(() => mockBatchTransport.addExceptions(any()));
    });

    test(
      'iOS keeps the native report when a live-session transport throws',
      () async {
        Faro().transports = <BaseTransport>[mockBaseTransport];
        when(
          () => mockBaseTransport.send(any()),
        ).thenThrow(StateError('transport unavailable'));
        final crashReport = json.encode({
          'type': 'SIGSEGV',
          'value': 'Application crash',
          'timestamp': '2026-08-14T12:03:00.000Z',
        });

        final accepted = await Faro().reportIOSCrashesForTesting([crashReport]);

        expect(accepted, isFalse);
      },
    );

    test('iOS keeps the native report when the collector rejects it', () async {
      when(
        () => mockFaroTransport.sendHistoricalAcknowledged(any()),
      ).thenAnswer((_) async => false);
      final crashReport = json.encode({
        'type': 'SIGSEGV',
        'value': 'Application crash',
        'timestamp': '2026-08-14T12:03:00.000Z',
      });

      final accepted = await Faro().reportIOSCrashesForTesting([crashReport]);

      expect(accepted, isFalse);
    });

    test('recovered iOS crash from an unsampled session is not sent', () async {
      final recoveredSession = PersistedSessionRecord(
        currentSessionId: 'unsampled-session',
        previousSessionId: null,
        startedAt: DateTime.utc(2026, 8, 14, 12),
        lastActivityAt: DateTime.utc(2026, 8, 14, 12, 5),
        isSampled: false,
      );
      final crashReport = json.encode({
        'type': 'SIGSEGV',
        'value': 'Application crash',
        'timestamp': '2026-08-14T12:03:00.000Z',
      });

      await Faro().reportIOSCrashesForTesting([
        crashReport,
      ], recoveredSession: recoveredSession);

      verifyNever(() => mockFaroTransport.sendHistoricalAcknowledged(any()));
      verifyNever(() => mockBatchTransport.addExceptions(any()));
    });

    test('recovered iOS crash respects disabled data collection', () async {
      Faro().dataCollectionPolicy = mockDataCollectionPolicy;
      when(() => mockDataCollectionPolicy.isEnabled).thenReturn(false);
      final crashReport = json.encode({
        'type': 'SIGSEGV',
        'value': 'Application crash',
        'timestamp': '2026-08-14T12:03:00.000Z',
      });

      final accepted = await Faro().reportIOSCrashesForTesting([crashReport]);

      expect(accepted, isFalse);
      verifyNever(() => mockFaroTransport.sendHistoricalAcknowledged(any()));
      verifyNever(() => mockBatchTransport.addExceptions(any()));
    });

    test('recovered crash from an unsampled session is not sent', () async {
      final recoveredSession = PersistedSessionRecord(
        currentSessionId: 'unsampled-session',
        previousSessionId: null,
        startedAt: DateTime.utc(2026, 8, 14, 12),
        lastActivityAt: DateTime.utc(2026, 8, 14, 12, 5),
        isSampled: false,
      );
      final crashReport = json.encode({
        'reason': 'CRASH',
        'status': 0,
        'timestamp': '1786710000000',
      });

      await Faro().reportAndroidCrashesForTesting([
        crashReport,
      ], recoveredSession: recoveredSession);

      verifyNever(() => mockFaroTransport.sendHistoricalAcknowledged(any()));
      verifyNever(() => mockBatchTransport.addExceptions(any()));
    });

    test('recovered crash respects disabled data collection', () async {
      Faro().dataCollectionPolicy = mockDataCollectionPolicy;
      when(() => mockDataCollectionPolicy.isEnabled).thenReturn(false);
      final recoveredSession = PersistedSessionRecord(
        currentSessionId: 'crashed-session',
        previousSessionId: null,
        startedAt: DateTime.utc(2026, 8, 14, 12),
        lastActivityAt: DateTime.utc(2026, 8, 14, 12, 5),
        isSampled: true,
      );

      await Faro().reportAndroidCrashesForTesting([
        json.encode({
          'reason': 'CRASH',
          'status': 0,
          'timestamp': '1786710000000',
        }),
      ], recoveredSession: recoveredSession);

      verifyNever(() => mockFaroTransport.sendHistoricalAcknowledged(any()));
    });

    test('multiple recovered crashes use their matching sessions', () async {
      final firstSession = PersistedSessionRecord(
        currentSessionId: 'first-session',
        previousSessionId: null,
        startedAt: DateTime.utc(2026, 8, 14, 12),
        lastActivityAt: DateTime.utc(2026, 8, 14, 12, 5),
        isSampled: true,
      );
      final secondSession = PersistedSessionRecord(
        currentSessionId: 'second-session',
        previousSessionId: 'first-session',
        startedAt: DateTime.utc(2026, 8, 14, 12, 10),
        lastActivityAt: DateTime.utc(2026, 8, 14, 12, 15),
        isSampled: true,
      );

      await Faro().reportAndroidCrashesForTesting(
        [
          json.encode({
            'reason': 'CRASH',
            'status': 0,
            'timestamp': DateTime.utc(
              2026,
              8,
              14,
              12,
              5,
            ).millisecondsSinceEpoch,
            'processName': 'com.example.app',
          }),
          json.encode({
            'reason': 'ANR',
            'status': 0,
            'timestamp': DateTime.utc(
              2026,
              8,
              14,
              12,
              20,
            ).millisecondsSinceEpoch,
            'processName': 'com.example.app',
          }),
        ],
        recoveredSessions: <PersistedSessionRecord>[
          firstSession,
          secondSession,
        ],
        processIdentifier: 'com.example.app',
      );

      final payloads = verify(
        () => mockFaroTransport.sendHistoricalAcknowledged(captureAny()),
      ).captured;
      expect(payloads, hasLength(2));
      expect(
        payloads.map(
          (payload) =>
              (payload as Map<String, dynamic>)['meta']['session']['id'],
        ),
        <String>['first-session', 'second-session'],
      );
    });

    test('recovered crash from another process is ignored', () async {
      final recoveredSession = PersistedSessionRecord(
        currentSessionId: 'main-process-session',
        previousSessionId: null,
        startedAt: DateTime.utc(2026, 8, 14, 12),
        lastActivityAt: DateTime.utc(2026, 8, 14, 12, 5),
        isSampled: true,
      );

      await Faro().reportAndroidCrashesForTesting(
        [
          json.encode({
            'reason': 'CRASH',
            'status': 0,
            'timestamp': DateTime.utc(
              2026,
              8,
              14,
              12,
              5,
            ).millisecondsSinceEpoch,
            'processName': 'com.example.app:worker',
          }),
        ],
        recoveredSessions: <PersistedSessionRecord>[recoveredSession],
        processIdentifier: 'com.example.app',
      );

      verifyNever(() => mockFaroTransport.sendHistoricalAcknowledged(any()));
      verifyNever(() => mockBatchTransport.addExceptions(any()));
    });

    test(
      'recovered crash is ignored when persisted history is empty',
      () async {
        await Faro().reportAndroidCrashesForTesting(
          [
            json.encode({
              'reason': 'CRASH',
              'status': 0,
              'timestamp': DateTime.utc(
                2026,
                8,
                14,
                12,
                5,
              ).millisecondsSinceEpoch,
              'processName': 'com.example.app',
            }),
          ],
          recoveredSessions: const <PersistedSessionRecord>[],
          processIdentifier: 'com.example.app',
        );

        verifyNever(() => mockFaroTransport.sendHistoricalAcknowledged(any()));
        verifyNever(() => mockBatchTransport.addExceptions(any()));
      },
    );

    test('malformed recovered crash does not block later reports', () async {
      final crashReport = json.encode({
        'reason': 'CRASH',
        'status': 0,
        'timestamp': '1786710000000',
      });

      await Faro().reportAndroidCrashesForTesting(['not-json', crashReport]);

      verify(() => mockBatchTransport.addExceptions(any())).called(1);
    });

    test('send custom measurement', () {
      const measurementType = 'TestMeasurement';
      const measurementValue = {'key1': 1233, 'key2': 100};
      Faro().pushMeasurement(measurementValue, measurementType);
      verify(() => mockBatchTransport.addMeasurement(any())).called(1);
    });

    test(
      'enableDataCollection getter reflects DataCollectionPolicy state',
      () async {
        // Set the mock policy on Faro
        Faro().dataCollectionPolicy = mockDataCollectionPolicy;

        // Default should be enabled (as per our mock setup)
        expect(Faro().enableDataCollection, isTrue);

        // Test when policy reports disabled
        when(() => mockDataCollectionPolicy.isEnabled).thenReturn(false);
        expect(Faro().enableDataCollection, isFalse);

        // Test when policy reports enabled
        when(() => mockDataCollectionPolicy.isEnabled).thenReturn(true);
        expect(Faro().enableDataCollection, isTrue);
      },
    );

    test('enableDataCollection setter updates DataCollectionPolicy', () async {
      // Set the mock policy on Faro
      Faro().dataCollectionPolicy = mockDataCollectionPolicy;

      // Test setting to false
      Faro().enableDataCollection = false;
      verify(() => mockDataCollectionPolicy.disable()).called(1);

      // Test setting to true
      Faro().enableDataCollection = true;
      verify(() => mockDataCollectionPolicy.enable()).called(1);
    });
  });
}
