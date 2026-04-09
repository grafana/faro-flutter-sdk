# Releasing

This document describes the process for releasing new versions of the Faro Flutter SDK.

## Development Workflow

### Adding Changes

As you develop new features or fix bugs, add entries to the `CHANGELOG.md` under the `## Unreleased` section:

```markdown
## Unreleased

- Add new feature X
- Fix bug Y
- Update dependency Z

## 0.3.3

...
```

### Release Process

1. **Create Release Branch**

   ```bash
   git checkout main
   git pull origin main
   git checkout -b release/v0.3.4
   ```

2. **Pre-Version-Bump Safety Check**

   ```bash
   dart tool/pre_release_check.dart
   ```

   This automatically verifies:

   - ✅ Dependencies are up to date
   - ✅ Code formatting is correct
   - ✅ Code analyzer passes
   - ✅ All tests pass
   - ✅ CHANGELOG has unreleased content

3. **Version Bump**

   ```bash
   dart tool/version_bump.dart <patch|minor|major>
   ```

   This automatically:

   - Updates version in `pubspec.yaml`, `ios/faro.podspec`, and `android/build.gradle`
   - Converts `## Unreleased` → `## 0.3.4 (2025-01-22)` in `CHANGELOG.md`
   - Creates a new empty `## Unreleased` section

4. **Commit Version Bump Changes**

   ```bash
   git add .
   git commit -m "chore: bump version to v0.3.4"
   ```

5. **Post-Version-Bump Validation**

   ```bash
   dart tool/pre_release_check.dart --post
   ```

   This verifies:

   - ✅ `flutter pub publish --dry-run` succeeds with new version
   - ⚠️ Note: If this check fails, fix the issues and amend the commit: `git commit --amend`

6. **Push Release Branch**

   ```bash
   git push origin release/v0.3.4
   ```

   Then create a Pull Request to `main` with:

   - Title: `chore: bump version to v0.3.4`
   - Description: Review changelog and version updates

7. **Create Release**

   After PR review and merge, use the release script:

   ```bash
   git checkout main
   git pull origin main
   dart tool/create_release.dart
   ```

   > **Tip:** Use `dart tool/create_release.dart --dry-run` to preview without creating anything.

   > **Tip:** Use `dart tool/create_release.dart --enrich` to use AI to generate polished release notes from the changelog (requires `OPENAI_API_KEY` environment variable).

   This will:

   - Read the version from `pubspec.yaml`
   - Extract release notes from `CHANGELOG.md`
   - Show a preview and ask for confirmation
   - Create and push the git tag
   - Create a GitHub release with changelog content and compare link

8. **Automated Publishing**

   - GitHub Actions automatically publishes to pub.dev when you push a version tag
   - Uses the `pub.dev` GitHub environment for security
   - No manual `flutter pub publish` needed!

9. **Post-Release**
   - Verify the package is available on [pub.dev](https://pub.dev/packages/faro)
   - Check the [GitHub release](https://github.com/grafana/faro-flutter-sdk/releases) was created
   - Test that the example project can depend on the new version

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
