import 'package:rum_sdk/src/models/trace/trace_attribute.dart';

class TraceResource {
  TraceResource({
    required List<TraceAttribute> attributes,
  }) : _attributes = attributes;

  TraceResource.fromJson(dynamic json) {
    if (json['attributes'] != null) {
      _attributes = [];
      json['attributes'].forEach((dynamic v) {
        _attributes.add(TraceAttribute.fromJson(v));
      });
    }
  }

  List<TraceAttribute> _attributes = [];

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['attributes'] = _attributes.map((v) => v.toJson()).toList();
    return map;
  }
}
