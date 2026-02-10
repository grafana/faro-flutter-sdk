class Sdk {
  Sdk(this.name, this.version);

  Sdk.fromJson(dynamic json) {
    name = json['name'];
    version = json['version'];
  }
  String name = '';
  String version = '';

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['name'] = name;
    map['version'] = version;
    return map;
  }
}
