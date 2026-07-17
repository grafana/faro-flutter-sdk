import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/version_bump.dart';

void main() {
  group('resolveNextVersion:', () {
    test('accepts explicit targets from a prerelease', () {
      expect(
        resolveNextVersion('0.17.0-beta.1', '0.17.0-beta.2').toString(),
        '0.17.0-beta.2',
      );
      expect(
        resolveNextVersion('0.17.0-beta.1', '0.17.0').toString(),
        '0.17.0',
      );
      expect(
        resolveNextVersion('0.17.0-beta.1', '0.18.0').toString(),
        '0.18.0',
      );
    });

    test('keeps stable bump behavior', () {
      expect(resolveNextVersion('0.17.1', 'patch').toString(), '0.17.2');
      expect(resolveNextVersion('0.17.1', 'minor').toString(), '0.18.0');
      expect(resolveNextVersion('0.17.1', 'major').toString(), '1.0.0');
    });

    test('requires an explicit target from a prerelease', () {
      for (final bumpType in ['patch', 'minor', 'major']) {
        expect(
          () => resolveNextVersion('0.17.0-beta.1', bumpType),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.message.toString(),
              'message',
              allOf(
                contains('Cannot use "$bumpType"'),
                contains('0.17.0-beta.1 is a prerelease'),
                contains('Specify the intended version explicitly'),
                contains('dart tool/version_bump.dart 0.17.0'),
                contains('dart tool/version_bump.dart 0.18.0'),
              ),
            ),
          ),
        );
      }
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

    test('rejects invalid SemVer targets', () {
      expect(
        () => resolveNextVersion('0.17.0-beta.1', 'not-a-version'),
        throwsFormatException,
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
