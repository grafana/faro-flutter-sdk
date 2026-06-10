import 'package:faro/src/device_info/installation_id_provider.dart';
import 'package:faro/src/util/uuid_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {}

class MockUuidProvider extends Mock implements UuidProvider {}

void main() {
  late MockSharedPreferences mockSharedPreferences;
  late MockUuidProvider mockUuidProvider;

  late InstallationIdProvider sut;

  setUp(() {
    mockSharedPreferences = MockSharedPreferences();
    mockUuidProvider = MockUuidProvider();

    when(() => mockSharedPreferences.getString(any())).thenReturn(null);
    when(
      () => mockSharedPreferences.setString(any(), any()),
    ).thenAnswer((_) async => true);

    sut = InstallationIdProvider(
      sharedPreferences: mockSharedPreferences,
      uuidProvider: mockUuidProvider,
    );
  });

  group('InstallationIdProvider:', () {
    test(
      'should return a newly generated uuid when not stored before',
      () async {
        // Simulate no stored installation id.
        when(() => mockSharedPreferences.getString(any())).thenReturn(null);

        const expectedUuid = 'some-random-uuid';
        when(() => mockUuidProvider.getUuidV4()).thenReturn(expectedUuid);

        final installationId = await sut.getInstallationId();

        expect('$installationId', expectedUuid);
        verify(() => mockSharedPreferences.setString(any(), any())).called(1);
      },
    );

    test('should return stored uuid when stored before', () async {
      const expectedUuid = 'stored-some-random-uuid';
      when(
        () => mockSharedPreferences.getString(any()),
      ).thenReturn(expectedUuid);

      final installationId = await sut.getInstallationId();

      expect('$installationId', expectedUuid);
      verifyNever(mockUuidProvider.getUuidV4);
      verifyNever(() => mockSharedPreferences.setString(any(), any()));
    });

    test(
      'should return cached version of stored uuid when called a second time',
      () async {
        const expectedUuid = 'cached-stored-some-random-uuid';
        when(
          () => mockSharedPreferences.getString(any()),
        ).thenReturn(expectedUuid);

        var installationId = await sut.getInstallationId();
        installationId = await sut.getInstallationId();

        expect('$installationId', expectedUuid);
        verify(() => mockSharedPreferences.getString(any())).called(1);
      },
    );
  });
}
