import 'package:faro/src/models/faro_user.dart';
import 'package:faro/src/user/user_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Callback signature for when user metadata should be applied.
///
/// The [userJson] contains the user data in the format expected by Meta:
/// `{'id': ..., 'username': ..., 'email': ...}`.
typedef OnUserMetaApplied = void Function(Map<String, dynamic> userJson);

/// Callback signature for pushing internal events.
typedef OnPushEvent = void Function(String eventName);

/// Manages user identity for Faro telemetry.
///
/// This class encapsulates all user-related operations including:
/// - Setting and clearing user identity
/// - Persisting user data between app sessions
/// - Initializing user state on app start
///
/// The [UserManager] uses callbacks to communicate with the Faro instance,
/// avoiding circular dependencies while maintaining clean separation.
class UserManager {
  /// Creates a [UserManager] with the required dependencies.
  ///
  /// - [persistence]: Handles storing user data between sessions (optional)
  /// - [onUserMetaApplied]: Called with user JSON to apply to telemetry meta
  /// - [onPushEvent]: Called when an internal event should be pushed
  UserManager({
    required UserPersistence? persistence,
    required OnUserMetaApplied onUserMetaApplied,
    required OnPushEvent onPushEvent,
  })  : _persistence = persistence,
        _onUserMetaApplied = onUserMetaApplied,
        _onPushEvent = onPushEvent;

  final UserPersistence? _persistence;
  final OnUserMetaApplied _onUserMetaApplied;
  final OnPushEvent _onPushEvent;

  FaroUser? _currentUser;

  /// The currently set user, or null if no user is set.
  FaroUser? get currentUser => _currentUser;

  /// Sets the user for all subsequent telemetry.
  ///
  /// The user information will be attached to all logs, events, exceptions,
  /// and traces sent to the Faro collector.
  ///
  /// If [persistUser] is true, the user will be persisted and automatically
  /// restored on the next app start. If false, any previously persisted user
  /// data will be cleared to prevent stale data.
  ///
  /// To clear the user, pass [FaroUser.cleared].
  ///
  /// Returns a [Future] that completes when persistence is done. Callers can
  /// await this if they need to ensure persistence order, or ignore it for
  /// fire-and-forget behavior.
  Future<void> setUser(FaroUser user, {required bool persistUser}) async {
    // Normalize cleared user to null for comparison and persistence
    final effectiveUser = user.isCleared ? null : user;

    // Early exit if user hasn't changed
    if (effectiveUser == _currentUser) {
      return;
    }

    _currentUser = effectiveUser;

    // Always apply user meta (matching original setUserMeta behavior)
    _onUserMetaApplied(_createUserJson(user));

    // Handle persistence
    if (effectiveUser == null) {
      await _persistence?.clearUser();
    } else if (persistUser) {
      await _persistence?.saveUser(effectiveUser);
    } else {
      // Clear stale data when persistence is disabled
      await _persistence?.clearUser();
    }

    _onPushEvent('faro_internal_user_updated');
  }

  /// Creates user JSON in the format expected by Meta.
  Map<String, dynamic> _createUserJson(FaroUser user) {
    return user.toJson();
  }

  /// Initializes user based on config precedence rules.
  ///
  /// Precedence:
  /// 1. If [initialUser] is provided, use it (cleared means no user)
  /// 2. Else if persistence enabled and persisted user exists, restore it
  /// 3. Else no user
  ///
  /// When [persistUser] is false, any previously persisted user data will be
  /// cleared to prevent stale data from reappearing if persistence is
  /// re-enabled later.
  ///
  /// This method should be called during SDK initialization.
  Future<void> initialize({
    FaroUser? initialUser,
    required bool persistUser,
  }) async {
    final isCleared = initialUser?.isCleared ?? false;

    // Clear persisted data if:
    // - persistence is disabled (clean up stale data), OR
    // - initialUser is explicitly cleared
    if (!persistUser || isCleared) {
      await _persistence?.clearUser();
    }

    // Apply user based on precedence
    if (initialUser != null && !isCleared) {
      // Explicit user provided - use it
      _currentUser = initialUser;
      _onUserMetaApplied(_createUserJson(initialUser));
      if (persistUser) {
        await _persistence?.saveUser(initialUser);
      }
    } else if (initialUser == null && persistUser) {
      // No explicit user, persistence enabled - try to restore
      final persistedUser = _persistence?.loadUser();
      if (persistedUser != null) {
        _currentUser = persistedUser;
        _onUserMetaApplied(_createUserJson(persistedUser));
      }
    } else if (isCleared) {
      // Explicitly cleared - no user to apply
      _currentUser = null;
    }
    // If null user + !persistUser: already cleared, nothing to apply
  }
}

/// Factory for creating [UserManager] instances.
///
/// Handles the async creation of [UserPersistence] and wires up
/// the callbacks to the Faro instance.
class UserManagerFactory {
  /// Creates a [UserManager] with persistence.
  ///
  /// The [UserManager] always has access to persistence so it can clean up
  /// stale data when persistence is disabled in the config.
  ///
  /// Pass the callbacks that will be used to communicate
  /// user changes back to the Faro instance.
  Future<UserManager> create({
    required OnUserMetaApplied onUserMetaApplied,
    required OnPushEvent onPushEvent,
  }) async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final persistence = UserPersistence(sharedPreferences: sharedPreferences);
    return UserManager(
      persistence: persistence,
      onUserMetaApplied: onUserMetaApplied,
      onPushEvent: onPushEvent,
    );
  }
}
