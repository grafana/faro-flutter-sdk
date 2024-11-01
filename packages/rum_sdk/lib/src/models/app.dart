class App {
  App(this.name, this.environment, this.version);

  App.fromJson(dynamic json) {
    name = json['name'];
    version = json['version'];
    environment = json['environment'];
  }
  String? name;
  String? version;
  String? environment;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    map['name'] = name;
    map['version'] = version;
    map['environment'] = environment;

    return map;
  }
}
