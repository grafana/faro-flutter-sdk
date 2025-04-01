import 'dart:io';

class PlatformInfoProvider {
  final isAndroid = Platform.isAndroid;

  final isIOS = Platform.isIOS;

  final dartVersion = Platform.version;

  final operatingSystem = Platform.operatingSystem;

  final operatingSystemVersion = Platform.operatingSystemVersion;
}

class PlatformInfoProviderFactory {
  PlatformInfoProvider create() {
    return PlatformInfoProvider();
  }
}
