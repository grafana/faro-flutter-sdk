import 'dart:convert';

import 'package:faro/faro.dart';

/// Configuration parsed from optional QA dart-define keys.
///
/// Reads `FARO_QA_RUN_ID` and `FARO_QA_INITIAL_USER_JSON` from
/// `String.fromEnvironment`, allowing QA smoke tests to inject
/// session attributes and an initial user without patching source code.
///
/// Usage in production code:
/// ```dart
/// final qa = QaConfig.fromEnvironment();
/// ```
///
/// Usage in tests (inject values directly):
/// ```dart
/// final qa = QaConfig.parse(qaRunId: 'run-42');
/// ```
class QaConfig {
  const QaConfig._({this.runId, this.initialUser});

  /// A QA-assigned run identifier included in session attributes.
  final String? runId;

  /// A [FaroUser] parsed from JSON, used as `initialUser` when present.
  final FaroUser? initialUser;

  /// Whether a QA run ID was provided.
  bool get hasRunId => runId != null && runId!.isNotEmpty;

  /// Whether a QA initial user was provided.
  bool get hasInitialUser => initialUser != null;

  /// Reads QA config from compile-time dart-define environment variables.
  ///
  /// Equivalent to `parse()` with defaults wired to `String.fromEnvironment`.
  static QaConfig fromEnvironment() {
    return parse(
      qaRunId: const String.fromEnvironment('FARO_QA_RUN_ID'),
      qaInitialUserJson: const String.fromEnvironment(
        'FARO_QA_INITIAL_USER_JSON',
      ),
    );
  }

  /// Parses QA configuration from raw string values.
  ///
  /// Empty strings are treated as "not provided".
  /// Invalid JSON in [qaInitialUserJson] is silently ignored (returns
  /// a config with no initial user).
  static QaConfig parse({String qaRunId = '', String qaInitialUserJson = ''}) {
    final runId = qaRunId.isNotEmpty ? qaRunId : null;
    final user = _parseUser(qaInitialUserJson);
    return QaConfig._(runId: runId, initialUser: user);
  }

  static FaroUser? _parseUser(String json) {
    if (json.isEmpty) return null;

    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return null;

      return FaroUser(
        id: decoded['id'] is String ? decoded['id'] as String : null,
        username: decoded['username'] is String
            ? decoded['username'] as String
            : null,
        email: decoded['email'] is String ? decoded['email'] as String : null,
        attributes: _parseAttributes(decoded['attributes']),
      );
    } on FormatException {
      return null;
    }
  }

  /// Converts an attributes map to `Map<String, String>`, coercing
  /// primitive values (bool, int, double) to their string representation.
  static Map<String, String>? _parseAttributes(dynamic raw) {
    if (raw == null) return null;
    if (raw is! Map) return null;

    return raw.map<String, String>(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }
}
