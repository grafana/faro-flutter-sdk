// Captures a normalized snapshot of the telemetry a Faro app emitted for a
// single run, and diffs two snapshots. Built for before/after validation of
// SDK changes: run the app on `main`, snapshot; run on the branch, snapshot;
// diff. The diff highlights structural changes (which signal types gained or
// lost fields, and whether they carry trace context) while ignoring volatile
// noise like timestamps, session ids, and the concrete trace/span id values.
//
// Normalization strategy: signals are grouped by "kind::name". For each group
// we record the count, the union of structuredMetadata keys, and whether the
// group carries trace context. Volatile values are never compared — only the
// SHAPE (key set) and trace presence, so two runs of the same code match.
//
// Generic: works for any Faro app, via the `gcx` CLI.
//
// Usage:
//   # snapshot a run to a file
//   dart tool/telemetry/snapshot.dart snapshot \
//     --context <ctx> (--app-id <id> | --app-name <name>) \
//     [--run-id <id> | --session-id <id>] [--since 30m] [--out run.json]
//
//   # diff two snapshots (before = main, after = branch)
//   dart tool/telemetry/snapshot.dart diff before.json after.json
//
// Exit codes for `diff`: 0 = identical shape; 2 = differences found (not an
// error, just a signal for scripting).

import 'dart:convert';
import 'dart:io';

import 'common.dart';

// Trace-context keys. Their VALUES are volatile across runs, but their
// PRESENCE is exactly what a correlation change adds, so they are surfaced via
// the `has_trace` flag rather than the compared metadata-key set.
const _traceKeys = <String>{'trace_id', 'span_id', 'traceID', 'spanID'};

void main(List<String> argv) {
  // Only the bare `help` keyword counts as help when it's the first token;
  // matching it anywhere would treat flag values/paths (e.g. `--run-id help`
  // or `diff help after.json`) as a help request. The `--help`/`-h` flags may
  // appear anywhere.
  if (argv.isEmpty ||
      argv.first == 'help' ||
      argv.contains('--help') ||
      argv.contains('-h')) {
    _printUsage();
    return;
  }
  final mode = argv.first;
  final rest = argv.sublist(1);
  switch (mode) {
    case 'snapshot':
      _snapshot(Args(rest));
    case 'diff':
      final positional = rest.where((a) => !a.startsWith('-')).toList();
      if (positional.length != 2) {
        fail('diff needs exactly two snapshot files: <before> <after>');
      }
      _diff(positional[0], positional[1]);
    default:
      fail('Unknown mode "$mode". Use "snapshot" or "diff". See --help.');
  }
}

void _snapshot(Args args) {
  args.ensureKnown({
    'context', 'gcx', 'loki-ds', 'since', 'limit', //
    'run-id', 'session-id', 'app-id', 'app-name', 'out',
  });
  final context = args.value('context');
  final gcx = args.value('gcx') ?? 'gcx';
  final lokiDs = args.value('loki-ds') ?? 'grafanacloud-logs';
  final since = args.value('since') ?? '30m';
  final limit = args.value('limit') ?? '2000';
  final runId = args.value('run-id');
  final sessionId = args.value('session-id');
  var appId = args.value('app-id');
  final appName = args.value('app-name');
  final out = args.value('out');

  if (context == null) fail('Missing required --context.');
  if (appId == null && appName == null) {
    fail('Provide either --app-id or --app-name.');
  }

  final runner = Gcx(gcx, context);
  if (appId == null) {
    appId = resolveAppId(runner, appName!, lokiDs: lokiDs, since: since);
    if (appId == null) fail('Could not resolve app-id for "$appName".');
  }

  final signals = queryLokiSignals(
    runner,
    lokiDs: lokiDs,
    appId: appId,
    since: since,
    limit: limit,
    runId: runId,
    sessionId: sessionId,
  );

  if (signals.isEmpty) {
    final filtered = runId != null || sessionId != null;
    fail(
      'No signals found for app_id=$appId in the last $since'
      '${filtered ? ' matching the given filter' : ''}. '
      'Refusing to write an empty snapshot (an empty-vs-empty diff would look '
      '"identical"). Data can take ~30-45s to appear; try a wider --since.',
    );
  }

  final groups = <String, _Group>{};
  for (final s in signals) {
    final group = groups.putIfAbsent(
      '${s.kind}::${s.name}',
      () => _Group(s.kind, s.name),
    );
    group.count++;
    if (s.hasTrace) group.hasTrace = true;
    for (final key in s.metadata.keys) {
      // Trace keys are surfaced via has_trace, not the compared key set.
      if (!_traceKeys.contains(key)) group.keys.add(key);
    }
  }

  final sorted = groups.values.toList()..sort((a, b) => a.key.compareTo(b.key));
  final snapshot = {
    'app_id': appId,
    'context': context,
    'run_id': runId,
    'session_id': sessionId,
    'since': since,
    'total_signals': signals.length,
    'groups': {
      for (final g in sorted)
        g.key: {
          'kind': g.kind,
          'name': g.name,
          'count': g.count,
          'has_trace': g.hasTrace,
          'metadata_keys': g.keys.toList()..sort(),
        },
    },
  };

  final encoded = const JsonEncoder.withIndent('  ').convert(snapshot);
  if (out != null) {
    File(out).writeAsStringSync('$encoded\n');
    stdout.writeln(
      'Wrote snapshot: $out  (${groups.length} groups, '
      '${signals.length} signals)',
    );
  } else {
    stdout.writeln(encoded);
  }
}

