class App {
  App({
    this.name,
    this.environment,
    this.version,
    this.namespace,
  });

  App.fromJson(dynamic json) {
    name = json['name'];
    version = json['version'];
    environment = json['environment'];
    namespace = json['namespace'];
  }
  String? name;
  String? version;
  String? environment;
  String? namespace;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    map['name'] = name;
    map['version'] = version;
    map['environment'] = environment;
    map['namespace'] = namespace;

    return map;
  }
}
