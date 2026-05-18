import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/models/trace/trace_resource.dart';
import 'package:faro/src/tracing/extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OTel Attribute Types', () {
    test('Attributes.getX() should preserve typed values', () {
      final attributes = otel.OTelAPI.attributes([
        otel.OTelAPI.attributeString('string_attr', 'hello'),
        otel.OTelAPI.attributeInt('int_attr', 42),
        otel.OTelAPI.attributeDouble('double_attr', 3.14),
        otel.OTelAPI.attributeBool('bool_attr', true),
      ]);

      final stringVal = attributes.getString('string_attr');
      final intVal = attributes.getInt('int_attr');
      final doubleVal = attributes.getDouble('double_attr');
      final boolVal = attributes.getBool('bool_attr');

      expect(stringVal, isA<String>());
      expect(intVal, isA<int>());
      expect(doubleVal, isA<double>());
      expect(boolVal, isA<bool>());

      expect(stringVal, equals('hello'));
      expect(intVal, equals(42));
      expect(doubleVal, equals(3.14));
      expect(boolVal, equals(true));
    });

    test('toTraceAttributes extension should preserve typed values', () {
      final attributes = otel.OTelAPI.attributes([
        otel.OTelAPI.attributeString('string_attr', 'hello'),
        otel.OTelAPI.attributeInt('int_attr', 42),
        otel.OTelAPI.attributeDouble('double_attr', 3.14),
        otel.OTelAPI.attributeBool('bool_attr', true),
      ]);

      final traceAttributes = attributes.toTraceAttributes();

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

      expect(stringAttr.toJson()['value'], equals({'stringValue': 'hello'}));
      expect(intAttr.toJson()['value'], equals({'intValue': 42}));
      expect(doubleAttr.toJson()['value'], equals({'doubleValue': 3.14}));
      expect(boolAttr.toJson()['value'], equals({'boolValue': true}));
    });

    test('Full OTLP JSON structure verification', () {
      final attributes = otel.OTelAPI.attributes([
        otel.OTelAPI.attributeString('team', 'mobile'),
        otel.OTelAPI.attributeInt('test_int', 42),
        otel.OTelAPI.attributeDouble('test_double', 3.14),
        otel.OTelAPI.attributeBool('test_bool', true),
      ]);

      final traceResource = TraceResource(
        attributes: attributes.toTraceAttributes(),
      );

      final json = traceResource.toJson();

      final attrList = json['attributes'] as List;

      final testIntAttr = attrList.firstWhere((a) => a['key'] == 'test_int');
      expect(testIntAttr['value']['intValue'], equals(42));
      expect(testIntAttr['value'].containsKey('stringValue'), isFalse);

      final testBoolAttr = attrList.firstWhere((a) => a['key'] == 'test_bool');
      expect(testBoolAttr['value']['boolValue'], equals(true));
      expect(testBoolAttr['value'].containsKey('stringValue'), isFalse);

      final testDoubleAttr = attrList.firstWhere(
        (a) => a['key'] == 'test_double',
      );
      expect(testDoubleAttr['value']['doubleValue'], equals(3.14));
      expect(testDoubleAttr['value'].containsKey('stringValue'), isFalse);
    });
  });
}
