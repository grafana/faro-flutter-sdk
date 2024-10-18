import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rum_sdk/rum_flutter.dart';
import 'dart:async';
import 'package:rum_sdk/rum_native_methods.dart';
import 'package:rum_sdk/rum_sdk.dart';

class MockRumFlutter extends Mock implements RumFlutter {}
class MockNativeChannel extends Mock implements RumNativeMethods {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockRumFlutter mockRumFlutter;
  late MockNativeChannel mockNativeChannel;
  late NativeIntegration nativeIntegration;

  setUp(() {
    mockRumFlutter = MockRumFlutter();
    mockNativeChannel = MockNativeChannel();
    nativeIntegration = NativeIntegration();

    when(() => mockRumFlutter.nativeChannel).thenReturn(mockNativeChannel);
    when(() => mockNativeChannel.getMemoryUsage()).thenAnswer((_) async => 50.0);
    when(() => mockNativeChannel.initRefreshRate()).thenAnswer((_) async {});

    RumFlutter.instance = mockRumFlutter;
  });

  group('NativeIntegration', () {
    test('init initializes refresh rate and method channel', () async {

      nativeIntegration.init(
        memusage: true,
        cpuusage: true,
        anr: true,
        refreshrate: true,
        setSendUsageInterval: Duration(seconds: 60),
      );

      verify(() => mockNativeChannel.initRefreshRate()).called(1);
    });

    test('getWarmStart correctly pushes warm start measurement', () async {
      nativeIntegration.setWarmStart();
      await Future.delayed(Duration(milliseconds: 10));
      nativeIntegration.getWarmStart();

      verify(() => mockRumFlutter.pushMeasurement(any(), "app_startup")).called(1);
    });
  });
}
