// ignore_for_file: lines_longer_than_80_chars

import 'dart:io';

import 'package:faro/faro_sdk.dart';
import 'package:faro/src/tracing/dart_otel_tracer_resources_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:opentelemetry/api.dart' as otel_api;

class MockMeta extends Mock implements Meta {}

class MockApp extends Mock implements App {}

class MockSession extends Mock implements Session {}

/// Helper function to read the version from pubspec.yaml
String _getPackageVersionFromPubspec() {
  final pubspecFile = File('pubspec.yaml');
  final pubspecContent = pubspecFile.readAsStringSync();
  final versionMatch =
      RegExp(r'^version:\s*(.+)$', multiLine: true).firstMatch(pubspecContent);

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

      // Set up the Faro singleton with mocked meta
      Faro().meta = mockMeta;
    });

    tearDown(() {
      // No need to reset Faro.instance - tests use the same instance
    });

    group('getTracerResource', () {
      test(
          'should create resource with app information when all app data is present',
          () {
        // Arrange
        when(() => mockMeta.app).thenReturn(mockApp);
        when(() => mockMeta.session).thenReturn(null);
        when(() => mockApp.name).thenReturn('TestApp');
        when(() => mockApp.environment).thenReturn('production');
        when(() => mockApp.version).thenReturn('1.2.3');
        when(() => mockApp.namespace).thenReturn('test.namespace');

        // Act
        final resource = factory.getTracerResource();

        // Assert
        expect(resource, isNotNull);
        expect(resource.attributes.keys, isNotEmpty);

        expect(
            resource.attributes
                .get(otel_api.ResourceAttributes.serviceName)
                .toString(),
            equals('TestApp'));
        expect(
            resource.attributes
                .get(otel_api.ResourceAttributes.deploymentEnvironment)
                .toString(),
            equals('production'));
        expect(
            resource.attributes
                .get(otel_api.ResourceAttributes.serviceVersion)
                .toString(),
            equals('1.2.3'));
        expect(
            resource.attributes
                .get(otel_api.ResourceAttributes.serviceNamespace)
                .toString(),
            equals('test.namespace'));
      });

      test('should use default values when app data is null', () {
        // Arrange
        when(() => mockMeta.app).thenReturn(null);
        when(() => mockMeta.session).thenReturn(null);

        // Act
        final resource = factory.getTracerResource();

        // Assert
        expect(
            resource.attributes
                .get(otel_api.ResourceAttributes.serviceName)
                .toString(),
            equals('unknown'));
        expect(
            resource.attributes
                .get(otel_api.ResourceAttributes.deploymentEnvironment)
                .toString(),
            equals('unknown'));
        expect(
            resource.attributes
                .get(otel_api.ResourceAttributes.serviceVersion)
                .toString(),
            equals('unknown'));
        expect(
            resource.attributes
                .get(otel_api.ResourceAttributes.serviceNamespace)
                .toString(),
            equals('flutter_app'));
      });

      test('should use default values when individual app fields are null', () {
        // Arrange
        when(() => mockMeta.app).thenReturn(mockApp);
        when(() => mockMeta.session).thenReturn(null);
        when(() => mockApp.name).thenReturn(null);
        when(() => mockApp.environment).thenReturn(null);
        when(() => mockApp.version).thenReturn(null);
        when(() => mockApp.namespace).thenReturn(null);

        // Act
        final resource = factory.getTracerResource();

        // Assert
        expect(
            resource.attributes
                .get(otel_api.ResourceAttributes.serviceName)
                .toString(),
            equals('unknown'));
        expect(
            resource.attributes
                .get(otel_api.ResourceAttributes.deploymentEnvironment)
                .toString(),
            equals('unknown'));
        expect(
            resource.attributes
                .get(otel_api.ResourceAttributes.serviceVersion)
                .toString(),
            equals('unknown'));
        expect(
            resource.attributes
                .get(otel_api.ResourceAttributes.serviceNamespace)
                .toString(),
            equals('flutter_app'));
      });

      test('should include SDK telemetry attributes', () {
        // Arrange
        when(() => mockMeta.app).thenReturn(null);
        when(() => mockMeta.session).thenReturn(null);

        // Act
        final resource = factory.getTracerResource();

        // Assert
        expect(resource.attributes.get('telemetry.sdk.name').toString(),
            equals('faro-flutter-sdk'));
        expect(resource.attributes.get('telemetry.sdk.language').toString(),
            equals('dart'));
        expect(resource.attributes.get('telemetry.sdk.version').toString(),
            equals(_getPackageVersionFromPubspec()));
        expect(resource.attributes.get('telemetry.sdk.platform').toString(),
            equals('flutter'));
      });

      test('should include session attributes when session exists', () {
        // Arrange
        when(() => mockMeta.app).thenReturn(null);
        when(() => mockMeta.session).thenReturn(mockSession);
        when(() => mockSession.attributes).thenReturn({
          'session_id': '12345',
          'user_id': 'user123',
          'custom_attr': 'value'
        });

        // Act
        final resource = factory.getTracerResource();

        // Assert
        expect(
            resource.attributes.get('session_id').toString(), equals('12345'));
        expect(
            resource.attributes.get('user_id').toString(), equals('user123'));
        expect(
            resource.attributes.get('custom_attr').toString(), equals('value'));
      });

      test('should handle empty session attributes', () {
        // Arrange
        when(() => mockMeta.app).thenReturn(null);
        when(() => mockMeta.session).thenReturn(mockSession);
        when(() => mockSession.attributes).thenReturn(<String, dynamic>{});

        // Act
        final resource = factory.getTracerResource();

        // Assert - should not throw and should still include other attributes
        expect(resource, isNotNull);
        expect(resource.attributes.keys, isNotEmpty);
      });

      test('should handle session attributes with dynamic values', () {
        // Arrange
        when(() => mockMeta.app).thenReturn(null);
        when(() => mockMeta.session).thenReturn(mockSession);
        when(() => mockSession.attributes).thenReturn({
          'number': 42,
          'boolean': true,
          'null_value': null,
          'object': {'nested': 'value'},
        });

        // Act
        final resource = factory.getTracerResource();

        // Assert
        expect(resource.attributes.get('number').toString(), equals('42'));
        expect(resource.attributes.get('boolean').toString(), equals('true'));
        expect(resource.attributes.get('null_value').toString(), equals(''));
        expect(resource.attributes.get('object').toString(),
            equals('{nested: value}'));
      });

      test('should handle null session', () {
        // Arrange
        when(() => mockMeta.app).thenReturn(null);
        when(() => mockMeta.session).thenReturn(null);

        // Act
        final resource = factory.getTracerResource();

        // Assert - should not throw and should still include other attributes
        expect(resource, isNotNull);
        expect(resource.attributes.keys, isNotEmpty);
        // Should not have any session attributes
        expect(resource.attributes.get('session_id'), isNull);
      });
    });
  });
}
