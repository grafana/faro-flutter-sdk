import 'package:faro/src/device_info/platform_info_provider.dart';

/// [PlatformInfoProvider] for Flutter web.
///
/// `dart:io`'s `Platform` throws on the web, so every value here is constant.
/// Browser details are not exposed by this class.
class WebPlatformInfoProvider extends PlatformInfoProvider {
  @override
  bool get isAndroid => false;

  @override
  bool get isIOS => false;

  @override
  bool get isWeb => true;

  @override
  String get dartVersion => 'web';

  @override
  String get operatingSystem => 'web';

  @override
  String get operatingSystemVersion => '';
}

/// Creates the platform provider used on the web.
PlatformInfoProvider createPlatformInfoProvider() => WebPlatformInfoProvider();
