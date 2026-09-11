import 'package:faro/src/integrations/http_url_redaction.dart';
import 'package:faro/src/integrations/http_url_redaction_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults and empty configuration retain all built-in protections', () {
    final policy = HttpUrlRedactionPolicy();
    final url = Uri.parse(
      'https://example.com/?'
      'X-Amz-Signature=x&X-Amz-Credential=x&X-Amz-Security-Token=x'
      '&AWSAccessKeyId=x&Signature=x&sig=x&X-Goog-Signature=x'
      '&token=x&access_token=x&refresh_token=x&api_key=x&apikey=x'
      '&password=x&client_secret=x',
    );
    for (final configure in [false, true]) {
      if (configure) policy.configure({});
      expect(
        redactHttpUrl(
          url,
          sensitiveQueryParameters: policy.sensitiveQueryParameters,
        ),
        url.toString().replaceAll('=x', '=REDACTED'),
      );
    }
  });

  test(
    'configuration adds names, snapshots inputs and exposes immutable state',
    () {
      final names = {'custom'};
      final policy = HttpUrlRedactionPolicy()..configure(names);
      names.clear();
      expect(
        redactHttpUrl(
          Uri.parse('https://example.com/?custom=x&token=x'),
          sensitiveQueryParameters: policy.sensitiveQueryParameters,
        ),
        'https://example.com/?custom=REDACTED&token=REDACTED',
      );
      expect(
        () => policy.sensitiveQueryParameters.clear(),
        throwsUnsupportedError,
      );
    },
  );
}
