// ignore_for_file: lines_longer_than_80_chars

import 'package:faro/src/util/timestamp_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimestampExtension:', () {
    test(
        'converts valid Unix epoch timestamp in milliseconds to ISO 8601 string',
        () {
      const timestamp = '1749080960296';
      final result = timestamp.toHumanReadableTimestamp();
      expect(result, '2025-06-04T23:49:20.296Z');
    });

    test('converts another valid timestamp correctly', () {
      const timestamp = '1744879144096';
      final result = timestamp.toHumanReadableTimestamp();
      expect(result, '2025-04-17T08:39:04.096Z');
    });

    test('handles "No timestamp" input', () {
      const timestamp = 'No timestamp';
      final result = timestamp.toHumanReadableTimestamp();
      expect(result, 'No readable timestamp');
    });

    test('handles invalid numeric string', () {
      const timestamp = 'invalid_number';
      final result = timestamp.toHumanReadableTimestamp();
      expect(result, 'Invalid timestamp format');
    });

    test('handles empty string', () {
      const timestamp = '';
      final result = timestamp.toHumanReadableTimestamp();
      expect(result, 'Invalid timestamp format');
    });

    test('handles very large timestamp', () {
      const timestamp = '999999999999999999';
      final result = timestamp.toHumanReadableTimestamp();
      expect(result, 'Invalid timestamp format');
    });

    test('handles negative timestamp', () {
      const timestamp = '-1749080960296';
      final result = timestamp.toHumanReadableTimestamp();
      expect(result, '1914-07-30T00:10:39.704Z');
    });

    test('handles zero timestamp', () {
      const timestamp = '0';
      final result = timestamp.toHumanReadableTimestamp();
      expect(result, '1970-01-01T00:00:00.000Z');
    });

    test('handles timestamp with decimal point', () {
      const timestamp = '1749080960296.5';
      final result = timestamp.toHumanReadableTimestamp();
      expect(result, 'Invalid timestamp format');
    });
  });
}
