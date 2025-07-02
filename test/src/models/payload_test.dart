import 'package:faro/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Payload:', () {
    test('should create an empty payload', () {
      final meta = Meta();
      final payload = Payload(meta);

      expect(payload.events, isEmpty);
      expect(payload.measurements, isEmpty);
      expect(payload.logs, isEmpty);
      expect(payload.exceptions, isEmpty);
      expect(payload.meta, equals(meta));
    });

    test('fromJson should properly filter out invalid measurements', () {
      final validMeasurement = {
        'values': {'cpu': 50.0},
        'type': 'device',
        'timestamp': '2023-01-01T12:00:00.000Z',
      };

      final invalidMeasurementMissingType = {
        'values': {'memory': 100.0},
        'timestamp': '2023-01-01T12:00:00.000Z',
      };

      final invalidMeasurementMissingTimestamp = {
        'values': {'disk': 75.0},
        'type': 'device',
      };

      final jsonData = {
        'measurements': [
          validMeasurement,
          invalidMeasurementMissingType,
          invalidMeasurementMissingTimestamp,
        ],
      };

      final payload = Payload.fromJson(jsonData);

      // Should only include the valid measurement
      expect(payload.measurements.length, equals(1));

      // Verify the valid measurement was properly deserialized
      final measurement = payload.measurements.first;
      expect(measurement.type, equals('device'));
      expect(measurement.values!['cpu'], equals(50.0));
      expect(measurement.timestamp, equals('2023-01-01T12:00:00.000Z'));
    });

    test('fromJson should properly filter out invalid exceptions', () {
      final validException = {
        'type': 'error_type',
        'value': 'Error message',
        'stacktrace': {'frames': <String>[]},
        'timestamp': '2023-01-01T12:00:00.000Z',
        'context': {'string': 'value', 'number': 42}, // Mixed type context
      };

      final invalidExceptionMissingType = {
        'value': 'Error message',
        'stacktrace': {'frames': <String>[]},
        'timestamp': '2023-01-01T12:00:00.000Z',
      };

      final invalidExceptionMissingValue = {
        'type': 'error_type',
        'stacktrace': {'frames': <String>[]},
        'timestamp': '2023-01-01T12:00:00.000Z',
      };

      final invalidExceptionMissingTimestamp = {
        'type': 'error_type',
        'value': 'Error message',
        'stacktrace': {'frames': <String>[]},
      };

      final jsonData = {
        'exceptions': [
          validException,
          invalidExceptionMissingType,
          invalidExceptionMissingValue,
          invalidExceptionMissingTimestamp,
        ],
      };

      final payload = Payload.fromJson(jsonData);

      // Should only include the valid exception
      expect(payload.exceptions.length, equals(1));

      // Verify the valid exception was properly deserialized
      final exception = payload.exceptions.first;
      expect(exception.type, equals('error_type'));
      expect(exception.value, equals('Error message'));
      expect(exception.timestamp, equals('2023-01-01T12:00:00.000Z'));

      // Verify context values were converted to strings
      expect(exception.context!['string'], equals('value'));
      expect(exception.context!['number'], equals('42'));
    });

    test('fromJson should properly handle empty data', () {
      final emptyJson = <String, dynamic>{};
      final payload = Payload.fromJson(emptyJson);

      expect(payload.events, isEmpty);
      expect(payload.measurements, isEmpty);
      expect(payload.logs, isEmpty);
      expect(payload.exceptions, isEmpty);
      expect(payload.meta, isNull);
    });

    test('toJson should create valid JSON', () {
      final meta = Meta();
      final payload = Payload(meta);

      payload.measurements.add(Measurement({'cpu': 50.0}, 'device'));

      final json = payload.toJson();

      expect(json.containsKey('measurements'), isTrue);
      expect(json['measurements'].length, equals(1));

      final measurementJson = json['measurements'][0];
      expect(measurementJson['type'], equals('device'));
      expect(measurementJson['values']['cpu'], equals(50.0));
    });
  });
}
