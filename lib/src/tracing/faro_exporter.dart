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
    final batchTransport = _batchTransport;
    if (batchTransport == null) {
      return;
    }

    for (final otelReadOnlySpan in spans) {
      final spanRecord = SpanRecord(otelReadOnlySpan: otelReadOnlySpan);

      batchTransport.addEvent(Event(
        spanRecord.getFaroEventName(),
        attributes: spanRecord.getFaroEventAttributes(),
        trace: spanRecord.getFaroSpanContext(),
      ));

      batchTransport.addSpan(spanRecord);
    }
  }

  BatchTransport? get _batchTransport => _batchTransportFactory.instance;
}

class FaroExporterFactory {
  FaroExporter create() {
    return FaroExporter(batchTransportFactory: BatchTransportFactory());
  }
}
