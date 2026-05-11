/// Controls how exceptions thrown from the body of `startSpan` are recorded.
///
/// Can be configured globally via [FaroConfig.spanExceptionOptions]
/// or per-span via the `exceptionOptions` parameter of `startSpan()`.
/// Per-span options are merged over global configuration.
class SpanExceptionOptions {
  /// Creates span exception options.
  ///
  /// Omitted parameters inherit from global configuration when these options
  /// are used as a per-span override. Without global configuration, omitted
  /// parameters default to the SDK's standard behavior:
  /// - [recordException]: `true` — auto-record exceptions on the span
  /// - [setStatusOnException]: `true` — auto-set span status to error
  /// - [exceptionSanitizer]: `null` — record the raw exception as-is
  const SpanExceptionOptions({
    bool? recordException,
    bool? setStatusOnException,
    this.exceptionSanitizer,
  }) : _recordException = recordException,
       _setStatusOnException = setStatusOnException;

  /// SDK default span exception behavior.
  static const defaults = SpanExceptionOptions(
    recordException: true,
    setStatusOnException: true,
  );

  final bool? _recordException;
  final bool? _setStatusOnException;

  /// Whether the SDK should automatically record the exception on the span.
  ///
  /// When `true` (default), the SDK calls `span.recordException()`.
  /// When `false`, the SDK skips automatic exception recording.
  bool get recordException => _recordException ?? true;

  /// Whether the SDK should automatically set the span status to error.
  ///
  /// When `true` (default), the SDK calls
  /// `span.setStatus(SpanStatusCode.error)`.
  /// When `false`, the SDK skips automatic status updates on exception.
  bool get setStatusOnException => _setStatusOnException ?? true;

  /// Optional callback to sanitize exception data before recording.
  ///
  /// When provided, the SDK uses the returned [SanitizedSpanException]
  /// to record the exception instead of the raw error object. This is
  /// useful for removing PII or sensitive data from error messages.
  ///
  /// The sanitizer is only invoked when [recordException] or
  /// [setStatusOnException] is `true`.
  final ExceptionSanitizer? exceptionSanitizer;

  /// Returns a new options object with [overrides] applied field-by-field.
  ///
  /// This allows a per-span override like
  /// `SpanExceptionOptions(recordException: false)` to keep a globally
  /// configured [exceptionSanitizer] while changing only one flag.
  ///
  /// Note: passing `exceptionSanitizer: null` in [overrides] is
  /// indistinguishable from not setting it — to intentionally clear a global
  /// sanitizer, use separate configuration.
  SpanExceptionOptions mergeWith(SpanExceptionOptions? overrides) {
    if (overrides == null) {
      return this;
    }

    return SpanExceptionOptions(
      recordException: overrides._recordException ?? _recordException,
      setStatusOnException:
          overrides._setStatusOnException ?? _setStatusOnException,
      exceptionSanitizer: overrides.exceptionSanitizer ?? exceptionSanitizer,
    );
  }
}

/// Callback that transforms a raw exception into sanitized span data.
///
/// Used by [SpanExceptionOptions.exceptionSanitizer] to control what
/// exception information is recorded on the span.
typedef ExceptionSanitizer =
    SanitizedSpanException Function(Object error, StackTrace stackTrace);

/// Sanitized exception data to record on a span.
///
/// Returned by [ExceptionSanitizer] to control exactly what gets recorded
/// as exception attributes on the span.
class SanitizedSpanException {
  /// Creates a sanitized span exception.
  const SanitizedSpanException({
    required this.type,
    required this.message,
    this.stackTrace,
    this.statusDescription,
  });

  /// The exception type (recorded as `exception.type` attribute).
  final String type;

  /// The sanitized error message (recorded as `exception.message`
  /// attribute).
  final String message;

  /// Optional sanitized stack trace. If `null`, no stack trace is
  /// recorded.
  final StackTrace? stackTrace;

  /// Optional status description for `span.setStatus()`.
  ///
  /// Used as the message in
  /// `span.setStatus(SpanStatusCode.error, message: statusDescription)`.
  /// Falls back to [message] if not provided.
  final String? statusDescription;
}
