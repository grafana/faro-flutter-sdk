/// Device information collected from the current device.
class DeviceInfo {
  DeviceInfo({
    required this.dartVersion,
    required this.deviceOs,
    required this.deviceOsVersion,
    required this.deviceOsDetail,
    required this.deviceManufacturer,
    required this.deviceModel,
    required this.deviceModelName,
    required this.deviceBrand,
    required this.deviceIsPhysical,
    this.deviceOsBuildId,
    this.deviceOsApiLevel,
    this.deviceArch,
    this.deviceScreenWidth,
    this.deviceScreenHeight,
    this.deviceScreenDensity,
    this.deviceMemoryTotal,
  });

  /// The Dart runtime version.
  ///
  /// Example: "3.5.0 (stable) (Wed Jul 3 15:04:34 2024 +0000) on \"ios_arm64\""
  final String dartVersion;

  /// The operating system name.
  ///
  /// - iOS: "iOS" or "iPadOS"
  /// - Android: "Android"
  final String deviceOs;

  /// The operating system version number.
  ///
  /// - iOS: "17.0", "18.1"
  /// - Android: "14", "15"
  final String deviceOsVersion;

  /// Detailed operating system information.
  ///
  /// - iOS: "iOS 17.0", "iPadOS 18.1"
  /// - Android: "Android 14 (SDK 34)"
  final String deviceOsDetail;

  /// The operating system build identifier, when available.
  ///
  /// - iOS: Build number (e.g., "24A437")
  /// - Android: `Build.ID` (e.g., "CP2A.260705.006")
  final String? deviceOsBuildId;

  /// The device manufacturer.
  ///
  /// - iOS: "apple"
  /// - Android: "samsung", "Google", "Xiaomi", etc.
  final String deviceManufacturer;

  /// Raw device model identifier.
  ///
  /// - iOS: Internal identifier (e.g., "iPhone16,1")
  /// - Android: Model name (e.g., "SM-A155F", "Pixel 8")
  final String deviceModel;

  /// Human-readable device model name.
  ///
  /// - iOS: Marketing name (e.g., "iPhone 15 Pro")
  /// - Android: Same as [deviceModel] - Android does not provide a mapping
  ///   from model codes to marketing names
  final String deviceModelName;

  /// The device brand.
  ///
  /// - iOS: "Apple"
  /// - Android: "samsung", "google", "xiaomi", etc.
  final String deviceBrand;

  /// Whether the device is a physical device or an emulator/simulator.
  final bool deviceIsPhysical;

  /// The Android API level, such as 35. Omitted on iOS.
  final int? deviceOsApiLevel;

  /// The CPU architecture, as the platform reports it.
  ///
  /// Android sends its preferred ABI, such as "arm64-v8a". iOS sends the
  /// architecture the app is built for, such as "arm64" or "x86_64".
  final String? deviceArch;

  /// The screen width in physical pixels, as the OS reports it.
  ///
  /// iOS always reports portrait values. Android reports the values for the
  /// orientation when the SDK reads them.
  final int? deviceScreenWidth;

  /// The screen height in physical pixels, as the OS reports it.
  final int? deviceScreenHeight;

  /// Physical pixels per density-independent pixel.
  ///
  /// - iOS: `UIScreen.nativeScale` (e.g., 3.0)
  /// - Android: `DisplayMetrics.densityDpi / 160` (e.g., 2.625)
  final double? deviceScreenDensity;

  /// Total device memory in whole MB, where 1 MB is 1,048,576 bytes.
  final int? deviceMemoryTotal;
}
