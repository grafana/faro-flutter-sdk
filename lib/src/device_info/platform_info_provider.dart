import 'package:faro/src/device_info/platform_info_provider_io.dart'
    if (dart.library.js_interop) 'package:faro/src/device_info/platform_info_provider_web.dart'
    as platform_implementation;

/// Describes the platform the SDK is currently running on.
///
/// There is one concrete implementation per platform family, chosen once by
/// [PlatformInfoProviderFactory]. Callers should depend on this interface
/// instead of `dart:io`'s `Platform`, which throws when used on the web.
abstract class PlatformInfoProvider {
  /// Whether the app is running on Android.
  bool get isAndroid;

  /// Whether the app is running on iOS.
  bool get isIOS;

  /// Whether the app is running in a web browser.
  bool get isWeb;

  /// Whether the app is running on Android or iOS.
  bool get isMobile => isAndroid || isIOS;

  /// The Dart runtime version string.
  String get dartVersion;

  /// The name of the operating system.
  String get operatingSystem;

  /// The version of the operating system.
  String get operatingSystemVersion;
}

/// Creates the [PlatformInfoProvider] matching the current platform.
class PlatformInfoProviderFactory {
  /// Returns the platform-specific [PlatformInfoProvider].
  PlatformInfoProvider create() {
    return platform_implementation.createPlatformInfoProvider();
  }
}
