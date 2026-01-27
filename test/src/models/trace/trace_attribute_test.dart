// ignore_for_file: prefer_int_literals

import 'package:faro/src/models/trace/trace_attribute.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TraceAttributeValue:', () {
    group('string values:', () {
      test('should create with string value', () {
        final value = TraceAttributeValue.string('hello');

        expect(value.stringValue, 'hello');
        expect(value.intValue, isNull);
        expect(value.doubleValue, isNull);
        expect(value.boolValue, isNull);
      });

      test('should serialize string value to JSON', () {
        final value = TraceAttributeValue.string('hello');

        final json = value.toJson();

        expect(json, {'stringValue': 'hello'});
        expect(json.containsKey('intValue'), isFalse);
        expect(json.containsKey('doubleValue'), isFalse);
        expect(json.containsKey('boolValue'), isFalse);
      });

      test('should deserialize string value from JSON', () {
        final json = {'stringValue': 'hello'};

        final value = TraceAttributeValue.fromJson(json);

        expect(value.stringValue, 'hello');
        expect(value.intValue, isNull);
        expect(value.doubleValue, isNull);
        expect(value.boolValue, isNull);
      });
    });

    group('int values:', () {
      test('should create with int value', () {
        final value = TraceAttributeValue.int(42);

        expect(value.intValue, 42);
        expect(value.stringValue, isNull);
        expect(value.doubleValue, isNull);
        expect(value.boolValue, isNull);
      });

      test('should serialize int value to JSON', () {
        final value = TraceAttributeValue.int(42);

        final json = value.toJson();

        expect(json, {'intValue': 42});
        expect(json.containsKey('stringValue'), isFalse);
        expect(json.containsKey('doubleValue'), isFalse);
        expect(json.containsKey('boolValue'), isFalse);
      });

      test('should deserialize int value from JSON', () {
        final json = {'intValue': 42};

        final value = TraceAttributeValue.fromJson(json);

        expect(value.intValue, 42);
        expect(value.stringValue, isNull);
        expect(value.doubleValue, isNull);
        expect(value.boolValue, isNull);
      });

      test('should handle negative int values', () {
        final value = TraceAttributeValue.int(-100);

        expect(value.intValue, -100);
        expect(value.toJson(), {'intValue': -100});
      });

      test('should handle zero int value', () {
        final value = TraceAttributeValue.int(0);

        expect(value.intValue, 0);
        expect(value.toJson(), {'intValue': 0});
      });
    });

    group('double values:', () {
      test('should create with double value', () {
        final value = TraceAttributeValue.double(3.14);

        expect(value.doubleValue, 3.14);
        expect(value.stringValue, isNull);
        expect(value.intValue, isNull);
        expect(value.boolValue, isNull);
      });

      test('should serialize double value to JSON', () {
        final value = TraceAttributeValue.double(3.14);

        final json = value.toJson();

        expect(json, {'doubleValue': 3.14});
        expect(json.containsKey('stringValue'), isFalse);
        expect(json.containsKey('intValue'), isFalse);
        expect(json.containsKey('boolValue'), isFalse);
      });

      test('should deserialize double value from JSON', () {
        final json = {'doubleValue': 3.14};

        final value = TraceAttributeValue.fromJson(json);

        expect(value.doubleValue, 3.14);
        expect(value.stringValue, isNull);
        expect(value.intValue, isNull);
        expect(value.boolValue, isNull);
      });

      test('should handle negative double values', () {
        final value = TraceAttributeValue.double(-99.99);

        expect(value.doubleValue, -99.99);
        expect(value.toJson(), {'doubleValue': -99.99});
      });

      test('should handle zero double value', () {
        final value = TraceAttributeValue.double(0.0);

        expect(value.doubleValue, 0.0);
        expect(value.toJson(), {'doubleValue': 0.0});
      });
    });

    group('bool values:', () {
      test('should create with true value', () {
        final value = TraceAttributeValue.bool(true);

        expect(value.boolValue, true);
        expect(value.stringValue, isNull);
        expect(value.intValue, isNull);
        expect(value.doubleValue, isNull);
      });

      test('should create with false value', () {
        final value = TraceAttributeValue.bool(false);

        expect(value.boolValue, false);
        expect(value.stringValue, isNull);
        expect(value.intValue, isNull);
        expect(value.doubleValue, isNull);
      });

      test('should serialize bool value to JSON', () {
        final value = TraceAttributeValue.bool(true);

        final json = value.toJson();

        expect(json, {'boolValue': true});
        expect(json.containsKey('stringValue'), isFalse);
        expect(json.containsKey('intValue'), isFalse);
        expect(json.containsKey('doubleValue'), isFalse);
      });

      test('should deserialize bool value from JSON', () {
        final json = {'boolValue': false};

        final value = TraceAttributeValue.fromJson(json);

        expect(value.boolValue, false);
        expect(value.stringValue, isNull);
        expect(value.intValue, isNull);
        expect(value.doubleValue, isNull);
      });
    });

    group('fromDynamic factory:', () {
      test('should create string value from String', () {
        final value = TraceAttributeValue.fromDynamic('hello');

        expect(value.stringValue, 'hello');
      });

      test('should create int value from int', () {
        final value = TraceAttributeValue.fromDynamic(42);

        expect(value.intValue, 42);
      });

      test('should create double value from double', () {
        final value = TraceAttributeValue.fromDynamic(3.14);

        expect(value.doubleValue, 3.14);
      });

      test('should create bool value from bool', () {
        final value = TraceAttributeValue.fromDynamic(true);

        expect(value.boolValue, true);
      });

      test('should convert unknown types to string', () {
        final value = TraceAttributeValue.fromDynamic(['list', 'items']);

        expect(value.stringValue, '[list, items]');
      });

      test('should convert null to string "null"', () {
        final value = TraceAttributeValue.fromDynamic(null);

        expect(value.stringValue, 'null');
      });
    });

    group('backward compatibility:', () {
      test('should support legacy constructor with required stringValue', () {
        // This ensures backward compatibility with existing code
        final value = TraceAttributeValue(stringValue: 'legacy');

        expect(value.stringValue, 'legacy');
      });

      test('should round-trip string value through JSON', () {
        final original = TraceAttributeValue.string('test');
        final json = original.toJson();
        final restored = TraceAttributeValue.fromJson(json);

        expect(restored.stringValue, original.stringValue);
      });

      test('should round-trip int value through JSON', () {
        final original = TraceAttributeValue.int(42);
        final json = original.toJson();
        final restored = TraceAttributeValue.fromJson(json);

        expect(restored.intValue, original.intValue);
      });

      test('should round-trip double value through JSON', () {
        final original = TraceAttributeValue.double(3.14);
        final json = original.toJson();
        final restored = TraceAttributeValue.fromJson(json);

        expect(restored.doubleValue, original.doubleValue);
      });

      test('should round-trip bool value through JSON', () {
        final original = TraceAttributeValue.bool(true);
        final json = original.toJson();
        final restored = TraceAttributeValue.fromJson(json);

        expect(restored.boolValue, original.boolValue);
      });
    });
  });

  group('TraceAttribute:', () {
    test('should create with key and typed value', () {
      final attribute = TraceAttribute(
        key: 'count',
        value: TraceAttributeValue.int(42),
      );

      final json = attribute.toJson();

      expect(json['key'], 'count');
      expect(json['value'], {'intValue': 42});
    });

    test('should serialize string attribute to JSON', () {
      final attribute = TraceAttribute(
        key: 'name',
        value: TraceAttributeValue.string('test'),
      );

      final json = attribute.toJson();

      expect(json, {
        'key': 'name',
        'value': {'stringValue': 'test'},
      });
    });

    test('should serialize int attribute to JSON', () {
      final attribute = TraceAttribute(
        key: 'count',
        value: TraceAttributeValue.int(100),
      );

      final json = attribute.toJson();

      expect(json, {
        'key': 'count',
        'value': {'intValue': 100},
      });
    });

    test('should serialize double attribute to JSON', () {
      final attribute = TraceAttribute(
        key: 'duration',
        value: TraceAttributeValue.double(1.5),
      );

      final json = attribute.toJson();

      expect(json, {
        'key': 'duration',
        'value': {'doubleValue': 1.5},
      });
    });

    test('should serialize bool attribute to JSON', () {
      final attribute = TraceAttribute(
        key: 'enabled',
        value: TraceAttributeValue.bool(true),
      );

      final json = attribute.toJson();

      expect(json, {
        'key': 'enabled',
        'value': {'boolValue': true},
      });
    });

    test('should deserialize from JSON with int value', () {
      final json = {
        'key': 'count',
        'value': {'intValue': 42},
      };

      final attribute = TraceAttribute.fromJson(json);
      final serialized = attribute.toJson();

      expect(serialized['key'], 'count');
      expect(serialized['value'], {'intValue': 42});
    });

    test('should round-trip through JSON', () {
      final original = TraceAttribute(
        key: 'score',
        value: TraceAttributeValue.double(99.5),
      );

      final json = original.toJson();
      final restored = TraceAttribute.fromJson(json);
      final restoredJson = restored.toJson();

      expect(restoredJson, json);
    });
  });
}
