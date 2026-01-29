import 'package:faro/src/models/trace/trace_resource.dart';
import 'package:faro/src/tracing/extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentelemetry/api.dart' as otel_api;
import 'package:opentelemetry/sdk.dart' as otel_sdk;

void main() {
  group('OTel Attribute Types', () {
    test('Resource.attributes.get() should preserve typed values', () {
      // Create typed attributes
      final attributes = [
        otel_api.Attribute.fromString('string_attr', 'hello'),
        otel_api.Attribute.fromInt('int_attr', 42),
        otel_api.Attribute.fromDouble('double_attr', 3.14),
        otel_api.Attribute.fromBoolean('bool_attr', true),
      ];

      // Create Resource with attributes
      final resource = otel_sdk.Resource(attributes);

      // Check what types are returned by get()
      final stringVal = resource.attributes.get('string_attr');
      final intVal = resource.attributes.get('int_attr');
      final doubleVal = resource.attributes.get('double_attr');
      final boolVal = resource.attributes.get('bool_attr');

      // Verify types
      expect(stringVal, isA<String>());
      expect(intVal, isA<int>());
      expect(doubleVal, isA<double>());
      expect(boolVal, isA<bool>());

      // Verify values
      expect(stringVal, equals('hello'));
      expect(intVal, equals(42));
      expect(doubleVal, equals(3.14));
      expect(boolVal, equals(true));
    });

    test('toTraceAttributes extension should preserve typed values', () {
      // Create typed attributes
      final attributes = [
        otel_api.Attribute.fromString('string_attr', 'hello'),
        otel_api.Attribute.fromInt('int_attr', 42),
        otel_api.Attribute.fromDouble('double_attr', 3.14),
        otel_api.Attribute.fromBoolean('bool_attr', true),
      ];

      // Create Resource with attributes
      final resource = otel_sdk.Resource(attributes);

      // Convert to TraceAttributes using our extension
      final traceAttributes = resource.attributes.toTraceAttributes();

      // Find each attribute and verify
      final stringAttr = traceAttributes.firstWhere(
        (a) => a.toJson()['key'] == 'string_attr',
      );
      final intAttr = traceAttributes.firstWhere(
        (a) => a.toJson()['key'] == 'int_attr',
      );
      final doubleAttr = traceAttributes.firstWhere(
        (a) => a.toJson()['key'] == 'double_attr',
      );
      final boolAttr = traceAttributes.firstWhere(
        (a) => a.toJson()['key'] == 'bool_attr',
      );

      // Verify JSON serialization uses typed fields
      expect(stringAttr.toJson()['value'], equals({'stringValue': 'hello'}));
      expect(intAttr.toJson()['value'], equals({'intValue': 42}));
      expect(doubleAttr.toJson()['value'], equals({'doubleValue': 3.14}));
      expect(boolAttr.toJson()['value'], equals({'boolValue': true}));
    });

    test('Full OTLP JSON structure verification', () {
      // Create typed attributes
      final attributes = [
        otel_api.Attribute.fromString('team', 'mobile'),
        otel_api.Attribute.fromInt('test_int', 42),
        otel_api.Attribute.fromDouble('test_double', 3.14),
        otel_api.Attribute.fromBoolean('test_bool', true),
      ];

      // Create Resource with attributes
      final resource = otel_sdk.Resource(attributes);

      // Convert to TraceResource, simulating what SpanRecord.getResource() does
      final traceResource = TraceResource(
        attributes: resource.attributes.toTraceAttributes(),
      );

      // Get the full JSON
      final json = traceResource.toJson();

      // Verify the structure matches OTLP spec
      final attrList = json['attributes'] as List;

      // Find test_int attribute
      final testIntAttr = attrList.firstWhere(
        (a) => a['key'] == 'test_int',
      );
      expect(testIntAttr['value']['intValue'], equals(42));
      expect(testIntAttr['value'].containsKey('stringValue'), isFalse);

      // Find test_bool attribute
      final testBoolAttr = attrList.firstWhere(
        (a) => a['key'] == 'test_bool',
      );
      expect(testBoolAttr['value']['boolValue'], equals(true));
      expect(testBoolAttr['value'].containsKey('stringValue'), isFalse);

      // Find test_double attribute
      final testDoubleAttr = attrList.firstWhere(
        (a) => a['key'] == 'test_double',
      );
      expect(testDoubleAttr['value']['doubleValue'], equals(3.14));
      expect(testDoubleAttr['value'].containsKey('stringValue'), isFalse);
    });
  });
}
