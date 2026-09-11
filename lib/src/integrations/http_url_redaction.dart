/// Redacts the HTTP span URL without changing the request or Faro event URL.
///
/// OTel HTTP client URL redaction rules (the query-key list is Development):
/// https://opentelemetry.io/docs/specs/semconv/http/http-spans/#http-client-span
/// Preserves the encoding/order of non-sensitive query parameters.
String redactHttpSpanUrl(Uri url) {
  const sensitiveKeys = {
    'X-Amz-Signature',
    'X-Amz-Credential',
    'X-Amz-Security-Token',
    'AWSAccessKeyId',
    'Signature',
    'sig',
    'X-Goog-Signature',
  };
  final query = url.query
      .split('&')
      .map((part) {
        final separator = part.indexOf('=');
        final key = separator < 0 ? part : part.substring(0, separator);
        try {
          if (sensitiveKeys.contains(Uri.decodeQueryComponent(key))) {
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
