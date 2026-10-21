import 'dart:developer';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:faro/src/device_info/platform_info_provider.dart';
import 'package:faro/src/models/device_info.dart';
import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';

class DeviceInfoProvider {
  DeviceInfoProvider({
    required DeviceInfoPlugin deviceInfoPlugin,
    required PlatformInfoProvider platformInfoProvider,
    required FaroNativeMethods nativeMethods,
  }) : _deviceInfoPlugin = deviceInfoPlugin,
       _platformInfoProvider = platformInfoProvider,
       _nativeMethods = nativeMethods;

  final DeviceInfoPlugin _deviceInfoPlugin;
  final PlatformInfoProvider _platformInfoProvider;
  final FaroNativeMethods _nativeMethods;

  DeviceInfo? _deviceInfo;

  Future<DeviceInfo> getDeviceInfo() async {
    if (_deviceInfo != null) {
      return _deviceInfo!;
    }

    final dartVersion = _platformInfoProvider.dartVersion;
    var deviceOs = _platformInfoProvider.operatingSystem;
    var deviceOsVersion = _platformInfoProvider.operatingSystemVersion;
    var deviceOsDetail = 'unknown';
    String? deviceOsBuildId;
    var deviceManufacturer = 'unknown';
    var deviceModel = 'unknown';
    var deviceModelName = 'unknown';
    var deviceBrand = 'unknown';
    var deviceIsPhysical = true;
    String? deviceType;
    int? deviceOsApiLevel;
    String? deviceArch;
    Map<String, dynamic>? nativeMetadata;

    if (_platformInfoProvider.isAndroid) {
      final androidInfo = await _deviceInfoPlugin.androidInfo;
      nativeMetadata = await _getNativeDeviceMetadata();
      final release = androidInfo.version.release;
      final sdkInt = androidInfo.version.sdkInt;

      deviceOs = 'Android';
      deviceOsVersion = release;
      deviceOsBuildId = androidInfo.id;
      deviceOsDetail = 'Android $release (SDK $sdkInt)';
      deviceOsApiLevel = sdkInt;
      // The first ABI is the device's preferred one.
      deviceArch = androidInfo.supportedAbis.firstOrNull;
      deviceManufacturer = androidInfo.manufacturer;
      deviceModel = androidInfo.model;
      // Android does not provide a mapping from model codes to marketing names,
      // so deviceModelName is the same as deviceModel (e.g., "SM-A155F").
      deviceModelName = androidInfo.model;
      deviceBrand = androidInfo.brand;
      deviceIsPhysical = androidInfo.isPhysicalDevice;
      // device_info_plus does not reliably expose Android phone/tablet form
      // factor, so deviceType is left unset instead of guessed.
    }

    if (_platformInfoProvider.isIOS) {
      final iosInfo = await _deviceInfoPlugin.iosInfo;
      nativeMetadata = await _getNativeDeviceMetadata();
      deviceOs = iosInfo.systemName;
      deviceOsVersion = iosInfo.systemVersion;
      // device_info_plus does not expose the iOS OS build number.
      deviceOsBuildId = _stringValue(nativeMetadata, 'osBuildId');
      deviceOsDetail = '$deviceOs $deviceOsVersion';
      deviceManufacturer = 'apple';
      // Raw identifier like "iPhone16,1"
      deviceModel = iosInfo.utsname.machine;
      // Human-readable name like "iPhone 15 Pro"
      deviceModelName = iosInfo.modelName;
      // Company-level, like Android Build.BRAND ("google", "samsung").
      deviceBrand = 'Apple';
      deviceIsPhysical = iosInfo.isPhysicalDevice;
      deviceType = iosInfo.model.toLowerCase().contains('ipad')
          ? 'tablet'
          : 'mobile';
      deviceArch = _stringValue(nativeMetadata, 'arch');
    }

    final screenWidth = _positiveInt(nativeMetadata, 'screenWidth');
    final screenHeight = _positiveInt(nativeMetadata, 'screenHeight');
    final hasScreenSize = screenWidth != null && screenHeight != null;

    final deviceInfo = DeviceInfo(
      dartVersion: dartVersion,
      deviceOs: deviceOs,
      deviceOsVersion: deviceOsVersion,
      deviceOsDetail: deviceOsDetail,
      deviceManufacturer: deviceManufacturer,
      deviceModel: deviceModel,
      deviceModelName: deviceModelName,
      deviceBrand: deviceBrand,
      deviceIsPhysical: deviceIsPhysical,
      deviceOsBuildId: deviceOsBuildId,
      deviceType: deviceType,
      deviceOsApiLevel: deviceOsApiLevel,
      deviceArch: deviceArch,
      deviceScreenWidth: hasScreenSize ? screenWidth : null,
      deviceScreenHeight: hasScreenSize ? screenHeight : null,
      deviceScreenDensity: _positiveDouble(nativeMetadata, 'screenDensity'),
      deviceMemoryTotal: _wholeMb(_positiveInt(nativeMetadata, 'memoryTotal')),
    );
    _deviceInfo = deviceInfo;
    return deviceInfo;
  }

  // Missing native metadata must never fail SDK init.
  Future<Map<String, dynamic>?> _getNativeDeviceMetadata() async {
    try {
      return await _nativeMethods.getDeviceMetadata();
    } catch (error) {
      log('Faro: Native device metadata unavailable: $error');
      return null;
    }
  }

  String? _stringValue(Map<String, dynamic>? metadata, String key) {
    final value = metadata?[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  int? _positiveInt(Map<String, dynamic>? metadata, String key) {
    final value = metadata?[key];
    return value is int && value > 0 ? value : null;
  }

  // 1 MB is 1,048,576 bytes. A value under 1 MB is unusable.
  int? _wholeMb(int? bytes) {
    if (bytes == null) return null;
    final megabytes = bytes ~/ (1024 * 1024);
    return megabytes > 0 ? megabytes : null;
  }

  double? _positiveDouble(Map<String, dynamic>? metadata, String key) {
    final value = metadata?[key];
    return value is num && value > 0 ? value.toDouble() : null;
  }
}

class DeviceInfoProviderFactory {
  DeviceInfoProvider create({required FaroNativeMethods nativeMethods}) {
    return DeviceInfoProvider(
      deviceInfoPlugin: DeviceInfoPlugin(),
      platformInfoProvider: PlatformInfoProviderFactory().create(),
      nativeMethods: nativeMethods,
    );
  }
}
