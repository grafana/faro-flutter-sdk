class Os {
  Os({this.name, this.version, this.buildId, this.detail, this.apiLevel});

  Os.fromJson(dynamic json) {
    name = json['name'];
    version = json['version'];
    buildId = json['build_id'];
    detail = json['detail'];
    apiLevel = json['api_level'];
  }

  /// Operating system name.
  ///
  /// Examples: "Android", "iOS", "iPadOS".
  String? name;

  /// Operating system version.
  ///
  /// Examples: "17", "18.1".
  String? version;

  /// Operating system build identifier, when available.
  ///
  /// Examples: Android build ID like "CP21.260330.005", iOS build number like
  /// "24A437".
  String? buildId;

  /// Human-readable operating system detail.
  ///
  /// Examples: "Android 17 (SDK 36)", "iOS 18.1".
  String? detail;

  /// Android API level.
  ///
  /// Example: 35. Omitted on iOS.
  int? apiLevel;

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
    if (apiLevel != null) {
      map['api_level'] = apiLevel;
    }
    return map;
  }
}
