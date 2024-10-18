import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

class SessionAttributes {
  Future<Map<String, String>> getAttributes() async {
    final dartVersion = Platform.version;
    String deviceOs = Platform.operatingSystem;
    String deviceOsVersion = Platform.operatingSystemVersion;
    String deviceOsDetail = "unknown";
    String deviceManufacturer = "unknown";
    String deviceModel = "unknown";
    String deviceBrand = "unknown";
    bool deviceIsPhysical = true;

    if (Platform.isAndroid) {
      var androidInfo = await DeviceInfoPlugin().androidInfo;
      var release = androidInfo.version.release;
      var sdkInt = androidInfo.version.sdkInt;

      deviceOs = "Android";
      deviceOsVersion = release;
      deviceOsDetail = "Android $release (SDK $sdkInt)";
      deviceManufacturer = androidInfo.manufacturer;
      deviceModel = androidInfo.model;
      deviceBrand = androidInfo.brand;
      deviceIsPhysical = androidInfo.isPhysicalDevice;
    }

    if (Platform.isIOS) {
      var iosInfo = await DeviceInfoPlugin().iosInfo;
      deviceOs = iosInfo.systemName;
      deviceOsVersion = iosInfo.systemVersion;
      deviceOsDetail = "$deviceOs $deviceOsVersion";
      deviceManufacturer = "apple";
      deviceModel = iosInfo.utsname.machine;
      deviceBrand = iosInfo.model;
      deviceIsPhysical = iosInfo.isPhysicalDevice;
    }

    final attributes = <String, String>{
      "dart_version": dartVersion,
      "device_os": deviceOs,
      "device_os_version": deviceOsVersion,
      "device_os_detail": deviceOsDetail,
      "device_manufacturer": deviceManufacturer,
      "device_model": deviceModel,
      "device_brand": deviceBrand,
      "device_is_physical": '$deviceIsPhysical',
    };

    return attributes;
  }
}
