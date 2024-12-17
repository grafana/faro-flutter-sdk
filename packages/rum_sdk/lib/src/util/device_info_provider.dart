import 'package:device_info_plus/device_info_plus.dart';
import 'package:rum_sdk/src/models/device_info.dart';
import 'package:rum_sdk/src/util/platform_info_provider.dart';

class DeviceInfoProvider {
  DeviceInfoProvider({
    required DeviceInfoPlugin deviceInfoPlugin,
    required PlatformInfoProvider platformInfoProvider,
  })  : _deviceInfoPlugin = deviceInfoPlugin,
        _platformInfoProvider = platformInfoProvider;

  final DeviceInfoPlugin _deviceInfoPlugin;
  final PlatformInfoProvider _platformInfoProvider;

  DeviceInfo? _deviceInfo;

  Future<DeviceInfo> getDeviceInfo() async {
    if (_deviceInfo != null) {
      return _deviceInfo!;
    }

    final dartVersion = _platformInfoProvider.dartVersion;
    var deviceOs = _platformInfoProvider.operatingSystem;
    var deviceOsVersion = _platformInfoProvider.operatingSystemVersion;
    var deviceOsDetail = 'unknown';
    var deviceManufacturer = 'unknown';
    var deviceModel = 'unknown';
    var deviceBrand = 'unknown';
    var deviceIsPhysical = true;

    if (_platformInfoProvider.isAndroid) {
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

    if (_platformInfoProvider.isIOS) {
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
      deviceIsPhysical: deviceIsPhysical,
    );
    _deviceInfo = deviceInfo;
    return deviceInfo;
  }
}

class DeviceInfoProviderFactory {
  DeviceInfoProvider create() {
    return DeviceInfoProvider(
      deviceInfoPlugin: DeviceInfoPlugin(),
      platformInfoProvider: PlatformInfoProviderFactory().create(),
    );
  }
}
