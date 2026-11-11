// Runs in a browser: `flutter test --platform chrome test/web`.
//
// The SDK compiles for web even when it calls `dart:io`'s `Platform`, which
// only throws when it runs. These tests execute the code in a real browser so
// that kind of regression fails here instead of in an app.
@TestOn('browser')
library;

import 'package:faro/faro.dart';
import 'package:faro/src/device_info/platform_info_provider.dart';
import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockBatchTransport extends Mock implements BatchTransport {}

class _MockFaroNativeMethods extends Mock implements FaroNativeMethods {}

void main() {
  group('PlatformInfoProviderFactory on web', () {
    test('creates a web provider without throwing', () {
      final provider = PlatformInfoProviderFactory().create();

      expect(provider.isWeb, isTrue);
      expect(provider.isAndroid, isFalse);
      expect(provider.isIOS, isFalse);
      expect(provider.isMobile, isFalse);
      expect(provider.operatingSystem, 'web');
    });
  });

  group('Faro on web', () {
    late _MockBatchTransport batchTransport;
    late _MockFaroNativeMethods nativeMethods;

    setUpAll(() {
      registerFallbackValue(
        FaroException('test', 'something', {
          'frames': <Map<String, dynamic>>[],
        }),
      );
      registerFallbackValue(Event('test', attributes: {'test': 'test'}));
      registerFallbackValue(FaroLog('This is a message'));
      registerFallbackValue(Measurement({'test': 123}, 'test'));
      registerFallbackValue(Meta());
    });

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await Faro.resetForTesting();
      BatchTransportFactory().reset();

      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'WebTestApp',
        packageName: 'com.grafana.web.test',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );

      batchTransport = _MockBatchTransport();
      nativeMethods = _MockFaroNativeMethods();
      BatchTransportFactory().setInstance(batchTransport);
      Faro().batchTransport = batchTransport;
      Faro().nativeChannel = nativeMethods;

      when(() => batchTransport.addLog(any())).thenAnswer((_) async {});
      when(() => batchTransport.addEvent(any())).thenAnswer((_) async {});
      when(() => batchTransport.addExceptions(any())).thenAnswer((_) async {});
      when(() => batchTransport.addMeasurement(any())).thenAnswer((_) async {});
      when(
        () => batchTransport.updatePayloadMeta(any()),
      ).thenAnswer((_) async {});
    });

    tearDown(() async {
      await Faro.resetForTesting();
      BatchTransportFactory().reset();
    });

    test('init completes and telemetry can be pushed', () async {
      await Faro().init(
        optionsConfiguration: FaroConfig(
          appName: 'WebTestApp',
          appEnv: 'test',
          apiKey: 'key',
          collectorUrl: null,
          transports: [],
          persistSession: false,
          persistUser: false,
          enableUiActivityMonitoring: false,
        ),
      );

      Faro().pushLog('hello from the browser', level: LogLevel.info);

      expect(Faro().meta.app?.name, 'WebTestApp');
      expect(Faro().meta.session?.id, isNotEmpty);
      expect(Faro().meta.os?.name, 'web');
      verify(() => batchTransport.addLog(any())).called(1);
    });

    testWidgets('lifecycle changes send events but no start measurements', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await Faro().init(
          optionsConfiguration: FaroConfig(
            appName: 'WebTestApp',
            appEnv: 'test',
            apiKey: 'key',
            collectorUrl: null,
            transports: [],
            persistSession: false,
            persistUser: false,
            enableUiActivityMonitoring: false,
          ),
        );
      });
      await tester.pumpWidget(const SizedBox());

      // The browser tab being hidden and shown again.
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      final events = verify(
        () => batchTransport.addEvent(captureAny()),
      ).captured.cast<Event>();
      expect(
        events.where((event) => event.name == 'app_lifecycle_changed'),
        isNotEmpty,
      );
      // Cold and warm start are not reported on web.
      verifyNever(() => batchTransport.addMeasurement(any()));
      verifyZeroInteractions(nativeMethods);
    });

    test('init does not call native code', () async {
      await Faro().init(
        optionsConfiguration: FaroConfig(
          appName: 'WebTestApp',
          appEnv: 'test',
          apiKey: 'key',
          collectorUrl: null,
          transports: [],
          persistSession: false,
          persistUser: false,
          enableUiActivityMonitoring: false,
          // CPU and memory vitals are on by default. They and the options
          // below must be ignored on web, not started.
          anrTracking: true,
          enableCrashReporting: true,
        ),
      );

      verifyZeroInteractions(nativeMethods);
    });
  });
}
