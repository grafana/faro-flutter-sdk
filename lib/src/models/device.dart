class Device {
  Device({
    this.manufacturer,
    this.modelIdentifier,
    this.modelName,
    this.brand,
    this.isPhysical,
    this.type,
    this.arch,
    this.screenWidth,
    this.screenHeight,
    this.screenDensity,
    this.memoryTotal,
  });

  Device.fromJson(dynamic json) {
    manufacturer = json['manufacturer'];
    modelIdentifier = json['model_identifier'];
    modelName = json['model_name'];
    brand = json['brand'];
    isPhysical = json['is_physical'];
    type = json['type'];
    arch = json['arch'];
    screenWidth = json['screen_width'];
    screenHeight = json['screen_height'];
    screenDensity = (json['screen_density'] as num?)?.toDouble();
    memoryTotal = json['memory_total'];
  }

  String? manufacturer;
  String? modelIdentifier;
  String? modelName;
  String? brand;
  bool? isPhysical;
  String? type;

  /// CPU architecture, as the platform reports it, such as "arm64-v8a" on
  /// Android or "arm64" on iOS.
  String? arch;

  /// Screen width in physical pixels, as the OS reports it.
  int? screenWidth;

  /// Screen height in physical pixels, as the OS reports it.
  int? screenHeight;

  /// Physical pixels per density-independent pixel (iOS: per point).
  double? screenDensity;

  /// Total device memory in bytes.
  int? memoryTotal;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (manufacturer != null) {
      map['manufacturer'] = manufacturer;
    }
    if (modelIdentifier != null) {
      map['model_identifier'] = modelIdentifier;
    }
    if (modelName != null) {
      map['model_name'] = modelName;
    }
    if (brand != null) {
      map['brand'] = brand;
    }
    if (isPhysical != null) {
      map['is_physical'] = isPhysical;
    }
    if (type != null) {
      map['type'] = type;
    }
    if (arch != null) {
      map['arch'] = arch;
    }
    if (screenWidth != null) {
      map['screen_width'] = screenWidth;
    }
    if (screenHeight != null) {
      map['screen_height'] = screenHeight;
    }
    if (screenDensity != null) {
      map['screen_density'] = screenDensity;
    }
    if (memoryTotal != null) {
      map['memory_total'] = memoryTotal;
    }
    return map;
  }
}
