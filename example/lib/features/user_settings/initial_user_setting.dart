import 'package:faro/faro.dart';

import 'test_users.dart';

/// Enum representing the initial user options for FaroConfig.
enum InitialUserSetting {
  /// No initial user specified (uses persisted user if available).
  none('None (use persisted)'),

  /// Explicitly clear any persisted user on start.
  cleared('Cleared (force no user)'),

  /// Start with john.doe user.
  johnDoe('john.doe'),

  /// Start with jane.smith user.
  janeSmith('jane.smith');

  const InitialUserSetting(this.displayName);

  final String displayName;

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

  /// Returns a subtitle description for this setting.
  String get subtitle {
    switch (this) {
      case InitialUserSetting.none:
        return 'Uses persisted user if persistUser is enabled';
      case InitialUserSetting.cleared:
        return 'Clears any persisted user on start';
      case InitialUserSetting.johnDoe:
        return 'user-123 / john.doe@example.com';
      case InitialUserSetting.janeSmith:
        return 'user-456 / jane.smith@example.com';
    }
  }
}
