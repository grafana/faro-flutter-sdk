import 'package:device_info_plus/device_info_plus.dart';
import 'package:faro/src/device_info/platform_info_provider.dart';
import 'package:faro/src/models/device_info.dart';

class DeviceInfoProvider {
  DeviceInfoProvider({
    required DeviceInfoPlugin deviceInfoPlugin,
    required PlatformInfoProvider platformInfoProvider,
  }) : _deviceInfoPlugin = deviceInfoPlugin,
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
      deviceOs = iosInfo.systemName;
      deviceOsVersion = iosInfo.systemVersion;
      // device_info_plus does not expose the real iOS OS build number.
      deviceOsBuildId = null;
      deviceOsDetail = '$deviceOs $deviceOsVersion';
      deviceManufacturer = 'apple';
      // Raw identifier like "iPhone16,1"
      deviceModel = iosInfo.utsname.machine;
      // Human-readable name like "iPhone 15 Pro"
      deviceModelName = iosInfo.modelName;
      deviceBrand = iosInfo.model;
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
}

class DeviceInfoProviderFactory {
  DeviceInfoProvider create() {
    return DeviceInfoProvider(
      deviceInfoPlugin: DeviceInfoPlugin(),
      platformInfoProvider: PlatformInfoProviderFactory().create(),
    );
  }
}
