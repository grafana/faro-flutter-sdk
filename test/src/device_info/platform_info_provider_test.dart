import 'dart:io';

import 'package:faro/src/device_info/platform_info_provider.dart';
import 'package:faro/src/device_info/platform_info_provider_io.dart';
import 'package:faro/src/device_info/platform_info_provider_web.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IoPlatformInfoProvider', () {
    test('mirrors dart:io Platform values', () {
      final provider = IoPlatformInfoProvider();

      expect(provider.isAndroid, Platform.isAndroid);
      expect(provider.isIOS, Platform.isIOS);
      expect(provider.dartVersion, Platform.version);
      expect(provider.operatingSystem, Platform.operatingSystem);
      expect(provider.operatingSystemVersion, Platform.operatingSystemVersion);
    });

    test('is never web', () {
      expect(IoPlatformInfoProvider().isWeb, isFalse);
    });

    test('isMobile is true only for Android or iOS', () {
      final provider = IoPlatformInfoProvider();

      expect(provider.isMobile, Platform.isAndroid || Platform.isIOS);
    });
  });

  group('WebPlatformInfoProvider', () {
    final provider = WebPlatformInfoProvider();

    test('reports web and neither Android nor iOS', () {
      expect(provider.isWeb, isTrue);
      expect(provider.isAndroid, isFalse);
      expect(provider.isIOS, isFalse);
    });

    test('is not mobile', () {
      expect(provider.isMobile, isFalse);
    });

    test('exposes constant values without touching dart:io', () {
      expect(provider.dartVersion, 'web');
      expect(provider.operatingSystem, 'web');
      expect(provider.operatingSystemVersion, isEmpty);
    });
  });

  group('PlatformInfoProviderFactory', () {
    test('creates the dart:io provider on the VM', () {
      final provider = PlatformInfoProviderFactory().create();

      expect(provider, isA<IoPlatformInfoProvider>());
      expect(provider.isWeb, isFalse);
    });
  });
}
