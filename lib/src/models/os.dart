class Os {
  Os({this.name, this.version, this.buildId, this.detail});

  Os.fromJson(dynamic json) {
    name = json['name'];
    version = json['version'];
    buildId = json['build_id'];
    detail = json['detail'];
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
  /// Example: Android build ID like "CP21.260330.005".
  String? buildId;

  /// Human-readable operating system detail.
  ///
  /// Examples: "Android 17 (SDK 36)", "iOS 18.1".
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
