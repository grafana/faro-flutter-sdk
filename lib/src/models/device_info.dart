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
  /// - iOS: "iPhone", "iPad"
  /// - Android: "samsung", "google", "xiaomi", etc.
  final String deviceBrand;

  /// Whether the device is a physical device or an emulator/simulator.
  final bool deviceIsPhysical;
}
