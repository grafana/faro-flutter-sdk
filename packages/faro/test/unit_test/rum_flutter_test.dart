import 'package:faro/faro_native_methods.dart';
import 'package:faro/faro_sdk.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFaroTransport extends Mock implements FaroTransport {}

class MockBatchTransport extends Mock implements BatchTransport {}

class MockFaroNativeMethods extends Mock implements FaroNativeMethods {}

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

    setUp(() {
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});

      PackageInfo.setMockInitialValues(
        appName: appName,
        packageName: 'com.example.example',
        version: appVersion,
        buildNumber: '2',
        buildSignature: 'buildSignature',
      );

      registerFallbackValue(
        FaroException(
          'test',
          'something',
          {'frames': <Map<String, dynamic>>[]},
        ),
      );
      registerFallbackValue(Event('test', attributes: {'test': 'test'}));
      registerFallbackValue(FaroLog('This is a message'));
      registerFallbackValue(Measurement({'test': 123}, 'test'));
      registerFallbackValue(Payload(Meta()));
      mockFaroTransport = MockFaroTransport();
      mockBatchTransport = MockBatchTransport();
      mockFaroNativeMethods = MockFaroNativeMethods();
      Faro().transports = [mockFaroTransport];
      Faro().nativeChannel = mockFaroNativeMethods;
      Faro().batchTransport = mockBatchTransport;
      when(() => mockFaroNativeMethods.enableCrashReporter(any()))
          .thenAnswer((_) async {});
      when(() => mockBatchTransport.addExceptions(any()))
          .thenAnswer((_) async {});
      when(() => mockBatchTransport.addLog(any())).thenAnswer((_) async {});
      when(() => mockBatchTransport.addEvent(any())).thenAnswer((_) async {});
      when(() => mockBatchTransport.addMeasurement(any()))
          .thenAnswer((_) async {});
      when(() => mockFaroTransport.send(any())).thenAnswer((_) async {});
    });

    tearDown(() {});

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

    test('set user meta data ', () {
      Faro().setUserMeta(
          userId: 'testuserid',
          userName: 'testusername',
          userEmail: 'testusermail@example.com');
      expect(Faro().meta.user?.id, 'testuserid');
      expect(Faro().meta.user?.username, 'testusername');
      expect(Faro().meta.user?.email, 'testusermail@example.com');
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
      const logLevel = 'info';
      const logContext = {'testkey': 'testvalue'};
      const trace = {'traceId': 'testtraceid', 'spanId': 'testspanid'};
      Faro().pushLog(logMessage,
          level: logLevel, context: logContext, trace: trace);
      verify(() => mockBatchTransport.addLog(any())).called(1);
    });

    test('send Error Logs', () {
      final flutterErrorDetails =
          FlutterErrorDetails(exception: FlutterError('Test Error'));
      const errorType = 'flutter_error';
      Faro().pushError(
          type: errorType,
          value: flutterErrorDetails.exception.toString(),
          stacktrace: flutterErrorDetails.stack);
      verify(() => mockBatchTransport.addExceptions(any())).called(1);
    });

    test('send custom measurement', () {
      const measurementType = 'TestMeasurement';
      const measurementValue = {'key1': 1233, 'key2': 100};
      Faro().pushMeasurement(measurementValue, measurementType);
      verify(() => mockBatchTransport.addMeasurement(any())).called(1);
    });
  });
}
