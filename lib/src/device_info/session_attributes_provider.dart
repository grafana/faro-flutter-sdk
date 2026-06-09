import 'package:faro/src/device_info/device_id_provider.dart';
import 'package:faro/src/device_info/device_info_provider.dart';
import 'package:faro/src/models/device_id.dart';
import 'package:faro/src/models/device_info.dart';

class SessionAttributesProvider {
  SessionAttributesProvider({
    required DeviceIdProvider deviceIdProvider,
    required DeviceInfoProvider deviceInfoProvider,
  }) : _deviceIdProvider = deviceIdProvider,
       _deviceInfoProvider = deviceInfoProvider;

  final DeviceIdProvider _deviceIdProvider;
  final DeviceInfoProvider _deviceInfoProvider;

  Future<DeviceId> getDeviceId() {
    return _deviceIdProvider.getDeviceId();
  }

  Future<DeviceInfo> getDeviceInfo() {
    return _deviceInfoProvider.getDeviceInfo();
  }

  Future<Map<String, Object>> getAttributes({
    DeviceId? deviceId,
    DeviceInfo? deviceInfo,
  }) async {
    deviceId ??= await getDeviceId();
    deviceInfo ??= await getDeviceInfo();

    final attributes = <String, Object>{
      'dart_version': deviceInfo.dartVersion,
      'device_os': deviceInfo.deviceOs,
      'device_os_version': deviceInfo.deviceOsVersion,
      'device_os_detail': deviceInfo.deviceOsDetail,
      'device_manufacturer': deviceInfo.deviceManufacturer,
      'device_model': deviceInfo.deviceModel,
      'device_model_name': deviceInfo.deviceModelName,
      'device_brand': deviceInfo.deviceBrand,
      'device_is_physical': deviceInfo.deviceIsPhysical,
      'device_id': '$deviceId',
    };

    return attributes;
  }
}

class SessionAttributesProviderFactory {
  Future<SessionAttributesProvider> create() async {
    final deviceIdProvider = await DeviceIdProviderFactory().create();
    final deviceInfoProvider = DeviceInfoProviderFactory().create();

    return SessionAttributesProvider(
      deviceIdProvider: deviceIdProvider,
      deviceInfoProvider: deviceInfoProvider,
    );
  }
}
