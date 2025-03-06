import 'package:fixnum/fixnum.dart';
import 'package:faro/src/models/trace/trace_attribute.dart';

class TraceSpanEvent {
  TraceSpanEvent({
    required String name,
    required Int64 timeUnixNano,
    required int droppedAttributesCount,
    required List<TraceAttribute> attributes,
  })  : _name = name,
        _timeUnixNano = timeUnixNano.toString(),
        _droppedAttributesCount = droppedAttributesCount,
        _attributes = attributes;

  TraceSpanEvent.fromJson(dynamic json) {
    if (json['name'] != null) {
      _name = json['name'];
    }
    if (json['timeUnixNano'] != null) {
      _timeUnixNano = json['timeUnixNano'];
    }
    if (json['droppedAttributesCount'] != null) {
      _droppedAttributesCount = json['droppedAttributesCount'];
    }
    if (json['attributes'] != null) {
      _attributes = [];
      json['attributes'].forEach((dynamic v) {
        _attributes.add(TraceAttribute.fromJson(v));
      });
    }
  }

  String? _name;
  String? _timeUnixNano;
  int? _droppedAttributesCount;
  List<TraceAttribute> _attributes = [];

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    if (_name != null) {
      map['name'] = _name;
    }
    if (_timeUnixNano != null) {
      map['timeUnixNano'] = _timeUnixNano;
    }
    if (_droppedAttributesCount != null) {
      map['droppedAttributesCount'] = _droppedAttributesCount;
    }
    map['attributes'] = _attributes.map((v) => v.toJson()).toList();

    return map;
  }
}
