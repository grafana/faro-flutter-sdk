import 'package:faro/faro.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'initial_user_setting.dart';

/// Service for managing user settings stored in SharedPreferences.
///
/// This is a singleton that handles loading and saving user-related
/// settings that are passed to FaroConfig on app startup.
class UserSettingsService {
  UserSettingsService._();

  static final UserSettingsService _instance = UserSettingsService._();

  /// Returns the singleton instance.
  static UserSettingsService get instance => _instance;

  static const String _initialUserKey = 'faro_initial_user_setting';
  static const String _persistUserKey = 'faro_persist_user_setting';

  SharedPreferences? _prefs;

  /// Initializes the service by loading SharedPreferences.
  ///
  /// Must be called before using any other methods.
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Ensures the service is initialized.
  void _ensureInitialized() {
    if (_prefs == null) {
      throw StateError(
        'UserSettingsService not initialized. Call init() first.',
      );
    }
  }

  // ===========================================================================
  // Initial User Setting
  // ===========================================================================

  /// Gets the current initial user setting.
  InitialUserSetting get initialUserSetting {
    _ensureInitialized();
    final storedName = _prefs!.getString(_initialUserKey);
    if (storedName == null) {
      return InitialUserSetting.none;
    }
    return InitialUserSetting.values.firstWhere(
      (e) => e.name == storedName,
      orElse: () => InitialUserSetting.none,
    );
  }

  /// Gets the FaroUser for the current initial user setting.
  FaroUser? get initialUser => initialUserSetting.faroUser;

  /// Sets the initial user setting.
  Future<void> setInitialUserSetting(InitialUserSetting setting) async {
    _ensureInitialized();
    if (setting == InitialUserSetting.none) {
      await _prefs!.remove(_initialUserKey);
    } else {
      await _prefs!.setString(_initialUserKey, setting.name);
    }
  }

  // ===========================================================================
  // Persist User Setting
  // ===========================================================================

  /// Gets the saved persist user setting (for next app start).
  ///
  /// Defaults to `true` if not set.
  bool get persistUser {
    _ensureInitialized();
    return _prefs!.getBool(_persistUserKey) ?? true;
  }

  /// Gets the current session's persist user setting from Faro config.
  ///
  /// This is the value that was passed to FaroConfig on app start.
  bool get currentSessionPersistUser => Faro().config?.persistUser ?? true;

  /// Returns true if the saved persist user setting differs from the
  /// current session's setting (meaning a restart is needed).
  bool get persistUserNeedsRestart => persistUser != currentSessionPersistUser;

  /// Sets the persist user setting.
  Future<void> setPersistUser(bool value) async {
    _ensureInitialized();
    await _prefs!.setBool(_persistUserKey, value);
  }

  // ===========================================================================
  // Current User Display
  // ===========================================================================

  /// Gets a display string for the current Faro user.
  String getCurrentUserDisplay() {
    final user = Faro().meta.user;
    if (user == null ||
        (user.id == null && user.username == null && user.email == null)) {
      return 'Not set';
    }
    return user.username ?? user.id ?? user.email ?? 'Set';
  }
}