void _diff(String beforePath, String afterPath) {
  final before = _readSnapshot(beforePath);
  final after = _readSnapshot(afterPath);
  final bGroups = (before['groups'] as Map).cast<String, dynamic>();
  final aGroups = (after['groups'] as Map).cast<String, dynamic>();

  final allKeys = {...bGroups.keys, ...aGroups.keys}.toList()..sort();
  var changes = 0;

  stdout.writeln('TELEMETRY SHAPE DIFF');
  stdout.writeln('  before: $beforePath');
  stdout.writeln('  after : $afterPath');
  stdout.writeln('-' * 78);

  for (final key in allKeys) {
    final b = bGroups[key] as Map<String, dynamic>?;
    final a = aGroups[key] as Map<String, dynamic>?;
    if (b == null) {
      stdout.writeln('  + NEW GROUP   $key  (has_trace=${a!['has_trace']})');
      changes++;
      continue;
    }
    if (a == null) {
      stdout.writeln('  - REMOVED     $key');
      changes++;
      continue;
    }
    final bTrace = b['has_trace'] == true;
    final aTrace = a['has_trace'] == true;
    final bKeys = (b['metadata_keys'] as List).map((e) => e.toString()).toSet();
    final aKeys = (a['metadata_keys'] as List).map((e) => e.toString()).toSet();
    final added = aKeys.difference(bKeys).toList()..sort();
    final removed = bKeys.difference(aKeys).toList()..sort();

    if (bTrace != aTrace || added.isNotEmpty || removed.isNotEmpty) {
      stdout.writeln('  ~ CHANGED     $key');
      if (bTrace != aTrace) {
        stdout.writeln('      has_trace: $bTrace -> $aTrace');
      }
      if (added.isNotEmpty) stdout.writeln('      + keys: ${added.join(', ')}');
      if (removed.isNotEmpty) {
        stdout.writeln('      - keys: ${removed.join(', ')}');
      }
      changes++;
    }
  }

  stdout.writeln('-' * 78);
  if (changes == 0) {
    stdout.writeln('No structural differences. Telemetry shape is identical.');
    exit(0);
  }
  stdout.writeln(
    '$changes group(s) differ. Review above — for a '
    'trace-correlation change, expect only has_trace / trace-key deltas.',
  );
  exit(2);
}

class _Group {
  _Group(this.kind, this.name);
  final String kind;
  final String name;
  int count = 0;
  bool hasTrace = false;
  final Set<String> keys = {};
  String get key => '$kind::$name';
}

Map<String, dynamic> _readSnapshot(String path) {
  final file = File(path);
  if (!file.existsSync()) fail('Snapshot file not found: $path');
  final dynamic decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } catch (e) {
    fail('Could not parse snapshot "$path": $e');
  }
  if (decoded is! Map<String, dynamic> || decoded['groups'] is! Map) {
    fail(
      '"$path" is not a telemetry snapshot (missing "groups"). '
      'Generate one with: snapshot.dart snapshot ... --out $path',
    );
  }
  return decoded;
}

void _printUsage() {
  stdout.writeln(r'''
snapshot.dart — normalized before/after telemetry comparison.

MODES:
  snapshot   capture a run's telemetry shape to JSON
  diff       compare two snapshot files

snapshot flags:
  --context <name>        gcx context (required)
  --app-id <id> | --app-name <service_name>
  --run-id <id>           filter by session_attr_qa_run_id
  --session-id <id>       filter by session_id
  --loki-ds <uid>         default: grafanacloud-logs
  --since <dur>           default: 30m
  --limit <n>             default: 2000
  --out <file>            write JSON here (default: stdout)

Examples:
  dart tool/telemetry/snapshot.dart snapshot --context <ctx> \
    --app-id <app-id> --run-id main-run   --since 1h --out before.json
  dart tool/telemetry/snapshot.dart snapshot --context <ctx> \
    --app-id <app-id> --run-id branch-run --since 1h --out after.json
  dart tool/telemetry/snapshot.dart diff before.json after.json
''');
}
