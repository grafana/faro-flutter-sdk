import 'dart:math';

import 'package:faro/src/offline_transport/outbox_retry_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 12);

  test('backoff grows exponentially and saturates at the maximum', () {
    final policy = OutboxRetryPolicy(
      initialDelay: const Duration(seconds: 1),
      maxDelay: const Duration(seconds: 8),
      random: Random(1),
    );
    for (final failures in [1, 2, 3, 4, 5, 100000]) {
      final ceiling = min(8, pow(2, min(failures - 1, 4)));
      final delay = policy
          .nextAttempt(now: now, failures: failures)
          .difference(now);
      expect(
        delay.inMilliseconds,
        inInclusiveRange(ceiling * 500, ceiling * 1000),
      );
    }
  });

  test('Retry-After can exceed the client backoff cap', () {
    final policy = OutboxRetryPolicy(
      initialDelay: const Duration(seconds: 1),
      maxDelay: const Duration(seconds: 8),
    );
    final deadline = now.add(const Duration(minutes: 5));
    expect(
      policy.nextAttempt(now: now, failures: 1, serverRetryAt: deadline),
      deadline,
    );
  });

  test('past server deadlines still use backoff', () {
    final policy = OutboxRetryPolicy(
      initialDelay: const Duration(seconds: 1),
      maxDelay: const Duration(seconds: 8),
    );
    expect(
      policy
          .nextAttempt(
            now: now,
            failures: 1,
            serverRetryAt: now.subtract(const Duration(seconds: 1)),
          )
          .isAfter(now),
      isTrue,
    );
  });

  test('rejects sub-millisecond delays that would spin the retry timer', () {
    expect(
      () => OutboxRetryPolicy(
        initialDelay: const Duration(microseconds: 1),
        maxDelay: const Duration(seconds: 1),
      ),
      throwsArgumentError,
    );
  });
}
