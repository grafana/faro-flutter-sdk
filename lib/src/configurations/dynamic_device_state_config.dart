/// Turns the dynamic device and network metadata on or off, one group at a
/// time.
///
/// Every group is on by default. A group that is off adds none of its fields
/// to `meta`, and the SDK does not register the system listeners for it.
class DynamicDeviceStateConfig {
  const DynamicDeviceStateConfig({
    this.battery = true,
    this.thermal = true,
    this.network = true,
  });

  /// `meta.device.battery_level`, `meta.device.is_charging` and
  /// `meta.device.low_power_mode`.
  final bool battery;

  /// `meta.device.thermal_state`.
  final bool thermal;

  /// `meta.network.connection_type`, `meta.network.connection_subtype` and
  /// `meta.network.carrier_name`.
  final bool network;

  /// Whether at least one group is on.
  bool get isAnyEnabled => battery || thermal || network;

  /// The names of the groups that are on, as the native side knows them.
  List<String> get enabledGroups => [
    if (battery) batteryGroup,
    if (thermal) thermalGroup,
    if (network) networkGroup,
  ];

  static const batteryGroup = 'battery';
  static const thermalGroup = 'thermal';
  static const networkGroup = 'network';
}
