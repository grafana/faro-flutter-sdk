import 'package:faro/src/configurations/batch_config.dart';
import 'package:faro/src/configurations/faro_config.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/models/event.dart';
import 'package:faro/src/models/meta.dart';
import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/transport/faro_transport.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockFaroTransport extends Mock implements FaroTransport {}

class _MockBatchTransport extends Mock implements BatchTransport {}

class _MockFaroNativeMethods extends Mock implements FaroNativeMethods {}

void main() {
  group('Faro lifecycle timestamps:', () {
    const appName = 'TestApp';
    const appVersion = '2.0.3';
    const appEnv = 'Test';
    const apiKey = 'TestAPIKey';

    late _MockFaroTransport mockFaroTransport;
    late _MockBatchTransport mockBatchTransport;
    late _MockFaroNativeMethods mockFaroNativeMethods;

    setUpAll(() {
      registerFallbackValue(Event('test', attributes: {'test': 'test'}));
      registerFallbackValue(BatchConfig());
      registerFallbackValue(Meta());
    });

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      Faro.resetForTesting();
      BatchTransportFactory().reset();
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: appName,
        packageName: 'com.grafana.example',
        version: appVersion,
        buildNumber: '2',
        buildSignature: 'buildSignature',
      );

      mockFaroTransport = _MockFaroTransport();
      mockBatchTransport = _MockBatchTransport();
      mockFaroNativeMethods = _MockFaroNativeMethods();

      BatchTransportFactory().setInstance(mockBatchTransport);

      Faro().transports = [mockFaroTransport];
      Faro().nativeChannel = mockFaroNativeMethods;
      Faro().batchTransport = mockBatchTransport;

      when(
        () => mockFaroNativeMethods.enableCrashReporter(any()),
      ).thenAnswer((_) async {});
      when(() => mockBatchTransport.addEvent(any())).thenAnswer((_) async {});
      when(
        () => mockBatchTransport.updatePayloadMeta(any()),
      ).thenAnswer((_) async {});
      when(() => mockFaroTransport.send(any())).thenAnswer((_) async {});
    });

    tearDown(() {
      Faro.resetForTesting();
      BatchTransportFactory().reset();
    });

    testWidgets(
      'binding-dispatched lifecycle events rely on microsecond timestamps '
      'instead of a sequence attribute',
      (tester) async {
        await Faro().init(
          optionsConfiguration: FaroConfig(
            appName: appName,
            appVersion: appVersion,
            appEnv: appEnv,
            apiKey: apiKey,
            collectorUrl: 'https://some-url.com',
          ),
        );
        clearInteractions(mockBatchTransport);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.hidden,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );

        final capturedEvents = verify(
          () => mockBatchTransport.addEvent(captureAny()),
        ).captured.cast<Event>();

        expect(capturedEvents, hasLength(3));
        expect(
          capturedEvents.map((event) => event.name),
          everyElement('app_lifecycle_changed'),
        );
        expect(
          capturedEvents.map((event) => event.attributes?['sequence']),
          everyElement(isNull),
        );
        expect(
          capturedEvents.map((event) => event.timestamp),
          everyElement(
            matches(
              RegExp(
                r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z$',
              ),
            ),
          ),
        );
        expect(
          capturedEvents.map((event) => event.timestamp).toSet().length,
          equals(3),
        );
        expect(
          capturedEvents.map((event) => event.timestamp).toList()
            ..sort((left, right) => left.compareTo(right)),
          orderedEquals(capturedEvents.map((event) => event.timestamp)),
        );
      },
    );
  });
}
