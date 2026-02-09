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
  });
}

String _joinLines(Lines lines) => lines.join('\n');
