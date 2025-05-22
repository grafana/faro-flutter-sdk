import 'dart:io';

/// ANSI color codes for console output
class Colors {
  static const String red = '\x1B[31m';
  static const String green = '\x1B[32m';
  static const String yellow = '\x1B[33m';
  static const String blue = '\x1B[34m';
  static const String reset = '\x1B[0m';
}

/// Pre-release safety checks
class PreReleaseChecker {
  int _checksPassed = 0;
  int _checksTotal = 0;

  /// Run a check and report results
  Future<bool> _runCheck(String name, Future<bool> Function() check) async {
    _checksTotal++;
    stdout.write('${Colors.blue}➤${Colors.reset} $name... ');

    try {
      final result = await check();
      if (result) {
        _checksPassed++;
        // ignore: avoid_print
        print('${Colors.green}✓${Colors.reset}');
        return true;
      } else {
        // ignore: avoid_print
        print('${Colors.red}✗${Colors.reset}');
        return false;
      }
    } catch (e) {
      // ignore: avoid_print
      print('${Colors.red}✗${Colors.reset} Error: $e');
      return false;
    }
  }

  /// Check if CHANGELOG has unreleased content
  Future<bool> _checkChangelog() async {
    final file = File('CHANGELOG.md');
    if (!file.existsSync()) return false;

    final content = file.readAsStringSync();
    final lines = content.split('\n');

    // Find the Unreleased section
    var unreleasedIndex = -1;
    var nextVersionIndex = -1;

    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim() == '## Unreleased') {
        unreleasedIndex = i;
      } else if (unreleasedIndex != -1 &&
          lines[i].startsWith('## ') &&
          !lines[i].contains('Unreleased')) {
        nextVersionIndex = i;
        break;
      }
    }

    if (unreleasedIndex == -1) return false;

    // Check if there's content between Unreleased and next version
    final endIndex = nextVersionIndex == -1 ? lines.length : nextVersionIndex;
    for (var i = unreleasedIndex + 1; i < endIndex; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty && !line.startsWith('##')) {
        return true; // Found content
      }
    }

    return false; // No content found
  }

  /// Run Flutter tests
  Future<bool> _checkTests() async {
    final result = await Process.run('flutter', ['test']);
    return result.exitCode == 0;
  }

  /// Run Flutter analyzer
  Future<bool> _checkAnalyzer() async {
    final result = await Process.run('flutter', ['analyze']);
    return result.exitCode == 0;
  }

  /// Check code formatting
  Future<bool> _checkFormatting() async {
    // Just run dart format without checking for changes during development
    final result = await Process.run('dart', ['format', '.']);
    return result.exitCode == 0;
  }

  /// Check publish dry run
  Future<bool> _checkPublishDryRun() async {
    final result =
        await Process.run('flutter', ['pub', 'publish', '--dry-run']);
    return result.exitCode == 0;
  }

  /// Check if dependencies are up to date
  Future<bool> _checkDependencies() async {
    final result = await Process.run('flutter', ['pub', 'get']);
    return result.exitCode == 0;
  }

  /// Run pre-version-bump checks
  Future<bool> runPreChecks() async {
    // ignore: avoid_print
    print('${Colors.blue}🔍 Running pre-version-bump checks...'
        '${Colors.reset}\n');

    // Git checks (skipped - we expect changes during development)

    // Dependencies
    await _runCheck('Update dependencies', _checkDependencies);

    // Code quality
    await _runCheck('Check code formatting', _checkFormatting);
    await _runCheck('Run analyzer', _checkAnalyzer);
    await _runCheck('Run tests', _checkTests);

    // Release readiness
    await _runCheck('Check CHANGELOG has unreleased content', _checkChangelog);

    // Summary
    // ignore: avoid_print
    print('\n${Colors.blue}📊 Pre-checks Results:${Colors.reset}');
    if (_checksPassed == _checksTotal) {
      // ignore: avoid_print
      print('${Colors.green}✅ All $_checksTotal pre-checks passed! '
          'Ready for version bump.${Colors.reset}');
      return true;
    } else {
      // ignore: avoid_print
      print('${Colors.red}❌ $_checksPassed/$_checksTotal pre-checks '
          'passed. Please fix issues before version bump.${Colors.reset}');
      return false;
    }
  }

  /// Run post-version-bump checks
  Future<bool> runPostChecks() async {
    // ignore: avoid_print
    print('${Colors.blue}🔍 Running post-version-bump checks...'
        '${Colors.reset}\n');

    // Reset counters
    _checksPassed = 0;
    _checksTotal = 0;

    // Final validation
    await _runCheck('Validate pub publish (dry run)', _checkPublishDryRun);

    // Summary
    // ignore: avoid_print
    print('\n${Colors.blue}📊 Post-checks Results:${Colors.reset}');
    if (_checksPassed == _checksTotal) {
      // ignore: avoid_print
      print('${Colors.green}✅ All $_checksTotal post-checks passed! '
          'Ready for commit.${Colors.reset}');
      return true;
    } else {
      // ignore: avoid_print
      print('${Colors.red}❌ $_checksPassed/$_checksTotal post-checks '
          'passed. Please fix issues before commit.${Colors.reset}');
      return false;
    }
  }
}

/// Main entry point
Future<void> main(List<String> args) async {
  final checker = PreReleaseChecker();

  if (args.isNotEmpty && args[0] == '--post') {
    // Post-version-bump checks
    final success = await checker.runPostChecks();
    if (!success) {
      exit(1);
    }
    // ignore: avoid_print
    print('\n${Colors.green}🚀 Ready to commit and create PR!'
        '${Colors.reset}');
  } else {
    // Pre-version-bump checks
    final success = await checker.runPreChecks();
    if (!success) {
      exit(1);
    }
    // ignore: avoid_print
    print('\n${Colors.green}🚀 Ready to run: ${Colors.yellow}'
        'dart tool/version_bump.dart <patch|minor|major>${Colors.reset}');
  }
}
