import 'package:equatable/equatable.dart';

/// Represents user information for Faro telemetry.
///
/// Use this class to identify users in your telemetry data.
/// User information is attached to all telemetry events, logs,
/// and traces sent to the Faro collector.
///
/// Example:
/// ```dart
/// Faro().setUser(FaroUser(
///   id: 'user-123',
///   username: 'john.doe',
///   email: 'john@example.com',
/// ));
/// ```
///
/// To explicitly clear any persisted user on app start, use [FaroUser.cleared]:
/// ```dart
/// await Faro.init(
///   config: FaroConfig(
///     initialUser: FaroUser.cleared(),
///   ),
/// );
/// ```
class FaroUser extends Equatable {
  /// Creates a new [FaroUser] with the specified properties.
  ///
  /// All parameters are optional. At minimum, you should provide an [id]
  /// to uniquely identify the user.
  const FaroUser({
    this.id,
    this.username,
    this.email,
  }) : _isCleared = false;

  /// Creates a sentinel value that explicitly clears any persisted user.
  ///
  /// Use this when you want to ensure no user is set on app start,
  /// regardless of any previously persisted user data.
  ///
  /// This is useful for:
  /// - Forcing a "logged out" state on app start
  /// - Testing scenarios
  /// - Apps that detect the user was logged out externally
  const FaroUser.cleared()
      : id = null,
        username = null,
        email = null,
        _isCleared = true;

  /// Creates a [FaroUser] from a JSON map.
  factory FaroUser.fromJson(Map<String, dynamic> json) {
    return FaroUser(
      id: json['id'] as String?,
      username: json['username'] as String?,
      email: json['email'] as String?,
    );
  }

  /// Unique identifier for the user.
  final String? id;

  /// Display name or username.
  final String? username;

  /// User's email address.
  final String? email;

  /// Internal flag to track if this is a cleared sentinel value.
  final bool _isCleared;

  /// Returns true if this represents an explicitly cleared user.
  ///
  /// A cleared user is created via [FaroUser.cleared] and indicates
  /// that any persisted user should be removed.
  bool get isCleared => _isCleared;

  /// Returns true if this user has any identifying information.
  bool get hasData => id != null || username != null || email != null;

  /// Converts this user to a JSON map for serialization.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
    };
  }

  @override
  List<Object?> get props => [id, username, email, _isCleared];

  @override
  String toString() {
    if (_isCleared) return 'FaroUser.cleared()';
    return 'FaroUser(id: $id, username: $username, email: $email)';
  }
}
