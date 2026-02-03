import 'package:faro/src/util/random_value_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DefaultRandomValueProvider:', () {
    test('should return a double value', () {
      final sut = DefaultRandomValueProvider();

      final result = sut.nextDouble();

      expect(result, isA<double>());
    });

    test('should return values in range [0, 1)', () {
      final sut = DefaultRandomValueProvider();

      // Generate multiple values to ensure they're all in range
      for (var i = 0; i < 100; i++) {
        final result = sut.nextDouble();

        expect(result, greaterThanOrEqualTo(0.0));
        expect(result, lessThan(1.0));
      }
    });

    test('should generate different values on subsequent calls', () {
      final sut = DefaultRandomValueProvider();

      final values = <double>{};
      for (var i = 0; i < 20; i++) {
        values.add(sut.nextDouble());
      }

      // Should have generated multiple different values
      // (extremely unlikely to get all same values with random)
      expect(values.length, greaterThan(1));
    });
  });

  group('RandomValueProviderFactory:', () {
    late RandomValueProviderFactory sut;

    setUp(() {
      sut = RandomValueProviderFactory();
      sut.reset();
    });

    tearDown(() {
      sut.reset();
    });

    test('should create a RandomValueProvider instance', () {
      final provider = sut.create();

      expect(provider, isA<RandomValueProvider>());
    });

    test('should return the same instance on multiple calls (singleton)', () {
      final provider1 = sut.create();
      final provider2 = sut.create();

      expect(identical(provider1, provider2), isTrue);
    });

    test('should return same instance across different factory instances', () {
      final factory1 = RandomValueProviderFactory();
      final factory2 = RandomValueProviderFactory();

      final provider1 = factory1.create();
      final provider2 = factory2.create();

      expect(identical(provider1, provider2), isTrue);
    });

    test('should allow setting a custom instance for testing', () {
      final customProvider = _FakeRandomValueProvider(0.5);

      sut.setInstance(customProvider);
      final provider = sut.create();

      expect(identical(provider, customProvider), isTrue);
      expect(provider.nextDouble(), equals(0.5));
    });

    test('should reset the singleton instance', () {
      final provider1 = sut.create();

      sut.reset();
      final provider2 = sut.create();

      expect(identical(provider1, provider2), isFalse);
    });
  });
}

/// Fake implementation for testing the factory's setInstance method.
class _FakeRandomValueProvider implements RandomValueProvider {
  _FakeRandomValueProvider(this.fixedValue);

  final double fixedValue;

  @override
  double nextDouble() => fixedValue;
}
