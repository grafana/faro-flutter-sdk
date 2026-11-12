import 'dart:io';

import 'package:faro/src/transport/delivery_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 12);

  group('DeliveryResult:', () {
    for (final code in [200, 202, 204, 299]) {
      test('accepts HTTP $code', () {
        final result = DeliveryResult.fromResponse(code, null);
        expect(result.accepted, isTrue);
        expect(result.isTerminal, isTrue);
      });
    }
    for (final code in [400, 401, 403, 404, 413, 422]) {
      test('drops permanent HTTP $code', () {
        final result = DeliveryResult.fromResponse(code, null);
        expect(result.accepted, isFalse);
        expect(result.isTerminal, isTrue);
      });
    }
    for (final code in [301, 408, 429, 500, 502, 503, 599]) {
      test('retains retryable HTTP $code', () {
        final result = DeliveryResult.fromResponse(code, null);
        expect(result.status, DeliveryStatus.retryableFailure);
        expect(result.isTerminal, isFalse);
      });
    }
    test('parses Retry-After seconds relative to response time', () {
      final result = DeliveryResult.fromResponse(429, ' 120 ', now: now);
      expect(result.retryAt, now.add(const Duration(minutes: 2)));
    });
    test('parses Retry-After HTTP dates', () {
      final next = now.add(const Duration(minutes: 3));
      final result = DeliveryResult.fromResponse(503, HttpDate.format(next));
      expect(result.retryAt, next);
    });
    for (final value in ['invalid', '-1', '1.5', '999999999999999999999']) {
      test('ignores malformed Retry-After $value', () {
        expect(DeliveryResult.fromResponse(429, value).retryAt, isNull);
      });
    }
    test('ignores Retry-After on a terminal result', () {
      expect(DeliveryResult.fromResponse(400, '120').retryAt, isNull);
    });
  });
}
