import 'package:rum_sdk/src/models/device_id.dart';
import 'package:rum_sdk/src/util/uuid_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdProvider {
  DeviceIdProvider({
    required SharedPreferences sharedPreferences,
    required UuidProvider uuidProvider,
  })  : _sharedPreferences = sharedPreferences,
        _uuidProvider = uuidProvider;

  final String _deviceIdPrefsKey = 'device_id';

  final SharedPreferences _sharedPreferences;
  final UuidProvider _uuidProvider;

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
      final newDeviceId = _uuidProvider.getUuidV4();
      await _sharedPreferences.setString(_deviceIdPrefsKey, newDeviceId);
      deviceId = DeviceId(newDeviceId);
    }

    _deviceId = deviceId;
    return deviceId;
  }
}

class DeviceIdProviderFactory {
  Future<DeviceIdProvider> create() async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final uuidProvider = UuidProviderFactory.create();
    return DeviceIdProvider(
      sharedPreferences: sharedPreferences,
      uuidProvider: uuidProvider,
    );
  }
}
