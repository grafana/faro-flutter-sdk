import 'dart:io';

import 'package:pub_semver/pub_semver.dart';

const _semVerPattern =
    r'\d+\.\d+\.\d+(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?'
    r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?';
const _bumpTargets = {'patch', 'minor', 'major'};

/// Resolve a bump type or explicit SemVer target into the next version.
Version resolveNextVersion(String currentVersion, String target) {
  final current = Version.parse(currentVersion);
  final normalizedTarget = target.toLowerCase();
  if (current.isPreRelease && _bumpTargets.contains(normalizedTarget)) {
    final stableVersion = current.nextPatch;
    throw ArgumentError(
      'Cannot use "$normalizedTarget" because current version $current '
      'is a prerelease.\n'
      'Specify the intended version explicitly, for example:\n'
      '  dart tool/version_bump.dart $stableVersion\n'
      '  dart tool/version_bump.dart ${stableVersion.nextMinor}\n'
      'To continue the prerelease, provide its complete next version.',
    );
  }

  final next = switch (normalizedTarget) {
    'patch' => current.nextPatch,
    'minor' => current.nextMinor,
    'major' => current.nextMajor,
    _ => Version.parse(target),
  };

  if (next.compareTo(current) <= 0) {
    throw ArgumentError(
      'Target version $next must be newer than current version $current',
    );
  }
  return next;
}

/// Update version in pubspec.yaml
Future<void> updatePubspec(String version) async {
  final file = File('pubspec.yaml');
  final content = await file.readAsString();
  final updated = content.replaceFirst(
    RegExp('version: $_semVerPattern'),
    'version: $version',
  );
  _ensureUpdated(file.path, content, updated);
  await file.writeAsString(updated);
}

/// Update version in iOS podspec
Future<void> updatePodspec(String version) async {
  final file = File('ios/faro.podspec');
  final content = await file.readAsString();
  final updated = content.replaceFirst(
    RegExp("s\\.version\\s*=\\s*'$_semVerPattern'"),
    "s.version          = '$version'",
  );
  _ensureUpdated(file.path, content, updated);
  await file.writeAsString(updated);
}

/// Update version in Android build.gradle
Future<void> updateBuildGradle(String version) async {
  final file = File('android/build.gradle');
  final content = await file.readAsString();
  final updated = content.replaceFirst(
    RegExp("version '$_semVerPattern'"),
    "version '$version'",
  );
  _ensureUpdated(file.path, content, updated);
  await file.writeAsString(updated);
}

/// Update CHANGELOG.md with new version
Future<void> updateChangelog(String version) async {
  final file = File('CHANGELOG.md');
  final content = await file.readAsString();

  // Get current date
  final now = DateTime.now();
  final dateStr =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';

  // Replace "## [Unreleased]" with version and date, then add new Unreleased
  final updated = content.replaceFirst('## [Unreleased]', '''
## [Unreleased]

## [$version] - $dateStr''');

  // If there was no "[Unreleased]" section, add the version at the top
  // after the header
  if (updated == content) {
    // Find the end of the header section (after "## [Unreleased]")
    final unreleasedIndex = content.indexOf('## [Unreleased]');
    if (unreleasedIndex != -1) {
      final beforeUnreleased = content.substring(0, unreleasedIndex);
      final afterUnreleased = content.substring(unreleasedIndex);
      final newEntry =
          '''
$beforeUnreleased## [Unreleased]

## [$version] - $dateStr

$afterUnreleased''';
      await file.writeAsString(newEntry);
    } else {
      // Fallback: add at the beginning if no Unreleased section found
      final newEntry =
          '''
## [Unreleased]

## [$version] - $dateStr

$content''';
      await file.writeAsString(newEntry);
    }
  } else {
    await file.writeAsString(updated);
  }
}

/// Update version in constants file
Future<void> updateConstants(String version) async {
  final file = File('lib/src/util/constants.dart');
  final content = await file.readAsString();
  final updated = content.replaceFirst(
    RegExp("static const String sdkVersion = '$_semVerPattern';"),
    "static const String sdkVersion = '$version';",
  );
  _ensureUpdated(file.path, content, updated);
  await file.writeAsString(updated);
}

void _ensureUpdated(String path, String content, String updated) {
  if (updated == content) {
    throw StateError('Could not update version in $path');
  }
}

/// Main entry point
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart version_bump.dart <patch|minor|major|version>');
    exit(1);
  }

  try {
    // Read current version from pubspec
    final pubspecFile = File('pubspec.yaml');
    final pubspecContent = await pubspecFile.readAsString();
    final versionMatch = RegExp(
      'version: ($_semVerPattern)',
    ).firstMatch(pubspecContent);

    if (versionMatch == null) {
      stderr.writeln('Could not find version in pubspec.yaml');
      exit(1);
    }

    // Calculate new version
    final currentVersion = versionMatch.group(1)!;
    final newVersion = resolveNextVersion(currentVersion, args[0]);

    stdout.writeln('Bumping version: $currentVersion -> $newVersion');

    // Update all files
    await updatePubspec(newVersion.toString());
    await updatePodspec(newVersion.toString());
    await updateBuildGradle(newVersion.toString());
    await updateChangelog(newVersion.toString());
    await updateConstants(newVersion.toString());

    // Resolve dependencies so example/pubspec.lock reflects the new version
    stdout.writeln('Resolving dependencies...');
    final pubGetResult = await Process.run('flutter', [
      'pub',
      'get',
    ], workingDirectory: Directory.current.path);
    if (pubGetResult.exitCode != 0) {
      stderr.writeln('Warning: flutter pub get failed:');
      stderr.writeln(pubGetResult.stderr);
    }

    stdout.writeln('Successfully updated version to $newVersion');
  } catch (e) {
    stderr.writeln('Error updating version: $e');
    exit(1);
  }
}
