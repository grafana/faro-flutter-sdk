/// Network state of the device. Values are current when a signal is sent.
class Network {
  Network({this.connectionType, this.connectionSubtype, this.carrierName});

  Network.fromJson(dynamic json) {
    connectionType = json['connection_type'];
    connectionSubtype = json['connection_subtype'];
    carrierName = json['carrier_name'];
  }

  /// Connection type, as OpenTelemetry `network.connection.type` names it:
  /// "wifi", "cell", "wired", "unavailable" or "unknown".
  String? connectionType;

  /// Cellular technology, as OpenTelemetry `network.connection.subtype` names
  /// it, such as "lte" or "nr".
  String? connectionSubtype;

  /// Mobile carrier name. Android only.
  String? carrierName;

  bool get isEmpty =>
      connectionType == null &&
      connectionSubtype == null &&
      carrierName == null;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (connectionType != null) {
      map['connection_type'] = connectionType;
    }
    if (connectionSubtype != null) {
      map['connection_subtype'] = connectionSubtype;
    }
    if (carrierName != null) {
      map['carrier_name'] = carrierName;
    }
    return map;
  }
}
