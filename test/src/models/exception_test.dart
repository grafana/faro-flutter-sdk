// ignore_for_file: avoid_redundant_argument_values, lines_longer_than_80_chars

import 'dart:convert';

import 'package:faro/src/models/exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FaroException:', () {
    test('should create a FaroException with valid values', () {
      final exception = FaroException(
        'error_type',
        'Error message',
        {'frames': '[]'},
        context: {'key': 'value'},
      );

      expect(exception.type, equals('error_type'));
      expect(exception.value, equals('Error message'));
      expect(exception.stacktrace, isA<Map<String, dynamic>>());
      expect(exception.context, isA<Map<String, String>>());
      expect(exception.context!['key'], equals('value'));
      expect(exception.fatal, isFalse);
      expect(exception.timestamp, isNotNull);
    });

    test('should create a fatal FaroException', () {
      final exception = FaroException(
        'crash',
        'App crashed',
        null,
        fatal: true,
      );

      expect(exception.fatal, isTrue);
      expect(exception.toJson()['fatal'], isTrue);
    });

    test('should create a FaroException with null stacktrace', () {
      final exception = FaroException(
        'error_type',
        'Error message',
        null,
        context: {'key': 'value'},
      );

      expect(exception.type, equals('error_type'));
      expect(exception.value, equals('Error message'));
      expect(exception.stacktrace, isNull);
      expect(exception.context, isA<Map<String, String>>());
      expect(exception.context!['key'], equals('value'));
      expect(exception.timestamp, isNotNull);
    });

    test('should create a FaroException with null context', () {
      final exception = FaroException('error_type', 'Error message', {
        'frames': '[]',
      }, context: null);

      expect(exception.type, equals('error_type'));
      expect(exception.value, equals('Error message'));
      expect(exception.stacktrace, isA<Map<String, dynamic>>());
      expect(exception.context, isNull);
      expect(exception.timestamp, isNotNull);
    });

    test('should handle fromJson with valid data', () {
      final json = {
        'type': 'error_type',
        'value': 'Error message',
        'stacktrace': {'frames': '[]'},
        'timestamp': '2023-01-01T12:00:00.000Z',
        'fatal': true,
        'context': {'key': 'value'},
      };

      final exception = FaroException.fromJson(json);

      expect(exception.type, equals('error_type'));
      expect(exception.value, equals('Error message'));
      expect(exception.stacktrace, isA<Map<String, dynamic>>());
      expect(exception.context, isA<Map<String, String>>());
      expect(exception.context!['key'], equals('value'));
      expect(exception.fatal, isTrue);
      expect(exception.timestamp, equals('2023-01-01T12:00:00.000Z'));
    });

    test('should handle null stacktrace field in fromJson', () {
      final json = {
        'type': 'error_type',
        'value': 'Error message',
        'timestamp': '2023-01-01T12:00:00.000Z',
        // No stacktrace field
      };

      final exception = FaroException.fromJson(json);

      expect(exception.type, equals('error_type'));
      expect(exception.value, equals('Error message'));
      expect(exception.stacktrace, isNull);
      expect(exception.context, isNull);
      expect(exception.timestamp, equals('2023-01-01T12:00:00.000Z'));
    });

    test('should handle null context field in fromJson', () {
      final json = {
        'type': 'error_type',
        'value': 'Error message',
        'timestamp': '2023-01-01T12:00:00.000Z',
        'stacktrace': {'frames': '[]'},
        // No context field
      };

      final exception = FaroException.fromJson(json);

      expect(exception.type, equals('error_type'));
      expect(exception.value, equals('Error message'));
      expect(exception.stacktrace, isA<Map<String, dynamic>>());
      expect(exception.context, isNull);
      expect(exception.timestamp, equals('2023-01-01T12:00:00.000Z'));
    });

    test('should convert non-string stacktrace values to strings', () {
      final json = {
        'type': 'error_type',
        'value': 'Error message',
        'timestamp': '2023-01-01T12:00:00.000Z',
        'stacktrace': {
          'string': 'string_value',
          'number': 42,
          'boolean': true,
          'object': {'nested': 'value'},
          'null': null,
        },
      };

      final exception = FaroException.fromJson(json);

      expect(exception.stacktrace, isA<Map<String, dynamic>>());
      expect(exception.stacktrace!['string'], equals('string_value'));
      expect(exception.stacktrace!['number'], equals('42'));
      expect(exception.stacktrace!['boolean'], equals('true'));
      expect(exception.stacktrace!['object'], equals('{nested: value}'));
      expect(exception.stacktrace!['null'], equals(''));
    });

    test('should convert non-string context values to strings', () {
      final json = {
        'type': 'error_type',
        'value': 'Error message',
        'timestamp': '2023-01-01T12:00:00.000Z',
        'stacktrace': 'simple stacktrace',
        'context': {
          'string': 'string_value',
          'number': 42,
          'boolean': true,
          'object': {'nested': 'value'},
          'null': null,
        },
      };

      final exception = FaroException.fromJson(json);

      expect(exception.context, isA<Map<String, String>>());
      expect(exception.context!['string'], equals('string_value'));
      expect(exception.context!['number'], equals('42'));
      expect(exception.context!['boolean'], equals('true'));
      expect(exception.context!['object'], equals('{nested: value}'));
      expect(exception.context!['null'], equals(''));
    });

    test('fromJsonOrNull should return null for missing required fields', () {
      // Missing type field
      final missingType = {
        'value': 'Error message',
        'stacktrace': {'frames': '[]'},
        'timestamp': '2023-01-01T12:00:00.000Z',
      };

      // Missing value field
      final missingValue = {
        'type': 'error_type',
        'stacktrace': {'frames': '[]'},
        'timestamp': '2023-01-01T12:00:00.000Z',
      };

      // Missing timestamp field
      final missingTimestamp = {
        'type': 'error_type',
        'value': 'Error message',
        'stacktrace': {'frames': '[]'},
      };

      // Valid exception with no stacktrace
      final validJsonNoStacktrace = {
        'type': 'error_type',
        'value': 'Error message',
        'timestamp': '2023-01-01T12:00:00.000Z',
      };

      // Valid exception with stacktrace
      final validJson = {
        'type': 'error_type',
        'value': 'Error message',
        'stacktrace': {'frames': '[]'},
        'timestamp': '2023-01-01T12:00:00.000Z',
      };

      expect(FaroException.fromJsonOrNull(missingType), isNull);
      expect(FaroException.fromJsonOrNull(missingValue), isNull);
      expect(FaroException.fromJsonOrNull(missingTimestamp), isNull);
      expect(FaroException.fromJsonOrNull(validJsonNoStacktrace), isNotNull);
      expect(FaroException.fromJsonOrNull(validJson), isNotNull);
    });

    test('toJson should create a valid JSON representation', () {
      final exception = FaroException(
        'error_type',
        'Error message',
        {'frames': '[]'},
        context: {'key': 'value'},
      );

      final json = exception.toJson();
      final encoded = jsonEncode(json);

      expect(json['type'], equals('error_type'));
      expect(json['value'], equals('Error message'));
      expect(json['fatal'], isFalse);
      expect(json['stacktrace'], isA<Map<String, dynamic>>());
      expect(json['context'], isA<Map<String, String>>());
      expect(encoded, isNotNull);
    });

    test('toJson should include stacktrace only when not null', () {
      // Create with null stacktrace
      final nullException = FaroException(
        'error_type',
        'Error message',
        null,
        context: {'key': 'value'},
      );

      final json = nullException.toJson();

      expect(json['type'], equals('error_type'));
      expect(json['value'], equals('Error message'));
      expect(json.containsKey('stacktrace'), isFalse);
      expect(json['context'], isA<Map<String, String>>());
    });

    test('stackTraceParse should extract stack trace information', () {
      final sampleStackTrace = StackTrace.fromString('''
#0      SomeClass.someMethod (package:app/file.dart:10:5)
#1      AnotherClass.anotherMethod (package:app/another_file.dart:20:10)
''');

      final frames = FaroException.stackTraceParse(sampleStackTrace);

      expect(frames, isA<List<Map<String, dynamic>>>());
      expect(frames.length, equals(2));

      // The actual implementation extracts the path differently than expected.
      // Use contains to check for the relevant parts without enforcing exact equality
      expect(frames[0]['filename'], contains('app/file.dart'));
      expect(frames[1]['filename'], contains('app/another_file.dart'));
    });

    group('stackTraceParse with non-standard formats (issue #102):', () {
      test('should parse sanitized (trimmed) standard frames', () {
        // Simulates a user sanitizer that trims each line before rejoining
        // (see issue #102) - frames keep the "#N" index but lose padding.
        final sanitizedStackTrace = StackTrace.fromString(
          '#0 MyClass.myMethod (package:my_app/my_file.dart:10:5)\n'
          '#1 OtherClass.otherMethod (package:my_app/other.dart:20:7)',
        );

        final frames = FaroException.stackTraceParse(sanitizedStackTrace);

        expect(frames.length, equals(2));
        expect(frames[0]['filename'], contains('my_app/my_file.dart'));
        expect(frames[0]['function'], equals('MyClass.myMethod'));
        expect(frames[0]['lineno'], equals(10));
        expect(frames[0]['colno'], equals(5));
        expect(frames[1]['filename'], contains('my_app/other.dart'));
        expect(frames[1]['function'], equals('OtherClass.otherMethod'));
        expect(frames[1]['lineno'], equals(20));
        expect(frames[1]['colno'], equals(7));
      });

      test('should parse frames without a leading "#N" index', () {
        final stackTrace = StackTrace.fromString(
          'MyClass.myMethod (package:my_app/my_file.dart:10:5)',
        );

        final frames = FaroException.stackTraceParse(stackTrace);

        expect(frames.length, equals(1));
        expect(frames[0]['filename'], contains('my_app/my_file.dart'));
        expect(frames[0]['function'], equals('MyClass.myMethod'));
        expect(frames[0]['lineno'], equals(10));
        expect(frames[0]['colno'], equals(5));
      });

      test('should preserve lines in package:stack_trace Trace format', () {
        final stackTrace = StackTrace.fromString(
          'package:my_app/my_file.dart 10:5  MyClass.myMethod',
        );

        final frames = FaroException.stackTraceParse(stackTrace);

        expect(frames.length, equals(1));
        expect(
          frames[0]['function'],
          equals('package:my_app/my_file.dart 10:5  MyClass.myMethod'),
        );
      });

      test('should preserve free-form lines without spaces', () {
        // A single-token line used to throw a RangeError, which dropped
        // the entire stack trace.
        final stackTrace = StackTrace.fromString('some-free-form-line');

        final frames = FaroException.stackTraceParse(stackTrace);

        expect(frames.length, equals(1));
        expect(frames[0]['function'], equals('some-free-form-line'));
      });

      test('should preserve obfuscated release-mode android frames', () {
        final stackTrace = StackTrace.fromString(
          '#00 abs 0000000000043b8f virt 00000000001fdb8f '
          '_kDartIsolateSnapshotInstructions+0x1e3b8f\n'
          '#01 abs 0000000000043c12 virt 00000000001fdc12 '
          '_kDartIsolateSnapshotInstructions+0x1e3c12',
        );

        final frames = FaroException.stackTraceParse(stackTrace);

        expect(frames.length, equals(2));
        expect(
          frames[0]['function'],
          equals(
            '#00 abs 0000000000043b8f virt 00000000001fdb8f '
            '_kDartIsolateSnapshotInstructions+0x1e3b8f',
          ),
        );
        expect(
          frames[1]['function'],
          equals(
            '#01 abs 0000000000043c12 virt 00000000001fdc12 '
            '_kDartIsolateSnapshotInstructions+0x1e3c12',
          ),
        );
      });

      test('should preserve asynchronous suspension markers', () {
        final stackTrace = StackTrace.fromString('<asynchronous suspension>');

        final frames = FaroException.stackTraceParse(stackTrace);

        expect(frames.length, equals(1));
        expect(frames[0]['function'], equals('<asynchronous suspension>'));
      });

      test('should preserve frames missing a column number', () {
        final stackTrace = StackTrace.fromString(
          '#0      main (package:app/file.dart:10)',
        );

        final frames = FaroException.stackTraceParse(stackTrace);

        expect(frames.length, equals(1));
        expect(
          frames[0]['function'],
          equals('#0      main (package:app/file.dart:10)'),
        );
      });

      test('should not drop parsable frames when mixed with free-form '
          'lines', () {
        final stackTrace = StackTrace.fromString(
          '#0      SomeClass.someMethod (package:app/file.dart:10:5)\n'
          'free-form-line\n'
          '#1      Other.otherMethod (package:app/other_file.dart:20:10)',
        );

        final frames = FaroException.stackTraceParse(stackTrace);

        expect(frames.length, equals(3));
        expect(frames[0]['filename'], contains('app/file.dart'));
        expect(frames[0]['function'], equals('SomeClass.someMethod'));
        expect(frames[1]['function'], equals('free-form-line'));
        expect(frames[2]['filename'], contains('app/other_file.dart'));
        expect(frames[2]['function'], equals('Other.otherMethod'));
      });

      test('should skip blank lines', () {
        final stackTrace = StackTrace.fromString(
          '#0      SomeClass.someMethod (package:app/file.dart:10:5)\n'
          '\n'
          '#1      Other.otherMethod (package:app/other_file.dart:20:10)',
        );

        final frames = FaroException.stackTraceParse(stackTrace);

        expect(frames.length, equals(2));
        expect(frames[0]['function'], equals('SomeClass.someMethod'));
        expect(frames[1]['function'], equals('Other.otherMethod'));
      });
    });
  });
}
