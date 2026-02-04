// ignore_for_file: lines_longer_than_80_chars

import 'package:faro/src/models/log_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogLevel:', () {
    test('should have correct string values', () {
      expect(LogLevel.trace.value, 'trace');
      expect(LogLevel.debug.value, 'debug');
      expect(LogLevel.info.value, 'info');
      expect(LogLevel.log.value, 'log');
      expect(LogLevel.warn.value, 'warn');
      expect(LogLevel.error.value, 'error');
    });

    test('toString should return the string value', () {
      expect(LogLevel.warn.toString(), 'warn');
      expect(LogLevel.error.toString(), 'error');
    });

    test('fromString should convert string to LogLevel', () {
      expect(LogLevel.fromString('trace'), LogLevel.trace);
      expect(LogLevel.fromString('debug'), LogLevel.debug);
      expect(LogLevel.fromString('info'), LogLevel.info);
      expect(LogLevel.fromString('log'), LogLevel.log);
      expect(LogLevel.fromString('warn'), LogLevel.warn);
      expect(LogLevel.fromString('error'), LogLevel.error);
    });

    test('fromString should handle warning variant for API compatibility', () {
      expect(LogLevel.fromString('warning'), LogLevel.warn);
    });

    test('fromString should be case insensitive', () {
      expect(LogLevel.fromString('WARN'), LogLevel.warn);
      expect(LogLevel.fromString('Error'), LogLevel.error);
      expect(LogLevel.fromString('INFO'), LogLevel.info);
    });

    test('fromString should return null for invalid values', () {
      expect(LogLevel.fromString('invalid'), null);
      expect(LogLevel.fromString(''), null);
      expect(LogLevel.fromString(null), null);
    });

    test('should align with Faro Web SDK values', () {
      // Verify our enum values match the Faro Web SDK
      final webSDKLevels = {
        'trace': LogLevel.trace,
        'debug': LogLevel.debug,
        'info': LogLevel.info,
        'log': LogLevel.log,
        'warn': LogLevel.warn,
        'error': LogLevel.error,
      };

      for (final entry in webSDKLevels.entries) {
        expect(entry.value.value, entry.key);
      }
    });
  });
}
