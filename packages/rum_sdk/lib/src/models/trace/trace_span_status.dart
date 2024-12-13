class TraceSpanStatus {
  TraceSpanStatus({
    required int code,
    required String? message,
  })  : _code = code,
        _message = message;

  TraceSpanStatus.fromJson(dynamic json) {
    if (json['code'] != null) {
      _code = json['code'];
    }
    if (json['message'] != null) {
      _message = json['message'];
    }
  }

  int? _code;
  String? _message;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (_code != null) {
      map['code'] = _code;
    }
    if (_message != null) {
      map['message'] = _message;
    }
    return map;
  }
}
