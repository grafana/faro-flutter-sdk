import 'package:faro/src/data_collection_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  late MockSharedPreferences mockSharedPreferences;
  late DataCollectionPolicy sut;

  setUp(() {
    mockSharedPreferences = MockSharedPreferences();
    reset(mockSharedPreferences);
  });

  group('DataCollectionPolicy:', () {
    test('should default to enabled when no previous value is stored', () {
      when(() => mockSharedPreferences.getBool('faro_enable_data_collection'))
          .thenReturn(null);
      when(() => mockSharedPreferences.setBool(any(), any()))
          .thenAnswer((_) async => true);

      sut = DataCollectionPolicy(sharedPreferences: mockSharedPreferences);

      expect(sut.isEnabled, isTrue);
      verify(() => mockSharedPreferences.getBool('faro_enable_data_collection'))
          .called(1);
    });

    test('should load persisted disabled state', () {
      when(() => mockSharedPreferences.getBool('faro_enable_data_collection'))
          .thenReturn(false);
      when(() => mockSharedPreferences.setBool(any(), any()))
          .thenAnswer((_) async => true);

      sut = DataCollectionPolicy(sharedPreferences: mockSharedPreferences);

      expect(sut.isEnabled, isFalse);
      verify(() => mockSharedPreferences.getBool('faro_enable_data_collection'))
          .called(1);
    });

    test('should load persisted enabled state', () {
      when(() => mockSharedPreferences.getBool('faro_enable_data_collection'))
          .thenReturn(true);
      when(() => mockSharedPreferences.setBool(any(), any()))
          .thenAnswer((_) async => true);

      sut = DataCollectionPolicy(sharedPreferences: mockSharedPreferences);

      expect(sut.isEnabled, isTrue);
      verify(() => mockSharedPreferences.getBool('faro_enable_data_collection'))
          .called(1);
    });

    test('should persist enabled state when calling enable()', () async {
      when(() => mockSharedPreferences.getBool('faro_enable_data_collection'))
          .thenReturn(null);
      when(() => mockSharedPreferences.setBool(any(), any()))
          .thenAnswer((_) async => true);

      sut = DataCollectionPolicy(sharedPreferences: mockSharedPreferences);

      await sut.enable();

      expect(sut.isEnabled, isTrue);
      verify(() => mockSharedPreferences.setBool(
          'faro_enable_data_collection', true)).called(1);
    });

    test('should persist disabled state when calling disable()', () async {
      when(() => mockSharedPreferences.getBool('faro_enable_data_collection'))
          .thenReturn(null);
      when(() => mockSharedPreferences.setBool(any(), any()))
          .thenAnswer((_) async => true);

      sut = DataCollectionPolicy(sharedPreferences: mockSharedPreferences);

      await sut.disable();

      expect(sut.isEnabled, isFalse);
      verify(() => mockSharedPreferences.setBool(
          'faro_enable_data_collection', false)).called(1);
    });

    test('should persist state change from enabled to disabled', () async {
      when(() => mockSharedPreferences.getBool('faro_enable_data_collection'))
          .thenReturn(true);
      when(() => mockSharedPreferences.setBool(any(), any()))
          .thenAnswer((_) async => true);

      sut = DataCollectionPolicy(sharedPreferences: mockSharedPreferences);

      expect(sut.isEnabled, isTrue);

      await sut.disable();

      expect(sut.isEnabled, isFalse);
      verify(() => mockSharedPreferences.setBool(
          'faro_enable_data_collection', false)).called(1);
    });

    test('should persist state change from disabled to enabled', () async {
      when(() => mockSharedPreferences.getBool('faro_enable_data_collection'))
          .thenReturn(false);
      when(() => mockSharedPreferences.setBool(any(), any()))
          .thenAnswer((_) async => true);

      sut = DataCollectionPolicy(sharedPreferences: mockSharedPreferences);

      expect(sut.isEnabled, isFalse);

      await sut.enable();

      expect(sut.isEnabled, isTrue);
      verify(() => mockSharedPreferences.setBool(
          'faro_enable_data_collection', true)).called(1);
    });

    test('should handle SharedPreferences setBool errors gracefully', () async {
      when(() => mockSharedPreferences.getBool('faro_enable_data_collection'))
          .thenReturn(null);
      when(() => mockSharedPreferences.setBool(any(), any()))
          .thenThrow(Exception('Storage failed'));

      sut = DataCollectionPolicy(sharedPreferences: mockSharedPreferences);

      // Should not throw, just log the error
      await sut.enable();

      // State should still be updated in memory
      expect(sut.isEnabled, isTrue);
      verify(() => mockSharedPreferences.setBool(
          'faro_enable_data_collection', true)).called(1);
    });
  });

  group('DataCollectionPolicyFactory:', () {
    test('should create DataCollectionPolicy instance', () async {
      // The factory uses real SharedPreferences, so we need Flutter binding
      SharedPreferences.setMockInitialValues({});

      final factory = DataCollectionPolicyFactory();
      final policy = await factory.create();

      expect(policy, isA<DataCollectionPolicy>());
      expect(policy.isEnabled, isTrue); // Default state
    });
  });
}
