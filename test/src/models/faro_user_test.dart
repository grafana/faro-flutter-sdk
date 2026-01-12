import 'package:faro/src/models/faro_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FaroUser:', () {
    test('should create user with all properties', () {
      const user = FaroUser(
        id: 'user-123',
        username: 'john.doe',
        email: 'john@example.com',
      );

      expect(user.id, 'user-123');
      expect(user.username, 'john.doe');
      expect(user.email, 'john@example.com');
      expect(user.isCleared, isFalse);
      expect(user.hasData, isTrue);
    });

    test('should create user with only id', () {
      const user = FaroUser(id: 'user-123');

      expect(user.id, 'user-123');
      expect(user.username, isNull);
      expect(user.email, isNull);
      expect(user.isCleared, isFalse);
      expect(user.hasData, isTrue);
    });

    test('should create empty user without data', () {
      const user = FaroUser();

      expect(user.id, isNull);
      expect(user.username, isNull);
      expect(user.email, isNull);
      expect(user.isCleared, isFalse);
      expect(user.hasData, isFalse);
    });

    group('FaroUser.cleared():', () {
      test('should create cleared sentinel value', () {
        const user = FaroUser.cleared();

        expect(user.id, isNull);
        expect(user.username, isNull);
        expect(user.email, isNull);
        expect(user.isCleared, isTrue);
        expect(user.hasData, isFalse);
      });

      test('should be distinguishable from empty user', () {
        const clearedUser = FaroUser.cleared();
        const emptyUser = FaroUser();

        expect(clearedUser.isCleared, isTrue);
        expect(emptyUser.isCleared, isFalse);
        expect(clearedUser, isNot(equals(emptyUser)));
      });

      test('should have descriptive toString', () {
        const user = FaroUser.cleared();

        expect(user.toString(), 'FaroUser.cleared()');
      });
    });

    group('JSON serialization:', () {
      test('should convert to JSON with all properties', () {
        const user = FaroUser(
          id: 'user-123',
          username: 'john.doe',
          email: 'john@example.com',
        );

        final json = user.toJson();

        expect(json['id'], 'user-123');
        expect(json['username'], 'john.doe');
        expect(json['email'], 'john@example.com');
      });

      test('should convert to JSON with null properties', () {
        const user = FaroUser(id: 'user-123');

        final json = user.toJson();

        expect(json['id'], 'user-123');
        expect(json['username'], isNull);
        expect(json['email'], isNull);
      });

      test('should create from JSON with all properties', () {
        final json = {
          'id': 'user-123',
          'username': 'john.doe',
          'email': 'john@example.com',
        };

        final user = FaroUser.fromJson(json);

        expect(user.id, 'user-123');
        expect(user.username, 'john.doe');
        expect(user.email, 'john@example.com');
        expect(user.isCleared, isFalse);
      });

      test('should create from JSON with null properties', () {
        final json = {
          'id': 'user-123',
          'username': null,
          'email': null,
        };

        final user = FaroUser.fromJson(json);

        expect(user.id, 'user-123');
        expect(user.username, isNull);
        expect(user.email, isNull);
      });

      test('should round-trip through JSON', () {
        const original = FaroUser(
          id: 'user-123',
          username: 'john.doe',
          email: 'john@example.com',
        );

        final json = original.toJson();
        final restored = FaroUser.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.username, original.username);
        expect(restored.email, original.email);
      });
    });

    group('equality:', () {
      test('should be equal when all properties match', () {
        const user1 = FaroUser(
          id: 'user-123',
          username: 'john.doe',
          email: 'john@example.com',
        );
        const user2 = FaroUser(
          id: 'user-123',
          username: 'john.doe',
          email: 'john@example.com',
        );

        expect(user1, equals(user2));
        expect(user1.hashCode, equals(user2.hashCode));
      });

      test('should not be equal when properties differ', () {
        const user1 = FaroUser(id: 'user-123');
        const user2 = FaroUser(id: 'user-456');

        expect(user1, isNot(equals(user2)));
      });

      test('should compare all properties correctly', () {
        const user1 = FaroUser(
          id: 'user-123',
          username: 'john',
          email: 'john@example.com',
        );
        const user2 = FaroUser(
          id: 'user-123',
          username: 'john',
          email: 'john@example.com',
        );
        const user3 = FaroUser(
          id: 'user-123',
          username: 'jane',
          email: 'john@example.com',
        );

        expect(user1, equals(user2));
        expect(user1, isNot(equals(user3)));
      });
    });

    group('toString:', () {
      test('should return descriptive string for normal user', () {
        const user = FaroUser(
          id: 'user-123',
          username: 'john.doe',
          email: 'john@example.com',
        );

        expect(
          user.toString(),
          'FaroUser(id: user-123, username: john.doe, '
          'email: john@example.com)',
        );
      });

      test('should return descriptive string for cleared user', () {
        const user = FaroUser.cleared();

        expect(user.toString(), 'FaroUser.cleared()');
      });

      test('should include attributes in toString when present', () {
        const user = FaroUser(
          id: 'user-123',
          attributes: {'role': 'admin'},
        );

        expect(
          user.toString(),
          contains('attributes: {role: admin}'),
        );
      });
    });

    group('attributes:', () {
      test('should create user with attributes', () {
        const user = FaroUser(
          id: 'user-123',
          attributes: {'role': 'admin', 'org': 'acme'},
        );

        expect(user.attributes, {'role': 'admin', 'org': 'acme'});
        expect(user.hasData, isTrue);
      });

      test('should have hasData true with only attributes', () {
        const user = FaroUser(
          attributes: {'role': 'admin'},
        );

        expect(user.id, isNull);
        expect(user.username, isNull);
        expect(user.email, isNull);
        expect(user.attributes, {'role': 'admin'});
        expect(user.hasData, isTrue);
      });

      test('should have hasData false with empty attributes', () {
        const user = FaroUser(
          attributes: {},
        );

        expect(user.hasData, isFalse);
      });

      test('should serialize attributes to JSON', () {
        const user = FaroUser(
          id: 'user-123',
          attributes: {'role': 'admin', 'org': 'acme'},
        );

        final json = user.toJson();

        expect(json['attributes'], {'role': 'admin', 'org': 'acme'});
      });

      test('should not include attributes key in JSON when null', () {
        const user = FaroUser(id: 'user-123');

        final json = user.toJson();

        expect(json.containsKey('attributes'), isFalse);
      });

      test('should deserialize attributes from JSON', () {
        final json = {
          'id': 'user-123',
          'attributes': {'role': 'admin', 'org': 'acme'},
        };

        final user = FaroUser.fromJson(json);

        expect(user.attributes, {'role': 'admin', 'org': 'acme'});
      });

      test('should handle missing attributes in JSON (backward compat)', () {
        final json = {
          'id': 'user-123',
          'username': 'john.doe',
        };

        final user = FaroUser.fromJson(json);

        expect(user.id, 'user-123');
        expect(user.username, 'john.doe');
        expect(user.attributes, isNull);
      });

      test('should round-trip attributes through JSON', () {
        const original = FaroUser(
          id: 'user-123',
          attributes: {'role': 'admin', 'tier': 'premium'},
        );

        final json = original.toJson();
        final restored = FaroUser.fromJson(json);

        expect(restored.attributes, original.attributes);
      });

      test('should compare attributes in equality', () {
        const user1 = FaroUser(
          id: 'user-123',
          attributes: {'role': 'admin'},
        );
        const user2 = FaroUser(
          id: 'user-123',
          attributes: {'role': 'admin'},
        );
        const user3 = FaroUser(
          id: 'user-123',
          attributes: {'role': 'user'},
        );

        expect(user1, equals(user2));
        expect(user1, isNot(equals(user3)));
      });

      test('cleared user should have null attributes', () {
        const user = FaroUser.cleared();

        expect(user.attributes, isNull);
      });
    });
  });
}
