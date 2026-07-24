// Shared helpers for the Faro telemetry debugging tools in this folder.
//
// These scripts inspect the telemetry a Faro app actually exported to Grafana
// Cloud (Loki + Tempo) via the `gcx` CLI. They are development/debugging aids,
// kept separate from the release tooling in the parent `tool/` directory.
//
// This file is a library (no `main`); the sibling scripts import it.

import 'dart:convert';
import 'dart:io';

/// A single telemetry signal (log, event, exception, or measurement) pulled
/// from Loki, with the fields the tools commonly need plus the raw metadata.
class Signal {
  Signal({
    required this.kind,
    required this.name,
    required this.timestamp,
    required this.metadata,
    this.level,
    this.traceId,
    this.spanId,
  });
  final String kind;
  final String name;
  final String timestamp;
  final Map<String, dynamic> metadata;
  final String? level;
  final String? traceId;
  final String? spanId;

  bool get hasTrace => traceId != null || spanId != null;
}

/// Thin wrapper around the `gcx` CLI that returns parsed JSON.
class Gcx {
  Gcx(this.bin, this.context);
  final String bin;
  final String context;

  dynamic json(List<String> args, {bool allowFailure = false}) {
    final ProcessResult result;
    try {
      result = Process.runSync(bin, ['--context', context, ...args]);
    } on ProcessException catch (e) {
      fail('Could not run "$bin" (${e.message}). '
          'Is gcx installed and on your PATH? See https://github.com/grafana/gcx');
    }
    if (result.exitCode != 0) {
      if (allowFailure) return null;
      fail('gcx ${args.join(' ')} failed (exit ${result.exitCode}):\n'
          '${result.stderr}');
    }
    final out = (result.stdout as String).trim();
    if (out.isEmpty) return allowFailure ? null : <String, dynamic>{};
    try {
      return jsonDecode(out);
    } catch (e) {
      if (allowFailure) return null;
      fail('Could not parse gcx JSON for "${args.join(' ')}": $e');
    }
  }
}

/// Resolves a Loki `app_id` from a Faro app name (`service_name`).
String? resolveAppId(Gcx runner, String appName) {
  final json = runner.json(['frontend', 'apps', 'list', '-o', 'json']);
  if (json is! List) return null;
  for (final app in json) {
    if (app is Map && app['spec'] is Map) {
      final spec = app['spec'] as Map;
      if (spec['name'] == appName) return spec['id']?.toString();
    }
  }
  return null;
}

/// Pulls telemetry signals for an app from Loki, filtered client-side by run
/// id / session id / kind. Those are stored in `structuredMetadata`, not as
/// indexed Loki labels, so filtering happens here rather than in the query.
List<Signal> queryLokiSignals(
  Gcx runner, {
  required String lokiDs,
  required String appId,
  required String since,
  required String limit,
  String? runId,
  String? sessionId,
  Set<String>? kinds,
}) {
  final json = runner.json([
    'logs',
    'query',
    '-d',
    lokiDs,
    '{app_id="$appId"}',
    '--since',
    since,
    '--limit',
    limit,
    '-o',
    'json',
  ]);
  final result = dig(json, ['data', 'result']);
  if (result is! List) return [];

  final signals = <Signal>[];
  var rawCount = 0;
  for (final stream in result) {
    if (stream is! Map) continue;
    final rawLabels = stream['stream'];
    final labels = rawLabels is Map<String, dynamic>
        ? rawLabels
        : const <String, dynamic>{};
    final values = stream['values'];
    if (values is! List) continue;
    for (final v in values) {
      rawCount++;
      // gcx returns each value as an object with a structuredMetadata map,
      // NOT a [timestamp, line] array.
      final rawMd = v is Map ? v['structuredMetadata'] : null;
      final md =
          rawMd is Map<String, dynamic> ? rawMd : const <String, dynamic>{};
      if (runId != null && md['session_attr_qa_run_id'] != runId) continue;
      if (sessionId != null && md['session_id'] != sessionId) continue;

      final kind = (md['kind'] ?? labels['kind'] ?? 'unknown').toString();
      if (kinds != null && !kinds.contains(kind)) continue;

      final ts =
          (md['timestamp'] ?? (v is Map ? v['timestamp'] : null) ?? '')
              .toString();
      signals.add(
        Signal(
          kind: kind,
          name: signalName(kind, md),
          timestamp: ts,
          metadata: md,
          level: md['level']?.toString(),
          traceId: (md['trace_id'] ?? md['traceID'])?.toString(),
          spanId: (md['span_id'] ?? md['spanID'])?.toString(),
        ),
      );
    }
  }
  // The --limit applies to the raw Loki stream, BEFORE client-side run/session
  // filtering. If we hit it, the run's signals may be silently truncated.
  final limitN = int.tryParse(limit);
  if (limitN != null && rawCount >= limitN) {
    stderr.writeln('WARNING: hit --limit ($limit) raw Loki lines; results may '
        'be truncated. Raise --limit or narrow --since.');
  }
  return signals;
}

