import 'package:faro/faro_native_methods.dart';
import 'package:faro/faro_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFaro extends Mock implements Faro {}

class MockNativeChannel extends Mock implements FaroNativeMethods {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFaro mockFaro;
  late MockNativeChannel mockNativeChannel;
  late NativeIntegration nativeIntegration;

  setUp(() {
    mockFaro = MockFaro();
    mockNativeChannel = MockNativeChannel();
    nativeIntegration = NativeIntegration();

    when(() => mockFaro.nativeChannel).thenReturn(mockNativeChannel);
    when(() => mockNativeChannel.getMemoryUsage())
        .thenAnswer((_) async => 50.0);
    when(() => mockNativeChannel.initRefreshRate()).thenAnswer((_) async {});

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

      verify(() => mockFaro.pushMeasurement(any(), 'app_startup'))
          .called(1);
    });
  });
}
