// Verifies Faro log/trace correlation for a single run by cross-referencing
// Loki signals against Tempo traces via the `gcx` CLI.
//
// For a given app + run (or session), it pulls every log/event/exception/
// measurement from Loki, extracts the trace_id/span_id each one carries, then
// fetches the referenced traces from Tempo and confirms the span actually
// exists. Signals that reference a trace/span not found in Tempo are reported
// as dangling correlations and cause a non-zero exit.
//
// Generic: works for any Faro app, not just the example app in this repo.
//
// Usage:
//   dart tool/telemetry/verify_correlation.dart \
//     --context <gcx-context> \
//     (--app-id <id> | --app-name <service_name>) \
//     [--run-id <qa_run_id> | --session-id <id>] \
//     [--loki-ds grafanacloud-logs] [--tempo-ds grafanacloud-traces] \
//     [--since 30m] [--limit 2000] [--gcx gcx]
//
// Exit codes: 0 = all referenced spans found in Tempo (or no correlation to
// check); 1 = at least one dangling correlation or a query error.

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
    'context', 'gcx', 'loki-ds', 'tempo-ds', 'since', 'limit', //
    'run-id', 'session-id', 'app-id', 'app-name',
  });

  final context = args.value('context');
  final gcx = args.value('gcx') ?? 'gcx';
  final lokiDs = args.value('loki-ds') ?? 'grafanacloud-logs';
  final tempoDs = args.value('tempo-ds') ?? 'grafanacloud-traces';
  final since = args.value('since') ?? '30m';
  final limit = args.value('limit') ?? '2000';
  final runId = args.value('run-id');
  final sessionId = args.value('session-id');
  var appId = args.value('app-id');
  final appName = args.value('app-name');

  if (context == null) fail('Missing required --context. See --help.');
  if (appId == null && appName == null) {
    fail('Provide either --app-id or --app-name. See --help.');
  }

  final runner = Gcx(gcx, context);

  if (appId == null) {
    stdout.writeln('Resolving app-id for "$appName" ...');
    appId = resolveAppId(runner, appName!, lokiDs: lokiDs, since: since);
    if (appId == null) {
      fail('Could not resolve an app-id for --app-name "$appName".');
    }
    stdout.writeln('  -> app_id=$appId');
  }

  final filter = runId != null
      ? 'qa_run_id=$runId'
      : sessionId != null
      ? 'session_id=$sessionId'
      : '(none)';
  stdout
    ..writeln('Context : $context')
    ..writeln('App     : id=$appId')
    ..writeln('Loki    : $lokiDs   Tempo: $tempoDs')
    ..writeln('Window  : last $since')
    ..writeln('Filter  : $filter')
    ..writeln();

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
      'Data can take ~30-45s to appear; try a wider --since.',
    );
  }

  // "Correlated" = carries ANY trace context (trace_id and/or span_id). A
  // signal with only one of the two is partial context and must be flagged,
  // not silently passed as uncorrelated.
  final correlated = signals.where((s) => s.hasTrace).toList();
  final uncorrelated = signals.where((s) => !s.hasTrace).toList();

  // Fetch each referenced trace once and collect its span-id set (hex).
  final traceSpanIds = <String, Set<String>?>{};
  for (final traceId
      in correlated.map((s) => s.traceId).whereType<String>().toSet()) {
    traceSpanIds[traceId] = _fetchTraceSpanIds(runner, tempoDs, traceId);
  }

  stdout.writeln('CORRELATED SIGNALS (carry trace context)');
  stdout.writeln('-' * 78);
  var dangling = 0;
  if (correlated.isEmpty) {
    stdout.writeln('  (none)');
  }
  for (final s in correlated) {
    final spans = s.traceId == null ? null : traceSpanIds[s.traceId];
    final String status;
    if (s.traceId == null) {
      status = 'NO TRACE ID (partial context)';
      dangling++;
    } else if (s.spanId == null) {
      status = 'NO SPAN ID (partial context)';
      dangling++;
    } else if (spans == null) {
      status = 'TRACE NOT FOUND IN TEMPO';
      dangling++;
    } else if (spans.isEmpty) {
      status = 'TRACE HAS NO DECODABLE SPANS';
      dangling++;
    } else if (!spans.contains(s.spanId!.toLowerCase())) {
      status = 'SPAN NOT IN TRACE';
      dangling++;
    } else {
      status = 'OK';
    }
    stdout.writeln(
      '  [${pad(s.kind, 11)}] ${pad(s.name, 30)} '
      'trace=${short(s.traceId)} span=${s.spanId ?? '-'}  $status',
    );
  }

  stdout.writeln();
  stdout.writeln('UNCORRELATED SIGNALS (no trace context) — grouped');
  stdout.writeln('-' * 78);
  final grouped = <String, int>{};
  for (final s in uncorrelated) {
    final key = '${s.kind}::${s.name}';
    grouped[key] = (grouped[key] ?? 0) + 1;
  }
  if (grouped.isEmpty) {
    stdout.writeln('  (none)');
  }
  final keys = grouped.keys.toList()..sort();
  for (final k in keys) {
    stdout.writeln('  ${pad(k, 44)} x${grouped[k]}');
  }

  stdout.writeln();
  stdout.writeln('SUMMARY');
  stdout.writeln('-' * 78);
  final tracesFound = traceSpanIds.values.where((s) => s != null).length;
  stdout
    ..writeln('  signals total     : ${signals.length}')
    ..writeln('  correlated        : ${correlated.length}')
    ..writeln('  uncorrelated      : ${uncorrelated.length}')
    ..writeln(
      '  distinct traces   : ${traceSpanIds.length} '
      '(found in Tempo: $tracesFound)',
    )
    ..writeln('  dangling refs     : $dangling');

  if (dangling > 0) {
    stdout.writeln(
      '\nFAIL: $dangling signal(s) have partial context or '
      'reference a trace/span not found in Tempo.',
    );
    exit(1);
  }
  stdout.writeln(
    '\nPASS: every correlated signal resolves to a real Tempo '
    'span.',
  );
}

