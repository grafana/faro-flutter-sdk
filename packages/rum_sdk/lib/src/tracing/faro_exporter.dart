import 'package:opentelemetry/sdk.dart' as otel_sdk;
import 'package:rum_sdk/rum_flutter.dart';
import 'package:rum_sdk/src/models/span_record.dart';

class FaroExporter implements otel_sdk.SpanExporter {
  var _isShutdown = false;

  @override
  void export(List<otel_sdk.ReadOnlySpan> spans) {
    if (_isShutdown) {
      return;
    }
    _sendSpansToFaro(spans);
  }

  @override
  void forceFlush() {
    return;
  }

  @override
  void shutdown() {
    _isShutdown = true;
  }

  void _sendSpansToFaro(List<otel_sdk.ReadOnlySpan> spans) {
    final rumFlutter = RumFlutter();

    for (var i = 0; i < spans.length; i++) {
      final otelReadOnlySpan = spans[i];
      final spanRecord = SpanRecord(otelReadOnlySpan: otelReadOnlySpan);

      rumFlutter.pushEvent(
        'faro.tracing.${spanRecord.name()}',
        attributes: spanRecord.getFaroEventAttributes(),
        trace: spanRecord.getFaroSpanContext(),
      );

      rumFlutter.pushSpan(spanRecord);
    }
  }
}
