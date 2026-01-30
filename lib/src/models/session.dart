class Session {
  Session(this.id, {this.attributes});

  Session.fromJson(dynamic json) {
    id = json['id'] ?? '';
    attributes = json['attributes'] ?? {};
  }
  String? id;
  Map<String, dynamic>? attributes;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['attributes'] = attributes;
    return map;
  }

  /// Creates a JSON representation with all attribute
  /// values converted to strings. Use this for Faro protocol
  /// which requires string values for session attributes.
  Map<String, dynamic> toFaroJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    // Faro protocol requires string values for session attributes
    map['attributes'] = attributes?.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    );
    return map;
  }
}
