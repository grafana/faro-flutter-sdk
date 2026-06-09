class Os {
  Os({this.name, this.version, this.buildId, this.detail});

  Os.fromJson(dynamic json) {
    name = json['name'];
    version = json['version'];
    buildId = json['build_id'];
    detail = json['detail'];
  }

  String? name;
  String? version;
  String? buildId;
  String? detail;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (name != null) {
      map['name'] = name;
    }
    if (version != null) {
      map['version'] = version;
    }
    if (buildId != null) {
      map['build_id'] = buildId;
    }
    if (detail != null) {
      map['detail'] = detail;
    }
    return map;
  }
}
