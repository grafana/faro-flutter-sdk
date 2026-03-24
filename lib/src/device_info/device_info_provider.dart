import 'package:device_info_plus/device_info_plus.dart';
import 'package:faro/src/device_info/platform_info_provider.dart';
import 'package:faro/src/models/models.dart';

class DeviceInfoProvider {
  DeviceInfoProvider({
    required DeviceInfoPlugin deviceInfoPlugin,
    required PlatformInfoProvider platformInfoProvider,
  })  : _deviceInfoPlugin = deviceInfoPlugin,
        _platformInfoProvider = platformInfoProvider;

  final DeviceInfoPlugin _deviceInfoPlugin;
  final PlatformInfoProvider _platformInfoProvider;

  DeviceInfo? _deviceInfo;
  Browser? _browserInfo;

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
    var deviceModelName = 'unknown';
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
      // Android does not provide a mapping from model codes to marketing names,
      // so deviceModelName is the same as deviceModel (e.g., "SM-A155F").
      deviceModelName = androidInfo.model;
      deviceBrand = androidInfo.brand;
      deviceIsPhysical = androidInfo.isPhysicalDevice;
    }

    if (_platformInfoProvider.isIOS) {
      final iosInfo = await _deviceInfoPlugin.iosInfo;
      deviceOs = iosInfo.systemName;
      deviceOsVersion = iosInfo.systemVersion;
      deviceOsDetail = '$deviceOs $deviceOsVersion';
      deviceManufacturer = 'apple';
      // Raw identifier like "iPhone16,1"
      deviceModel = iosInfo.utsname.machine;
      // Human-readable name like "iPhone 15 Pro"
      deviceModelName = iosInfo.modelName;
      deviceBrand = iosInfo.model;
      deviceIsPhysical = iosInfo.isPhysicalDevice;
    }

    if (_platformInfoProvider.isWeb) {
      final webInfo = await _deviceInfoPlugin.webBrowserInfo;
      final browserName = webInfo.browserName.name;
      final browserPlatform =
          webInfo.platform ?? _platformInfoProvider.operatingSystem;
      final browserVersion = webInfo.appVersion ?? 'unknown';
      final userAgent = webInfo.userAgent ?? '';
      final language = webInfo.language ?? 'unknown';

      deviceOs = browserPlatform;
      deviceOsVersion = browserVersion;
      deviceOsDetail = '$browserName on $browserPlatform';
      deviceManufacturer = webInfo.vendor ?? 'browser';
      deviceModel = browserName;
      deviceModelName = browserName;
      deviceBrand = browserPlatform;
      deviceIsPhysical = true;
      _browserInfo = Browser(
        browserName,
        browserVersion,
        browserPlatform,
        userAgent,
        language,
        webInfo.maxTouchPoints != null && webInfo.maxTouchPoints! > 0,
      );
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
    );
    _deviceInfo = deviceInfo;
    return deviceInfo;
  }

  Future<Browser?> getBrowserInfo() async {
    if (_browserInfo != null) {
      return _browserInfo;
    }

    await getDeviceInfo();
    return _browserInfo;
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
