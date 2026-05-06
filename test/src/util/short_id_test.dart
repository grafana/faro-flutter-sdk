import 'package:faro/src/util/short_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generateShortId:', () {
    test('should generate ID with default length of 10', () {
      final id = generateShortId();
      expect(id.length, equals(10));
    });

    test('should generate ID with custom length', () {
      expect(generateShortId(5).length, equals(5));
      expect(generateShortId(20).length, equals(20));
      expect(generateShortId(1).length, equals(1));
    });

    test('should only contain allowed characters', () {
      const allowed =
          'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ0123456789';

      for (var i = 0; i < 100; i++) {
        final id = generateShortId();
        for (final char in id.split('')) {
          expect(
            allowed.contains(char),
            isTrue,
            reason: 'Unexpected character "$char" in ID "$id"',
          );
        }
      }
    });

    test('should not contain ambiguous characters', () {
      final ids = List.generate(100, (_) => generateShortId());
      final allChars = ids.join();

      expect(allChars.contains('l'), isFalse);
      expect(allChars.contains('I'), isFalse);
      expect(allChars.contains('O'), isFalse);
    });

    test('should generate unique IDs', () {
      final ids = Set<String>.from(
        List.generate(1000, (_) => generateShortId()),
      );

      expect(ids.length, equals(1000));
    });
  });
}
