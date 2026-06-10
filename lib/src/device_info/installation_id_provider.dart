import 'package:faro/src/models/installation_id.dart';
import 'package:faro/src/util/uuid_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InstallationIdProvider {
  InstallationIdProvider({
    required SharedPreferences sharedPreferences,
    required UuidProvider uuidProvider,
  }) : _sharedPreferences = sharedPreferences,
       _uuidProvider = uuidProvider;

  // Preserve the existing storage key so installation IDs survive SDK upgrades.
  final String _installationIdPrefsKey = 'device_id';

  final SharedPreferences _sharedPreferences;
  final UuidProvider _uuidProvider;

  InstallationId? _installationId;

  Future<InstallationId> getInstallationId() async {
    if (_installationId != null) {
      return _installationId!;
    }

    final storedInstallationId = _sharedPreferences.getString(
      _installationIdPrefsKey,
    );
    final InstallationId installationId;

    if (storedInstallationId != null) {
      installationId = InstallationId(storedInstallationId);
    } else {
      final newInstallationId = _uuidProvider.getUuidV4();
      await _sharedPreferences.setString(
        _installationIdPrefsKey,
        newInstallationId,
      );
      installationId = InstallationId(newInstallationId);
    }

    _installationId = installationId;
    return installationId;
  }
}

class InstallationIdProviderFactory {
  Future<InstallationIdProvider> create() async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final uuidProvider = UuidProviderFactory.create();
    return InstallationIdProvider(
      sharedPreferences: sharedPreferences,
      uuidProvider: uuidProvider,
    );
  }
}
