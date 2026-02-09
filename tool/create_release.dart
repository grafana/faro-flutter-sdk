// ignore_for_file: avoid_redundant_argument_values

import 'dart:convert';
import 'dart:io';

/// ANSI color codes for console output
class Colors {
  static const String red = '\x1B[31m';
  static const String green = '\x1B[32m';
  static const String yellow = '\x1B[33m';
  static const String blue = '\x1B[34m';
  static const String cyan = '\x1B[36m';
  static const String dim = '\x1B[2m';
  static const String reset = '\x1B[0m';
}

/// Get the current version from pubspec.yaml
Future<String> getVersion() async {
  final file = File('pubspec.yaml');
  final content = await file.readAsString();
  final match = RegExp(r'version:\s*(\d+\.\d+\.\d+)').firstMatch(content);
  if (match == null) {
    throw Exception('Could not find version in pubspec.yaml');
  }
  return match.group(1)!;
}

/// Get the previous git tag
Future<String?> getPreviousTag() async {
  // Get all tags sorted by version
  final result = await Process.run(
    'git',
    ['tag', '--sort=-v:refname'],
  );

  if (result.exitCode != 0) {
    return null;
  }

  final tags = (result.stdout as String)
      .split('\n')
      .where((t) => t.trim().isNotEmpty && t.startsWith('v'))
      .toList();

  return tags.isNotEmpty ? tags.first : null;
}

/// Get the GitHub repository URL
Future<String?> getRepoUrl() async {
  final result = await Process.run(
    'git',
    ['remote', 'get-url', 'origin'],
  );

  if (result.exitCode != 0) {
    return null;
  }

  var url = (result.stdout as String).trim();

  // Convert SSH URL to HTTPS URL
  if (url.startsWith('git@github.com:')) {
    url = url.replaceFirst('git@github.com:', 'https://github.com/');
  }

  // Remove .git suffix
  if (url.endsWith('.git')) {
    url = url.substring(0, url.length - 4);
  }

  return url;
}

/// Extract changelog content for a specific version
Future<String> getChangelogForVersion(String version) async {
  final file = File('CHANGELOG.md');
  final content = await file.readAsString();
  return extractChangelogForVersion(content, version);
}

/// Extract changelog content for a specific version from full content
String extractChangelogForVersion(String content, String version) {
  final lines = content.split('\n');

  final versionHeader = '## [$version]';
  var startIndex = -1;
  var endIndex = lines.length;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.startsWith(versionHeader)) {
      startIndex = i + 1; // Start after the header
    } else if (startIndex != -1 && line.startsWith('## [')) {
      endIndex = i;
      break;
    }
  }

  if (startIndex == -1) {
    throw Exception('Could not find version $version in CHANGELOG.md');
  }

  // Extract and clean up the content
  final changelogLines = lines.sublist(startIndex, endIndex);

  // Remove leading/trailing empty lines
  while (changelogLines.isNotEmpty && changelogLines.first.trim().isEmpty) {
    changelogLines.removeAt(0);
  }
  while (changelogLines.isNotEmpty && changelogLines.last.trim().isEmpty) {
    changelogLines.removeLast();
  }

  return changelogLines.join('\n');
}

/// Check if we're on main branch
Future<bool> isOnMainBranch() async {
  final result = await Process.run('git', ['branch', '--show-current']);
  final branch = (result.stdout as String).trim();
  return branch == 'main' || branch == 'master';
}

/// Check if working directory is clean
Future<bool> isWorkingDirectoryClean() async {
  final result = await Process.run('git', ['status', '--porcelain']);
  return (result.stdout as String).trim().isEmpty;
}

/// Check if tag already exists
Future<bool> tagExists(String tag) async {
  final result = await Process.run('git', ['tag', '-l', tag]);
  return (result.stdout as String).trim().isNotEmpty;
}

