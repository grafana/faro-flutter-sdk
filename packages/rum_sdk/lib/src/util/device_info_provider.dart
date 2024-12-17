import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:rum_sdk/src/models/device_info.dart';

class DeviceInfoProvider {
  DeviceInfoProvider({
    required DeviceInfoPlugin deviceInfoPlugin,
  }) : _deviceInfoPlugin = deviceInfoPlugin;

  final DeviceInfoPlugin _deviceInfoPlugin;
  DeviceInfo? _deviceInfo;

  Future<DeviceInfo> getDeviceInfo() async {
    if (_deviceInfo != null) {
      return _deviceInfo!;
    }

    final dartVersion = Platform.version;
    var deviceOs = Platform.operatingSystem;
    var deviceOsVersion = Platform.operatingSystemVersion;
    var deviceOsDetail = 'unknown';
    var deviceManufacturer = 'unknown';
    var deviceModel = 'unknown';
    var deviceBrand = 'unknown';
    var deviceIsPhysical = true;

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfoPlugin.androidInfo;
      final release = androidInfo.version.release;
      final sdkInt = androidInfo.version.sdkInt;

      deviceOs = 'Android';
      deviceOsVersion = release;
      deviceOsDetail = 'Android $release (SDK $sdkInt)';
      deviceManufacturer = androidInfo.manufacturer;
      deviceModel = androidInfo.model;
      deviceBrand = androidInfo.brand;
      deviceIsPhysical = androidInfo.isPhysicalDevice;
    }

    if (Platform.isIOS) {
      final iosInfo = await _deviceInfoPlugin.iosInfo;
      deviceOs = iosInfo.systemName;
      deviceOsVersion = iosInfo.systemVersion;
      deviceOsDetail = '$deviceOs $deviceOsVersion';
      deviceManufacturer = 'apple';
      deviceModel = iosInfo.utsname.machine;
      deviceBrand = iosInfo.model;
      deviceIsPhysical = iosInfo.isPhysicalDevice;
    }

    final deviceInfo = DeviceInfo(
      dartVersion: dartVersion,
      deviceOs: deviceOs,
      deviceOsVersion: deviceOsVersion,
      deviceOsDetail: deviceOsDetail,
      deviceManufacturer: deviceManufacturer,
      deviceModel: deviceModel,
      deviceBrand: deviceBrand,
      deviceIsPhysical: '$deviceIsPhysical',
    );
    _deviceInfo = deviceInfo;
    return deviceInfo;
  }
}

class DeviceInfoProviderFactory {
  DeviceInfoProvider getDeviceInfoProvider() {
    return DeviceInfoProvider(deviceInfoPlugin: DeviceInfoPlugin());
  }
}
