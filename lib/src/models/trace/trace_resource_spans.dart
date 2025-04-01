import 'package:faro/src/models/span_record.dart';
import 'package:faro/src/models/trace/trace_resource.dart';
import 'package:faro/src/models/trace/trace_scope_spans.dart';

class TraceResourceSpans {
  TraceResourceSpans();

  TraceResourceSpans.fromJson(dynamic json) {
    if (json['resource'] != null) {
      _resource = TraceResource.fromJson(json['resource']);
    }
    if (json['scopeSpans'] != null) {
      _scopeSpansMap = {};
      json['scopeSpans'].forEach((dynamic v) {
        final scopeSpans = TraceScopeSpans.fromJson(v);
        _scopeSpansMap[scopeSpans.scope!] = scopeSpans;
      });
    }
  }

  TraceResource? _resource;
  Map<TraceScope, TraceScopeSpans> _scopeSpansMap = {};

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (_resource != null) {
      map['resource'] = _resource!.toJson();
    }
    final scopeSpansList = _scopeSpansMap.values.toList();
    if (scopeSpansList.isNotEmpty) {
      map['scopeSpans'] = scopeSpansList.map((v) => v.toJson()).toList();
    }
    return map;
  }

  int numberSpans() {
    return _scopeSpansMap.values
        .fold(0, (total, spanScope) => total + spanScope.numberSpans);
  }

  void resetSpans() {
    _scopeSpansMap = {};
  }

  void addSpan(SpanRecord spanRecord) {
    _resource ??= spanRecord.getResource();

    final scope = spanRecord.getScope();
    final span = spanRecord.getSpan();

    final scopeSpans =
        _scopeSpansMap[scope] ?? TraceScopeSpans(scope: scope, spans: []);
    scopeSpans.addSpan(span);
    _scopeSpansMap[scope] = scopeSpans;
  }
}
