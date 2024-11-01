// ignore_for_file: avoid_positional_boolean_parameters

class Browser {
  Browser(this.name, this.version, this.os, this.userAgent, this.language,
      this.mobile);

  Browser.fromJson(dynamic json) {
    name = json['name'];
    version = json['version'];
    os = json['os'];
    userAgent = json['userAgent'];
    language = json['language'];
    mobile = json['mobile'];
  }
  String name = '';
  String version = '';
  String os = '';
  String userAgent = '';
  String language = '';
  bool mobile = false;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['name'] = name;
    map['version'] = version;
    map['os'] = os;
    map['userAgent'] = userAgent;
    map['language'] = language;
    map['mobile'] = mobile;
    return map;
  }
}
