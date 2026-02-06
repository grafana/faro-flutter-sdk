// ignore_for_file: avoid_redundant_argument_values, prefer_int_literals, lines_longer_than_80_chars

import 'package:faro/src/configurations/faro_config.dart';
import 'package:faro/src/configurations/sampling.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';
import 'package:faro/src/session/sampling_context.dart';
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

    test('SamplingRate(1.0) should sample session and send telemetry',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      final config = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
        sampling: const SamplingRate(1.0),
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

    test('SamplingRate(0.0) should not sample session and drop telemetry',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      final config = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
        sampling: const SamplingRate(0.0),
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
      // With rate 0.5, random 0.3 < 0.5, so should be sampled
      RandomValueProviderFactory().setInstance(FakeRandomValueProvider(0.3));

      final config = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
        sampling: const SamplingRate(0.5),
        cpuUsageVitals: false,
        memoryUsageVitals: false,
      );

      await Faro().init(optionsConfiguration: config);

      expect(
          BatchTransportFactory().instance, isNot(isA<NoOpBatchTransport>()));
    });

    test(
        'sampling decision is consistent with injected random value, - not sampled',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Inject a fake random provider that returns 0.7
      // With rate 0.5, random 0.7 >= 0.5, so should NOT be sampled
      RandomValueProviderFactory().setInstance(FakeRandomValueProvider(0.7));

      final config = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
        sampling: const SamplingRate(0.5),
        cpuUsageVitals: false,
        memoryUsageVitals: false,
      );

      await Faro().init(optionsConfiguration: config);

      expect(BatchTransportFactory().instance, isA<NoOpBatchTransport>());
    });

    test('default sampling is 100% (all sessions sampled)', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Use default sampling (should be 100%)
      final config = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
        cpuUsageVitals: false,
        memoryUsageVitals: false,
        // sampling not specified, should default to 100%
      );

      await Faro().init(optionsConfiguration: config);

      // With default 100%, should always be sampled (not NoOpBatchTransport)
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
        sampling: const SamplingRate(0.0),
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
        sampling: const SamplingRate(0.0),
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
        sampling: const SamplingRate(0.0),
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

    group('SamplingFunction:', () {
      test('function is called with SamplingContext', () async {
        TestWidgetsFlutterBinding.ensureInitialized();

        SamplingContext? capturedContext;

        final config = FaroConfig(
          appName: appName,
          appVersion: appVersion,
          appEnv: appEnv,
          apiKey: apiKey,
          collectorUrl: 'https://some-url.com',
          cpuUsageVitals: false,
          memoryUsageVitals: false,
          sampling: SamplingFunction((context) {
            capturedContext = context;
            return 1.0;
          }),
        );

        await Faro().init(optionsConfiguration: config);

        expect(capturedContext, isNotNull);
        expect(capturedContext!.meta, isNotNull);
      });

      test('context contains app metadata', () async {
        TestWidgetsFlutterBinding.ensureInitialized();

        SamplingContext? capturedContext;

        final config = FaroConfig(
          appName: appName,
          appVersion: appVersion,
          appEnv: appEnv,
          apiKey: apiKey,
          collectorUrl: 'https://some-url.com',
          cpuUsageVitals: false,
          memoryUsageVitals: false,
          sampling: SamplingFunction((context) {
            capturedContext = context;
            return 1.0;
          }),
        );

        await Faro().init(optionsConfiguration: config);

        expect(capturedContext!.meta.app?.name, equals(appName));
        expect(capturedContext!.meta.app?.environment, equals(appEnv));
        expect(capturedContext!.meta.app?.version, equals(appVersion));
      });

      test('context contains session metadata', () async {
        TestWidgetsFlutterBinding.ensureInitialized();

        SamplingContext? capturedContext;

        final config = FaroConfig(
          appName: appName,
          appVersion: appVersion,
          appEnv: appEnv,
          apiKey: apiKey,
          collectorUrl: 'https://some-url.com',
          cpuUsageVitals: false,
          memoryUsageVitals: false,
          sessionAttributes: {'team': 'mobile', 'feature_flag': 'beta'},
          sampling: SamplingFunction((context) {
            capturedContext = context;
            return 1.0;
          }),
        );

        await Faro().init(optionsConfiguration: config);

        expect(capturedContext!.meta.session, isNotNull);
        expect(capturedContext!.meta.session?.id, isNotNull);
        // Session attributes should include custom attributes
        expect(capturedContext!.meta.session?.attributes?['team'],
            equals('mobile'));
        expect(capturedContext!.meta.session?.attributes?['feature_flag'],
            equals('beta'));
      });

      test('returning 1.0 should sample session', () async {
        TestWidgetsFlutterBinding.ensureInitialized();

        final config = FaroConfig(
          appName: appName,
          appVersion: appVersion,
          appEnv: appEnv,
          apiKey: apiKey,
          collectorUrl: 'https://some-url.com',
          cpuUsageVitals: false,
          memoryUsageVitals: false,
          sampling: SamplingFunction((context) => 1.0),
        );

        await Faro().init(optionsConfiguration: config);

        expect(
            BatchTransportFactory().instance, isNot(isA<NoOpBatchTransport>()));
      });

      test('returning 0.0 should not sample session', () async {
        TestWidgetsFlutterBinding.ensureInitialized();

        final config = FaroConfig(
          appName: appName,
          appVersion: appVersion,
          appEnv: appEnv,
          apiKey: apiKey,
          collectorUrl: 'https://some-url.com',
          cpuUsageVitals: false,
          memoryUsageVitals: false,
          sampling: SamplingFunction((context) => 0.0),
        );

        await Faro().init(optionsConfiguration: config);

        expect(BatchTransportFactory().instance, isA<NoOpBatchTransport>());
      });

      test('return value is used with random decision', () async {
        TestWidgetsFlutterBinding.ensureInitialized();

        // Inject a fake random provider that returns 0.3
        // Function returns 0.5, so random 0.3 < 0.5, should be sampled
        RandomValueProviderFactory().setInstance(FakeRandomValueProvider(0.3));

        final config = FaroConfig(
          appName: appName,
          appVersion: appVersion,
          appEnv: appEnv,
          apiKey: apiKey,
          collectorUrl: 'https://some-url.com',
          cpuUsageVitals: false,
          memoryUsageVitals: false,
          sampling: SamplingFunction((context) => 0.5),
        );

        await Faro().init(optionsConfiguration: config);

        expect(
            BatchTransportFactory().instance, isNot(isA<NoOpBatchTransport>()));
      });

      test('return value above 1.0 is clamped to 1.0', () async {
        TestWidgetsFlutterBinding.ensureInitialized();

        // Function returns 2.0, which should be clamped to 1.0
        // With rate 1.0, should always sample
        final config = FaroConfig(
          appName: appName,
          appVersion: appVersion,
          appEnv: appEnv,
          apiKey: apiKey,
          collectorUrl: 'https://some-url.com',
          cpuUsageVitals: false,
          memoryUsageVitals: false,
          sampling: SamplingFunction((context) => 2.0),
        );

        await Faro().init(optionsConfiguration: config);

        expect(
            BatchTransportFactory().instance, isNot(isA<NoOpBatchTransport>()));
      });

      test('return value below 0.0 is clamped to 0.0', () async {
        TestWidgetsFlutterBinding.ensureInitialized();

        // Function returns -1.0, which should be clamped to 0.0
        // With rate 0.0, should never sample
        final config = FaroConfig(
          appName: appName,
          appVersion: appVersion,
          appEnv: appEnv,
          apiKey: apiKey,
          collectorUrl: 'https://some-url.com',
          cpuUsageVitals: false,
          memoryUsageVitals: false,
          sampling: SamplingFunction((context) => -1.0),
        );

        await Faro().init(optionsConfiguration: config);

        expect(BatchTransportFactory().instance, isA<NoOpBatchTransport>());
      });

      test('can make decision based on app environment', () async {
        TestWidgetsFlutterBinding.ensureInitialized();

        // Inject random value that would sample at 0.5 rate
        RandomValueProviderFactory().setInstance(FakeRandomValueProvider(0.3));

        final config = FaroConfig(
          appName: appName,
          appVersion: appVersion,
          appEnv: 'production',
          apiKey: apiKey,
          collectorUrl: 'https://some-url.com',
          cpuUsageVitals: false,
          memoryUsageVitals: false,
          sampling: SamplingFunction((context) {
            // Sample 10% of production, 100% of everything else
            if (context.meta.app?.environment == 'production') {
              return 0.1;
            }
            return 1.0;
          }),
        );

        await Faro().init(optionsConfiguration: config);

        // With random 0.3 and rate 0.1, 0.3 >= 0.1, should NOT be sampled
        expect(BatchTransportFactory().instance, isA<NoOpBatchTransport>());
      });

      test('can make decision based on session attributes', () async {
        TestWidgetsFlutterBinding.ensureInitialized();

        final config = FaroConfig(
          appName: appName,
          appVersion: appVersion,
          appEnv: appEnv,
          apiKey: apiKey,
          collectorUrl: 'https://some-url.com',
          cpuUsageVitals: false,
          memoryUsageVitals: false,
          sessionAttributes: {'team': 'beta-testers'},
          sampling: SamplingFunction((context) {
            // Sample all beta testers
            if (context.meta.session?.attributes?['team'] == 'beta-testers') {
              return 1.0;
            }
            return 0.0;
          }),
        );

        await Faro().init(optionsConfiguration: config);

        expect(
            BatchTransportFactory().instance, isNot(isA<NoOpBatchTransport>()));
      });
    });
  });
}
