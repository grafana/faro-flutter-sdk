// ignore_for_file: lines_longer_than_80_chars

import 'package:faro/src/session/session_id_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SessionIdProvider:', () {
    test('should generate a session ID on instantiation', () {
      final sut = SessionIdProvider();

      expect(sut.sessionId, isNotEmpty);
      expect(sut.sessionId, isA<String>());
    });

    test('should generate session ID with correct length', () {
      final sut = SessionIdProvider();

      expect(sut.sessionId.length, equals(10));
    });

    test('should generate session ID with valid characters only', () {
      final sut = SessionIdProvider();
      const validChars =
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

      for (var i = 0; i < sut.sessionId.length; i++) {
        expect(validChars.contains(sut.sessionId[i]), isTrue,
            reason:
                'Character "${sut.sessionId[i]}" at position $i is not valid');
      }
    });

    test('should generate different session IDs for different instances', () {
      final provider1 = SessionIdProvider();
      final provider2 = SessionIdProvider();
      final provider3 = SessionIdProvider();

      // Test that IDs are different (extremely unlikely to be the same due to randomness)
      expect(provider1.sessionId, isNot(equals(provider2.sessionId)));
      expect(provider1.sessionId, isNot(equals(provider3.sessionId)));
      expect(provider2.sessionId, isNot(equals(provider3.sessionId)));
    });

    test('should generate consistent session ID for same instance', () {
      final sut = SessionIdProvider();
      final firstAccess = sut.sessionId;
      final secondAccess = sut.sessionId;

      expect(firstAccess, equals(secondAccess));
    });

    test('should generate session IDs matching expected pattern', () {
      // Generate multiple IDs to test pattern consistency
      for (var i = 0; i < 10; i++) {
        final sut = SessionIdProvider();
        final sessionId = sut.sessionId;

        // Check pattern: exactly 10 alphanumeric characters
        expect(RegExp(r'^[a-zA-Z0-9]{10}$').hasMatch(sessionId), isTrue,
            reason: 'Session ID "$sessionId" does not match expected pattern');
      }
    });
  });

  group('SessionIdProviderFactory:', () {
    late SessionIdProviderFactory sut;

    setUp(() {
      sut = SessionIdProviderFactory();
    });

    test('should create a SessionIdProvider instance', () {
      final provider = sut.create();

      expect(provider, isA<SessionIdProvider>());
      expect(provider.sessionId, isNotEmpty);
    });

    test(
        'should return the same instance on multiple calls (singleton behavior)',
        () {
      final provider1 = sut.create();
      final provider2 = sut.create();

      expect(identical(provider1, provider2), isTrue);
      expect(provider1.sessionId, equals(provider2.sessionId));
    });

    test('should return same instance across different factory instances', () {
      final factory1 = SessionIdProviderFactory();
      final factory2 = SessionIdProviderFactory();

      final provider1 = factory1.create();
      final provider2 = factory2.create();

      expect(identical(provider1, provider2), isTrue);
      expect(provider1.sessionId, equals(provider2.sessionId));
    });

    test(
        'should maintain singleton state after multiple factory instantiations',
        () {
      final factory1 = SessionIdProviderFactory();
      final provider1 = factory1.create();

      final factory2 = SessionIdProviderFactory();
      final provider2 = factory2.create();

      final factory3 = SessionIdProviderFactory();
      final provider3 = factory3.create();

      expect(identical(provider1, provider2), isTrue);
      expect(identical(provider2, provider3), isTrue);
      expect(provider1.sessionId, equals(provider2.sessionId));
      expect(provider2.sessionId, equals(provider3.sessionId));
    });
  });

  group('SessionIdProvider _generateSessionID static method:', () {
    test('should generate different IDs when called directly multiple times',
        () {
      // We can't call the private method directly, but we can test its behavior
      // through multiple SessionIdProvider instantiations
      final ids = <String>{};

      // Generate 20 IDs and ensure they're all unique
      for (var i = 0; i < 20; i++) {
        final provider = SessionIdProvider();
        ids.add(provider.sessionId);
      }

      // All IDs should be unique (set size should equal number of generated IDs)
      expect(ids.length, equals(20),
          reason: 'Generated session IDs are not sufficiently random');
    });

    test('should generate IDs with good distribution of characters', () {
      final characterCounts = <String, int>{};
      const sampleSize = 100;

      // Generate many session IDs and count character usage
      for (var i = 0; i < sampleSize; i++) {
        final provider = SessionIdProvider();
        for (var j = 0; j < provider.sessionId.length; j++) {
          final char = provider.sessionId[j];
          characterCounts[char] = (characterCounts[char] ?? 0) + 1;
        }
      }

      // Should have used multiple different characters (not just a few)
      expect(characterCounts.keys.length, greaterThan(10),
          reason:
              'Session ID generation should use a good variety of characters');
    });
  });
}
