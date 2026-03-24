import 'package:faro/src/core/pod.dart';
import 'package:faro/src/device_info/platform_info_provider.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/integrations/native_integration.dart';
import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFaro extends Mock implements Faro {}

class MockNativeChannel extends Mock implements FaroNativeMethods {}

class MockPlatformInfoProvider extends Mock implements PlatformInfoProvider {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFaro mockFaro;
  late MockNativeChannel mockNativeChannel;
  late MockPlatformInfoProvider mockPlatformInfoProvider;
  late NativeIntegration nativeIntegration;

  setUp(() {
    mockFaro = MockFaro();
    mockNativeChannel = MockNativeChannel();
    mockPlatformInfoProvider = MockPlatformInfoProvider();
    nativeIntegration = NativeIntegration();

    when(() => mockFaro.nativeChannel).thenReturn(mockNativeChannel);
    when(() => mockNativeChannel.getMemoryUsage())
        .thenAnswer((_) async => 50.0);
    when(() => mockNativeChannel.initRefreshRate()).thenAnswer((_) async {});
    when(() => mockPlatformInfoProvider.supportsNativeIntegration)
        .thenReturn(true);
    when(() => mockPlatformInfoProvider.isAndroid).thenReturn(true);
    pod.overrideProvider(
      platformInfoProvider,
      (_) => mockPlatformInfoProvider,
    );

    Faro.instance = mockFaro;
  });

  group('NativeIntegration', () {
    test('init initializes refresh rate and method channel', () async {
      nativeIntegration.init(
        memusage: true,
        cpuusage: true,
        anr: true,
        refreshrate: true,
        setSendUsageInterval: const Duration(seconds: 60),
      );

      verify(() => mockNativeChannel.initRefreshRate()).called(1);
    });

    test('getWarmStart correctly pushes warm start measurement', () async {
      nativeIntegration.setWarmStart();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      nativeIntegration.getWarmStart();

      verify(() => mockFaro.pushMeasurement(any(), 'app_startup')).called(1);
    });

    test('init is a no-op when native integration is unsupported', () async {
      when(() => mockPlatformInfoProvider.supportsNativeIntegration)
          .thenReturn(false);

      await nativeIntegration.init(
        memusage: true,
        cpuusage: true,
        anr: true,
        refreshrate: true,
        setSendUsageInterval: const Duration(seconds: 60),
      );

      verifyNever(() => mockNativeChannel.initRefreshRate());
    });
  });
}
