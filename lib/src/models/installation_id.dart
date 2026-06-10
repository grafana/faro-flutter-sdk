/// Stable SDK-generated identifier for this app installation.
///
/// The underlying storage key is still `device_id` so existing installations
/// keep the same stable ID after upgrading.
class InstallationId {
  InstallationId(this._value);

  final String _value;

  @override
  String toString() {
    return _value;
  }
}
