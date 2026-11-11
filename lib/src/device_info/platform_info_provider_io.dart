import 'dart:io';

import 'package:faro/src/device_info/platform_info_provider.dart';

/// [PlatformInfoProvider] for platforms that expose `dart:io`'s `Platform`
/// (Android, iOS and desktop).
class IoPlatformInfoProvider extends PlatformInfoProvider {
  @override
  final bool isAndroid = Platform.isAndroid;

  @override
  final bool isIOS = Platform.isIOS;

  @override
  bool get isWeb => false;

  @override
  final String dartVersion = Platform.version;

  @override
  final String operatingSystem = Platform.operatingSystem;

  @override
  final String operatingSystemVersion = Platform.operatingSystemVersion;
}

/// Creates the platform provider used on `dart:io` platforms.
PlatformInfoProvider createPlatformInfoProvider() => IoPlatformInfoProvider();