/// Create and push git tag
Future<bool> createAndPushTag(String tag) async {
  // Create tag
  var result = await Process.run('git', ['tag', tag]);
  if (result.exitCode != 0) {
    stderr.writeln(
        '${Colors.red}Failed to create tag: ${result.stderr}${Colors.reset}');
    return false;
  }

  // Push tag
  result = await Process.run('git', ['push', 'origin', tag]);
  if (result.exitCode != 0) {
    stderr.writeln(
        '${Colors.red}Failed to push tag: ${result.stderr}${Colors.reset}');
    // Try to delete the local tag if push failed
    await Process.run('git', ['tag', '-d', tag]);
    return false;
  }

  return true;
}

/// Create GitHub release using gh CLI
Future<bool> createGitHubRelease(
  String tag,
  String title,
  String body,
) async {
  final result = await Process.run(
    'gh',
    [
      'release',
      'create',
      tag,
      '--title',
      title,
      '--notes',
      body,
    ],
  );

  if (result.exitCode != 0) {
    stderr.writeln('${Colors.red}Failed to create GitHub '
        'release: ${result.stderr}${Colors.reset}');
    return false;
  }

  return true;
}

/// Enrich changelog content using OpenAI API for polished release notes
Future<String?> enrichWithAI(String changelog, String version) async {
  final apiKey = Platform.environment['OPENAI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('${Colors.red}Error: OPENAI_API_KEY '
        'environment variable is not set${Colors.reset}');
    stderr.writeln('Set it with: export OPENAI_API_KEY="your-key-here"');
    return null;
  }

  stdout.write(
      '${Colors.blue}Enriching release notes with AI... ${Colors.reset}');

  try {
    final client = HttpClient();
    final request = await client.postUrl(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
    );

    request.headers.set('Content-Type', 'application/json; charset=utf-8');
    request.headers.set('Authorization', 'Bearer $apiKey');

    final prompt = jsonEncode({
      'model': 'gpt-4o-mini',
      'temperature': 0.3,
      'messages': [
        {
          'role': 'system',
          'content': '''
You are writing GitHub release notes for the Grafana Faro Flutter SDK (pub.dev package: faro), a mobile observability SDK for Flutter applications.

Transform raw CHANGELOG content into polished, user-friendly GitHub release notes.

CRITICAL: Only use information that is explicitly present in the provided changelog content. Do NOT invent, guess, or assume any API names, parameter names, method signatures, or code examples that are not directly stated in the input. If the changelog does not include enough detail for a code example, omit the example entirely. Accuracy is more important than polish — it is better to leave a section sparse than to include anything that might be incorrect.

Guidelines:
- Start with: # Faro Flutter SDK v$version
- Keep the exact same section headers from the changelog (### Added, ### Fixed, ### Changed, ### Removed, etc.) — do NOT rename them to creative alternatives like "What's New" or "What's Fixed". You may add an emoji prefix to each header (e.g. ### ✨ Added, ### 🔧 Fixed, ### ⚠️ Changed).
- Only include code examples if the changelog itself contains the exact code or API signatures to reference — never fabricate examples
- Use markdown tables for comparing before/after API changes, but only when the changelog provides both the before and after
- Reference GitHub issues using #number format
- Keep it concise but informative — the audience is Flutter developers using this SDK
- End with: See [CHANGELOG.md](https://github.com/grafana/faro-flutter-sdk/blob/main/CHANGELOG.md) for complete details.
- Do NOT add a "Full Changelog" compare link — that is appended automatically
- Output raw markdown only, no wrapping code fences
''',
        },
        {
          'role': 'user',
          'content':
              'Create release notes for version $version from this changelog '
                  'content:\n\n$changelog',
        },
      ],
    });

    request.add(utf8.encode(prompt));
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    client.close();

    if (response.statusCode != 200) {
      stdout.writeln('${Colors.red}✗${Colors.reset}');
      stderr.writeln('${Colors.yellow}Warning: OpenAI API returned status '
          '${response.statusCode}${Colors.reset}');
      return null;
    }

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>;
    if (choices.isEmpty) {
      stdout.writeln('${Colors.red}✗${Colors.reset}');
      stderr.writeln('${Colors.yellow}Warning: OpenAI API returned no choices'
          '${Colors.reset}');
      return null;
    }

    final message = choices[0]['message']['content'] as String;
    stdout.writeln('${Colors.green}✓${Colors.reset}');
    return message.trim();
  } catch (e) {
    stdout.writeln('${Colors.red}✗${Colors.reset}');
    stderr.writeln(
        '${Colors.yellow}Warning: AI enrichment failed: $e${Colors.reset}');
    return null;
  }
}

