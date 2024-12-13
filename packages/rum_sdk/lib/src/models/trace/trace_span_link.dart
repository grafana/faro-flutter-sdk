import 'package:rum_sdk/src/models/trace/trace_attribute.dart';

class TraceSpanLink {
  TraceSpanLink({
    required String traceId,
    required String spanId,
    required String traceState,
    required List<TraceAttribute> attributes,
  })  : _traceId = traceId,
        _spanId = spanId,
        _traceState = traceState,
        _attributes = attributes;

  TraceSpanLink.fromJson(dynamic json) {
    if (json['traceId'] != null) {
      _traceId = json['traceId'];
    }
    if (json['spanId'] != null) {
      _spanId = json['spanId'];
    }
    if (json['traceState'] != null) {
      _traceState = json['traceState'];
    }
    if (json['attributes'] != null) {
      _attributes = [];
      json['attributes'].forEach((dynamic v) {
        _attributes.add(TraceAttribute.fromJson(v));
      });
    }
  }

  String? _traceId;
  String? _spanId;
  String? _traceState;
  List<TraceAttribute> _attributes = [];

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    if (_traceId != null) {
      map['traceId'] = _traceId;
    }
    if (_spanId != null) {
      map['spanId'] = _spanId;
    }
    if (_traceState != null) {
      map['traceState'] = _traceState;
    }
    if (_attributes.isNotEmpty) {
      map['attributes'] = _attributes.map((v) => v.toJson()).toList();
    }

    return map;
  }
}
