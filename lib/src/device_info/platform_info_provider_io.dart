import 'dart:io';

import 'package:faro/src/device_info/platform_info_provider.dart';

class IoPlatformInfoProvider implements PlatformInfoProvider {
  @override
  bool get isWeb => false;

  @override
  bool get isAndroid => Platform.isAndroid;

  @override
  bool get isIOS => Platform.isIOS;

  @override
  bool get supportsHttpOverrides => true;

  @override
  bool get supportsNativeIntegration => isAndroid || isIOS;

  @override
  bool get supportsOfflineTransport => true;

  @override
  String get dartVersion => Platform.version;

  @override
  String get operatingSystem => Platform.operatingSystem;

  @override
  String get operatingSystemVersion => Platform.operatingSystemVersion;
}

PlatformInfoProvider createPlatformInfoProvider() {
  return IoPlatformInfoProvider();
}
