import 'package:dartypod/dartypod.dart';
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/integrations/http_url_redaction.dart';

/// Internal HTTP URL policy for one Faro initialization.
class HttpUrlRedactionPolicy {
  Set<String> _sensitiveQueryParameters = defaultSensitiveHttpQueryParameters;

  /// Immutable effective names, including all built-in protections.
  Set<String> get sensitiveQueryParameters => _sensitiveQueryParameters;

  /// Installs application additions without retaining caller-owned state.
  void configure(Set<String> additionalNames) {
    _sensitiveQueryParameters = Set.unmodifiable({
      ...defaultSensitiveHttpQueryParameters,
      ...additionalNames,
    });
  }
}

/// Resolving after a test reset returns the default policy again.
final httpUrlRedactionPolicyProvider = Provider<HttpUrlRedactionPolicy>(
  (_) => HttpUrlRedactionPolicy(),
  scope: faroInitScope,
);
