import 'integrations.dart';

class Sdk {
  String name = "";
  String version = "";
  List<Integration> integrations = [];

  Sdk(this.name, this.version, this.integrations);

  Sdk.fromJson(dynamic json) {
    name = json['name'];
    version = json['version'];
    if (json['integrations'] != null) {
      integrations = [];
      json['integrations'].forEach((v) {
        integrations.add(Integration.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['name'] = name;
    map['version'] = version;
    map['integrations'] = integrations.map((v) => v.toJson()).toList();
    return map;
  }
}
