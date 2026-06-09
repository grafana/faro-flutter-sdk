import 'package:faro/src/device_info/device_info_provider.dart';
import 'package:faro/src/device_info/installation_id_provider.dart';
import 'package:faro/src/models/device_info.dart';
import 'package:faro/src/models/installation_id.dart';

class SessionAttributesProvider {
  SessionAttributesProvider({
    required InstallationIdProvider installationIdProvider,
    required DeviceInfoProvider deviceInfoProvider,
  }) : _installationIdProvider = installationIdProvider,
       _deviceInfoProvider = deviceInfoProvider;

  final InstallationIdProvider _installationIdProvider;
  final DeviceInfoProvider _deviceInfoProvider;

  Future<InstallationId> getInstallationId() {
    return _installationIdProvider.getInstallationId();
  }

  Future<DeviceInfo> getDeviceInfo() {
    return _deviceInfoProvider.getDeviceInfo();
  }

  Future<CollectedSessionAttributes> collectAttributes() async {
    final installationId = await getInstallationId();
    final deviceInfo = await getDeviceInfo();

    return CollectedSessionAttributes(
      installationId: installationId,
      deviceInfo: deviceInfo,
      attributes: _attributesFor(
        installationId: installationId,
        deviceInfo: deviceInfo,
      ),
    );
  }

  Map<String, Object> _attributesFor({
    required InstallationId installationId,
    required DeviceInfo deviceInfo,
  }) {
    return <String, Object>{
      'dart_version': deviceInfo.dartVersion,
      'device_os': deviceInfo.deviceOs,
      'device_os_version': deviceInfo.deviceOsVersion,
      'device_os_detail': deviceInfo.deviceOsDetail,
      'device_manufacturer': deviceInfo.deviceManufacturer,
      'device_model': deviceInfo.deviceModel,
      'device_model_name': deviceInfo.deviceModelName,
      'device_brand': deviceInfo.deviceBrand,
      'device_is_physical': deviceInfo.deviceIsPhysical,
      // Keep the legacy flat key during the structured meta migration.
      'device_id': '$installationId',
    };
  }
}

class CollectedSessionAttributes {
  CollectedSessionAttributes({
    required this.installationId,
    required this.deviceInfo,
    required this.attributes,
  });

  final InstallationId installationId;
  final DeviceInfo deviceInfo;
  final Map<String, Object> attributes;
}

class SessionAttributesProviderFactory {
  Future<SessionAttributesProvider> create() async {
    final installationIdProvider = await InstallationIdProviderFactory()
        .create();
    final deviceInfoProvider = DeviceInfoProviderFactory().create();

    return SessionAttributesProvider(
      installationIdProvider: installationIdProvider,
      deviceInfoProvider: deviceInfoProvider,
    );
  }
}
