import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rum_sdk/src/util/device_info_provider.dart';
import 'package:rum_sdk/src/util/platform_info_provider.dart';

class MockDeviceInfoPlugin extends Mock implements DeviceInfoPlugin {}

class MockAndroidDeviceInfo extends Mock implements AndroidDeviceInfo {}

class MockIosDeviceInfo extends Mock implements IosDeviceInfo {}

class MockAndroidBuildVersion extends Mock implements AndroidBuildVersion {}

class MockPlatformInfoProvider extends Mock implements PlatformInfoProvider {}

class MockIosUtsname extends Mock implements IosUtsname {}

void main() {
  late MockDeviceInfoPlugin mockDeviceInfoPlugin;
  late MockAndroidDeviceInfo mockAndroidDeviceInfo;
  late MockIosDeviceInfo mockIosDeviceInfo;
  late MockPlatformInfoProvider mockPlatformInfoProvider;

  late DeviceInfoProvider sut;

  setUp(() {
    mockDeviceInfoPlugin = MockDeviceInfoPlugin();
    mockAndroidDeviceInfo = MockAndroidDeviceInfo();
    mockIosDeviceInfo = MockIosDeviceInfo();
    mockPlatformInfoProvider = MockPlatformInfoProvider();

    when(() => mockDeviceInfoPlugin.androidInfo).thenAnswer(
      (_) async => mockAndroidDeviceInfo,
    );
    when(() => mockDeviceInfoPlugin.iosInfo).thenAnswer(
      (_) async => mockIosDeviceInfo,
    );

    when(() => mockPlatformInfoProvider.dartVersion)
        .thenReturn('Some-dart-version');
    when(() => mockPlatformInfoProvider.operatingSystem).thenReturn('Some-OS');
    when(() => mockPlatformInfoProvider.operatingSystemVersion)
        .thenReturn('Some-OS-version');

    sut = DeviceInfoProvider(
      deviceInfoPlugin: mockDeviceInfoPlugin,
      platformInfoProvider: mockPlatformInfoProvider,
    );
  });

  group('DeviceInfoProvider:', () {
    test('should return correct device info for Android', () async {
      when(() => mockPlatformInfoProvider.isAndroid).thenReturn(true);
      when(() => mockPlatformInfoProvider.isIOS).thenReturn(false);

      final mockAndroidBuildVersion = MockAndroidBuildVersion();
      when(() => mockAndroidBuildVersion.release).thenReturn('11');
      when(() => mockAndroidBuildVersion.sdkInt).thenReturn(30);

      when(() => mockAndroidDeviceInfo.version)
          .thenReturn(mockAndroidBuildVersion);
      when(() => mockAndroidDeviceInfo.manufacturer).thenReturn('Google');
      when(() => mockAndroidDeviceInfo.model).thenReturn('Pixel 4');
      when(() => mockAndroidDeviceInfo.brand).thenReturn('Google');
      when(() => mockAndroidDeviceInfo.isPhysicalDevice).thenReturn(true);

      final deviceInfo = await sut.getDeviceInfo();

      expect(deviceInfo.dartVersion, 'Some-dart-version');
      expect(deviceInfo.deviceOs, 'Android');
      expect(deviceInfo.deviceOsVersion, '11');
      expect(deviceInfo.deviceOsDetail, 'Android 11 (SDK 30)');
      expect(deviceInfo.deviceManufacturer, 'Google');
      expect(deviceInfo.deviceModel, 'Pixel 4');
      expect(deviceInfo.deviceBrand, 'Google');
      expect(deviceInfo.deviceIsPhysical, true);
    });

    test('should return correct device info for iOS', () async {
      when(() => mockPlatformInfoProvider.isAndroid).thenReturn(false);
      when(() => mockPlatformInfoProvider.isIOS).thenReturn(true);

      when(() => mockIosDeviceInfo.systemName).thenReturn('iOS');
      when(() => mockIosDeviceInfo.systemVersion).thenReturn('14.4');

      final mockIosUtsname = MockIosUtsname();
      when(() => mockIosUtsname.machine).thenReturn('iPhone12,1');

      when(() => mockIosDeviceInfo.utsname).thenReturn(mockIosUtsname);
      when(() => mockIosDeviceInfo.model).thenReturn('iPhone');
      when(() => mockIosDeviceInfo.isPhysicalDevice).thenReturn(true);

      final deviceInfo = await sut.getDeviceInfo();

      expect(deviceInfo.dartVersion, 'Some-dart-version');
      expect(deviceInfo.deviceOs, 'iOS');
      expect(deviceInfo.deviceOsVersion, '14.4');
      expect(deviceInfo.deviceOsDetail, 'iOS 14.4');
      expect(deviceInfo.deviceManufacturer, 'apple');
      expect(deviceInfo.deviceModel, 'iPhone12,1');
      expect(deviceInfo.deviceBrand, 'iPhone');
      expect(deviceInfo.deviceIsPhysical, true);
    });

    test('should return correct device info when not iOS and not Android',
        () async {
      when(() => mockPlatformInfoProvider.isAndroid).thenReturn(false);
      when(() => mockPlatformInfoProvider.isIOS).thenReturn(false);

      final deviceInfo = await sut.getDeviceInfo();

      expect(deviceInfo.dartVersion, 'Some-dart-version');
      expect(deviceInfo.deviceOs, 'Some-OS');
      expect(deviceInfo.deviceOsVersion, 'Some-OS-version');
      expect(deviceInfo.deviceOsDetail, 'unknown');
      expect(deviceInfo.deviceManufacturer, 'unknown');
      expect(deviceInfo.deviceModel, 'unknown');
      expect(deviceInfo.deviceBrand, 'unknown');
      expect(deviceInfo.deviceIsPhysical, true);
    });
  });
}
