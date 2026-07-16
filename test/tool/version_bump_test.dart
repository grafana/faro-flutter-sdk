import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/version_bump.dart';

void main() {
  group('Version.parse:', () {
    test('preserves prerelease and build metadata', () {
      final version = Version.parse('1.2.3-rc.2+42');

      expect(version.major, 1);
      expect(version.minor, 2);
      expect(version.patch, 3);
      expect(version.prerelease, 'rc.2');
      expect(version.buildMetadata, '42');
      expect(version.toString(), '1.2.3-rc.2+42');
    });

    test('rejects leading zeros', () {
      expect(() => Version.parse('01.2.3'), throwsFormatException);
      expect(() => Version.parse('1.2.3-beta.01'), throwsFormatException);
    });
  });

  group('Version.compareTo:', () {
    test('orders prerelease versions using SemVer precedence', () {
      expect(
        Version.parse(
          '0.17.0-beta.2',
        ).compareTo(Version.parse('0.17.0-beta.1')),
        greaterThan(0),
      );
      expect(
        Version.parse('0.17.0').compareTo(Version.parse('0.17.0-beta.2')),
        greaterThan(0),
      );
      expect(
        Version.parse('1.0.0-beta.11').compareTo(Version.parse('1.0.0-beta.2')),
        greaterThan(0),
      );
    });
  });

  group('resolveNextVersion:', () {
    test('accepts an explicit prerelease target', () {
      expect(
        resolveNextVersion('0.17.0-beta.1', '0.17.0-beta.2').toString(),
        '0.17.0-beta.2',
      );
    });

    test('keeps stable bump behavior', () {
      expect(resolveNextVersion('0.17.0-beta.1', 'patch').toString(), '0.17.1');
      expect(resolveNextVersion('0.17.0-beta.1', 'minor').toString(), '0.18.0');
      expect(resolveNextVersion('0.17.0-beta.1', 'major').toString(), '1.0.0');
    });

    test('rejects equal or older targets', () {
      expect(
        () => resolveNextVersion('0.17.0-beta.1', '0.17.0-beta.1'),
        throwsArgumentError,
      );
      expect(
        () => resolveNextVersion('0.17.0-beta.2', '0.17.0-beta.1'),
        throwsArgumentError,
      );
    });
  });

  group('version file updates:', () {
    late Directory originalDirectory;
    late Directory temporaryDirectory;

    setUp(() async {
      originalDirectory = Directory.current;
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'version-bump-test-',
      );
      Directory.current = temporaryDirectory;

      await Directory('ios').create();
      await Directory('android').create();
      await Directory('lib/src/util').create(recursive: true);
      await File(
        'pubspec.yaml',
      ).writeAsString('name: faro\nversion: 0.17.0-beta.1\n');
      await File(
        'ios/faro.podspec',
      ).writeAsString("s.version = '0.17.0-beta.1'\n");
      await File(
        'android/build.gradle',
      ).writeAsString("version '0.17.0-beta.1'\n");
      await File(
        'lib/src/util/constants.dart',
      ).writeAsString("static const String sdkVersion = '0.17.0-beta.1';\n");
    });

    tearDown(() async {
      Directory.current = originalDirectory;
      await temporaryDirectory.delete(recursive: true);
    });

    test('replaces complete prerelease versions', () async {
      const version = '0.17.0-beta.2';

      await updatePubspec(version);
      await updatePodspec(version);
      await updateBuildGradle(version);
      await updateConstants(version);

      expect(
        await File('pubspec.yaml').readAsString(),
        contains('version: $version'),
      );
      expect(
        await File('ios/faro.podspec').readAsString(),
        contains("s.version          = '$version'"),
      );
      expect(
        await File('android/build.gradle').readAsString(),
        contains("version '$version'"),
      );
      expect(
        await File('lib/src/util/constants.dart').readAsString(),
        contains("sdkVersion = '$version'"),
      );
    });
  });
}
