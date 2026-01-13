import 'package:faro/faro.dart';

import 'test_users.dart';

/// Enum representing the initial user options for FaroConfig.
enum InitialUserSetting {
  /// No initial user specified (uses persisted user if available).
  none,

  /// Explicitly clear any persisted user on start.
  cleared,

  /// Start with john.doe user.
  johnDoe,

  /// Start with jane.smith user.
  janeSmith;

  /// Get the FaroUser for this setting, or null if none.
  FaroUser? get faroUser {
    switch (this) {
      case InitialUserSetting.none:
        return null;
      case InitialUserSetting.cleared:
        return const FaroUser.cleared();
      case InitialUserSetting.johnDoe:
        return TestUsers.johnDoe;
      case InitialUserSetting.janeSmith:
        return TestUsers.janeSmith;
    }
  }

  /// Returns the display name for this setting.
  String get displayName {
    switch (this) {
      case InitialUserSetting.none:
        return 'None (use persisted)';
      case InitialUserSetting.cleared:
        return 'Cleared (force no user)';
      case InitialUserSetting.johnDoe:
        return TestUsers.johnDoe.username!;
      case InitialUserSetting.janeSmith:
        return TestUsers.janeSmith.username!;
    }
  }

  /// Returns a subtitle description for this setting.
  String get subtitle {
    switch (this) {
      case InitialUserSetting.none:
        return 'Uses persisted user if persistUser is enabled';
      case InitialUserSetting.cleared:
        return 'Clears any persisted user on start';
      case InitialUserSetting.johnDoe:
        return '${TestUsers.johnDoe.id} / ${TestUsers.johnDoe.email}';
      case InitialUserSetting.janeSmith:
        return '${TestUsers.janeSmith.id} / ${TestUsers.janeSmith.email}';
    }
  }
}
