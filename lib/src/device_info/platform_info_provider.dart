import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

abstract class PlatformInfoProvider {
  bool get isWeb;
  bool get isAndroid;
  bool get isIOS;
  String get dartVersion;
  String get operatingSystem;
  String get operatingSystemVersion;
}

class MobilePlatformInfoProvider implements PlatformInfoProvider {
  @override
  final bool isWeb = false;

  @override
  final isAndroid = Platform.isAndroid;

  @override
  final isIOS = Platform.isIOS;

  @override
  final dartVersion = Platform.version;

  @override
  final operatingSystem = Platform.operatingSystem;

  @override
  final operatingSystemVersion = Platform.operatingSystemVersion;

}

class WebPlatformInfoProvider implements PlatformInfoProvider {
  @override
  final bool isWeb = true;

  @override
  final bool isAndroid = false;

  @override
  final bool isIOS = false;

  @override
  final String dartVersion = 'unknown (web)';

  @override
  final String operatingSystem = 'web';

  @override
  final String operatingSystemVersion = 'unknown';

}

class PlatformInfoProviderFactory {
  PlatformInfoProvider create() {
    if (kIsWeb) {
      return WebPlatformInfoProvider();
    }
    return MobilePlatformInfoProvider();
  }
}
