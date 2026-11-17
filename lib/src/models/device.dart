class Device {
  Device({
    this.manufacturer,
    this.modelIdentifier,
    this.modelName,
    this.brand,
    this.isPhysical,
    this.arch,
    this.screenWidth,
    this.screenHeight,
    this.screenDensity,
    this.memoryTotal,
    this.batteryLevel,
    this.isCharging,
    this.lowPowerMode,
    this.thermalState,
  });

  Device.fromJson(dynamic json) {
    manufacturer = json['manufacturer'];
    modelIdentifier = json['model_identifier'];
    modelName = json['model_name'];
    brand = json['brand'];
    isPhysical = json['is_physical'];
    arch = json['arch'];
    screenWidth = json['screen_width'];
    screenHeight = json['screen_height'];
    screenDensity = (json['screen_density'] as num?)?.toDouble();
    memoryTotal = json['memory_total'];
    batteryLevel = json['battery_level'];
    isCharging = json['is_charging'];
    lowPowerMode = json['low_power_mode'];
    thermalState = json['thermal_state'];
  }

  String? manufacturer;
  String? modelIdentifier;
  String? modelName;
  String? brand;
  bool? isPhysical;

  /// CPU architecture, as the platform reports it, such as "arm64-v8a" on
  /// Android or "arm64" on iOS.
  String? arch;

  /// Screen width in physical pixels, as the OS reports it.
  int? screenWidth;

  /// Screen height in physical pixels, as the OS reports it.
  int? screenHeight;

  /// Physical pixels per density-independent pixel (iOS: per point).
  double? screenDensity;

  /// Total device memory in whole MB, where 1 MB is 1,048,576 bytes.
  int? memoryTotal;

  /// Battery level as a whole percent from 0 to 100.
  int? batteryLevel;

  /// Whether the device is connected to power: AC, USB or wireless, charging
  /// or full.
  bool? isCharging;

  /// Whether Android battery saver or iOS Low Power Mode is on.
  bool? lowPowerMode;

  /// Thermal state: "nominal", "fair", "serious" or "critical".
  String? thermalState;

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
    if (batteryLevel != null) {
      map['battery_level'] = batteryLevel;
    }
    if (isCharging != null) {
      map['is_charging'] = isCharging;
    }
    if (lowPowerMode != null) {
      map['low_power_mode'] = lowPowerMode;
    }
    if (thermalState != null) {
      map['thermal_state'] = thermalState;
    }
    return map;
  }
}
