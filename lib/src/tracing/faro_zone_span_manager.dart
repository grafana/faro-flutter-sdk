import 'dart:async';

import 'package:faro/src/tracing/span.dart';
import 'package:faro/src/tracing/span_exception_options.dart';

export 'package:faro/src/tracing/span.dart' show ContextScope;

typedef ParentSpanLookup = dynamic Function(Symbol key);
typedef ZoneRunner =
    Future<T> Function<T>(
      Future<T> Function() callback,
      Map<Object?, Object?> zoneValues,
    );

/// Holds a span and tracks whether it's still active in context.
///
/// Used internally to support deactivation when the callback completes,
/// allowing proper separation between span lifecycle (end) and context scope.
class SpanContextHolder {
  SpanContextHolder({required this.span, required this.contextScope});

  /// The span being held.
  final Span span;

  /// The context scope that determines deactivation behavior.
  final ContextScope contextScope;

  bool _isActive = true;

  /// Whether this span is still active in the context.
  ///
  /// When false, [FaroZoneSpanManager.getActiveSpan] will not return this span.
  bool get isActive => _isActive;

  /// Deactivates this span from the context.
  ///
  /// After calling this, [isActive] will return false and the span will no
  /// longer be returned by [FaroZoneSpanManager.getActiveSpan].
  void deactivate() {
    _isActive = false;
  }
}

class FaroZoneSpanManager {
  FaroZoneSpanManager({
    required ParentSpanLookup parentSpanLookup,
    required ZoneRunner zoneRunner,
  }) : _parentSpanLookup = parentSpanLookup,
       _zoneRunner = zoneRunner;

  static const _spanContextKey = #faroSpanContext;

  final ParentSpanLookup _parentSpanLookup;
  final ZoneRunner _zoneRunner;

  /// Returns the active span from the current zone context, if any.
  ///
  /// Returns null if:
  /// - No span exists in the current zone context
  /// - The span's [SpanContextHolder] has been deactivated
  Span? getActiveSpan() {
    final potentialParent = _parentSpanLookup(_spanContextKey);
    if (potentialParent is SpanContextHolder && potentialParent.isActive) {
      return potentialParent.span;
    }
    return null;
  }

  /// Executes the callback with the span set as the active span in context.
  ///
  /// [contextScope] controls when the span is deactivated from context:
  /// - [ContextScope.callback] (default): Deactivates when callback completes
  /// - [ContextScope.zone]: Remains active for all async operations in zone
  Future<T> executeWithSpan<T>(
    Span span,
    FutureOr<T> Function(Span) body, {
    ContextScope contextScope = ContextScope.callback,
    SpanExceptionOptions? exceptionOptions,
  }) async {
    final spanContextHolder = SpanContextHolder(
      span: span,
      contextScope: contextScope,
    );

    return _zoneRunner(() async {
      try {
        final result = await body(span);
        if (!span.statusHasBeenSet) {
          span.setStatus(SpanStatusCode.ok);
        }
        return result;
      } catch (error, stackTrace) {
        final shouldSetStatus = exceptionOptions?.setStatusOnException ?? true;
        final shouldRecord = exceptionOptions?.recordException ?? true;
        final sanitizer = exceptionOptions?.exceptionSanitizer;

        if (sanitizer != null) {
          try {
            final sanitized = sanitizer(error, stackTrace);
            if (shouldSetStatus && !span.statusHasBeenSet) {
              span.setStatus(
                SpanStatusCode.error,
                message: sanitized.statusDescription ?? sanitized.message,
              );
            }
            if (shouldRecord) {
              span.addEvent(
                'exception',
                attributes: {
                  'exception.type': sanitized.type,
                  'exception.message': sanitized.message,
                  if (sanitized.stackTrace != null)
                    'exception.stacktrace': sanitized.stackTrace.toString(),
                },
              );
            }
          } catch (_) {
            // Preserve original exception if sanitizer fails.
            // Still mark the span as failed so it is not silently
            // reported as successful.
            if (shouldSetStatus && !span.statusHasBeenSet) {
              span.setStatus(
                SpanStatusCode.error,
                message: 'exception sanitizer failed',
              );
            }
          }
        } else {
          if (shouldSetStatus && !span.statusHasBeenSet) {
            span.setStatus(SpanStatusCode.error, message: error.toString());
          }
          if (shouldRecord) {
            span.recordException(error, stackTrace: stackTrace);
          }
        }
        rethrow;
      } finally {
        span.end();
        // Deactivate context as the last thing when leaving callback scope
        if (contextScope == ContextScope.callback) {
          spanContextHolder.deactivate();
        }
      }
    }, {_spanContextKey: spanContextHolder});
  }
}

class FaroZoneSpanManagerFactory {
  FaroZoneSpanManager create() {
    return FaroZoneSpanManager(
      parentSpanLookup: (key) => Zone.current[key],
      zoneRunner:
          <T>(callback, zoneValues) =>
              runZoned(callback, zoneValues: zoneValues),
    );
  }
}
