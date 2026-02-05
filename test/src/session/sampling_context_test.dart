import 'package:faro/src/models/app.dart';
import 'package:faro/src/models/faro_user.dart';
import 'package:faro/src/models/meta.dart';
import 'package:faro/src/models/sdk.dart';
import 'package:faro/src/models/session.dart';
import 'package:faro/src/models/view_meta.dart';
import 'package:faro/src/session/sampling_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SamplingContext:', () {
    test('should wrap Meta object', () {
      final meta = Meta(
        session: Session('test-session-id', attributes: {'team': 'mobile'}),
        app: App(
          name: 'TestApp',
          environment: 'production',
          version: '1.0.0',
        ),
        user: const FaroUser(
          id: 'user-123',
          attributes: {'role': 'beta'},
        ),
        sdk: Sdk('faro-flutter-sdk', '1.0.0', []),
        view: ViewMeta('home'),
      );

      final context = SamplingContext(meta: meta);

      expect(context.meta, equals(meta));
    });

    test('should provide access to session attributes', () {
      final meta = Meta(
        session: Session('test-session-id', attributes: {'team': 'mobile'}),
      );

      final context = SamplingContext(meta: meta);

      expect(context.meta.session?.attributes?['team'], equals('mobile'));
    });

    test('should provide access to user attributes', () {
      final meta = Meta(
        user: const FaroUser(
          id: 'user-123',
          attributes: {'role': 'beta', 'plan': 'premium'},
        ),
      );

      final context = SamplingContext(meta: meta);

      expect(context.meta.user?.attributes?['role'], equals('beta'));
      expect(context.meta.user?.attributes?['plan'], equals('premium'));
    });

    test('should provide access to app environment', () {
      final meta = Meta(
        app: App(
          name: 'TestApp',
          environment: 'production',
          version: '1.0.0',
        ),
      );

      final context = SamplingContext(meta: meta);

      expect(context.meta.app?.environment, equals('production'));
      expect(context.meta.app?.name, equals('TestApp'));
      expect(context.meta.app?.version, equals('1.0.0'));
    });

    test('should handle null meta fields gracefully', () {
      final meta = Meta();

      final context = SamplingContext(meta: meta);

      expect(context.meta.session, isNull);
      expect(context.meta.user, isNull);
      expect(context.meta.app, isNull);
    });
  });
}
