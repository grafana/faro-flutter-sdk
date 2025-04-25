import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class PlatformInfoProvider {
  final bool isWeb = kIsWeb;

  final bool isAndroid = !kIsWeb ? Platform.isAndroid : false;

  final bool isIOS = !kIsWeb ? Platform.isIOS : false;

  final String dartVersion = !kIsWeb ? Platform.version : 'unknown (web)';

  final String operatingSystem = !kIsWeb ? Platform.operatingSystem : 'web';

  final String operatingSystemVersion =
      !kIsWeb ? Platform.operatingSystemVersion : 'unknown';
}

class PlatformInfoProviderFactory {
  PlatformInfoProvider create() {
    return PlatformInfoProvider();
  }
}
