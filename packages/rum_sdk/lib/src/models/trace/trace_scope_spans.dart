import 'package:rum_sdk/src/models/trace/trace_span.dart';

class TraceScopeSpans {
  TraceScopeSpans({
    required TraceScope scope,
    required List<TraceSpan> spans,
  })  : _scope = scope,
        _spans = spans;

  TraceScopeSpans.fromJson(dynamic json) {
    if (json['scope'] != null) {
      _scope = TraceScope.fromJson(json['scope']);
    }
    if (json['spans'] != null) {
      _spans = [];
      json['spans'].forEach((dynamic v) {
        _spans.add(TraceSpan.fromJson(v));
      });
    }
  }

  TraceScope? _scope;
  TraceScope? get scope => _scope;

  List<TraceSpan> _spans = [];

  int get numberSpans => _spans.length;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (_scope != null) {
      map['scope'] = _scope!.toJson();
    }
    map['spans'] = _spans.map((v) => v.toJson()).toList();
    return map;
  }

  void addSpan(TraceSpan span) {
    _spans.add(span);
  }
}

class TraceScope {
  TraceScope({
    required String name,
    required String version,
  })  : _name = name,
        _version = version;

  TraceScope.fromJson(dynamic json) {
    if (json['name'] != null) {
      _name = json['name'];
    }
    if (json['version'] != null) {
      _version = json['version'];
    }
  }

  String? _name;
  String? _version;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (_name != null) {
      map['name'] = _name;
    }
    if (_version != null) {
      map['version'] = _version;
    }
    return map;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TraceScope &&
        other._name == _name &&
        other._version == _version;
  }

  @override
  int get hashCode => _name.hashCode ^ _version.hashCode;
}
