import 'package:faro/src/integrations/http_url_redaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('redactHttpUrl', () {
    for (final key in [
      'X-Amz-Signature',
      'X-Amz-Credential',
      'X-Amz-Security-Token',
      'AWSAccessKeyId',
      'Signature',
      'sig',
      'X-Goog-Signature',
    ]) {
      test('redacts the value of $key', () {
        expect(
          redactHttpUrl(Uri.parse('https://example.com/?$key=example-value')),
          'https://example.com/?$key=REDACTED',
        );
      });
    }

    final cases = [
      (
        'redacts username and password',
        'https://alice:example-password@example.com/path?color=blue#section',
        'https://REDACTED:REDACTED@example.com/path?color=blue#section',
      ),
      (
        'redacts a username without a password',
        'https://alice@example.com/path',
        'https://REDACTED:REDACTED@example.com/path',
      ),
      (
        'redacts encoded credentials and preserves IPv6 authority',
        'https://alice:p%40ss@[::1]:8443/path?sig=example#fragment',
        'https://REDACTED:REDACTED@[::1]:8443/path?sig=REDACTED#fragment',
      ),
      (
        'redacts repeated and encoded keys with case-sensitive matching',
        'https://example.com/?sig=one&sig=two&%73ig=three&Sig=visible'
            '&Signature=four&%53ignature=five&signature=visible',
        'https://example.com/?sig=REDACTED&sig=REDACTED&sig=REDACTED'
            '&Sig=visible&Signature=REDACTED&Signature=REDACTED'
            '&signature=visible',
      ),
      (
        'redacts empty values and keys without an equals sign',
        'https://example.com/?sig=&sig',
        'https://example.com/?sig=REDACTED&sig=REDACTED',
      ),
      (
        'redacts the entire value including equals signs',
        'https://example.com/?sig=a=b%3Dc&color=blue',
        'https://example.com/?sig=REDACTED&color=blue',
      ),
      (
        'tolerates invalid UTF-8 query keys and redacts invalid values',
        'https://example.com/?%FF=keep&sig=%FF',
        'https://example.com/?%FF=keep&sig=REDACTED',
      ),
      (
        'preserves unrelated query encoding, ordering, duplicates and flags',
        'https://example.com/?q=a%20b&sig=example&q=a+b&x=a%2Fb&&flag&',
        'https://example.com/?q=a%20b&sig=REDACTED&q=a+b&x=a%2Fb&&flag&',
      ),
    ];
    for (final (description, input, expected) in cases) {
      test(description, () {
        expect(redactHttpUrl(Uri.parse(input)), expected);
      });
    }

    for (final url in [
      'https://example.com/path',
      'https://example.com/path?',
      'https://example.com/path#fragment',
      'https://example.com/?token=example&password=example#sig=example',
    ]) {
      test('preserves a URL without recognized sensitive components: $url', () {
        expect(redactHttpUrl(Uri.parse(url)), url);
      });
    }

    test('redacting an already redacted URL leaves it unchanged', () {
      const redacted =
          'https://REDACTED:REDACTED@example.com/?'
          'sig=REDACTED&Signature=REDACTED&color=blue';
      expect(redactHttpUrl(Uri.parse(redacted)), redacted);
    });
  });
}
