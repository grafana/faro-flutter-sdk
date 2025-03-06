class DeviceInfo {
  DeviceInfo({
    required this.dartVersion,
    required this.deviceOs,
    required this.deviceOsVersion,
    required this.deviceOsDetail,
    required this.deviceManufacturer,
    required this.deviceModel,
    required this.deviceBrand,
    required this.deviceIsPhysical,
  });

  final String dartVersion;
  final String deviceOs;
  final String deviceOsVersion;
  final String deviceOsDetail;
  final String deviceManufacturer;
  final String deviceModel;
  final String deviceBrand;
  final bool deviceIsPhysical;
}
