import 'dart:io';

const _semVerPattern =
    r'\d+\.\d+\.\d+(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?'
    r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?';

/// Version bump types
enum BumpType { patch, minor, major }

/// Represents a semantic version
class Version implements Comparable<Version> {
  Version(
    this.major,
    this.minor,
    this.patch, {
    this.prerelease,
    this.buildMetadata,
  });

  /// Parse version string into Version object
  factory Version.parse(String version) {
    final match = RegExp('^($_semVerPattern)\$').firstMatch(version);
    if (match == null) {
      throw FormatException('Invalid version format: $version');
    }

    final coreAndPrerelease = version.split('+').first;
    final core = coreAndPrerelease.split('-').first;
    final coreParts = core.split('.');
    if (coreParts.any(
      (identifier) => identifier.length > 1 && identifier.startsWith('0'),
    )) {
      throw FormatException(
        'Numeric version identifiers cannot have leading zeros: $version',
      );
    }
    final prerelease = coreAndPrerelease.contains('-')
        ? coreAndPrerelease.substring(core.length + 1)
        : null;
    if (prerelease != null) {
      for (final identifier in prerelease.split('.')) {
        if (_isNumeric(identifier) &&
            identifier.length > 1 &&
            identifier.startsWith('0')) {
          throw FormatException(
            'Numeric prerelease identifiers cannot have leading zeros: '
            '$version',
          );
        }
      }
    }

    return Version(
      int.parse(coreParts[0]),
      int.parse(coreParts[1]),
      int.parse(coreParts[2]),
      prerelease: prerelease,
      buildMetadata: version.contains('+')
          ? version.substring(version.indexOf('+') + 1)
          : null,
    );
  }

  final int major;
  final int minor;
  final int patch;
  final String? prerelease;
  final String? buildMetadata;

  /// Bump version according to specified type
  Version bump(BumpType type) {
    switch (type) {
      case BumpType.major:
        return Version(major + 1, 0, 0);
      case BumpType.minor:
        return Version(major, minor + 1, 0);
      case BumpType.patch:
        return Version(major, minor, patch + 1);
    }
  }

  @override
  int compareTo(Version other) {
    for (final comparison in [
      major.compareTo(other.major),
      minor.compareTo(other.minor),
      patch.compareTo(other.patch),
    ]) {
      if (comparison != 0) return comparison;
    }

    if (prerelease == null && other.prerelease == null) return 0;
    if (prerelease == null) return 1;
    if (other.prerelease == null) return -1;

    final identifiers = prerelease!.split('.');
    final otherIdentifiers = other.prerelease!.split('.');
    final sharedLength = identifiers.length < otherIdentifiers.length
        ? identifiers.length
        : otherIdentifiers.length;
    for (var i = 0; i < sharedLength; i++) {
      final identifier = identifiers[i];
      final otherIdentifier = otherIdentifiers[i];
      if (identifier == otherIdentifier) continue;

      final numeric = _isNumeric(identifier);
      final otherNumeric = _isNumeric(otherIdentifier);
      if (numeric && otherNumeric) {
        return int.parse(identifier).compareTo(int.parse(otherIdentifier));
      }
      if (numeric) return -1;
      if (otherNumeric) return 1;
      return identifier.compareTo(otherIdentifier);
    }
    return identifiers.length.compareTo(otherIdentifiers.length);
  }

  @override
  String toString() {
    final buffer = StringBuffer('$major.$minor.$patch');
    if (prerelease != null) buffer.write('-$prerelease');
    if (buildMetadata != null) buffer.write('+$buildMetadata');
    return buffer.toString();
  }
}

bool _isNumeric(String value) => RegExp(r'^\d+$').hasMatch(value);

/// Resolve a bump type or explicit SemVer target into the next version.
Version resolveNextVersion(String currentVersion, String target) {
  final current = Version.parse(currentVersion);
  final normalizedTarget = target.toLowerCase();
  final bumpType = switch (normalizedTarget) {
    'patch' => BumpType.patch,
    'minor' => BumpType.minor,
    'major' => BumpType.major,
    _ => null,
  };
  final next = bumpType == null
      ? Version.parse(target)
      : current.bump(bumpType);

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
