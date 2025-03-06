import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:faro/src/models/measurement.dart';

void main() {
  group('Measurement:', () {
    test('should create a measurement with valid values', () {
      final measurement = Measurement(
        {'cpu': 50.0, 'memory': 100.0},
        'device',
      );

      expect(measurement.values, isNotNull);
      expect(measurement.values!['cpu'], 50.0);
      expect(measurement.values!['memory'], 100.0);
      expect(measurement.type, 'device');
      expect(measurement.timestamp, isNotNull);
    });

    test('should handle null values', () {
      final measurement = Measurement(
        null,
        'device',
      );

      expect(measurement.values, isNotNull);
      expect(measurement.values, <String, dynamic>{});
      expect(measurement.type, 'device');
      expect(measurement.timestamp, isNotNull);
    });

    test('should ignore infinity and NaN values', () {
      final measurement = Measurement(
        {
          'infinity': double.infinity,
          'negativeInfinity': double.negativeInfinity,
          'nan': double.nan,
          'valid': 42.0,
        },
        'device',
      );

      expect(measurement.values, isNotNull);
      // Infinity, negative infinity, and NaN values should be ignored
      expect(measurement.values!.containsKey('infinity'), false);
      expect(measurement.values!.containsKey('negativeInfinity'), false);
      expect(measurement.values!.containsKey('nan'), false);
      // Valid values should be kept
      expect(measurement.values!['valid'], 42.0);
    });

    test('should handle very large finite double values correctly', () {
      final measurement = Measurement(
        {
          'largeValue': double.maxFinite,
          'smallValue': double.minPositive,
        },
        'device',
      );

      expect(measurement.values, isNotNull);
      expect(measurement.values!['largeValue'], double.maxFinite);
      expect(measurement.values!['smallValue'], double.minPositive);
    });

    test('should handle non-encodable objects that are not numeric types', () {
      // Create a custom class that will fail JSON encoding
      final measurement = Measurement(
        {
          'nonEncodableObject': _JsonUnencodableObject(),
          'regularInt': 42,
        },
        'device',
      );

      expect(measurement.values, isNotNull);
      expect(
          measurement.values!['nonEncodableObject'], 'JsonUnencodableObject');
      expect(measurement.values!['regularInt'], 42);
    });

    test('should convert non-encodable objects to string representation', () {
      // Create a class that cannot be JSON encoded
      final nonEncodable = _NonEncodable();
      final measurement = Measurement(
        {
          'nonEncodable': nonEncodable,
          'valid': 42.0,
        },
        'device',
      );

      expect(measurement.values, isNotNull);
      expect(measurement.values!['nonEncodable'], 'NonEncodable object');
      expect(measurement.values!['valid'], 42.0);
    });

    test('toJson output should be JSON encodable', () {
      final measurement = Measurement(
        {
          'infinity': double.infinity,
          'negativeInfinity': double.negativeInfinity,
          'nan': double.nan,
          'valid': 42.0,
        },
        'device',
      );

      final json = measurement.toJson();

      // This should not throw
      final encoded = jsonEncode(json);
      expect(encoded, isNotNull);

      // The problematic values should be excluded from the JSON
      expect(encoded.contains('"infinity"'), false);
      expect(encoded.contains('"negativeInfinity"'), false);
      expect(encoded.contains('"nan"'), false);

      // Valid values should be included
      expect(encoded.contains('"valid":42.0'), true);
    });

    test('fromJson should handle problematic values', () {
      final now = DateTime.now();
      final json = {
        'values': {
          'infinity': double.infinity,
          'negativeInfinity': double.negativeInfinity,
          'nan': double.nan,
          'valid': 42.0,
        },
        'type': 'device',
        'timestamp': now.toIso8601String(),
      };

      final measurement = Measurement.fromJson(json);

      expect(measurement.values, isNotNull);
      // Problematic values should be excluded
      expect(measurement.values!.containsKey('infinity'), false);
      expect(measurement.values!.containsKey('negativeInfinity'), false);
      expect(measurement.values!.containsKey('nan'), false);
      // Valid values should be kept
      expect(measurement.values!['valid'], 42.0);
      expect(measurement.type, 'device');
    });
  });
}

// Helper class for testing
class _NonEncodable {
  @override
  String toString() {
    return 'NonEncodable object';
  }
}

// Helper class that fails JSON encoding
class _JsonUnencodableObject {
  @override
  String toString() => 'JsonUnencodableObject';

  // This will make jsonEncode fail
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('This object cannot be encoded to JSON');
  }
}
