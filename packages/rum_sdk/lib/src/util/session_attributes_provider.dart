import 'package:rum_sdk/src/util/device_id_provider.dart';
import 'package:rum_sdk/src/util/device_info_provider.dart';

class SessionAttributesProvider {
  SessionAttributesProvider({
    required DeviceIdProvider deviceIdProvider,
    required DeviceInfoProvider deviceInfoProvider,
  })  : _deviceIdProvider = deviceIdProvider,
        _deviceInfoProvider = deviceInfoProvider;

  final DeviceIdProvider _deviceIdProvider;
  final DeviceInfoProvider _deviceInfoProvider;

  Future<Map<String, String>> getAttributes() async {
    final deviceId = await _deviceIdProvider.getDeviceId();
    final deviceInfo = await _deviceInfoProvider.getDeviceInfo();

    final attributes = <String, String>{
      'dart_version': deviceInfo.dartVersion,
      'device_os': deviceInfo.deviceOs,
      'device_os_version': deviceInfo.deviceOsVersion,
      'device_os_detail': deviceInfo.deviceOsDetail,
      'device_manufacturer': deviceInfo.deviceManufacturer,
      'device_model': deviceInfo.deviceModel,
      'device_brand': deviceInfo.deviceBrand,
      'device_is_physical': deviceInfo.deviceIsPhysical,
      'device_id': '$deviceId',
    };

    return attributes;
  }
}

class SessionAttributesProviderFactory {
  Future<SessionAttributesProvider> getAttributesProvider() async {
    final deviceIdProvider =
        await DeviceIdProviderFactory().getDeviceIdProvider();
    final deviceInfoProvider =
        DeviceInfoProviderFactory().getDeviceInfoProvider();

    return SessionAttributesProvider(
      deviceIdProvider: deviceIdProvider,
      deviceInfoProvider: deviceInfoProvider,
    );
  }
}