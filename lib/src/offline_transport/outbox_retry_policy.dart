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

  /// The longest wait a collector can request through `Retry-After`.
  ///
  /// A misconfigured or hostile header must not stall delivery until saved
  /// batches age out, so later server deadlines are clamped to this bound.
  static const Duration maxServerDelay = Duration(hours: 1);

  /// The upper bound for the first retry delay before jitter.
  final Duration initialDelay;

  /// The upper bound for exponential backoff, excluding server-directed waits.
  final Duration maxDelay;
  final Random _random;

  /// Chooses the next deadline, never preceding a valid server retry deadline
  /// after it has been limited by [clampServerDeadline].
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
    final server = serverRetryAt == null
        ? null
        : clampServerDeadline(serverRetryAt, now: now);
    return server != null && server.isAfter(next) ? server : next;
  }

  /// Limits a server deadline to [maxServerDelay] from [now].
  ///
  /// Also applied to deadlines loaded from disk, so a restart, an old release
  /// or a device clock moved backwards cannot extend the wait.
  static DateTime clampServerDeadline(
    DateTime deadline, {
    required DateTime now,
  }) {
    final latest = now.add(maxServerDelay);
    return deadline.isAfter(latest) ? latest : deadline;
  }
}
