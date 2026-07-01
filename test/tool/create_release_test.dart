import 'package:flutter_test/flutter_test.dart';

import '../../tool/create_release.dart';

typedef Lines = List<String>;

void main() {
  group('extractChangelogForVersion:', () {
    test('extracts content for a specific version', () {
      final content = _joinLines([
        '# Changelog',
        '',
        '## [Unreleased]',
        '',
        '## [0.10.0] - 2026-02-09',
        '',
        '### Added',
        '- New feature A',
        '- New feature B',
        '',
        '## [0.9.0] - 2026-01-28',
        '',
        '### Fixed',
        '- Bug fix C',
      ]);

      final extracted = extractChangelogForVersion(content, '0.10.0');

      expect(extracted, contains('### Added'));
      expect(extracted, contains('- New feature A'));
      expect(extracted, contains('- New feature B'));
      expect(extracted, isNot(contains('### Fixed')));
      expect(extracted, isNot(contains('- Bug fix C')));
    });

    test('stops at next header even if version is prefix', () {
      final content = _joinLines([
        '# Changelog',
        '',
        '## [Unreleased]',
        '',
        '## [0.1.1] - 2026-02-01',
        '- Fix alpha issue',
        '',
        '## [0.1.10] - 2026-02-03',
        '- Add beta feature',
        '',
        '## [0.1.2] - 2026-02-04',
        '- Another fix',
      ]);

      final extracted = extractChangelogForVersion(content, '0.1.1');

      expect(extracted, contains('- Fix alpha issue'));
      expect(extracted, isNot(contains('- Add beta feature')));
      expect(extracted, isNot(contains('- Another fix')));
    });

    test('throws when version is not found', () {
      final content = _joinLines([
        '# Changelog',
        '',
        '## [Unreleased]',
        '',
        '## [0.1.0] - 2026-01-01',
        '- Initial release',
      ]);

      expect(
        () => extractChangelogForVersion(content, '0.2.0'),
        throwsA(isA<Exception>()),
      );
    });

    test('removes leading and trailing empty lines', () {
      final content = _joinLines([
        '## [0.5.0] - 2026-01-01',
        '',
        '',
        '### Added',
        '- Feature X',
        '',
        '',
        '## [0.4.0] - 2025-12-01',
        '- Old stuff',
      ]);

      final extracted = extractChangelogForVersion(content, '0.5.0');

      expect(extracted, startsWith('### Added'));
      expect(extracted, endsWith('- Feature X'));
    });

    test('extracts content for a pre-release version', () {
      final content = _joinLines([
        '# Changelog',
        '',
        '## [Unreleased]',
        '',
        '## [0.17.0-beta.1] - 2026-07-01',
        '',
        '### Changed',
        '- Beta change',
        '',
        '## [0.16.0] - 2026-05-11',
        '- Stable stuff',
      ]);

      final extracted = extractChangelogForVersion(content, '0.17.0-beta.1');

      expect(extracted, contains('- Beta change'));
      expect(extracted, isNot(contains('- Stable stuff')));
    });
  });

  group('parseVersion:', () {
    test('parses a plain major.minor.patch version', () {
      expect(parseVersion('version: 0.16.0'), '0.16.0');
    });

    test('preserves a pre-release identifier', () {
      expect(parseVersion('version: 0.17.0-beta.1'), '0.17.0-beta.1');
    });

    test('preserves build metadata', () {
      expect(parseVersion('version: 1.2.3+42'), '1.2.3+42');
    });

    test('preserves both pre-release and build metadata', () {
      expect(parseVersion('version: 1.2.3-rc.2+42'), '1.2.3-rc.2+42');
    });

    test('reads the version line from full pubspec content', () {
      final content = _joinLines([
        'name: faro',
        'description: Grafana Faro SDK for Flutter.',
        'version: 0.17.0-beta.1',
        'homepage: https://grafana.com',
      ]);

      expect(parseVersion(content), '0.17.0-beta.1');
    });

    test('returns null when no version line is present', () {
      expect(parseVersion('name: faro\ndescription: no version here'), isNull);
    });
  });

  group('isPrerelease:', () {
    test('is false for a stable version', () {
      expect(isPrerelease('0.17.0'), isFalse);
    });

    test('is true for a pre-release version', () {
      expect(isPrerelease('0.17.0-beta.1'), isTrue);
    });

    test('is false for build metadata only', () {
      expect(isPrerelease('1.2.3+42'), isFalse);
    });
  });
}

String _joinLines(Lines lines) => lines.join('\n');