/// Returns the set of span-ids (lowercase hex) in a Tempo trace. Returns null
/// only when the trace could not be fetched (missing/absent); an empty set
/// means the trace was fetched but no `spanId`s decoded, which is distinct and
/// reported separately so a decode/schema regression isn't mistaken for a
/// missing trace.
Set<String>? _fetchTraceSpanIds(Gcx runner, String tempoDs, String traceId) {
  final json = runner.json([
    'traces',
    'get',
    traceId,
    '-d',
    tempoDs,
    '-o',
    'json',
  ], allowFailure: true);
  if (json == null) return null;
  final ids = <String>{};
  _collectSpanIds(json, ids);
  return ids;
}

/// Recursively walks OTLP-shaped JSON collecting base64 `spanId` values,
/// decoded to lowercase hex. Skips `links`/`references`, whose `spanId`s point
/// at other spans (often in other traces) and would cause false matches.
void _collectSpanIds(dynamic node, Set<String> out) {
  if (node is Map) {
    for (final entry in node.entries) {
      if (entry.key == 'links' || entry.key == 'references') continue;
      if (entry.key == 'spanId' && entry.value is String) {
        final hex = _base64ToHex(entry.value as String);
        if (hex != null) out.add(hex);
      } else {
        _collectSpanIds(entry.value, out);
      }
    }
  } else if (node is List) {
    for (final item in node) {
      _collectSpanIds(item, out);
    }
  }
}

String? _base64ToHex(String b64) {
  try {
    final bytes = base64.decode(base64.normalize(b64));
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toLowerCase();
  } catch (_) {
    return null;
  }
}

void _printUsage() {
  stdout.writeln(r'''
verify_correlation.dart — cross-check Faro Loki signals vs Tempo.

Required:
  --context <name>        gcx context (Grafana stack)
  --app-id <id> | --app-name <service_name>

Optional:
  --run-id <id>           filter by session_attr_qa_run_id
  --session-id <id>       filter by session_id
  --loki-ds <uid>         default: grafanacloud-logs
  --tempo-ds <uid>        default: grafanacloud-traces
  --since <dur>           default: 30m
  --limit <n>             default: 2000
  --gcx <path>            default: gcx

Example:
  dart tool/telemetry/verify_correlation.dart \
    --context <ctx> --app-id <app-id> \
    --run-id <qa_run_id> --since 1h
''');
}
