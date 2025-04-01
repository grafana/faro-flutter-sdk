# Releasing

This document describes the process for releasing new versions of the Faro Flutter SDK.

## Process

1. **Update Version**

   - Update the version in `pubspec.yaml`
   - Update `CHANGELOG.md` with the new version and its changes
   - Run `dart run tools/version_bump.dart` to update version references

2. **Testing**

   - Ensure all tests pass: `flutter test`
   - Verify the example app builds and runs correctly
   - Test on both Android and iOS platforms

3. **Documentation**

   - Update any version references in documentation
   - Verify all documentation links are working
   - Ensure example code snippets are up to date

4. **Publishing**

   - Run `flutter pub publish --dry-run` to check for issues
   - Submit to pub.dev: `flutter pub publish`
   - Tag the release: `git tag -a v{version} -m "Release v{version}"`
   - Push the tag: `git push origin v{version}`

5. **Post-Release**
   - Create a release on GitHub with the changelog notes
   - Verify the package is available on pub.dev
   - Check the example project can depend on the new version

## Version Numbering

We follow semantic versioning (SemVer):

- MAJOR version for incompatible API changes
- MINOR version for backward-compatible functionality additions
- PATCH version for backward-compatible bug fixes

## Hotfixes

For urgent fixes:

1. Create a hotfix branch from the tag
2. Make the fix
3. Bump the patch version
4. Follow the normal release process
