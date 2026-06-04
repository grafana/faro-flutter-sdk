import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/configurations/batch_config.dart';
import 'package:faro/src/configurations/faro_config.dart';
import 'package:faro/src/data_collection_policy.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';
import 'package:faro/src/tracing/span.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/transport/faro_transport.dart';
import 'package:faro/src/util/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFaroTransport extends Mock implements FaroTransport {}

class MockBatchTransport extends Mock implements BatchTransport {}

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
      const trace = {'traceId': 'testtraceid', 'spanId': 'testspanid'};
      Faro().pushLog(
        logMessage,
        level: LogLevel.info,
        context: logContext,
        trace: trace,
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
