import 'dart:async';

import 'package:faro/src/tracing/span.dart';

typedef ParentSpanLookup = dynamic Function(Symbol key);
typedef ZoneRunner = Future<T> Function<T>(
  Future<T> Function() callback,
  Map<Object?, Object?> zoneValues,
);

class FaroZoneSpanManager {
  FaroZoneSpanManager({
    required ParentSpanLookup parentSpanLookup,
    required ZoneRunner zoneRunner,
  })  : _parentSpanLookup = parentSpanLookup,
        _zoneRunner = zoneRunner;

  static const _parentSpanKey = #faroParentSpan;

  final ParentSpanLookup _parentSpanLookup;
  final ZoneRunner _zoneRunner;

  Span? getActiveSpan() {
    final potentialParentSpan = _parentSpanLookup(_parentSpanKey);
    if (potentialParentSpan is Span) {
      return potentialParentSpan;
    }
    return null;
  }

  Future<T> executeWithSpan<T>(
    Span span,
    FutureOr<T> Function(Span) body,
  ) async {
    return _zoneRunner(() async {
      try {
        final result = await body(span);
        span.setStatus(SpanStatusCode.ok);
        return result;
      } catch (error, stackTrace) {
        // If no error was set yet, then the sdk will set it to error.
        if (span.status != SpanStatusCode.error) {
          span.setStatus(
            SpanStatusCode.error,
            message: error.toString(),
          );
        }
        span.recordException(error, stackTrace: stackTrace);
        rethrow;
      } finally {
        span.end();
      }
    }, {
      _parentSpanKey: span,
    });
  }
}

class FaroZoneSpanManagerFactory {
  FaroZoneSpanManager create() {
    return FaroZoneSpanManager(
      parentSpanLookup: (key) => Zone.current[key],
      zoneRunner: <T>(callback, zoneValues) =>
          runZoned(callback, zoneValues: zoneValues),
    );
  }
}
