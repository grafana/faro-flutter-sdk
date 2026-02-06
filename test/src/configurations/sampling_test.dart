// ignore_for_file: prefer_int_literals

import 'package:faro/src/configurations/sampling.dart';
import 'package:faro/src/models/app.dart';
import 'package:faro/src/models/faro_user.dart';
import 'package:faro/src/models/meta.dart';
import 'package:faro/src/session/sampling_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sampling:', () {
    group('SamplingRate:', () {
      test('should resolve to the fixed rate', () {
        const sampling = SamplingRate(0.5);
        final context = SamplingContext(meta: Meta());

        expect(sampling.resolve(context), equals(0.5));
      });

      test('should clamp values above 1.0', () {
        const sampling = SamplingRate(2.0);
        final context = SamplingContext(meta: Meta());

        expect(sampling.resolve(context), equals(1.0));
      });

      test('should clamp values below 0.0', () {
        const sampling = SamplingRate(-0.5);
        final context = SamplingContext(meta: Meta());

        expect(sampling.resolve(context), equals(0.0));
      });
    });

    group('SamplingFunction:', () {
      test('should call the function with context', () {
        SamplingContext? capturedContext;

        final sampling = SamplingFunction((context) {
          capturedContext = context;
          return 1.0;
        });

        final meta = Meta(
          app: App(name: 'TestApp', environment: 'test'),
          user: const FaroUser(id: 'user-123'),
        );
        final context = SamplingContext(meta: meta);

        sampling.resolve(context);

        expect(capturedContext, isNotNull);
        expect(capturedContext!.meta.app?.name, equals('TestApp'));
        expect(capturedContext!.meta.user?.id, equals('user-123'));
      });

      test('can return different rates based on environment', () {
        final sampling = SamplingFunction((context) {
          if (context.meta.app?.environment == 'production') {
            return 0.1;
          }
          return 1.0;
        });

        // Production context
        final prodMeta = Meta(
          app: App(name: 'TestApp', environment: 'production'),
        );
        final prodContext = SamplingContext(meta: prodMeta);
        expect(sampling.resolve(prodContext), equals(0.1));

        // Development context
        final devMeta = Meta(
          app: App(name: 'TestApp', environment: 'development'),
        );
        final devContext = SamplingContext(meta: devMeta);
        expect(sampling.resolve(devContext), equals(1.0));
      });

      test('can return different rates based on user attributes', () {
        final sampling = SamplingFunction((context) {
          if (context.meta.user?.attributes?['role'] == 'beta') {
            return 1.0; // Sample all beta users
          }
          return 0.1; // Sample 10% of others
        });

        // Beta user
        final betaMeta = Meta(
          user: const FaroUser(
            id: 'user-123',
            attributes: {'role': 'beta'},
          ),
        );
        final betaContext = SamplingContext(meta: betaMeta);
        expect(sampling.resolve(betaContext), equals(1.0));

        // Regular user
        final regularMeta = Meta(
          user: const FaroUser(
            id: 'user-456',
            attributes: {'role': 'standard'},
          ),
        );
        final regularContext = SamplingContext(meta: regularMeta);
        expect(sampling.resolve(regularContext), equals(0.1));
      });

      test('should clamp return values above 1.0', () {
        final sampling = SamplingFunction((context) => 5.0);
        final context = SamplingContext(meta: Meta());

        expect(sampling.resolve(context), equals(1.0));
      });

      test('should clamp return values below 0.0', () {
        final sampling = SamplingFunction((context) => -1.0);
        final context = SamplingContext(meta: Meta());

        expect(sampling.resolve(context), equals(0.0));
      });
    });
  });
}
