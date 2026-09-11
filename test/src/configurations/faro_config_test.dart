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
      Set<String>? sensitiveHttpQueryParameters,
      bool persistSession = true,
      FaroEngineRole engineRole = FaroEngineRole.automatic,
    }) {
      return FaroConfig(
        appName: appName,
        appEnv: appEnv,
        apiKey: apiKey,
        collectorUrl: collectorUrl,
        sampling: sampling,
        sensitiveHttpQueryParameters: sensitiveHttpQueryParameters,
        persistSession: persistSession,
        engineRole: engineRole,
      );
    }

    group('sensitive HTTP query parameters:', () {
      test('omitted, null and empty mean no application additions', () {
        expect(createConfig().sensitiveHttpQueryParameters, isEmpty);
        expect(
          createConfig(
            // Explicit null is part of the public constructor contract.
            // ignore: avoid_redundant_argument_values
            sensitiveHttpQueryParameters: null,
          ).sensitiveHttpQueryParameters,
          isEmpty,
        );
        expect(
          createConfig(
            sensitiveHttpQueryParameters: {},
          ).sensitiveHttpQueryParameters,
          isEmpty,
        );
      });

      test('copies caller names without normalization and is immutable', () {
        final names = {'customer_code', 'Token', ' customer_code '};
        final config = createConfig(sensitiveHttpQueryParameters: names);
        names.clear();
        expect(config.sensitiveHttpQueryParameters, {
          'customer_code',
          'Token',
          ' customer_code ',
        });
        expect(
          () => config.sensitiveHttpQueryParameters.add('new_name'),
          throwsUnsupportedError,
        );
      });
    });

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

    group('engine role:', () {
      test('is inferred automatically by default', () {
        expect(createConfig().engineRole, FaroEngineRole.automatic);
      });

      test('can identify a pre-warmed foreground engine', () {
        expect(
          createConfig(engineRole: FaroEngineRole.foreground).engineRole,
          FaroEngineRole.foreground,
        );
      });
    });
  });
}
