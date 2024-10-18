class Session {
  String? id;
  Map<String, dynamic>? attributes;

  Session(this.id, {this.attributes});

  Session.fromJson(dynamic json) {
    id = json['id'] ?? "";
    attributes = json['attributes'] ?? {};
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['attributes'] = attributes;
    return map;
  }
}
