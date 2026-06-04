class Device {
  Device({
    this.manufacturer,
    this.modelIdentifier,
    this.modelName,
    this.brand,
    this.isPhysical,
    this.type,
  });

  Device.fromJson(dynamic json) {
    manufacturer = json['manufacturer'];
    modelIdentifier = json['model_identifier'];
    modelName = json['model_name'];
    brand = json['brand'];
    isPhysical = json['is_physical'];
    type = json['type'];
  }

  String? manufacturer;
  String? modelIdentifier;
  String? modelName;
  String? brand;
  bool? isPhysical;
  String? type;

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
    return map;
  }
}
