import 'package:faro/src/configurations/faro_config.dart';
import 'package:faro/src/configurations/sampling.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FaroConfig:', () {
    FaroConfig createConfig({
      String appName = 'test-app',
      String appEnv = 'test',
      String apiKey = 'test-api-key',
      String collectorUrl = 'https://example.com',
      Sampling? sampling,
      bool persistSession = true,
    }) {
      return FaroConfig(
        appName: appName,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: collectorUrl,
        sampling: sampling,
        persistSession: persistSession,
      );
    }

    group('sampling:', () {
      test('should default to null (100% sampled)', () {
        final config = createConfig();

        expect(config.sampling, isNull);
      });

      test('should accept SamplingRate', () {
        final config = createConfig(sampling: const SamplingRate(0.5));

        final sampling = config.sampling;
        expect(sampling, isA<SamplingRate>());
        expect((sampling! as SamplingRate).rate, equals(0.5));
      });

      test('should accept SamplingFunction', () {
        final config = createConfig(
          sampling: SamplingFunction((context) => 0.5),
        );

        expect(config.sampling, isA<SamplingFunction>());
      });
    });

    group('session persistence:', () {
      test('is enabled by default', () {
        expect(createConfig().persistSession, isTrue);
      });

      test('can be disabled', () {
        expect(createConfig(persistSession: false).persistSession, isFalse);
      });
    });
  });
}
