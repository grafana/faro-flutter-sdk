class Event {
  Event(this.name, {this.attributes, this.trace});

  Event.fromJson(dynamic json) {
    name = json['name'];
    domain = json['domain'];
    attributes = json['attributes'];
    timestamp = json['timestamp'];
    trace = json['trace'];
  }
  String name = '';
  String domain = 'flutter';
  Map<String, dynamic>? attributes = {};
  Map<String, dynamic>? trace = {};
  String timestamp = DateTime.now().toUtc().toIso8601String();

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    map['name'] = name;
    map['domain'] = domain;
    map['timestamp'] = timestamp;
    map['attributes'] = attributes;

    if (trace != null) {
      map['trace'] = trace;
    }

    return map;
  }
}
