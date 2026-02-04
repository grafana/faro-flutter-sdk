// ignore_for_file: prefer_int_literals

import 'package:faro/src/configurations/faro_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FaroConfig:', () {
    FaroConfig createConfig({
      String appName = 'test-app',
      String appEnv = 'test',
      String apiKey = 'test-api-key',
      String collectorUrl = 'https://example.com',
      double? samplingRate,
    }) {
      if (samplingRate != null) {
        return FaroConfig(
          appName: appName,
          appEnv: appEnv,
          apiKey: apiKey,
          collectorUrl: collectorUrl,
          samplingRate: samplingRate,
        );
      }
      return FaroConfig(
        appName: appName,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: collectorUrl,
      );
    }

    group('samplingRate:', () {
      test('should default to 1.0 (100% sampled)', () {
        final config = createConfig();

        expect(config.samplingRate, equals(1.0));
      });

      test('should accept 0.0 (0% sampled)', () {
        final config = createConfig(samplingRate: 0.0);

        expect(config.samplingRate, equals(0.0));
      });

      test('should accept 0.5 (50% sampled)', () {
        final config = createConfig(samplingRate: 0.5);

        expect(config.samplingRate, equals(0.5));
      });

      test('should accept 1.0 (100% sampled)', () {
        final config = createConfig(samplingRate: 1.0);

        expect(config.samplingRate, equals(1.0));
      });

      test('should accept values between 0.0 and 1.0', () {
        final rates = [0.1, 0.25, 0.33, 0.75, 0.99];

        for (final rate in rates) {
          final config = createConfig(samplingRate: rate);
          expect(config.samplingRate, equals(rate));
        }
      });

      test('should throw assertion error for negative values', () {
        expect(
          () => createConfig(samplingRate: -0.1),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should throw assertion error for values greater than 1.0', () {
        expect(
          () => createConfig(samplingRate: 1.1),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should throw assertion error for value of 2.0', () {
        expect(
          () => createConfig(samplingRate: 2.0),
          throwsA(isA<AssertionError>()),
        );
      });
    });
  });
}
