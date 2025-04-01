import 'dart:io';

/// Version bump types
enum BumpType {
  patch,
  minor,
  major,
}

/// Represents a semantic version
class Version {
  final int major;
  final int minor;
  final int patch;

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

  final newEntry = '''## $version

- Version bump

''';

  await file.writeAsString(newEntry + content);
}

/// Main entry point
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart version_bump.dart <patch|minor|major>');
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
      print('Invalid bump type: $bumpTypeStr. Must be patch, minor, or major');
      exit(1);
  }

  try {
    // Read current version from pubspec
    final pubspecFile = File('pubspec.yaml');
    final pubspecContent = await pubspecFile.readAsString();
    final versionMatch =
        RegExp(r'version: (\d+\.\d+\.\d+)').firstMatch(pubspecContent);

    if (versionMatch == null) {
      print('Could not find version in pubspec.yaml');
      exit(1);
    }

    // Calculate new version
    final currentVersion = Version.parse(versionMatch.group(1)!);
    final newVersion = currentVersion.bump(bumpType);

    print(
        'Bumping version: ${currentVersion.toString()} -> ${newVersion.toString()}');

    // Update all files
    await updatePubspec(newVersion.toString());
    await updatePodspec(newVersion.toString());
    await updateBuildGradle(newVersion.toString());
    await updateChangelog(newVersion.toString());

    print('Successfully updated version to ${newVersion.toString()}');
  } catch (e) {
    print('Error updating version: $e');
    exit(1);
  }
}