/// Wrap raw changelog in a standard release notes template
String _wrapInTemplate(
  String changelog,
  String version,
  String changelogUrl,
) {
  final buffer = StringBuffer();
  buffer.writeln('# Faro Flutter SDK v$version');
  buffer.writeln();
  buffer.writeln(changelog);
  buffer.writeln();
  buffer.write('See [CHANGELOG.md]($changelogUrl) for complete details.');
  return buffer.toString();
}

/// Print usage information
void printUsage() {
  stdout.writeln('Usage: dart tool/create_release.dart [options]');
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout
      .writeln('  --dry-run    Preview the release without creating anything');
  stdout.writeln('  --enrich     Use AI to enrich release notes '
      '(requires OPENAI_API_KEY)');
  stdout.writeln('  --help       Show this help message');
}

/// Main entry point
Future<void> main(List<String> args) async {
  final isDryRun = args.contains('--dry-run');
  final isEnrich = args.contains('--enrich');
  final showHelp = args.contains('--help') || args.contains('-h');

  if (showHelp) {
    printUsage();
    exit(0);
  }

  stdout.writeln('');

  if (isDryRun) {
    stdout.writeln('${Colors.yellow}🔍 DRY RUN MODE '
        '- No changes will be made${Colors.reset}');
    stdout.writeln('');
  }

  // Check prerequisites (skip in dry-run mode)
  if (!isDryRun) {
    if (!await isOnMainBranch()) {
      stderr.writeln('${Colors.red}Error: Must be on main '
          'branch to create a release${Colors.reset}');
      stderr.writeln('Run: git checkout main && git pull origin main');
      exit(1);
    }

    if (!await isWorkingDirectoryClean()) {
      stderr.writeln('${Colors.red}Error: Working directory '
          'has uncommitted changes${Colors.reset}');
      stderr.writeln('Commit or stash your changes before creating a release.');
      exit(1);
    }
  }

  // Get version and create tag name
  final version = await getVersion();
  final tag = 'v$version';

  stdout.writeln('${Colors.blue}📦 Creating release for '
      'Faro Flutter SDK $tag${Colors.reset}');
  stdout.writeln('');

  // Check if tag already exists (warn in dry-run, error otherwise)
  if (await tagExists(tag)) {
    if (isDryRun) {
      stdout.writeln('${Colors.yellow}⚠ Tag $tag already '
          'exists (would fail in real run)${Colors.reset}');
      stdout.writeln('');
    } else {
      stderr.writeln(
          '${Colors.red}Error: Tag $tag already exists${Colors.reset}');
      stderr.writeln('If you need to re-release, delete the tag first:');
      stderr.writeln('  git tag -d $tag && git push origin :$tag');
      exit(1);
    }
  }

  // Get changelog content
  String changelog;
  try {
    changelog = await getChangelogForVersion(version);
  } catch (e) {
    stderr.writeln('${Colors.red}Error: $e${Colors.reset}');
    exit(1);
  }

  if (changelog.trim().isEmpty) {
    stderr.writeln('${Colors.red}Error: No changelog content '
        'found for version $version${Colors.reset}');
    exit(1);
  }

  // Get previous tag for compare link
  final previousTag = await getPreviousTag();
  final repoUrl = await getRepoUrl();

  // Build release notes — optionally enriched with AI
  const changelogUrl =
      'https://github.com/grafana/faro-flutter-sdk/blob/main/CHANGELOG.md';

  String releaseNotes;
  if (isEnrich) {
    final enriched = await enrichWithAI(changelog, version);
    if (enriched != null) {
      releaseNotes = enriched;
    } else {
      stderr.writeln(
          '${Colors.yellow}Falling back to plain changelog${Colors.reset}');
      stdout.writeln('');
      releaseNotes = _wrapInTemplate(changelog, version, changelogUrl);
    }
  } else {
    releaseNotes = _wrapInTemplate(changelog, version, changelogUrl);
  }

  // Append compare link
  if (previousTag != null && repoUrl != null) {
    releaseNotes += '\n\n---\n\n';
    releaseNotes += '**Full Changelog**: $repoUrl/compare/$previousTag...$tag';
  }

  // Show preview
  stdout.writeln('${Colors.cyan}📝 Release notes:${Colors.reset}');
  stdout.writeln('');
  stdout.writeln('${Colors.dim}$releaseNotes${Colors.reset}');
  stdout.writeln('');
  stdout.writeln('─' * 50);
  stdout.writeln('');

  if (isDryRun) {
    stdout.writeln('${Colors.yellow}This would:${Colors.reset}');
  } else {
    stdout.writeln('This will:');
  }
  stdout.writeln('  ${Colors.green}•${Colors.reset} Create '
      'git tag: ${Colors.yellow}$tag${Colors.reset}');
  stdout.writeln('  ${Colors.green}•${Colors.reset} Push tag to origin');
  stdout.writeln('  ${Colors.green}•${Colors.reset} Create '
      'GitHub release with above notes');
  stdout.writeln('');

  // In dry-run mode, exit here
  if (isDryRun) {
    stdout.writeln('${Colors.green}✅ Dry run complete. '
        'No changes were made.${Colors.reset}');
    exit(0);
  }

  // Ask for confirmation
  stdout.write('${Colors.yellow}Proceed? [y/N]:${Colors.reset} ');
  final input = stdin.readLineSync()?.toLowerCase() ?? '';

  if (input != 'y' && input != 'yes') {
    stdout.writeln('${Colors.yellow}Aborted.${Colors.reset}');
    exit(0);
  }

  stdout.writeln('');

  // Create and push tag
  stdout.write('Creating and pushing tag $tag... ');
  if (!await createAndPushTag(tag)) {
    exit(1);
  }
  stdout.writeln('${Colors.green}✓${Colors.reset}');

  // Create GitHub release
  stdout.write('Creating GitHub release... ');
  final releaseTitle = 'v$version';
  if (!await createGitHubRelease(tag, releaseTitle, releaseNotes)) {
    stderr.writeln('');
    stderr.writeln('${Colors.yellow}Tag was pushed but GitHub '
        'release creation failed.${Colors.reset}');
    stderr.writeln('You can create the release manually at:');
    stderr.writeln('  $repoUrl/releases/new?tag=$tag');
    exit(1);
  }
  stdout.writeln('${Colors.green}✓${Colors.reset}');

  // Success!
  stdout.writeln('');
  stdout.writeln(
      '${Colors.green}🚀 Release $tag created successfully!${Colors.reset}');
  stdout.writeln('');
  stdout.writeln('Next steps:');
  stdout.writeln('  1. GitHub Actions will automatically publish to pub.dev');
  stdout.writeln('  2. Verify at https://pub.dev/packages/faro');
  stdout.writeln('');
  if (repoUrl != null) {
    stdout.writeln(
        '${Colors.cyan}Release:${Colors.reset} $repoUrl/releases/tag/$tag');
    stdout.writeln('${Colors.cyan}Actions:${Colors.reset} $repoUrl/actions');
  }
}
