import 'dart:convert';
import 'dart:developer';

import 'package:faro/src/models/faro_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles persistence of user data between app sessions.
///
/// This class stores user information in SharedPreferences so that
/// it can be restored on the next app start, ensuring early telemetry
/// events include user identification.
class UserPersistence {
  UserPersistence({
    required SharedPreferences sharedPreferences,
  }) : _sharedPreferences = sharedPreferences;

  final SharedPreferences _sharedPreferences;
  static const String _userDataKey = 'faro_persisted_user';

  /// Loads the persisted user from storage.
  ///
  /// Returns the previously saved [FaroUser], or `null` if no user
  /// has been persisted.
  FaroUser? loadUser() {
    try {
      final userJson = _sharedPreferences.getString(_userDataKey);
      if (userJson == null) {
        return null;
      }

      final userData = json.decode(userJson) as Map<String, dynamic>;
      return FaroUser.fromJson(userData);
    } catch (error) {
      log('Faro: Failed to load persisted user: $error');
      return null;
    }
  }

  /// Persists the user to storage.
  ///
  /// If [user] is `null`, any previously persisted user data is cleared.
  Future<void> saveUser(FaroUser? user) async {
    try {
      if (user == null || user.isCleared) {
        await clearUser();
        return;
      }

      final userJson = json.encode(user.toJson());
      await _sharedPreferences.setString(_userDataKey, userJson);
      log('Faro: User data persisted');
    } catch (error) {
      log('Faro: Failed to persist user data: $error');
    }
  }

  /// Clears any persisted user data.
  Future<void> clearUser() async {
    try {
      await _sharedPreferences.remove(_userDataKey);
      log('Faro: Persisted user data cleared');
    } catch (error) {
      log('Faro: Failed to clear persisted user data: $error');
    }
  }

  /// Returns true if there is persisted user data.
  bool hasPersistedUser() {
    return _sharedPreferences.containsKey(_userDataKey);
  }
}

/// Factory for creating [UserPersistence] instances.
class UserPersistenceFactory {
  Future<UserPersistence> create() async {
    final sharedPreferences = await SharedPreferences.getInstance();
    return UserPersistence(sharedPreferences: sharedPreferences);
  }
}
