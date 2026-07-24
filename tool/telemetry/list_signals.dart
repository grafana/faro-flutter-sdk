// Lists every Faro telemetry signal (log, event, exception, measurement) for a
// single session or run, as a chronological timeline. This is the generic
// "reconstruct what the app emitted" primitive — not trace-specific — useful
// for eyeballing a session, debugging missing/duplicated signals, or feeding a
// normalized signal list into other tooling via --format json.
//
// Generic: works for any Faro app, via the `gcx` CLI.
//
// Usage:
//   dart tool/telemetry/list_signals.dart \
//     --context <ctx> (--app-id <id> | --app-name <service_name>) \
//     (--session-id <id> | --run-id <qa_run_id>) \
//     [--kind log,event,exception,measurement] \
//     [--since 1h] [--limit 2000] [--format timeline|json] \
//     [--loki-ds grafanacloud-logs] [--gcx gcx]
//
// Exit codes: 0 = signals listed (or none found); 1 = query/arg error.

import 'dart:convert';
import 'dart:io';

import 'common.dart';

void main(List<String> argv) {
  final args = Args(argv);
  if (args.has('help') || args.has('h')) {
    _printUsage();
    return;
  }
  args.ensureKnown({
    'context', 'gcx', 'loki-ds', 'since', 'limit', 'format', //
    'run-id', 'session-id', 'app-id', 'app-name', 'kind',
  });

  final context = args.value('context');
  final gcx = args.value('gcx') ?? 'gcx';
  final lokiDs = args.value('loki-ds') ?? 'grafanacloud-logs';
  final since = args.value('since') ?? '1h';
  final limit = args.value('limit') ?? '2000';
  final format = args.value('format') ?? 'timeline';
  final runId = args.value('run-id');
  final sessionId = args.value('session-id');
  var appId = args.value('app-id');
  final appName = args.value('app-name');
  final kindFilter = args
      .value('kind')
      ?.split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();

  if (context == null) fail('Missing required --context. See --help.');
  if (appId == null && appName == null) {
    fail('Provide either --app-id or --app-name. See --help.');
  }
  if (runId == null && sessionId == null) {
    fail('Provide either --session-id or --run-id. See --help.');
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
    kinds: kindFilter,
  )..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  if (format == 'json') {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert(signals.map(_toJson).toList()),
    );
    return;
  }

  final target = runId != null ? 'qa_run_id=$runId' : 'session_id=$sessionId';
  stdout
    ..writeln('Context : $context   App: id=$appId')
    ..writeln('Target  : $target   Window: last $since')
    ..writeln();

  if (signals.isEmpty) {
    stdout.writeln(
      'No signals found. Data can take ~30-45s to appear; try a '
      'wider --since.',
    );
    return;
  }

  stdout.writeln(
    '${pad('TIME (UTC)', 26)}${pad('KIND', 13)}'
    '${pad('SIGNAL', 34)}EXTRA',
  );
  stdout.writeln('-' * 100);
  for (final s in signals) {
    final kindCol = (s.kind == 'log' && s.level != null)
        ? '${s.kind}/${s.level}'
        : s.kind;
    stdout.writeln(
      '${pad(s.timestamp, 26)}${pad(kindCol, 13)}'
      '${pad(s.name, 34)}${_extra(s)}',
    );
  }

  final byKind = <String, int>{};
  for (final s in signals) {
    byKind[s.kind] = (byKind[s.kind] ?? 0) + 1;
  }
  final summary =
      (byKind.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
          .map((e) => '${e.key}=${e.value}')
          .join('  ');
  stdout
    ..writeln('-' * 100)
    ..writeln('Total: ${signals.length}   ($summary)');
}

Map<String, dynamic> _toJson(Signal s) => {
  'timestamp': s.timestamp,
  'kind': s.kind,
  'name': s.name,
  if (s.kind == 'log' && s.level != null) 'level': s.level,
  if (s.traceId != null) 'trace_id': s.traceId,
  if (s.spanId != null) 'span_id': s.spanId,
  // Full structuredMetadata so `--format json` can be used to inspect
  // actual field names/values (e.g. confirm a new field surfaces).
  'metadata': s.metadata,
};

/// Trailing EXTRA column: trace context plus a couple of kind-specific hints
/// (exception value, measurement value keys).
String _extra(Signal s) {
  final parts = <String>[];
  if (s.traceId != null) {
    parts.add('trace=${short(s.traceId, len: 10)}:${s.spanId ?? '-'}');
  }
  if (s.kind == 'exception' && s.metadata['value'] != null) {
    parts.add('value="${truncate(s.metadata['value'].toString(), 40)}"');
  }
  if (s.kind == 'measurement') {
    final values = s.metadata.entries
        .where((e) => e.key.startsWith('value'))
        .map((e) => '${e.key}=${e.value}')
        .toList();
    if (values.isNotEmpty) parts.add(values.join(','));
  }
  return parts.join('  ');
}

void _printUsage() {
  stdout.writeln(r'''
list_signals.dart — chronological timeline of a session's telemetry.

Required:
  --context <name>        gcx context (Grafana stack)
  --app-id <id> | --app-name <service_name>
  --session-id <id> | --run-id <qa_run_id>

Optional:
  --kind <list>           comma list: log,event,exception,measurement
  --since <dur>           default: 1h
  --limit <n>             default: 2000
  --format <fmt>          timeline (default) | json
  --loki-ds <uid>         default: grafanacloud-logs
  --gcx <path>            default: gcx

Example:
  dart tool/telemetry/list_signals.dart \
    --context <ctx> --app-id <app-id> --run-id validate-run --since 2h
''');
}
