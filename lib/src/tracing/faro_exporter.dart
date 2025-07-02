import 'package:faro/src/models/models.dart';
import 'package:faro/src/models/span_record.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:opentelemetry/sdk.dart' as otel_sdk;

class FaroExporter implements otel_sdk.SpanExporter {
  FaroExporter({
    required BatchTransportFactory batchTransportFactory,
  }) : _batchTransportFactory = batchTransportFactory;

  var _isShutdown = false;

  final BatchTransportFactory _batchTransportFactory;

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
    for (var i = 0; i < spans.length; i++) {
      final otelReadOnlySpan = spans[i];
      final spanRecord = SpanRecord(otelReadOnlySpan: otelReadOnlySpan);

      _batchTransport?.addEvent(Event(
        spanRecord.getFaroEventName(),
        attributes: spanRecord.getFaroEventAttributes(),
        trace: spanRecord.getFaroSpanContext(),
      ));

      _batchTransport?.addSpan(spanRecord);
    }
  }

  BatchTransport? get _batchTransport => _batchTransportFactory.instance;
}

class FaroExporterFactory {
  FaroExporter create() {
    return FaroExporter(batchTransportFactory: BatchTransportFactory());
  }
}
