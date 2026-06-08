/// Stable SDK-generated identifier for this app installation.
///
/// This is still named DeviceId for legacy API compatibility, but it is emitted
/// as app.installationId in Faro payloads.
class DeviceId {
  DeviceId(this._value);

  final String _value;

  @override
  String toString() {
    return _value;
  }
}
