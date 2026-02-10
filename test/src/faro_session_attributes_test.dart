import 'package:faro/src/configurations/batch_config.dart';
import 'package:faro/src/configurations/faro_config.dart';
import 'package:faro/src/data_collection_policy.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/transport/faro_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFaroTransport extends Mock implements FaroTransport {}

class MockBatchTransport extends Mock implements BatchTransport {}

class MockFaroNativeMethods extends Mock implements FaroNativeMethods {}

class MockDataCollectionPolicy extends Mock implements DataCollectionPolicy {}

void main() {
  group('Session Attributes:', () {
    const appName = 'TestApp';
    const appVersion = '2.0.3';
    const appEnv = 'Test';
    const apiKey = 'TestAPIKey';

    late MockFaroTransport mockFaroTransport;
    late MockBatchTransport mockBatchTransport;
    late MockFaroNativeMethods mockFaroNativeMethods;
    late MockDataCollectionPolicy mockDataCollectionPolicy;

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
      registerFallbackValue(BatchConfig());
      registerFallbackValue(Meta());
    });

    setUp(() {
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

      when(() => mockFaroNativeMethods.enableCrashReporter(any()))
          .thenAnswer((_) async {});
      when(() => mockBatchTransport.addExceptions(any()))
          .thenAnswer((_) async {});
      when(() => mockBatchTransport.addLog(any())).thenAnswer((_) async {});
      when(() => mockBatchTransport.addEvent(any())).thenAnswer((_) async {});
      when(() => mockBatchTransport.addMeasurement(any()))
          .thenAnswer((_) async {});
      when(() => mockBatchTransport.updatePayloadMeta(any()))
          .thenAnswer((_) async {});
      when(() => mockFaroTransport.send(any())).thenAnswer((_) async {});
    });

    tearDown(() {
      // Clean up the singleton state after each test
      BatchTransportFactory().reset();
    });

    test('init with custom session attributes merges with default attributes',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final rumConfig = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
        sessionAttributes: {
          'team': 'mobile',
          'department': 'engineering',
          'custom_label': 'test_value',
        },
      );

      await Faro().init(optionsConfiguration: rumConfig);

      final sessionAttributes = Faro().meta.session?.attributes;
      expect(sessionAttributes, isNotNull);

      // Custom attributes should be present
      expect(sessionAttributes?['team'], 'mobile');
      expect(sessionAttributes?['department'], 'engineering');
      expect(sessionAttributes?['custom_label'], 'test_value');

      // Default attributes should also be present
      expect(sessionAttributes?['device_os'], isNotNull);
      expect(sessionAttributes?['device_model'], isNotNull);
    });

    test('init with null session attributes works correctly', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final rumConfig = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
        // sessionAttributes not provided (null)
      );

      await Faro().init(optionsConfiguration: rumConfig);

      final sessionAttributes = Faro().meta.session?.attributes;
      expect(sessionAttributes, isNotNull);

      // Only default attributes should be present
      expect(sessionAttributes?['device_os'], isNotNull);
      expect(sessionAttributes?['device_model'], isNotNull);
    });

    test('init with empty session attributes map works correctly', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final rumConfig = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
        sessionAttributes: {}, // empty map
      );

      await Faro().init(optionsConfiguration: rumConfig);

      final sessionAttributes = Faro().meta.session?.attributes;
      expect(sessionAttributes, isNotNull);

      // Only default attributes should be present
      expect(sessionAttributes?['device_os'], isNotNull);
      expect(sessionAttributes?['device_model'], isNotNull);
    });

    test('default attributes take precedence over custom attributes', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      // Try to override a default attribute
      final rumConfig = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
        sessionAttributes: {
          'device_os': 'CustomOS', // Try to override device_os
          'custom_attr': 'custom_value',
        },
      );

      await Faro().init(optionsConfiguration: rumConfig);

      final sessionAttributes = Faro().meta.session?.attributes;
      expect(sessionAttributes, isNotNull);

      // Default attribute should override the custom one
      expect(sessionAttributes?['device_os'], isNot('CustomOS'));
      expect(sessionAttributes?['device_os'], isNotNull);

      // Custom attribute that doesn't conflict should still be present
      expect(sessionAttributes?['custom_attr'], 'custom_value');
    });

    test('session attributes with special characters work correctly', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final rumConfig = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
        sessionAttributes: {
          'label-with-dash': 'value1',
          'label_with_underscore': 'value2',
          'label.with.dot': 'value3',
          'label/with/slash': 'value4',
        },
      );

      await Faro().init(optionsConfiguration: rumConfig);

      final sessionAttributes = Faro().meta.session?.attributes;
      expect(sessionAttributes, isNotNull);

      // All custom attributes should be present
      expect(sessionAttributes?['label-with-dash'], 'value1');
      expect(sessionAttributes?['label_with_underscore'], 'value2');
      expect(sessionAttributes?['label.with.dot'], 'value3');
      expect(sessionAttributes?['label/with/slash'], 'value4');
    });

    test('session attributes with empty string values work correctly',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final rumConfig = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
        sessionAttributes: {
          'empty_label': '',
          'normal_label': 'value',
        },
      );

      await Faro().init(optionsConfiguration: rumConfig);

      final sessionAttributes = Faro().meta.session?.attributes;
      expect(sessionAttributes, isNotNull);

      // Empty string value should be present
      expect(sessionAttributes?['empty_label'], '');
      expect(sessionAttributes?['normal_label'], 'value');
    });

    test('multiple custom session attributes are all preserved', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final manyAttributes = <String, String>{};
      for (var i = 0; i < 50; i++) {
        manyAttributes['custom_attr_$i'] = 'value_$i';
      }

      final rumConfig = FaroConfig(
        appName: appName,
        appVersion: appVersion,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: 'https://some-url.com',
        sessionAttributes: manyAttributes,
      );

      await Faro().init(optionsConfiguration: rumConfig);

      final sessionAttributes = Faro().meta.session?.attributes;
      expect(sessionAttributes, isNotNull);

      // All custom attributes should be present
      for (var i = 0; i < 50; i++) {
        expect(sessionAttributes?['custom_attr_$i'], 'value_$i');
      }

      // Default attributes should still be present
      expect(sessionAttributes?['device_os'], isNotNull);
    });
  });
}
