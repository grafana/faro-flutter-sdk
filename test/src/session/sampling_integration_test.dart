// ignore_for_file: avoid_redundant_argument_values, prefer_int_literals

import 'package:faro/src/configurations/faro_config.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';
import 'package:faro/src/session/session_sampling_provider.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/transport/faro_transport.dart';
import 'package:faro/src/transport/no_op_batch_transport.dart';
import 'package:faro/src/util/random_value_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_random_value_provider.dart';

class MockFaroTransport extends Mock implements FaroTransport {}

class MockFaroNativeMethods extends Mock implements FaroNativeMethods {}

void main() {
  group('Sampling integration:', () {
    const appName = 'TestApp';
    const appVersion = '2.0.3';
    const appEnv = 'Test';
    const apiKey = 'TestAPIKey';

    late MockFaroTransport mockFaroTransport;
    late MockFaroNativeMethods mockFaroNativeMethods;

    setUpAll(() {
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
      registerFallbackValue(Meta());
    });

    setUp(() {
      // Reset all singleton factories
      BatchTransportFactory().reset();
      SessionSamplingProviderFactory().reset();
      RandomValueProviderFactory().reset();

      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});

      PackageInfo.setMockInitialValues(
        appName: appName,
        packageName: 'com.grafana.example',
        version: appVersion,
        buildNumber: '2',
        buildSignature: 'buildSignature',
      );

      mockFaroTransport = MockFaroTransport();
      mockFaroNativeMethods = MockFaroNativeMethods();

      Faro().transports = [mockFaroTransport];
      Faro().nativeChannel = mockFaroNativeMethods;

      when(() => mockFaroNativeMethods.enableCrashReporter(any()))
          .thenAnswer((_) async {});
      when(() => mockFaroTransport.send(any())).thenAnswer((_) async {});
    });

    tearDown(() {
      BatchTransportFactory().reset();
      SessionSamplingProviderFactory().reset();
      RandomValueProviderFactory().reset();
    });

    test('samplingRate 1.0 should sample session and send telemetry', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      final config = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
        samplingRate: 1.0,
        cpuUsageVitals: false,
        memoryUsageVitals: false,
      );

      await Faro().init(optionsConfiguration: config);

      // Verify BatchTransport is the real implementation (sampled)
      final batchTransport = BatchTransportFactory().instance;
      expect(batchTransport, isNot(isA<NoOpBatchTransport>()));

      // Push an event and verify it's added to the payload
      Faro().pushEvent('test_event');
    });

    test('samplingRate 0.0 should not sample session and drop telemetry',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      final config = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
        samplingRate: 0.0,
        cpuUsageVitals: false,
        memoryUsageVitals: false,
      );

      await Faro().init(optionsConfiguration: config);

      // Verify BatchTransport is NoOpBatchTransport (not sampled)
      final batchTransport = BatchTransportFactory().instance;
      expect(batchTransport, isA<NoOpBatchTransport>());
    });

    test('sampling decision is consistent with injected random value - sampled',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Inject a fake random provider that returns 0.3
      // With samplingRate 0.5, random 0.3 < 0.5, so should be sampled
      RandomValueProviderFactory().setInstance(FakeRandomValueProvider(0.3));

      final config = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
        samplingRate: 0.5,
        cpuUsageVitals: false,
        memoryUsageVitals: false,
      );

      await Faro().init(optionsConfiguration: config);

      expect(
          BatchTransportFactory().instance, isNot(isA<NoOpBatchTransport>()));
    });

    test(
        'sampling decision is consistent with injected random value - not sampled',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Inject a fake random provider that returns 0.7
      // With samplingRate 0.5, random 0.7 >= 0.5, so should NOT be sampled
      RandomValueProviderFactory().setInstance(FakeRandomValueProvider(0.7));

      final config = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
        samplingRate: 0.5,
        cpuUsageVitals: false,
        memoryUsageVitals: false,
      );

      await Faro().init(optionsConfiguration: config);

      expect(BatchTransportFactory().instance, isA<NoOpBatchTransport>());
    });

    test('default samplingRate is 1.0 (all sessions sampled)', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Use default samplingRate (should be 1.0)
      final config = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
        cpuUsageVitals: false,
        memoryUsageVitals: false,
        // samplingRate not specified, should default to 1.0
      );

      await Faro().init(optionsConfiguration: config);

      // With default 1.0, should always be sampled (not NoOpBatchTransport)
      expect(
          BatchTransportFactory().instance, isNot(isA<NoOpBatchTransport>()));
    });

    test('unsampled session drops events silently', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      final config = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
        samplingRate: 0.0,
        cpuUsageVitals: false,
        memoryUsageVitals: false,
      );

      await Faro().init(optionsConfiguration: config);

      final batchTransport = BatchTransportFactory().instance!;

      // NoOpBatchTransport always reports empty
      expect(batchTransport.payloadSize(), equals(0));

      // Try to push events - they should be dropped
      Faro().pushEvent('test_event_1');
      Faro().pushEvent('test_event_2');
      Faro().pushEvent('test_event_3');

      // Still empty
      expect(batchTransport.payloadSize(), equals(0));
    });

    test('unsampled session drops logs silently', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      final config = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
        samplingRate: 0.0,
        cpuUsageVitals: false,
        memoryUsageVitals: false,
      );

      await Faro().init(optionsConfiguration: config);

      final batchTransport = BatchTransportFactory().instance!;

      // NoOpBatchTransport always reports empty
      expect(batchTransport.payloadSize(), equals(0));

      // Try to push logs - they should be dropped
      Faro().pushLog('test log 1', level: LogLevel.info);
      Faro().pushLog('test log 2', level: LogLevel.info);

      // Still empty
      expect(batchTransport.payloadSize(), equals(0));
    });

    test('unsampled session drops measurements silently', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      final config = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
        samplingRate: 0.0,
        cpuUsageVitals: false,
        memoryUsageVitals: false,
      );

      await Faro().init(optionsConfiguration: config);

      final batchTransport = BatchTransportFactory().instance!;

      // NoOpBatchTransport always reports empty
      expect(batchTransport.payloadSize(), equals(0));

      // Try to push measurements - they should be dropped
      Faro().pushMeasurement({'value': 123}, 'test_measurement');

      // Still empty
      expect(batchTransport.payloadSize(), equals(0));
    });
  });
}
