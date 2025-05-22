import 'dart:io';

/// Version bump types
enum BumpType {
  patch,
  minor,
  major,
}

/// Represents a semantic version
class Version {
  Version(this.major, this.minor, this.patch);

  /// Parse version string into Version object
  factory Version.parse(String version) {
    final parts = version.split('.');
    if (parts.length != 3) {
      throw FormatException('Invalid version format: $version');
    }
    return Version(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  final int major;
  final int minor;
  final int patch;

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
  String toString() => '$major.$minor.$patch';
}

/// Update version in pubspec.yaml
Future<void> updatePubspec(String version) async {
  final file = File('pubspec.yaml');
  final content = await file.readAsString();
  final updated = content.replaceFirst(
    RegExp(r'version: \d+\.\d+\.\d+'),
    'version: $version',
  );
  await file.writeAsString(updated);
}

/// Update version in iOS podspec
Future<void> updatePodspec(String version) async {
  final file = File('ios/faro.podspec');
  final content = await file.readAsString();
  final updated = content.replaceFirst(
    RegExp(r"s\.version\s*=\s*'\d+\.\d+\.\d+'"),
    "s.version          = '$version'",
  );
  await file.writeAsString(updated);
}

/// Update version in Android build.gradle
Future<void> updateBuildGradle(String version) async {
  final file = File('android/build.gradle');
  final content = await file.readAsString();
  final updated = content.replaceFirst(
    RegExp(r"version '\d+\.\d+\.\d+'"),
    "version '$version'",
  );
  await file.writeAsString(updated);
}

/// Update CHANGELOG.md with new version
Future<void> updateChangelog(String version) async {
  final file = File('CHANGELOG.md');
  final content = await file.readAsString();

  // Get current date
  final now = DateTime.now();
  final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';

  // Replace "## [Unreleased]" with version and date, then add new Unreleased
  final updated = content.replaceFirst(
    '## [Unreleased]',
    '''
## [Unreleased]

## [$version] - $dateStr''',
  );

  // If there was no "[Unreleased]" section, add the version at the top
  // after the header
  if (updated == content) {
    // Find the end of the header section (after "## [Unreleased]")
    final unreleasedIndex = content.indexOf('## [Unreleased]');
    if (unreleasedIndex != -1) {
      final beforeUnreleased = content.substring(0, unreleasedIndex);
      final afterUnreleased = content.substring(unreleasedIndex);
      final newEntry = '''
$beforeUnreleased## [Unreleased]

## [$version] - $dateStr

$afterUnreleased''';
      await file.writeAsString(newEntry);
    } else {
      // Fallback: add at the beginning if no Unreleased section found
      final newEntry = '''
## [Unreleased]

## [$version] - $dateStr

$content''';
      await file.writeAsString(newEntry);
    }
  } else {
    await file.writeAsString(updated);
  }
}

/// Main entry point
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart version_bump.dart <patch|minor|major>');
    exit(1);
  }

  // Parse bump type
  final bumpTypeStr = args[0].toLowerCase();
  BumpType? bumpType;

  switch (bumpTypeStr) {
    case 'patch':
      bumpType = BumpType.patch;
      break;
    case 'minor':
      bumpType = BumpType.minor;
      break;
    case 'major':
      bumpType = BumpType.major;
      break;
    default:
      stderr.writeln(
          'Invalid bump type: $bumpTypeStr. Must be patch, minor, or major');
      exit(1);
  }

  try {
    // Read current version from pubspec
    final pubspecFile = File('pubspec.yaml');
    final pubspecContent = await pubspecFile.readAsString();
    final versionMatch =
        RegExp(r'version: (\d+\.\d+\.\d+)').firstMatch(pubspecContent);

    if (versionMatch == null) {
      stderr.writeln('Could not find version in pubspec.yaml');
      exit(1);
    }

    // Calculate new version
    final currentVersion = Version.parse(versionMatch.group(1)!);
    final newVersion = currentVersion.bump(bumpType);

    stdout.writeln('Bumping version: $currentVersion -> $newVersion');

    // Update all files
    await updatePubspec(newVersion.toString());
    await updatePodspec(newVersion.toString());
    await updateBuildGradle(newVersion.toString());
    await updateChangelog(newVersion.toString());

    stdout.writeln('Successfully updated version to $newVersion');
  } catch (e) {
    stderr.writeln('Error updating version: $e');
    exit(1);
  }
}
