import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:faro/src/device_info/device_id_provider.dart';
import 'package:faro/src/util/uuid_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {}

class MockUuidProvider extends Mock implements UuidProvider {}

void main() {
  late MockSharedPreferences mockSharedPreferences;
  late MockUuidProvider mockUuidProvider;

  late DeviceIdProvider sut;

  setUp(() {
    mockSharedPreferences = MockSharedPreferences();
    mockUuidProvider = MockUuidProvider();

    when(() => mockSharedPreferences.getString(any())).thenReturn(null);
    when(() => mockSharedPreferences.setString(any(), any()))
        .thenAnswer((_) async => true);

    sut = DeviceIdProvider(
      sharedPreferences: mockSharedPreferences,
      uuidProvider: mockUuidProvider,
    );
  });

  group('DeviceIdProvider:', () {
    test('should a newly generated uuid when not stored before', () async {
      // Returning null from sharedPrefs to simulate no stored device id
      when(() => mockSharedPreferences.getString(any())).thenReturn(null);

      const expectedUuid = 'some-random-uuid';
      when(() => mockUuidProvider.getUuidV4()).thenReturn(expectedUuid);

      final deviceId = await sut.getDeviceId();

      expect('$deviceId', expectedUuid);
      verify(() => mockSharedPreferences.setString(any(), any())).called(1);
    });

    test('should return stored uuid when stored before', () async {
      const expectedUuid = 'stored-some-random-uuid';
      when(() => mockSharedPreferences.getString(any())).thenReturn(
        expectedUuid,
      );

      final deviceId = await sut.getDeviceId();

      expect('$deviceId', expectedUuid);
      verifyNever(() => mockUuidProvider.getUuidV4());
      verifyNever(() => mockSharedPreferences.setString(any(), any()));
    });

    test(
        'should return cached version of stored uuid when called a second time',
        () async {
      const expectedUuid = 'cached-stored-some-random-uuid';
      when(() => mockSharedPreferences.getString(any())).thenReturn(
        expectedUuid,
      );

      var deviceId = await sut.getDeviceId();
      deviceId = await sut.getDeviceId();

      expect('$deviceId', expectedUuid);
      verify(() => mockSharedPreferences.getString(any())).called(1);
    });
  });
}
