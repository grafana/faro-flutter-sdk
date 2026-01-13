import 'dart:convert';

import 'package:faro/src/models/faro_user.dart';
import 'package:faro/src/user/user_persistence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  late MockSharedPreferences mockSharedPreferences;
  late UserPersistence sut;

  setUp(() {
    mockSharedPreferences = MockSharedPreferences();
    reset(mockSharedPreferences);
  });

  group('UserPersistence:', () {
    group('loadUser:', () {
      test('should return null when no user is stored', () {
        when(() => mockSharedPreferences.getString('faro_persisted_user'))
            .thenReturn(null);

        sut = UserPersistence(sharedPreferences: mockSharedPreferences);
        final result = sut.loadUser();

        expect(result, isNull);
        verify(() => mockSharedPreferences.getString('faro_persisted_user'))
            .called(1);
      });

      test('should return persisted user when stored', () {
        final userData = {
          'id': 'user-123',
          'username': 'john.doe',
          'email': 'john@example.com',
        };
        when(() => mockSharedPreferences.getString('faro_persisted_user'))
            .thenReturn(json.encode(userData));

        sut = UserPersistence(sharedPreferences: mockSharedPreferences);
        final result = sut.loadUser();

        expect(result, isNotNull);
        expect(result!.id, 'user-123');
        expect(result.username, 'john.doe');
        expect(result.email, 'john@example.com');
      });

      test('should return null when JSON is invalid', () {
        when(() => mockSharedPreferences.getString('faro_persisted_user'))
            .thenReturn('invalid json');

        sut = UserPersistence(sharedPreferences: mockSharedPreferences);
        final result = sut.loadUser();

        expect(result, isNull);
      });

      test('should handle errors gracefully', () {
        when(() => mockSharedPreferences.getString('faro_persisted_user'))
            .thenThrow(Exception('Storage error'));

        sut = UserPersistence(sharedPreferences: mockSharedPreferences);
        final result = sut.loadUser();

        expect(result, isNull);
      });
    });

    group('saveUser:', () {
      test('should persist user data', () async {
        when(() => mockSharedPreferences.setString(any(), any()))
            .thenAnswer((_) async => true);

        sut = UserPersistence(sharedPreferences: mockSharedPreferences);
        const user = FaroUser(
          id: 'user-123',
          username: 'john.doe',
          email: 'john@example.com',
        );

        await sut.saveUser(user);

        final captured = verify(
          () => mockSharedPreferences.setString(
              'faro_persisted_user', captureAny()),
        ).captured.single as String;

        final savedData = json.decode(captured) as Map<String, dynamic>;
        expect(savedData['id'], 'user-123');
        expect(savedData['username'], 'john.doe');
        expect(savedData['email'], 'john@example.com');
      });

      test('should clear user when null is passed', () async {
        when(() => mockSharedPreferences.remove(any()))
            .thenAnswer((_) async => true);

        sut = UserPersistence(sharedPreferences: mockSharedPreferences);

        await sut.saveUser(null);

        verify(() => mockSharedPreferences.remove('faro_persisted_user'))
            .called(1);
        verifyNever(() => mockSharedPreferences.setString(any(), any()));
      });

      test('should clear user when cleared user is passed', () async {
        when(() => mockSharedPreferences.remove(any()))
            .thenAnswer((_) async => true);

        sut = UserPersistence(sharedPreferences: mockSharedPreferences);

        await sut.saveUser(const FaroUser.cleared());

        verify(() => mockSharedPreferences.remove('faro_persisted_user'))
            .called(1);
        verifyNever(() => mockSharedPreferences.setString(any(), any()));
      });

      test('should handle errors gracefully', () async {
        when(() => mockSharedPreferences.setString(any(), any()))
            .thenThrow(Exception('Storage error'));

        sut = UserPersistence(sharedPreferences: mockSharedPreferences);

        // Should not throw
        await sut.saveUser(const FaroUser(id: 'user-123'));
      });
    });

    group('clearUser:', () {
      test('should remove persisted user data', () async {
        when(() => mockSharedPreferences.remove(any()))
            .thenAnswer((_) async => true);

        sut = UserPersistence(sharedPreferences: mockSharedPreferences);

        await sut.clearUser();

        verify(() => mockSharedPreferences.remove('faro_persisted_user'))
            .called(1);
      });

      test('should handle errors gracefully', () async {
        when(() => mockSharedPreferences.remove(any()))
            .thenThrow(Exception('Storage error'));

        sut = UserPersistence(sharedPreferences: mockSharedPreferences);

        // Should not throw
        await sut.clearUser();
      });
    });

    group('hasPersistedUser:', () {
      test('should return true when user data exists', () {
        when(() => mockSharedPreferences.containsKey('faro_persisted_user'))
            .thenReturn(true);

        sut = UserPersistence(sharedPreferences: mockSharedPreferences);

        expect(sut.hasPersistedUser(), isTrue);
      });

      test('should return false when no user data exists', () {
        when(() => mockSharedPreferences.containsKey('faro_persisted_user'))
            .thenReturn(false);

        sut = UserPersistence(sharedPreferences: mockSharedPreferences);

        expect(sut.hasPersistedUser(), isFalse);
      });
    });
  });

  group('UserPersistenceFactory:', () {
    test('should create UserPersistence instance', () async {
      SharedPreferences.setMockInitialValues({});

      final factory = UserPersistenceFactory();
      final persistence = await factory.create();

      expect(persistence, isA<UserPersistence>());
    });
  });
}
