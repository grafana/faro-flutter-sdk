/// Built-in sensitive query names, always retained by the HTTP policy.
const defaultSensitiveHttpQueryParameters = <String>{
  // OpenTelemetry default sensitive query keys.
  'X-Amz-Signature',
  'X-Amz-Credential',
  'X-Amz-Security-Token',
  'AWSAccessKeyId',
  'Signature',
  'sig',
  'X-Goog-Signature',
  // Additional Faro defaults for common application credentials.
  'token',
  'access_token',
  'refresh_token',
  'api_key',
  'apikey',
  'password',
  'client_secret',
};

/// Redacts HTTP span, event and fallback error-log URLs.
/// The request URL is unchanged.
///
/// OTel HTTP client URL redaction rules (the query-key list is Development):
/// https://opentelemetry.io/docs/specs/semconv/http/http-spans/#http-client-span
/// Preserves the encoding/order of non-sensitive query parameters.
String redactHttpUrl(
  Uri url, {
  Set<String> sensitiveQueryParameters = defaultSensitiveHttpQueryParameters,
}) {
  final query = url.query
      .split('&')
      .map((part) {
        // Empty separators are not query parameters with an empty name.
        if (part.isEmpty) return part;
        final separator = part.indexOf('=');
        final key = separator < 0 ? part : part.substring(0, separator);
        try {
          if (sensitiveQueryParameters.contains(
            Uri.decodeQueryComponent(key),
          )) {
            return '$key=REDACTED';
          }
        } on FormatException {
          // Invalid UTF-8 cannot match a sensitive key. Do not let telemetry
          // sanitization prevent the HTTP client from handling the request.
        }
        return part;
      })
      .join('&');
  return url
      .replace(
        userInfo: url.userInfo.isEmpty ? null : 'REDACTED:REDACTED',
        query: url.hasQuery ? query : null,
      )
      .toString();
}
