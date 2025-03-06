import 'package:fixnum/fixnum.dart';
import 'package:faro/src/models/trace/trace_attribute.dart';
import 'package:faro/src/models/trace/trace_span_event.dart';
import 'package:faro/src/models/trace/trace_span_link.dart';
import 'package:faro/src/models/trace/trace_span_status.dart';

class TraceSpan {
  TraceSpan({
    required String traceId,
    required String spanId,
    required String? parentSpanId,
    required String name,
    required int kind,
    required Int64 startTimeUnixNano,
    required Int64? endTimeUnixNano,
    required List<TraceAttribute> attributes,
    required TraceSpanStatus status,
    required List<TraceSpanEvent> events,
    required int droppedEventsCount,
    required List<TraceSpanLink> links,
  })  : _traceId = traceId,
        _spanId = spanId,
        _parentSpanId = parentSpanId,
        _name = name,
        _kind = kind,
        _startTimeUnixNano = startTimeUnixNano.toString(),
        _endTimeUnixNano = endTimeUnixNano.toString(),
        _attributes = attributes,
        _status = status,
        _events = events,
        _droppedEventsCount = droppedEventsCount,
        _links = links;

  TraceSpan.fromJson(dynamic json) {
    if (json['traceId'] != null) {
      _traceId = json['traceId'];
    }
    if (json['spanId'] != null) {
      _spanId = json['spanId'];
    }
    if (json['parentSpanId'] != null) {
      _parentSpanId = json['parentSpanId'];
    }
    if (json['name'] != null) {
      _name = json['name'];
    }
    if (json['kind'] != null) {
      _kind = json['kind'];
    }
    if (json['startTimeUnixNano'] != null) {
      _startTimeUnixNano = json['startTimeUnixNano'];
    }
    if (json['endTimeUnixNano'] != null) {
      _endTimeUnixNano = json['endTimeUnixNano'];
    }
    if (json['attributes'] != null) {
      _attributes = [];
      json['attributes'].forEach((dynamic v) {
        _attributes.add(TraceAttribute.fromJson(v));
      });
    }
    if (json['status'] != null) {
      _status = TraceSpanStatus.fromJson(json['status']);
    }
    if (json['events'] != null) {
      _events = [];
      json['events'].forEach((dynamic v) {
        _events.add(TraceSpanEvent.fromJson(v));
      });
    }
    if (json['droppedEventsCount'] != null) {
      _droppedEventsCount = json['droppedEventsCount'];
    }
    if (json['links'] != null) {
      _links = [];
      json['links'].forEach((dynamic v) {
        _links.add(TraceSpanLink.fromJson(v));
      });
    }
  }

  String? _traceId;
  String? _spanId;
  String? _parentSpanId;
  String? _name;
  int? _kind;
  String? _startTimeUnixNano;
  String? _endTimeUnixNano;
  List<TraceAttribute> _attributes = [];
  TraceSpanStatus? _status;
  List<TraceSpanEvent> _events = [];
  int? _droppedEventsCount;
  List<TraceSpanLink> _links = [];

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    if (_traceId != null) {
      map['traceId'] = _traceId;
    }
    if (_spanId != null) {
      map['spanId'] = _spanId;
    }
    if (_parentSpanId != null) {
      map['parentSpanId'] = _parentSpanId;
    }
    if (_name != null) {
      map['name'] = _name;
    }
    if (_kind != null) {
      map['kind'] = _kind;
    }
    if (_startTimeUnixNano != null) {
      map['startTimeUnixNano'] = _startTimeUnixNano;
    }
    if (_endTimeUnixNano != null) {
      map['endTimeUnixNano'] = _endTimeUnixNano;
    }
    if (_attributes.isNotEmpty) {
      map['attributes'] = _attributes.map((v) => v.toJson()).toList();
    }
    if (_status != null) {
      map['status'] = _status!.toJson();
    }
    map['events'] = _events.map((v) => v.toJson()).toList();
    if (_droppedEventsCount != null) {
      map['droppedEventsCount'] = _droppedEventsCount;
    }
    map['links'] = _links.map((v) => v.toJson()).toList();

    return map;
  }
}
