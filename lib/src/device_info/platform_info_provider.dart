import 'package:dartypod/dartypod.dart';

import 'package:faro/src/core/pod.dart';
import 'package:faro/src/device_info/platform_info_provider_io.dart'
    if (dart.library.js_interop) 'package:faro/src/device_info/platform_info_provider_web.dart'
    as platform_info;
import 'package:faro/src/device_info/platform_info_provider_test_support.dart';

abstract class PlatformInfoProvider {
  bool get isWeb;
  bool get isAndroid;
  bool get isIOS;
  bool get supportsHttpOverrides;
  bool get supportsNativeIntegration;
  bool get supportsOfflineTransport;
  String get dartVersion;
  String get operatingSystem;
  String get operatingSystemVersion;
}

class PlatformInfoProviderFactory {
  PlatformInfoProvider create() {
    final override = debugPlatformInfoProviderOverride;
    if (override != null) {
      return override;
    }
    return platform_info.createPlatformInfoProvider();
  }
}

final platformInfoProvider = Provider<PlatformInfoProvider>((_) {
  return PlatformInfoProviderFactory().create();
});

PlatformInfoProvider get resolvedPlatformInfoProvider {
  return pod.resolve(platformInfoProvider);
}
