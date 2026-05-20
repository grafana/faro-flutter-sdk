import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/tracing/extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IterableTraceAttributeX:', () {
    group('toTraceAttributes:', () {
      test('should preserve string attribute value', () {
        final attributes = [otel.OTelAPI.attributeString('name', 'test')];

        final result = attributes.toTraceAttributes();

        expect(result.length, 1);
        final json = result.first.toJson();
        expect(json['key'], 'name');
        expect(json['value'], {'stringValue': 'test'});
      });

      test('should preserve int attribute value', () {
        final attributes = [otel.OTelAPI.attributeInt('count', 42)];

        final result = attributes.toTraceAttributes();

        expect(result.length, 1);
        final json = result.first.toJson();
        expect(json['key'], 'count');
        expect(json['value'], {'intValue': 42});
      });

      test('should preserve double attribute value', () {
        final attributes = [otel.OTelAPI.attributeDouble('duration', 3.14)];

        final result = attributes.toTraceAttributes();

        expect(result.length, 1);
        final json = result.first.toJson();
        expect(json['key'], 'duration');
        expect(json['value'], {'doubleValue': 3.14});
      });

      test('should preserve bool attribute value', () {
        final attributes = [otel.OTelAPI.attributeBool('enabled', true)];

        final result = attributes.toTraceAttributes();

        expect(result.length, 1);
        final json = result.first.toJson();
        expect(json['key'], 'enabled');
        expect(json['value'], {'boolValue': true});
      });

      test('should preserve mixed attribute types', () {
        final attributes = <otel.Attribute<Object>>[
          otel.OTelAPI.attributeString('name', 'test'),
          otel.OTelAPI.attributeInt('count', 100),
          otel.OTelAPI.attributeDouble('score', 99.5),
          otel.OTelAPI.attributeBool('active', false),
        ];

        final result = attributes.toTraceAttributes();

        expect(result.length, 4);

        final nameJson = result[0].toJson();
        expect(nameJson['key'], 'name');
        expect(nameJson['value'], {'stringValue': 'test'});

        final countJson = result[1].toJson();
        expect(countJson['key'], 'count');
        expect(countJson['value'], {'intValue': 100});

        final scoreJson = result[2].toJson();
        expect(scoreJson['key'], 'score');
        expect(scoreJson['value'], {'doubleValue': 99.5});

        final activeJson = result[3].toJson();
        expect(activeJson['key'], 'active');
        expect(activeJson['value'], {'boolValue': false});
      });

      test('should handle negative int values', () {
        final attributes = [otel.OTelAPI.attributeInt('offset', -10)];

        final result = attributes.toTraceAttributes();

        final json = result.first.toJson();
        expect(json['value'], {'intValue': -10});
      });

      test('should handle zero values', () {
        final attributes = <otel.Attribute<Object>>[
          otel.OTelAPI.attributeInt('zero_int', 0),
          // ignore: prefer_int_literals
          otel.OTelAPI.attributeDouble('zero_double', 0.0),
        ];

        final result = attributes.toTraceAttributes();

        expect(result[0].toJson()['value'], {'intValue': 0});
        expect(result[1].toJson()['value'], {'doubleValue': 0.0});
      });

      test('should handle empty list', () {
        final attributes = <otel.Attribute<Object>>[];

        final result = attributes.toTraceAttributes();

        expect(result, isEmpty);
      });

      test('should convert list values to string (unsupported in OTLP)', () {
        // List values are not directly supported in our TraceAttributeValue
        // They should be converted to string representation
        final attributes = <otel.Attribute<Object>>[
          otel.OTelAPI.attributeStringList('tags', ['a', 'b', 'c']),
        ];

        final result = attributes.toTraceAttributes();

        final json = result.first.toJson();
        expect(json['key'], 'tags');
        // List values get stringified since we don't support arrays
        expect(json['value']['stringValue'], isNotNull);
      });
    });
  });
}
