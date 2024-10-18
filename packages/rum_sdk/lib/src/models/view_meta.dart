class ViewMeta {
  String? name;

  ViewMeta(this.name);

  ViewMeta.fromJson(dynamic json) {
    name = json['name'] ?? "";
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    map['name'] = name;

    return map;
  }
}