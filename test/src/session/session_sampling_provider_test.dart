// ignore_for_file: prefer_int_literals

import 'package:faro/src/configurations/sampling.dart';
import 'package:faro/src/models/app.dart';
import 'package:faro/src/models/meta.dart';
import 'package:faro/src/models/session.dart';
import 'package:faro/src/session/sampling_context.dart';
import 'package:faro/src/session/session_sampling_provider.dart';
import 'package:faro/src/util/random_value_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_random_value_provider.dart';

void main() {
  group('SessionSamplingProvider:', () {
    late Meta testMeta;

    setUp(() {
      testMeta = Meta(
        session: Session('test-session'),
        app: App(
          name: 'TestApp',
          environment: 'production',
          version: '1.0.0',
        ),
      );
    });

    test('should return isSampled=true when random < rate', () {
      final fakeRandom = FakeRandomValueProvider(0.3);

      final sut = SessionSamplingProvider(
        sampling: const SamplingRate(0.5),
        meta: testMeta,
        randomValueProvider: fakeRandom,
      );

      expect(sut.isSampled, isTrue);
    });

    test('should return isSampled=false when random >= rate', () {
      final fakeRandom = FakeRandomValueProvider(0.7);

      final sut = SessionSamplingProvider(
        sampling: const SamplingRate(0.5),
        meta: testMeta,
        randomValueProvider: fakeRandom,
      );

      expect(sut.isSampled, isFalse);
    });

    test('should return isSampled=false when random equals rate', () {
      final fakeRandom = FakeRandomValueProvider(0.5);

      final sut = SessionSamplingProvider(
        sampling: const SamplingRate(0.5),
        meta: testMeta,
        randomValueProvider: fakeRandom,
      );

      expect(sut.isSampled, isFalse);
    });

    test('SamplingRate(0.0) never samples (even with random 0.0)', () {
      final fakeRandom = FakeRandomValueProvider(0.0);

      final sut = SessionSamplingProvider(
        sampling: const SamplingRate(0.0),
        meta: testMeta,
        randomValueProvider: fakeRandom,
      );

      expect(sut.isSampled, isFalse);
    });

    test('SamplingRate(1.0) always samples (even with random 0.999)', () {
      final fakeRandom = FakeRandomValueProvider(0.999);

      final sut = SessionSamplingProvider(
        sampling: const SamplingRate(1.0),
        meta: testMeta,
        randomValueProvider: fakeRandom,
      );

      expect(sut.isSampled, isTrue);
    });

    test('sampling decision is immutable after construction', () {
      final fakeRandom = FakeRandomValueProvider(0.3);

      final sut = SessionSamplingProvider(
        sampling: const SamplingRate(0.5),
        meta: testMeta,
        randomValueProvider: fakeRandom,
      );

      final firstAccess = sut.isSampled;
      final secondAccess = sut.isSampled;

      expect(firstAccess, equals(secondAccess));
      expect(sut.isSampled, isTrue);
    });

    test('null sampling defaults to 100% sampled', () {
      final fakeRandom = FakeRandomValueProvider(0.999);

      final sut = SessionSamplingProvider(
        meta: testMeta,
        randomValueProvider: fakeRandom,
      );

      expect(sut.isSampled, isTrue);
    });

    group('SamplingFunction:', () {
      test('function is called with SamplingContext', () {
        final fakeRandom = FakeRandomValueProvider(0.5);
        SamplingContext? capturedContext;

        SessionSamplingProvider(
          sampling: SamplingFunction((context) {
            capturedContext = context;
            return 1.0;
          }),
          meta: testMeta,
          randomValueProvider: fakeRandom,
        );

        expect(capturedContext, isNotNull);
        expect(capturedContext!.meta, equals(testMeta));
        expect(capturedContext!.meta.app?.name, equals('TestApp'));
      });

      test('can make decision based on environment', () {
        final fakeRandom = FakeRandomValueProvider(0.5);

        final sut = SessionSamplingProvider(
          sampling: SamplingFunction((context) {
            if (context.meta.app?.environment == 'production') {
              return 0.1; // Low sampling in production
            }
            return 1.0;
          }),
          meta: testMeta, // production environment
          randomValueProvider: fakeRandom,
        );

        // 0.5 >= 0.1, so not sampled
        expect(sut.isSampled, isFalse);
      });

      test('return value above 1.0 is clamped', () {
        final fakeRandom = FakeRandomValueProvider(0.99);

        final sut = SessionSamplingProvider(
          sampling: SamplingFunction((context) => 5.0),
          meta: testMeta,
          randomValueProvider: fakeRandom,
        );

        expect(sut.isSampled, isTrue);
      });

      test('return value below 0.0 is clamped', () {
        final fakeRandom = FakeRandomValueProvider(0.0);

        final sut = SessionSamplingProvider(
          sampling: SamplingFunction((context) => -1.0),
          meta: testMeta,
          randomValueProvider: fakeRandom,
        );

        expect(sut.isSampled, isFalse);
      });
    });
  });

  group('SessionSamplingProviderFactory:', () {
    late SessionSamplingProviderFactory sut;
    late Meta testMeta;

    setUp(() {
      sut = SessionSamplingProviderFactory();
      sut.reset();
      RandomValueProviderFactory().reset();
      testMeta = Meta(
        session: Session('test-session'),
        app: App(
          name: 'TestApp',
          environment: 'production',
          version: '1.0.0',
        ),
      );
    });

    tearDown(() {
      sut.reset();
      RandomValueProviderFactory().reset();
    });

    test('should create a SessionSamplingProvider instance', () {
      final fakeRandom = FakeRandomValueProvider(0.5);

      final provider = sut.create(
        sampling: const SamplingRate(1.0),
        meta: testMeta,
        randomValueProvider: fakeRandom,
      );

      expect(provider, isA<SessionSamplingProvider>());
    });

    test('should return same instance on multiple calls (singleton)', () {
      final fakeRandom = FakeRandomValueProvider(0.5);

      final provider1 = sut.create(
        sampling: const SamplingRate(1.0),
        meta: testMeta,
        randomValueProvider: fakeRandom,
      );
      final provider2 = sut.create(
        sampling: const SamplingRate(0.5),
        meta: testMeta,
        randomValueProvider: fakeRandom,
      );

      expect(identical(provider1, provider2), isTrue);
    });

    test('should use injected RandomValueProvider', () {
      final fakeRandom = FakeRandomValueProvider(0.3);

      final provider = sut.create(
        sampling: const SamplingRate(0.5),
        meta: testMeta,
        randomValueProvider: fakeRandom,
      );

      expect(provider.isSampled, isTrue);
    });

    test('should work when sampling is not provided (defaults to 100%)', () {
      final provider = sut.create(
        meta: testMeta,
      );

      // With default sampling (1.0), should always be sampled
      expect(provider.isSampled, isTrue);
    });

    test('should reset the singleton instance', () {
      final fakeRandom1 = FakeRandomValueProvider(0.3);
      final provider1 = sut.create(
        sampling: const SamplingRate(0.5),
        meta: testMeta,
        randomValueProvider: fakeRandom1,
      );

      sut.reset();

      final fakeRandom2 = FakeRandomValueProvider(0.7);
      final provider2 = sut.create(
        sampling: const SamplingRate(0.5),
        meta: testMeta,
        randomValueProvider: fakeRandom2,
      );

      expect(identical(provider1, provider2), isFalse);
      expect(provider1.isSampled, isTrue);
      expect(provider2.isSampled, isFalse);
    });
  });
}
