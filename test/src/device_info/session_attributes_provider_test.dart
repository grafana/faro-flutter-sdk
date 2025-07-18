import 'package:faro/src/device_info/device_id_provider.dart';
import 'package:faro/src/device_info/device_info_provider.dart';
import 'package:faro/src/device_info/session_attributes_provider.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/util/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDeviceIdProvider extends Mock implements DeviceIdProvider {}

class MockDeviceInfoProvider extends Mock implements DeviceInfoProvider {}

void main() {
  late MockDeviceIdProvider mockDeviceIdProvider;
  late MockDeviceInfoProvider mockDeviceInfoProvider;

  late SessionAttributesProvider sut;

  setUp(() {
    mockDeviceIdProvider = MockDeviceIdProvider();
    mockDeviceInfoProvider = MockDeviceInfoProvider();

    sut = SessionAttributesProvider(
      deviceIdProvider: mockDeviceIdProvider,
      deviceInfoProvider: mockDeviceInfoProvider,
    );
  });

  group('SessionAttributesProvider:', () {
    test('should return correct attributes', () async {
      when(() => mockDeviceInfoProvider.getDeviceInfo())
          .thenAnswer((_) async => DeviceInfo(
                dartVersion: 'Some-dart-version',
                deviceOs: 'Some-OS',
                deviceOsVersion: 'Some-OS-version',
                deviceOsDetail: 'Some-OS-detail',
                deviceManufacturer: 'Some-manufacturer',
                deviceModel: 'Some-model',
                deviceBrand: 'Some-brand',
                deviceIsPhysical: true,
              ));
      when(() => mockDeviceIdProvider.getDeviceId())
          .thenAnswer((_) async => DeviceId('device-id'));

      final attributes = await sut.getAttributes();

      expect(attributes, {
        'faro_sdk_version': FaroConstants.sdkVersion,
        'dart_version': 'Some-dart-version',
        'device_os': 'Some-OS',
        'device_os_version': 'Some-OS-version',
        'device_os_detail': 'Some-OS-detail',
        'device_manufacturer': 'Some-manufacturer',
        'device_model': 'Some-model',
        'device_brand': 'Some-brand',
        'device_is_physical': 'true',
        'device_id': 'device-id',
      });
    });
  });
}
