import 'package:faro/faro.dart';

/// Predefined test users for the example app.
abstract class TestUsers {
  /// John Doe - a designer with user role.
  static const johnDoe = FaroUser(
    id: 'user-123',
    username: 'john.doe',
    email: 'john.doe@example.com',
    attributes: {
      'role': 'user',
      'department': 'design',
    },
  );

  /// Jane Smith - an engineer with admin role.
  static const janeSmith = FaroUser(
    id: 'user-456',
    username: 'jane.smith',
    email: 'jane.smith@example.com',
    attributes: {
      'role': 'admin',
      'department': 'engineering',
    },
  );
}
