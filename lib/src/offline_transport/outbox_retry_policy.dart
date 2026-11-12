import 'dart:math';

/// Computes bounded exponential backoff with equal jitter.
class OutboxRetryPolicy {
  /// Creates a policy with retry delays of at least one millisecond.
  OutboxRetryPolicy({
    required this.initialDelay,
    required this.maxDelay,
    Random? random,
  }) : _random = random ?? Random() {
    if (initialDelay.inMilliseconds <= 0 || maxDelay < initialDelay) {
      throw ArgumentError('Invalid outbox retry delays.');
    }
  }

  /// The upper bound for the first retry delay before jitter.
  final Duration initialDelay;

  /// The upper bound for exponential backoff, excluding server-directed waits.
  final Duration maxDelay;
  final Random _random;

  /// Chooses the next deadline, never preceding a valid server retry deadline.
  DateTime nextAttempt({
    required DateTime now,
    required int failures,
    DateTime? serverRetryAt,
  }) {
    var ceiling = initialDelay.inMilliseconds;
    for (
      var attempt = 1;
      attempt < failures && ceiling < maxDelay.inMilliseconds;
      attempt++
    ) {
      ceiling = min(ceiling * 2, maxDelay.inMilliseconds);
    }
    final delay = Duration(
      milliseconds: (ceiling / 2 + _random.nextDouble() * ceiling / 2).ceil(),
    );
    final next = now.add(delay);
    return serverRetryAt != null && serverRetryAt.isAfter(next)
        ? serverRetryAt
        : next;
  }
}
