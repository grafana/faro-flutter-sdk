// ignore_for_file: avoid_redundant_argument_values

import 'package:faro/src/models/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Session', () {
    group('toJson', () {
      test('should preserve typed attribute values', () {
        // Arrange - create session with typed attributes
        final session = Session('test-session-id', attributes: {
          'string_attr': 'hello',
          'int_attr': 42,
          'double_attr': 3.14,
          'bool_attr': true,
        });

        // Act
        final json = session.toJson();

        // Assert - types should be preserved for internal use
        final attributes = json['attributes'] as Map<String, dynamic>;
        expect(attributes['string_attr'], equals('hello'));
        expect(attributes['int_attr'], equals(42));
        expect(attributes['double_attr'], equals(3.14));
        expect(attributes['bool_attr'], equals(true));
      });

      test('toFaroJson should stringify all attribute values for Faro protocol',
          () {
        // Arrange - create session with typed attributes
        final session = Session('test-session-id', attributes: {
          'string_attr': 'hello',
          'int_attr': 42,
          'double_attr': 3.14,
          'bool_attr': true,
          'null_attr': null,
        });

        // Act
        final json = session.toFaroJson();

        // Assert - all values should be strings
        final attributes = json['attributes'] as Map<String, dynamic>;
        expect(attributes['string_attr'], equals('hello'));
        expect(attributes['int_attr'], equals('42'));
        expect(attributes['double_attr'], equals('3.14'));
        expect(attributes['bool_attr'], equals('true'));
        expect(attributes['null_attr'], equals(''));
      });

      test('should include session id in JSON', () {
        final session = Session('my-session-id');
        final json = session.toJson();

        expect(json['id'], equals('my-session-id'));
      });

      test('should handle null attributes', () {
        final session = Session('test-id', attributes: null);
        final json = session.toJson();

        expect(json['attributes'], isNull);
      });

      test('should handle empty attributes', () {
        final session = Session('test-id', attributes: {});
        final json = session.toJson();

        expect(json['attributes'], isEmpty);
      });
    });

    group('fromJson', () {
      test('should parse session from JSON', () {
        final json = {
          'id': 'parsed-session-id',
          'attributes': {'key': 'value'},
        };

        final session = Session.fromJson(json);

        expect(session.id, equals('parsed-session-id'));
        expect(session.attributes, equals({'key': 'value'}));
      });

      test('should handle missing id', () {
        final json = <String, dynamic>{'attributes': <String, dynamic>{}};
        final session = Session.fromJson(json);

        expect(session.id, equals(''));
      });

      test('should handle missing attributes', () {
        final json = {'id': 'test-id'};
        final session = Session.fromJson(json);

        expect(session.attributes, equals({}));
      });
    });
  });
}
