import 'package:faro/src/device_info/device_info_provider.dart';
import 'package:faro/src/device_info/installation_id_provider.dart';
import 'package:faro/src/device_info/session_attributes_provider.dart';
import 'package:faro/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockInstallationIdProvider extends Mock
    implements InstallationIdProvider {}

class MockDeviceInfoProvider extends Mock implements DeviceInfoProvider {}

void main() {
  late MockInstallationIdProvider mockInstallationIdProvider;
  late MockDeviceInfoProvider mockDeviceInfoProvider;

  late SessionAttributesProvider sut;

  setUp(() {
    mockInstallationIdProvider = MockInstallationIdProvider();
    mockDeviceInfoProvider = MockDeviceInfoProvider();

    sut = SessionAttributesProvider(
      installationIdProvider: mockInstallationIdProvider,
      deviceInfoProvider: mockDeviceInfoProvider,
    );
  });

  group('SessionAttributesProvider:', () {
    test('should return correct attributes', () async {
      when(() => mockDeviceInfoProvider.getDeviceInfo()).thenAnswer(
        (_) async => DeviceInfo(
          dartVersion: 'Some-dart-version',
          deviceOs: 'Some-OS',
          deviceOsVersion: 'Some-OS-version',
          deviceOsDetail: 'Some-OS-detail',
          deviceManufacturer: 'Some-manufacturer',
          deviceModel: 'Some-model',
          deviceModelName: 'Some-model-name',
          deviceBrand: 'Some-brand',
          deviceIsPhysical: true,
        ),
      );
      when(
        () => mockInstallationIdProvider.getInstallationId(),
      ).thenAnswer((_) async => InstallationId('installation-id'));

      final collectedAttributes = await sut.collectAttributes();

      expect('${collectedAttributes.installationId}', 'installation-id');
      expect(collectedAttributes.deviceInfo.deviceModel, 'Some-model');
      expect(collectedAttributes.attributes, {
        'dart_version': 'Some-dart-version',
        'device_os': 'Some-OS',
        'device_os_version': 'Some-OS-version',
        'device_os_detail': 'Some-OS-detail',
        'device_manufacturer': 'Some-manufacturer',
        'device_model': 'Some-model',
        'device_model_name': 'Some-model-name',
        'device_brand': 'Some-brand',
        'device_is_physical': true,
        'device_id': 'installation-id',
      });
    });
  });
}
