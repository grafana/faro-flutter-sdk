import 'dart:convert';

import 'package:faro_example/qa_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QaConfig.parse', () {
    test('returns empty config when no QA vars are provided', () {
      final config = QaConfig.parse();

      expect(config.hasRunId, isFalse);
      expect(config.runId, isNull);
      expect(config.hasInitialUser, isFalse);
      expect(config.initialUser, isNull);
    });

    test('returns empty config when QA vars are empty strings', () {
      final config = QaConfig.parse(qaRunId: '', qaInitialUserJson: '');

      expect(config.hasRunId, isFalse);
      expect(config.hasInitialUser, isFalse);
    });

    group('qaRunId', () {
      test('is set when non-empty value provided', () {
        final config = QaConfig.parse(qaRunId: 'smoke-test-12345');

        expect(config.hasRunId, isTrue);
        expect(config.runId, equals('smoke-test-12345'));
      });

      test('is null when empty string provided', () {
        final config = QaConfig.parse(qaRunId: '');

        expect(config.hasRunId, isFalse);
        expect(config.runId, isNull);
      });
    });

    group('qaInitialUserJson', () {
      test('parses full user JSON with all fields', () {
        final userJson = jsonEncode({
          'id': 'user-123',
          'username': 'john.doe',
          'email': 'john.doe@example.com',
          'attributes': {
            'role': 'user',
            'department': 'design',
            'qa_generated': true,
          },
        });

        final config = QaConfig.parse(qaInitialUserJson: userJson);

        expect(config.hasInitialUser, isTrue);
        final user = config.initialUser!;
        expect(user.id, equals('user-123'));
        expect(user.username, equals('john.doe'));
        expect(user.email, equals('john.doe@example.com'));
        expect(user.attributes, isNotNull);
        expect(user.attributes!['role'], equals('user'));
        expect(user.attributes!['department'], equals('design'));
        expect(user.attributes!['qa_generated'], equals('true'));
      });

      test('parses user JSON with only id', () {
        final userJson = jsonEncode({'id': 'user-456'});

        final config = QaConfig.parse(qaInitialUserJson: userJson);

        expect(config.hasInitialUser, isTrue);
        final user = config.initialUser!;
        expect(user.id, equals('user-456'));
        expect(user.username, isNull);
        expect(user.email, isNull);
        expect(user.attributes, isNull);
      });

      test('parses user JSON with no optional fields', () {
        final userJson = jsonEncode(<String, dynamic>{});

        final config = QaConfig.parse(qaInitialUserJson: userJson);

        expect(config.hasInitialUser, isTrue);
        final user = config.initialUser!;
        expect(user.id, isNull);
        expect(user.username, isNull);
        expect(user.email, isNull);
        expect(user.attributes, isNull);
      });

      test('converts non-string attribute values to strings', () {
        final userJson = jsonEncode({
          'id': 'user-789',
          'attributes': {
            'count': 42,
            'active': true,
            'ratio': 3.14,
            'name': 'test',
          },
        });

        final config = QaConfig.parse(qaInitialUserJson: userJson);

        final attrs = config.initialUser!.attributes!;
        expect(attrs['count'], equals('42'));
        expect(attrs['active'], equals('true'));
        expect(attrs['ratio'], equals('3.14'));
        expect(attrs['name'], equals('test'));
      });

      test('returns null user for invalid JSON', () {
        final config = QaConfig.parse(qaInitialUserJson: 'not valid json {{{');

        expect(config.hasInitialUser, isFalse);
        expect(config.initialUser, isNull);
      });

      test('returns null user for JSON array instead of object', () {
        final config = QaConfig.parse(qaInitialUserJson: '[1, 2, 3]');

        expect(config.hasInitialUser, isFalse);
        expect(config.initialUser, isNull);
      });

      test('returns null user for JSON string literal', () {
        final config = QaConfig.parse(qaInitialUserJson: '"just a string"');

        expect(config.hasInitialUser, isFalse);
        expect(config.initialUser, isNull);
      });

      test('skips non-string field values without crashing', () {
        final userJson = jsonEncode({
          'id': 123,
          'username': true,
          'email': 45.6,
        });

        final config = QaConfig.parse(qaInitialUserJson: userJson);

        expect(config.hasInitialUser, isTrue);
        final user = config.initialUser!;
        expect(user.id, isNull);
        expect(user.username, isNull);
        expect(user.email, isNull);
      });
    });

    group('combined', () {
      test('both run ID and user can be provided together', () {
        final userJson = jsonEncode({'id': 'qa-user', 'username': 'qa-bot'});

        final config = QaConfig.parse(
          qaRunId: 'run-99',
          qaInitialUserJson: userJson,
        );

        expect(config.hasRunId, isTrue);
        expect(config.runId, equals('run-99'));
        expect(config.hasInitialUser, isTrue);
        expect(config.initialUser!.id, equals('qa-user'));
        expect(config.initialUser!.username, equals('qa-bot'));
      });

      test('run ID present with invalid user JSON still returns run ID', () {
        final config = QaConfig.parse(
          qaRunId: 'run-100',
          qaInitialUserJson: 'broken',
        );

        expect(config.hasRunId, isTrue);
        expect(config.runId, equals('run-100'));
        expect(config.hasInitialUser, isFalse);
      });
    });
  });
}
