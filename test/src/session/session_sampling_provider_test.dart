// ignore_for_file: prefer_int_literals

import 'package:faro/src/session/session_sampling_provider.dart';
import 'package:faro/src/util/random_value_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_random_value_provider.dart';

void main() {
  group('SessionSamplingProvider:', () {
    test('should return isSampled=true when random < samplingRate', () {
      final fakeRandom = FakeRandomValueProvider(0.3);

      final sut = SessionSamplingProvider(
        samplingRate: 0.5,
        randomValueProvider: fakeRandom,
      );

      expect(sut.isSampled, isTrue);
    });

    test('should return isSampled=false when random >= samplingRate', () {
      final fakeRandom = FakeRandomValueProvider(0.7);

      final sut = SessionSamplingProvider(
        samplingRate: 0.5,
        randomValueProvider: fakeRandom,
      );

      expect(sut.isSampled, isFalse);
    });

    test('should return isSampled=false when random equals samplingRate', () {
      final fakeRandom = FakeRandomValueProvider(0.5);

      final sut = SessionSamplingProvider(
        samplingRate: 0.5,
        randomValueProvider: fakeRandom,
      );

      expect(sut.isSampled, isFalse);
    });

    test('samplingRate 0.0 never samples (even with random 0.0)', () {
      final fakeRandom = FakeRandomValueProvider(0.0);

      final sut = SessionSamplingProvider(
        samplingRate: 0.0,
        randomValueProvider: fakeRandom,
      );

      expect(sut.isSampled, isFalse);
    });

    test('samplingRate 1.0 always samples (even with random 0.999)', () {
      final fakeRandom = FakeRandomValueProvider(0.999);

      final sut = SessionSamplingProvider(
        samplingRate: 1.0,
        randomValueProvider: fakeRandom,
      );

      expect(sut.isSampled, isTrue);
    });

    test('sampling decision is immutable after construction', () {
      final fakeRandom = FakeRandomValueProvider(0.3);

      final sut = SessionSamplingProvider(
        samplingRate: 0.5,
        randomValueProvider: fakeRandom,
      );

      final firstAccess = sut.isSampled;
      final secondAccess = sut.isSampled;

      expect(firstAccess, equals(secondAccess));
      expect(sut.isSampled, isTrue);
    });

    group('clamping invalid values:', () {
      test('samplingRate > 1.0 is clamped to 1.0 (always samples)', () {
        final fakeRandom = FakeRandomValueProvider(0.999);

        final sut = SessionSamplingProvider(
          samplingRate: 2.0, // Invalid: > 1.0
          randomValueProvider: fakeRandom,
        );

        // Should behave like samplingRate 1.0: 0.999 < 1.0 is true
        expect(sut.isSampled, isTrue);
      });

      test('samplingRate < 0.0 is clamped to 0.0 (never samples)', () {
        final fakeRandom = FakeRandomValueProvider(0.0);

        final sut = SessionSamplingProvider(
          samplingRate: -0.5, // Invalid: < 0.0
          randomValueProvider: fakeRandom,
        );

        // Should behave like samplingRate 0.0: 0.0 < 0.0 is false
        expect(sut.isSampled, isFalse);
      });

      test('large positive samplingRate is clamped to 1.0', () {
        final fakeRandom = FakeRandomValueProvider(0.5);

        final sut = SessionSamplingProvider(
          samplingRate: 100.0, // Invalid: way > 1.0
          randomValueProvider: fakeRandom,
        );

        // Should behave like samplingRate 1.0
        expect(sut.isSampled, isTrue);
      });

      test('large negative samplingRate is clamped to 0.0', () {
        final fakeRandom = FakeRandomValueProvider(0.001);

        final sut = SessionSamplingProvider(
          samplingRate: -100.0, // Invalid: way < 0.0
          randomValueProvider: fakeRandom,
        );

        // Should behave like samplingRate 0.0
        expect(sut.isSampled, isFalse);
      });
    });
  });

  group('SessionSamplingProviderFactory:', () {
    late SessionSamplingProviderFactory sut;

    setUp(() {
      sut = SessionSamplingProviderFactory();
      sut.reset();
      RandomValueProviderFactory().reset();
    });

    tearDown(() {
      sut.reset();
      RandomValueProviderFactory().reset();
    });

    test('should create a SessionSamplingProvider instance', () {
      final fakeRandom = FakeRandomValueProvider(0.5);

      final provider = sut.create(
        samplingRate: 1.0,
        randomValueProvider: fakeRandom,
      );

      expect(provider, isA<SessionSamplingProvider>());
    });

    test('should return same instance on multiple calls (singleton)', () {
      final fakeRandom = FakeRandomValueProvider(0.5);

      final provider1 = sut.create(
        samplingRate: 1.0,
        randomValueProvider: fakeRandom,
      );
      final provider2 = sut.create(
        samplingRate: 0.5,
        randomValueProvider: fakeRandom,
      );

      expect(identical(provider1, provider2), isTrue);
    });

    test('should use injected RandomValueProvider', () {
      final fakeRandom = FakeRandomValueProvider(0.3);

      final provider = sut.create(
        samplingRate: 0.5,
        randomValueProvider: fakeRandom,
      );

      expect(provider.isSampled, isTrue);
    });

    test('should work when RandomValueProvider is not provided', () {
      // Verifies the code path works without an injected provider
      final provider = sut.create(samplingRate: 1.0);

      // With samplingRate 1.0, should always be sampled regardless of random
      expect(provider.isSampled, isTrue);
    });

    test('should reset the singleton instance', () {
      final fakeRandom1 = FakeRandomValueProvider(0.3);
      final provider1 = sut.create(
        samplingRate: 0.5,
        randomValueProvider: fakeRandom1,
      );

      sut.reset();

      final fakeRandom2 = FakeRandomValueProvider(0.7);
      final provider2 = sut.create(
        samplingRate: 0.5,
        randomValueProvider: fakeRandom2,
      );

      expect(identical(provider1, provider2), isFalse);
      expect(provider1.isSampled, isTrue);
      expect(provider2.isSampled, isFalse);
    });
  });
}
