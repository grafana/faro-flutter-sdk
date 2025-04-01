import 'package:faro/src/models/span_record.dart';
import 'package:faro/src/models/trace/trace_resource_spans.dart';

class Traces {
  Traces();

  Traces.fromJson(dynamic json) {
    if (json['resourceSpans'] != null) {
      _resourceSpans = [];
      json['resourceSpans'].forEach((dynamic v) {
        _resourceSpans.add(TraceResourceSpans.fromJson(v));
      });
    }
  }

  List<TraceResourceSpans> _resourceSpans = [];

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['resourceSpans'] = _resourceSpans.map((v) => v.toJson()).toList();
    return map;
  }

  bool hasTraces() {
    return numberSpans() > 0;
  }

  bool hasNoTraces() {
    return hasTraces() == false;
  }

  int numberSpans() {
    return _resourceSpans.fold(0, (total, resourceSpans) {
      return total + resourceSpans.numberSpans();
    });
  }

  void resetSpans() {
    for (final resourceSpans in _resourceSpans) {
      resourceSpans.resetSpans();
    }
  }

  void addSpan(SpanRecord spanRecord) {
    if (_resourceSpans.isEmpty) {
      _resourceSpans.add(TraceResourceSpans());
    }

    for (final resourceSpans in _resourceSpans) {
      resourceSpans.addSpan(spanRecord);
    }
  }
}
