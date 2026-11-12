import 'dart:io';

/// The outcome of handing a payload to the collector.
enum DeliveryStatus {
  /// The collector returned a successful HTTP response.
  accepted,

  /// Retrying the same payload will not resolve the rejection.
  permanentFailure,

  /// The payload should be retained for another attempt.
  retryableFailure,

  /// The request was not started, for example because the buffer was full.
  notAttempted,
}

/// Delivery information needed by the owner of a durable payload.
class DeliveryResult {
  /// Creates a delivery outcome without retaining response bodies or payloads.
  const DeliveryResult(this.status, {this.statusCode, this.retryAt});

  /// Classifies an HTTP response using the collector retry policy.
  factory DeliveryResult.fromResponse(
    int statusCode,
    String? retryAfter, {
    DateTime? now,
  }) {
    final status = switch (statusCode) {
      >= 200 && < 300 => DeliveryStatus.accepted,
      408 || 429 => DeliveryStatus.retryableFailure,
      >= 400 && < 500 => DeliveryStatus.permanentFailure,
      _ => DeliveryStatus.retryableFailure,
    };
    DateTime? retryAt;
    if (status == DeliveryStatus.retryableFailure && retryAfter != null) {
      final seconds = int.tryParse(retryAfter.trim());
      final responseTime = now ?? DateTime.now();
      final maximumSeconds =
          (8640000000000000 - responseTime.millisecondsSinceEpoch) ~/ 1000;
      if (seconds != null && seconds >= 0 && seconds <= maximumSeconds) {
        retryAt = responseTime.add(Duration(seconds: seconds));
      } else {
        try {
          retryAt = HttpDate.parse(retryAfter.trim());
        } on HttpException {
          // Invalid server hints must not prevent normal retries.
        }
      }
    }
    return DeliveryResult(status, statusCode: statusCode, retryAt: retryAt);
  }

  /// Whether delivery succeeded, failed permanently, or needs another attempt.
  final DeliveryStatus status;

  /// The HTTP status, when a response was received.
  final int? statusCode;

  /// The earliest server-requested retry time, when provided and valid.
  final DateTime? retryAt;

  /// Whether the collector accepted the payload.
  bool get accepted => status == DeliveryStatus.accepted;

  /// Whether the durable copy may be removed.
  bool get isTerminal => accepted || status == DeliveryStatus.permanentFailure;
}
