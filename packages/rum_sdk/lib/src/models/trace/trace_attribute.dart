class TraceAttribute {
  TraceAttribute({
    required String key,
    required TraceAttributeValue value,
  })  : _key = key,
        _value = value;

  TraceAttribute.fromJson(dynamic json) {
    if (json['key'] != null) {
      _key = json['key'];
    }
    if (json['value'] != null) {
      _value = TraceAttributeValue.fromJson(json['value']);
    }
  }
  String? _key;
  TraceAttributeValue? _value;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (_key != null && _value != null) {
      map['key'] = _key;
      map['value'] = _value!.toJson();
    }
    return map;
  }
}

class TraceAttributeValue {
  TraceAttributeValue({
    required String stringValue,
  }) : _stringValue = stringValue;

  TraceAttributeValue.fromJson(dynamic json) {
    if (json['stringValue'] != null) {
      _stringValue = json['stringValue'];
    }
  }

  String? _stringValue;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (_stringValue != null) {
      map['stringValue'] = _stringValue;
    }
    return map;
  }
}
