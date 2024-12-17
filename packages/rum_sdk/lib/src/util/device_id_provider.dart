import 'package:rum_sdk/src/models/device_id.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdProvider {
  DeviceIdProvider({
    required SharedPreferences sharedPreferences,
  }) : _sharedPreferences = sharedPreferences;

  final String _deviceIdPrefsKey = 'device_id';
  final SharedPreferences _sharedPreferences;
  DeviceId? _deviceId;

  Future<DeviceId> getDeviceId() async {
    if (_deviceId != null) {
      return _deviceId!;
    }

    final storedDeviceId = _sharedPreferences.getString(_deviceIdPrefsKey);
    final DeviceId deviceId;

    if (storedDeviceId != null) {
      deviceId = DeviceId(storedDeviceId);
    } else {
      final newDeviceId = const Uuid().v4();
      await _sharedPreferences.setString(_deviceIdPrefsKey, newDeviceId);
      deviceId = DeviceId(newDeviceId);
    }

    _deviceId = deviceId;
    return deviceId;
  }
}

class DeviceIdProviderFactory {
  Future<DeviceIdProvider> getDeviceIdProvider() async {
    final sharedPreferences = await SharedPreferences.getInstance();
    return DeviceIdProvider(sharedPreferences: sharedPreferences);
  }
}
