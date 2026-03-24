import 'package:faro/src/device_info/platform_info_provider.dart';

class WebPlatformInfoProvider implements PlatformInfoProvider {
  @override
  bool get isWeb => true;

  @override
  bool get isAndroid => false;

  @override
  bool get isIOS => false;

  @override
  bool get supportsHttpOverrides => false;

  @override
  bool get supportsNativeIntegration => false;

  @override
  bool get supportsOfflineTransport => false;

  @override
  String get dartVersion => 'web';

  @override
  String get operatingSystem => 'web';

  @override
  String get operatingSystemVersion => 'browser';
}

PlatformInfoProvider createPlatformInfoProvider() {
  return WebPlatformInfoProvider();
}
