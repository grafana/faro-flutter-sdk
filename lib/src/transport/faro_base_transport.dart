import 'dart:async';

abstract class BaseTransport {
  /// Accepts a payload for delivery.
  ///
  /// Completing normally tells the SDK that the payload was accepted or
  /// durably queued. Implementations must complete with an error when that
  /// handoff fails. This is especially important for recovered iOS crashes,
  /// because the SDK may purge the retained native report after a successful
  /// handoff.
  Future<void> send(Map<String, dynamic> payloadJson) async {}
}
