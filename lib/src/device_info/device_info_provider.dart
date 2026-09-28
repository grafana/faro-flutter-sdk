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

    if (_platformInfoProvider.isAndroid) {
      final androidInfo = await _deviceInfoPlugin.androidInfo;
      final release = androidInfo.version.release;
      final sdkInt = androidInfo.version.sdkInt;

      deviceOs = 'Android';
      deviceOsVersion = release;
      deviceOsBuildId = androidInfo.id;
      deviceOsDetail = 'Android $release (SDK $sdkInt)';
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
      final nativeMetadata = await _getNativeDeviceMetadata();
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
    }

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
