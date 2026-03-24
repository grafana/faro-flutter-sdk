import 'package:faro/src/configurations/batch_config.dart';
import 'package:faro/src/configurations/faro_config.dart';
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/data_collection_policy.dart';
import 'package:faro/src/device_info/platform_info_provider.dart';
import 'package:faro/src/device_info/platform_info_provider_test_support.dart';
import 'package:faro/src/device_info/session_attributes_provider.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/transport/faro_transport.dart';
import 'package:faro/src/user/user_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFaroTransport extends Mock implements FaroTransport {}

class MockBatchTransport extends Mock implements BatchTransport {}

class MockFaroNativeMethods extends Mock implements FaroNativeMethods {}

class MockDataCollectionPolicy extends Mock implements DataCollectionPolicy {}

class MockPlatformInfoProvider extends Mock implements PlatformInfoProvider {}

class MockUserManager extends Mock implements UserManager {}

class MockSessionAttributesProvider extends Mock
    implements SessionAttributesProvider {}

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
    late MockPlatformInfoProvider mockPlatformInfoProvider;
    late MockUserManager mockUserManager;
    late MockSessionAttributesProvider mockSessionAttributesProvider;

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
      registerFallbackValue(const FaroUser(id: 'fallback-user'));
    });

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      Faro.resetForTesting();

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
      mockPlatformInfoProvider = MockPlatformInfoProvider();
      mockUserManager = MockUserManager();
      mockSessionAttributesProvider = MockSessionAttributesProvider();

      pod.overrideProvider(
        platformInfoProvider,
        (_) => mockPlatformInfoProvider,
      );
      debugPlatformInfoProviderOverride = mockPlatformInfoProvider;
      when(() => mockPlatformInfoProvider.isWeb).thenReturn(false);
      when(() => mockPlatformInfoProvider.isAndroid).thenReturn(false);
      when(() => mockPlatformInfoProvider.isIOS).thenReturn(false);
      when(() => mockPlatformInfoProvider.supportsNativeIntegration)
          .thenReturn(false);
      when(() => mockPlatformInfoProvider.supportsHttpOverrides)
          .thenReturn(true);
      when(() => mockPlatformInfoProvider.supportsOfflineTransport)
          .thenReturn(true);
      when(() => mockPlatformInfoProvider.dartVersion)
          .thenReturn('test-dart-version');
      when(() => mockPlatformInfoProvider.operatingSystem)
          .thenReturn('test-os');
      when(() => mockPlatformInfoProvider.operatingSystemVersion)
          .thenReturn('test-os-version');
      when(
        () => mockUserManager.initialize(
          initialUser: any(named: 'initialUser'),
          persistUser: any(named: 'persistUser'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockUserManager.setUser(
          any(),
          persistUser: any(named: 'persistUser'),
        ),
      ).thenAnswer((invocation) async {
        final user = invocation.positionalArguments.first as FaroUser;
        Faro().meta = Meta.fromJson({
          ...Faro().meta.toJson(),
          'user': user.toJson(),
        });
      });
      when(() => mockSessionAttributesProvider.getAttributes()).thenAnswer(
        (_) async => <String, Object>{
          'dart_version': 'test-dart-version',
          'device_os': 'test-os',
        },
      );
      when(() => mockSessionAttributesProvider.getBrowserInfo()).thenAnswer(
        (_) async => null,
      );
      SessionAttributesProviderFactory.debugInstance =
          mockSessionAttributesProvider;

      BatchTransportFactory().setInstance(mockBatchTransport);

      Faro().transports = [mockFaroTransport];
      Faro().nativeChannel = mockFaroNativeMethods;
      Faro().batchTransport = mockBatchTransport;
      Faro().userManager = mockUserManager;

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

    tearDown(() {
      Faro.resetForTesting();
      debugPlatformInfoProviderOverride = null;
      SessionAttributesProviderFactory.debugInstance = null;

      // Clean up the singleton state after each test
      BatchTransportFactory().reset();
    });

    test('init called with no error', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
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
      verify(() => mockBatchTransport.addEvent(any())).called(1);
    });

    test('init sets browser/page metadata on web without native startup',
        () async {
      when(() => mockPlatformInfoProvider.isWeb).thenReturn(true);
      when(() => mockPlatformInfoProvider.supportsNativeIntegration)
          .thenReturn(false);
      when(() => mockPlatformInfoProvider.operatingSystem)
          .thenReturn('Linux x86_64');
      when(() => mockPlatformInfoProvider.operatingSystemVersion)
          .thenReturn('browser');
      when(() => mockSessionAttributesProvider.getBrowserInfo()).thenAnswer(
        (_) async => Browser(
          'chrome',
          '123.0',
          'Linux x86_64',
          'Mozilla/5.0 Chrome/123.0.0.0 Safari/537.36',
          'en-US',
          false,
        ),
      );

      final rumConfig = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
      );

      await Faro().init(optionsConfiguration: rumConfig);

      expect(Faro().meta.browser, isNotNull);
      expect(Faro().meta.page, isNotNull);
      verifyNever(() => mockFaroNativeMethods.getAppStart());
      verify(() => mockBatchTransport.addEvent(any())).called(greaterThan(0));
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
      verify(
        () => mockUserManager.setUser(
          const FaroUser(
            id: 'testuserid',
            username: 'testusername',
            email: 'testusermail@example.com',
          ),
          persistUser: true,
        ),
      ).called(1);
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
      verify(
        () => mockUserManager.setUser(
          const FaroUser(
            id: 'testuserid2',
            username: 'testusername2',
            email: 'testusermail2@example.com',
          ),
          persistUser: true,
        ),
      ).called(1);
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