/// Human-readable name for a signal. Note the per-kind field names: events use
/// `event_name`, logs use `message`, exceptions/measurements use `type`.
String signalName(String kind, Map<String, dynamic> md) {
  switch (kind) {
    case 'event':
      return (md['event_name'] ?? md['name'] ?? '(event)').toString();
    case 'measurement':
      return (md['type'] ?? '(measurement)').toString();
    case 'exception':
      return (md['type'] ?? md['value'] ?? '(exception)').toString();
    case 'log':
      return (md['message'] ?? '(log)').toString();
    default:
      return (md['name'] ?? md['message'] ?? md['type'] ?? '(unknown)')
          .toString();
  }
}

/// Safely walks nested maps by [path], returning null if any hop is missing.
dynamic dig(dynamic node, List<String> path) {
  var current = node;
  for (final key in path) {
    if (current is Map && current.containsKey(key)) {
      current = current[key];
    } else {
      return null;
    }
  }
  return current;
}

/// Shortens an id for display to [len] chars plus a trailing `...` when cut;
/// returns '-' for null.
String short(String? id, {int len = 12}) {
  if (id == null) return '-';
  return id.length <= len ? id : '${id.substring(0, len)}...';
}

/// Truncates [s] to [max] chars plus a trailing `...` when cut.
String truncate(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max)}...';

/// Pads/truncates [s] to a fixed column [width]. Truncation is marked with an
/// ellipsis (so a cut value is never mistaken for a complete one) and keeps a
/// trailing space so columns stay visually separated. Assumes width >= 4.
String pad(String s, int width) {
  if (s.length < width) return s.padRight(width);
  if (s.length == width) return s;
  return '${s.substring(0, width - 4)}... ';
}

/// Prints an error and exits non-zero.
Never fail(String message) {
  stderr.writeln('ERROR: $message');
  exit(1);
}

/// Minimal `--key value` / `--key=value` / `--flag` argument parser.
class Args {
  Args(List<String> argv) {
    for (var i = 0; i < argv.length; i++) {
      var a = argv[i];
      if (!a.startsWith('-')) continue;
      a = a.replaceFirst(RegExp('^--?'), '');
      if (a.contains('=')) {
        final idx = a.indexOf('=');
        _map[a.substring(0, idx)] = a.substring(idx + 1);
      } else if (i + 1 < argv.length && !argv[i + 1].startsWith('-')) {
        _map[a] = argv[++i];
      } else {
        _map[a] = 'true';
      }
    }
  }
  final _map = <String, String>{};
  String? value(String key) => _map[key];
  bool has(String key) => _map.containsKey(key);

  /// Fails if any parsed flag is not in [known] (plus `help`/`h`). Guards
  /// against silent typos like `--runid` widening a query to the wrong data.
  void ensureKnown(Set<String> known) {
    final allowed = {...known, 'help', 'h'};
    final unknown = _map.keys.where((k) => !allowed.contains(k)).toList();
    if (unknown.isNotEmpty) {
      fail('Unknown flag(s): ${unknown.map((k) => '--$k').join(', ')}. '
          'See --help.');
    }
  }
}
