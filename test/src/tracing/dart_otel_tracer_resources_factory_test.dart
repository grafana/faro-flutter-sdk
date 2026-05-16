// ignore_for_file: lines_longer_than_80_chars

import 'dart:io';

import 'package:faro/src/faro.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/tracing/dart_otel_tracer_resources_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMeta extends Mock implements Meta {}

class MockApp extends Mock implements App {}

class MockSession extends Mock implements Session {}

/// Helper function to read the version from pubspec.yaml
String _getPackageVersionFromPubspec() {
  final pubspecFile = File('pubspec.yaml');
  final pubspecContent = pubspecFile.readAsStringSync();
  final versionMatch = RegExp(
    r'^version:\s*(.+)$',
    multiLine: true,
  ).firstMatch(pubspecContent);

  if (versionMatch == null) {
    throw Exception('Could not find version in pubspec.yaml');
  }

  return versionMatch.group(1)!.trim();
}

void main() {
  group('DartOtelTracerResourcesFactory:', () {
    late DartOtelTracerResourcesFactory factory;
    late MockMeta mockMeta;
    late MockApp mockApp;
    late MockSession mockSession;

    setUp(() {
      factory = DartOtelTracerResourcesFactory();
      mockMeta = MockMeta();
      mockApp = MockApp();
      mockSession = MockSession();

      Faro().meta = mockMeta;
    });

    group('getTracerResourceAttributes', () {
      test(
        'should create resource with app information when all app data is present',
        () {
          when(() => mockMeta.app).thenReturn(mockApp);
          when(() => mockMeta.session).thenReturn(null);
          when(() => mockApp.name).thenReturn('TestApp');
          when(() => mockApp.environment).thenReturn('production');
          when(() => mockApp.version).thenReturn('1.2.3');
          when(() => mockApp.namespace).thenReturn('test.namespace');

          final attrs = factory.getTracerResourceAttributes();

          expect(attrs, isNotEmpty);
          expect(attrs['service.name'], equals('TestApp'));
          expect(attrs['deployment.environment'], equals('production'));
          expect(attrs['service.version'], equals('1.2.3'));
          expect(attrs['service.namespace'], equals('test.namespace'));
        },
      );

      test('should use default values when app data is null', () {
        when(() => mockMeta.app).thenReturn(null);
        when(() => mockMeta.session).thenReturn(null);

        final attrs = factory.getTracerResourceAttributes();

        expect(attrs['service.name'], equals('unknown'));
        expect(attrs['deployment.environment'], equals('unknown'));
        expect(attrs['service.version'], equals('unknown'));
        expect(attrs['service.namespace'], equals('flutter_app'));
      });

      test('should use default values when individual app fields are null', () {
        when(() => mockMeta.app).thenReturn(mockApp);
        when(() => mockMeta.session).thenReturn(null);
        when(() => mockApp.name).thenReturn(null);
        when(() => mockApp.environment).thenReturn(null);
        when(() => mockApp.version).thenReturn(null);
        when(() => mockApp.namespace).thenReturn(null);

        final attrs = factory.getTracerResourceAttributes();

        expect(attrs['service.name'], equals('unknown'));
        expect(attrs['deployment.environment'], equals('unknown'));
        expect(attrs['service.version'], equals('unknown'));
        expect(attrs['service.namespace'], equals('flutter_app'));
      });

      test('should include SDK telemetry attributes', () {
        when(() => mockMeta.app).thenReturn(null);
        when(() => mockMeta.session).thenReturn(null);

        final attrs = factory.getTracerResourceAttributes();

        expect(attrs['telemetry.sdk.name'], equals('faro-mobile-flutter'));
        expect(attrs['telemetry.sdk.language'], equals('dart'));
        expect(
          attrs['telemetry.sdk.version'],
          equals(_getPackageVersionFromPubspec()),
        );
        expect(attrs['telemetry.sdk.platform'], equals('flutter'));
      });

      test('should include session attributes when session exists', () {
        when(() => mockMeta.app).thenReturn(null);
        when(() => mockMeta.session).thenReturn(mockSession);
        when(() => mockSession.attributes).thenReturn({
          'session_id': '12345',
          'user_id': 'user123',
          'custom_attr': 'value',
        });

        final attrs = factory.getTracerResourceAttributes();

        expect(attrs['session_id'], equals('12345'));
        expect(attrs['user_id'], equals('user123'));
        expect(attrs['custom_attr'], equals('value'));
      });

      test('should handle empty session attributes', () {
        when(() => mockMeta.app).thenReturn(null);
        when(() => mockMeta.session).thenReturn(mockSession);
        when(() => mockSession.attributes).thenReturn(<String, dynamic>{});

        final attrs = factory.getTracerResourceAttributes();

        expect(attrs, isNotEmpty);
      });

      test('should preserve typed session attributes', () {
        when(() => mockMeta.app).thenReturn(null);
        when(() => mockMeta.session).thenReturn(mockSession);
        when(() => mockSession.attributes).thenReturn({
          'string_value': 'hello',
          'int_value': 42,
          'double_value': 3.14,
          'bool_value': true,
          'null_value': null,
          'object': {'nested': 'value'},
        });

        final attrs = factory.getTracerResourceAttributes();

        expect(attrs['string_value'], equals('hello'));
        expect(attrs['string_value'], isA<String>());

        expect(attrs['int_value'], equals(42));
        expect(attrs['int_value'], isA<int>());

        expect(attrs['double_value'], equals(3.14));
        expect(attrs['double_value'], isA<double>());

        expect(attrs['bool_value'], equals(true));
        expect(attrs['bool_value'], isA<bool>());

        // Null is skipped entirely.
        expect(attrs.containsKey('null_value'), isFalse);

        // Non-primitive falls back to string representation.
        expect(attrs['object'], equals('{nested: value}'));
      });

      test('should handle null session', () {
        when(() => mockMeta.app).thenReturn(null);
        when(() => mockMeta.session).thenReturn(null);

        final attrs = factory.getTracerResourceAttributes();

        expect(attrs, isNotEmpty);
        expect(attrs.containsKey('session_id'), isFalse);
      });
    });
  });
}
