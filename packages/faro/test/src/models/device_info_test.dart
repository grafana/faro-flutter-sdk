import 'package:flutter_test/flutter_test.dart';
import 'package:faro/faro_sdk.dart';

void main() {
  group('DeviceInfo:', () {
    test('assigns values correctly', () {
      const expectedDartVersion = 'dartVersion-1.0.0';
      const expectedDeviceOs = 'deviceOs-MoonOS-2.0.0';
      const expectedDeviceOsVersion = '9.9.9';
      const expectedDeviceOsDetail = 'Super detailed OS info';
      const expectedDeviceManufacturer = 'Acme Corp';
      const expectedDeviceModel = 'Model X';
      const expectedDeviceBrand = 'Brand Y';
      const expectedDeviceIsPhysical = true;

      final deviceInfo = DeviceInfo(
        dartVersion: expectedDartVersion,
        deviceOs: expectedDeviceOs,
        deviceOsVersion: expectedDeviceOsVersion,
        deviceOsDetail: expectedDeviceOsDetail,
        deviceManufacturer: expectedDeviceManufacturer,
        deviceModel: expectedDeviceModel,
        deviceBrand: expectedDeviceBrand,
        deviceIsPhysical: expectedDeviceIsPhysical,
      );

      expect(deviceInfo.dartVersion, expectedDartVersion);
      expect(deviceInfo.deviceOs, expectedDeviceOs);
      expect(deviceInfo.deviceOsVersion, expectedDeviceOsVersion);
      expect(deviceInfo.deviceOsDetail, expectedDeviceOsDetail);
      expect(deviceInfo.deviceManufacturer, expectedDeviceManufacturer);
      expect(deviceInfo.deviceModel, expectedDeviceModel);
      expect(deviceInfo.deviceBrand, expectedDeviceBrand);
      expect(deviceInfo.deviceIsPhysical, expectedDeviceIsPhysical);
    });
  });
}
