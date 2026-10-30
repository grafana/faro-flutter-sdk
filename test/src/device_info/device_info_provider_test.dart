import 'package:device_info_plus/device_info_plus.dart';
import 'package:faro/src/device_info/device_info_provider.dart';
import 'package:faro/src/device_info/platform_info_provider.dart';
import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDeviceInfoPlugin extends Mock implements DeviceInfoPlugin {}

class MockAndroidDeviceInfo extends Mock implements AndroidDeviceInfo {}

class MockIosDeviceInfo extends Mock implements IosDeviceInfo {}

class MockAndroidBuildVersion extends Mock implements AndroidBuildVersion {}

class MockPlatformInfoProvider extends Mock implements PlatformInfoProvider {}

class MockIosUtsname extends Mock implements IosUtsname {}

class MockFaroNativeMethods extends Mock implements FaroNativeMethods {}

void main() {
  late MockDeviceInfoPlugin mockDeviceInfoPlugin;
  late MockAndroidDeviceInfo mockAndroidDeviceInfo;
  late MockIosDeviceInfo mockIosDeviceInfo;
  late MockPlatformInfoProvider mockPlatformInfoProvider;
  late MockFaroNativeMethods mockNativeMethods;

  late DeviceInfoProvider sut;

  void stubAndroid({List<String> supportedAbis = const ['arm64-v8a']}) {
    when(() => mockPlatformInfoProvider.isAndroid).thenReturn(true);
    when(() => mockPlatformInfoProvider.isIOS).thenReturn(false);

    final mockAndroidBuildVersion = MockAndroidBuildVersion();
    when(() => mockAndroidBuildVersion.release).thenReturn('11');
    when(() => mockAndroidBuildVersion.sdkInt).thenReturn(30);

    when(
      () => mockAndroidDeviceInfo.version,
    ).thenReturn(mockAndroidBuildVersion);
    when(() => mockAndroidDeviceInfo.id).thenReturn('RQ3A');
    when(() => mockAndroidDeviceInfo.manufacturer).thenReturn('Google');
    when(() => mockAndroidDeviceInfo.model).thenReturn('Pixel 4');
    when(() => mockAndroidDeviceInfo.brand).thenReturn('Google');
    when(() => mockAndroidDeviceInfo.isPhysicalDevice).thenReturn(true);
    when(() => mockAndroidDeviceInfo.supportedAbis).thenReturn(supportedAbis);
  }

  void stubIos({String model = 'iPhone'}) {
    when(() => mockPlatformInfoProvider.isAndroid).thenReturn(false);
    when(() => mockPlatformInfoProvider.isIOS).thenReturn(true);

    when(() => mockIosDeviceInfo.systemName).thenReturn('iOS');
    when(() => mockIosDeviceInfo.systemVersion).thenReturn('14.4');

    final mockIosUtsname = MockIosUtsname();
    when(() => mockIosUtsname.machine).thenReturn('iPhone12,1');

    when(() => mockIosDeviceInfo.utsname).thenReturn(mockIosUtsname);
    when(() => mockIosDeviceInfo.model).thenReturn(model);
    when(() => mockIosDeviceInfo.modelName).thenReturn('iPhone 11');
    when(() => mockIosDeviceInfo.isPhysicalDevice).thenReturn(true);
  }

  setUp(() {
    mockDeviceInfoPlugin = MockDeviceInfoPlugin();
    mockAndroidDeviceInfo = MockAndroidDeviceInfo();
    mockIosDeviceInfo = MockIosDeviceInfo();
    mockPlatformInfoProvider = MockPlatformInfoProvider();
    mockNativeMethods = MockFaroNativeMethods();

    when(
      () => mockDeviceInfoPlugin.androidInfo,
    ).thenAnswer((_) async => mockAndroidDeviceInfo);
    when(
      () => mockDeviceInfoPlugin.iosInfo,
    ).thenAnswer((_) async => mockIosDeviceInfo);

    when(
      () => mockPlatformInfoProvider.dartVersion,
    ).thenReturn('Some-dart-version');
    when(() => mockPlatformInfoProvider.operatingSystem).thenReturn('Some-OS');
    when(
      () => mockPlatformInfoProvider.operatingSystemVersion,
    ).thenReturn('Some-OS-version');

    when(
      () => mockNativeMethods.getDeviceMetadata(),
    ).thenAnswer((_) async => null);

    sut = DeviceInfoProvider(
      deviceInfoPlugin: mockDeviceInfoPlugin,
      platformInfoProvider: mockPlatformInfoProvider,
      nativeMethods: mockNativeMethods,
    );
  });

  group('DeviceInfoProvider:', () {
    test('should return correct device info for Android', () async {
      stubAndroid();

      final deviceInfo = await sut.getDeviceInfo();

      expect(deviceInfo.dartVersion, 'Some-dart-version');
      expect(deviceInfo.deviceOs, 'Android');
      expect(deviceInfo.deviceOsVersion, '11');
      expect(deviceInfo.deviceOsBuildId, 'RQ3A');
      expect(deviceInfo.deviceOsDetail, 'Android 11 (SDK 30)');
      expect(deviceInfo.deviceManufacturer, 'Google');
      expect(deviceInfo.deviceModel, 'Pixel 4');
      expect(deviceInfo.deviceModelName, 'Pixel 4');
      expect(deviceInfo.deviceBrand, 'Google');
      expect(deviceInfo.deviceIsPhysical, true);
      expect(deviceInfo.deviceOsApiLevel, 30);
      expect(deviceInfo.deviceArch, 'arm64-v8a');
    });

    test('should return correct device info for iOS', () async {
      stubIos();
      when(
        () => mockNativeMethods.getDeviceMetadata(),
      ).thenAnswer((_) async => {'osBuildId': '18D52'});

      final deviceInfo = await sut.getDeviceInfo();

      expect(deviceInfo.dartVersion, 'Some-dart-version');
      expect(deviceInfo.deviceOs, 'iOS');
      expect(deviceInfo.deviceOsVersion, '14.4');
      expect(deviceInfo.deviceOsBuildId, '18D52');
      expect(deviceInfo.deviceOsDetail, 'iOS 14.4');
      expect(deviceInfo.deviceManufacturer, 'apple');
      expect(deviceInfo.deviceModel, 'iPhone12,1');
      expect(deviceInfo.deviceModelName, 'iPhone 11');
      expect(deviceInfo.deviceBrand, 'Apple');
      expect(deviceInfo.deviceIsPhysical, true);
      expect(deviceInfo.deviceOsApiLevel, isNull);
    });

    for (final model in ['iPad', 'iPad Simulator']) {
      test('should report the Apple brand for $model', () async {
        when(() => mockPlatformInfoProvider.isAndroid).thenReturn(false);
        when(() => mockPlatformInfoProvider.isIOS).thenReturn(true);

        when(() => mockIosDeviceInfo.systemName).thenReturn('iOS');
        when(() => mockIosDeviceInfo.systemVersion).thenReturn('18.1');

        final mockIosUtsname = MockIosUtsname();
        when(() => mockIosUtsname.machine).thenReturn('iPad14,3');

        when(() => mockIosDeviceInfo.utsname).thenReturn(mockIosUtsname);
        when(() => mockIosDeviceInfo.model).thenReturn(model);
        when(() => mockIosDeviceInfo.modelName).thenReturn('iPad Pro');
        when(() => mockIosDeviceInfo.isPhysicalDevice).thenReturn(true);

        final deviceInfo = await sut.getDeviceInfo();

        expect(deviceInfo.deviceBrand, 'Apple');
      });
    }

    for (final error in <Object>[
      MissingPluginException(),
      PlatformException(code: 'NATIVE_ERROR'),
      StateError('no binary messenger'),
    ]) {
      test('should keep iOS device info when native metadata fails with '
          '${error.runtimeType}', () async {
        stubIos();
        when(
          () => mockNativeMethods.getDeviceMetadata(),
        ).thenAnswer((_) => Future.error(error));

        final deviceInfo = await sut.getDeviceInfo();

        expect(deviceInfo.deviceOsBuildId, isNull);
        expect(deviceInfo.deviceBrand, 'Apple');
      });
    }

    for (final metadata in <Map<String, dynamic>?>[
      null,
      {},
      {'osBuildId': false},
      {'osBuildId': ''},
    ]) {
      test('should ignore unusable native metadata $metadata', () async {
        stubIos();
        when(
          () => mockNativeMethods.getDeviceMetadata(),
        ).thenAnswer((_) async => metadata);

        final deviceInfo = await sut.getDeviceInfo();

        expect(deviceInfo.deviceOsBuildId, isNull);
      });
    }

    group('static device fields', () {
      const nativeMetadata = <String, dynamic>{
        'screenWidth': 1080,
        'screenHeight': 2400,
        'screenDensity': 2.625,
        'memoryTotal': 7981822976,
      };

      void stubNativeMetadata(Map<String, dynamic>? metadata) {
        when(
          () => mockNativeMethods.getDeviceMetadata(),
        ).thenAnswer((_) async => metadata);
      }

      test('reads screen and memory from native metadata on Android', () async {
        stubAndroid();
        stubNativeMetadata(nativeMetadata);

        final deviceInfo = await sut.getDeviceInfo();

        expect(deviceInfo.deviceScreenWidth, 1080);
        expect(deviceInfo.deviceScreenHeight, 2400);
        expect(deviceInfo.deviceScreenDensity, 2.625);
        expect(deviceInfo.deviceMemoryTotal, 7612);
      });

      test(
        'reads screen, memory and arch from native metadata on iOS',
        () async {
          stubIos();
          stubNativeMetadata({
            'screenWidth': 1179,
            'screenHeight': 2556,
            'screenDensity': 3.0,
            'memoryTotal': 6442450944,
            'arch': 'arm64',
          });

          final deviceInfo = await sut.getDeviceInfo();

          expect(deviceInfo.deviceScreenWidth, 1179);
          expect(deviceInfo.deviceScreenHeight, 2556);
          expect(deviceInfo.deviceScreenDensity, 3.0);
          expect(deviceInfo.deviceMemoryTotal, 6144);
          expect(deviceInfo.deviceArch, 'arm64');
        },
      );

      // Android reports the size in the orientation at launch.
      test('sends the screen size as the OS reports it', () async {
        stubAndroid();
        stubNativeMetadata({'screenWidth': 2400, 'screenHeight': 1080});

        final deviceInfo = await sut.getDeviceInfo();

        expect(deviceInfo.deviceScreenWidth, 2400);
        expect(deviceInfo.deviceScreenHeight, 1080);
      });

      test('accepts an integer screen density', () async {
        stubAndroid();
        stubNativeMetadata({'screenDensity': 3});

        final deviceInfo = await sut.getDeviceInfo();

        expect(deviceInfo.deviceScreenDensity, 3.0);
      });

      for (final metadata in <Map<String, dynamic>?>[
        null,
        {},
        {'screenWidth': 1080},
        {'screenWidth': 0, 'screenHeight': 2400},
        {'screenWidth': '1080', 'screenHeight': '2400'},
        {'screenDensity': 0, 'memoryTotal': -1},
        {'screenDensity': '2.625', 'memoryTotal': 7.9e9},
        {'memoryTotal': 1000},
      ]) {
        test('omits unusable native values $metadata', () async {
          stubAndroid();
          stubNativeMetadata(metadata);

          final deviceInfo = await sut.getDeviceInfo();

          expect(deviceInfo.deviceScreenWidth, isNull);
          expect(deviceInfo.deviceScreenHeight, isNull);
          expect(deviceInfo.deviceScreenDensity, isNull);
          expect(deviceInfo.deviceMemoryTotal, isNull);
        });
      }

      test('keeps Android device info when native metadata fails', () async {
        stubAndroid();
        when(
          () => mockNativeMethods.getDeviceMetadata(),
        ).thenAnswer((_) => Future.error(MissingPluginException()));

        final deviceInfo = await sut.getDeviceInfo();

        expect(deviceInfo.deviceOs, 'Android');
        expect(deviceInfo.deviceOsApiLevel, 30);
        expect(deviceInfo.deviceScreenWidth, isNull);
      });

      for (final abi in ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'riscv64']) {
        test('sends the first Android ABI $abi as is', () async {
          stubAndroid(supportedAbis: [abi, 'armeabi']);

          final deviceInfo = await sut.getDeviceInfo();

          expect(deviceInfo.deviceArch, abi);
        });
      }

      test('omits the arch when Android reports no ABI', () async {
        stubAndroid(supportedAbis: []);

        final deviceInfo = await sut.getDeviceInfo();

        expect(deviceInfo.deviceArch, isNull);
      });

      test('sends the iOS simulator arch x86_64 as is', () async {
        stubIos();
        stubNativeMetadata({'arch': 'x86_64'});

        final deviceInfo = await sut.getDeviceInfo();

        expect(deviceInfo.deviceArch, 'x86_64');
      });
    });

    test('should query native device metadata once', () async {
      stubIos();

      await sut.getDeviceInfo();
      await sut.getDeviceInfo();

      verify(() => mockNativeMethods.getDeviceMetadata()).called(1);
    });

    test(
      'should return correct device info when not iOS and not Android',
      () async {
        when(() => mockPlatformInfoProvider.isAndroid).thenReturn(false);
        when(() => mockPlatformInfoProvider.isIOS).thenReturn(false);

        final deviceInfo = await sut.getDeviceInfo();

        expect(deviceInfo.dartVersion, 'Some-dart-version');
        expect(deviceInfo.deviceOs, 'Some-OS');
        expect(deviceInfo.deviceOsVersion, 'Some-OS-version');
        expect(deviceInfo.deviceOsBuildId, isNull);
        expect(deviceInfo.deviceOsDetail, 'unknown');
        expect(deviceInfo.deviceManufacturer, 'unknown');
        expect(deviceInfo.deviceModel, 'unknown');
        expect(deviceInfo.deviceModelName, 'unknown');
        expect(deviceInfo.deviceBrand, 'unknown');
        expect(deviceInfo.deviceIsPhysical, true);
        verifyNever(() => mockNativeMethods.getDeviceMetadata());
      },
    );
  });
}
