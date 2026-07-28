# Telemetry validation tools

Dev/debugging helpers for validating that an SDK change produces the intended
telemetry — and nothing else — by inspecting the real data that reached Grafana
Cloud (Loki + Tempo), not just unit tests.

These are tool-agnostic Dart scripts (no editor/agent assumptions). They shell
out to the [`gcx`](https://github.com/grafana/gcx) CLI and are kept separate
from the release tooling in the parent `tool/` directory.

## When this is useful

- A change touches what/how telemetry is emitted (new fields, trace/span
  correlation, HTTP tracking, measurements, events).
- You want to answer "does the data look right in Grafana Cloud?" or "is only X
  different vs `main`?".
- Verifying that signals correlate to the correct Tempo trace/span.

## Inputs you need

1. **Grafana stack / gcx context**. The example app's collector URL is in
   `example/api-config.json`; match its host to a context via
   `gcx config list-contexts`.
2. **App identity**: Loki `app_id` (preferred) or the app name
   (`service_name`). The example app is `faro-flutter-sdk-example`.
3. **Environment and time range**.
4. **Isolation key**: a `qa_run_id` (or `session_id`) for the run to inspect.
5. **Comparison scope**: which branch(es) to compare (branch vs `main`?).

### Placeholders used in the examples below

Substitute your own values — discover them via Preflight (below).

| Placeholder | Meaning | How to find it |
|---|---|---|
| `<ctx>` | gcx context (Grafana stack) | `gcx config list-contexts` |
| `<app-id>` | Loki `app_id` for your Faro app | `gcx frontend apps list` |
| `<qa_run_id>` | your run's `session_attr_qa_run_id` | you set it (see step 2) |
| Loki datasource | defaults to `grafanacloud-logs` | `gcx --context <ctx> datasources list` |
| Tempo datasource | defaults to `grafanacloud-traces` | `gcx --context <ctx> datasources list` |

The example app in this repo uses `service_name` `faro-flutter-sdk-example`.

## The tools

All three are generic (work for any Faro app), dependency-free Dart, share
`common.dart`, and shell out to `gcx`. Run any with `--help` for full flags.

### `verify_correlation.dart`

Pulls a run's signals from Loki, extracts each signal's `trace_id`/`span_id`,
fetches the referenced traces from Tempo, and confirms the span exists. Exits
non-zero on any dangling correlation.

```bash
dart tool/telemetry/verify_correlation.dart \
  --context <ctx> --app-id <app-id> \
  --run-id <qa_run_id> --since 1h
```

### `snapshot.dart`

Captures a normalized telemetry snapshot for a run (grouped by `kind::name`,
comparing only shape + trace presence, not volatile values), and diffs two
snapshots. Ideal for "only the trace context changed" checks.

```bash
# one run per branch, then diff
dart tool/telemetry/snapshot.dart snapshot --context <ctx> --app-id <app-id> \
  --run-id main-run --since 1h --out before.json
dart tool/telemetry/snapshot.dart snapshot --context <ctx> --app-id <app-id> \
  --run-id branch-run --since 1h --out after.json
dart tool/telemetry/snapshot.dart diff before.json after.json
```

`snapshot` is **not trace-specific** — it validates *any* metadata-shape change.
E.g. adding a new field like `battery_state` (or a whole new `app_battery`
measurement) shows up in the diff as `+ keys: battery_state` on the affected
`kind::name` groups (or `+ NEW GROUP`), proving the field appears where expected
and nothing else moved. Know its limits before trusting a clean diff:

- **Compares key *presence*, not values.** A same-key value change (e.g.
  battery `0–100` vs `0.0–1.0`, or a units change) is invisible. Use
  `list_signals.dart` (its EXTRA column / `--format json`) to check values.
- **Only sees fields that reach Loki `structuredMetadata`.** If a new field
  lands only in the log-line body or an unflattened nested payload, it won't
  appear as a key. Sanity-check once with `list_signals --format json` that the
  field actually surfaces.
- **Ignores `count`.** Per-group counts are captured but not diffed (they drift
  run to run), so "fires 5× instead of 1×" is not flagged — check the timeline.
- **Requires identical scenarios on both runs.** Grouping is by `kind::name`, so
  differing user actions produce spurious `NEW GROUP`/`REMOVED` noise. Keep the
  two runs identical (same taps, similar duration), distinct `qa_run_id`s.

### `list_signals.dart`

Generic (not trace-specific) chronological timeline of every
log/event/exception/measurement for a session or run. Use to eyeball what an app
actually emitted, spot missing/duplicated signals, or export a normalized signal
list (`--format json`). Filter with `--kind log,event,exception,measurement`.

```bash
dart tool/telemetry/list_signals.dart --context <ctx> --app-id <app-id> \
  --run-id <qa_run_id> --since 2h
dart tool/telemetry/list_signals.dart --context <ctx> --app-id <app-id> \
  --session-id <session_id> --kind log,exception --format json
```

## Workflow

```
- [ ] 1. Preflight: resolve context, app_id, datasources; verify gcx auth
- [ ] 2. Generate isolated data (example app + unique FARO_QA_RUN_ID)
- [ ] 3. Inspect timeline + verify correlation (list_signals, verify_correlation)
- [ ] 4. Before/after A/B if comparing branches (snapshot.dart)
- [ ] 5. Report findings with evidence
```

### 1. Preflight

```bash
# keep gcx current — the JSON output shape these tools parse has changed
# across versions (see gotchas). Update if it looks stale.
gcx version
gcx config check
gcx config list-contexts
# confirm datasources exist on the chosen context
gcx --context <ctx> datasources list -o json | jq -r \
  '.datasources[] | select(.name|test("logs|traces")) | "\(.uid)\t\(.name)"'
```

### 2. Generate isolated data

Set a unique run id in `example/api-config.json` (gitignored) so the run is
trivially filterable:

```json
{ "FARO_COLLECTOR_URL": "...", "FARO_QA_RUN_ID": "validate-<yyyymmdd-hhmm>" }
```

Run the app and trigger the relevant scenario(s), then wait ~30–45s for
ingestion. To drive the example app on an Android emulator headlessly, see
"Driving the example app" below.

### 3. Inspect and verify

First, get a chronological picture of what the run emitted:

```bash
dart tool/telemetry/list_signals.dart --context <ctx> --app-id <id> \
  --run-id <qa_run_id> --since 2h
```

Then run `verify_correlation.dart` (above). Read the output:

- **CORRELATED** signals should be exactly those emitted inside a span (plus the
  span's own `span.<name>` event, which always carries its context).
- **UNCORRELATED** should include background telemetry: `app_cpu_usage`,
  `app_memory`, `app_frames_rate`, `app_refresh_rate`, `app_startup`,
  `session_start`, `view_changed`, `user_interaction`, `app_lifecycle_changed`.
- Any signal correlated to a span **not** found in Tempo is a bug (dangling
  correlation) → tool exits non-zero.

### 4. Before/after A/B (branch vs main)

Only needed when confirming "nothing else changed". Do one isolated run per
branch (distinct `qa_run_id`), snapshot each, then `diff`. A correct
trace-correlation change shows **only** `has_trace: false -> true` (and/or added
trace keys) on the affected `kind::name` groups; anything else is unexpected.

### 5. Report

State: what correlates, what does not, the trace/span ids verified in Tempo, and
the exact A/B delta. Cite the `qa_run_id`, context, and commands used.

## gcx / Loki / Tempo gotchas (learned the hard way)

- **App name label is `service_name`**, not `app_name`. Filter Loki by the
  indexed `app_id` label.
- **Trace context is not a stream label.** It lives in the log line body and in
  `structuredMetadata` as `trace_id`/`span_id` (and duplicated as
  `traceID`/`spanID`).
- **Event fields are prefixed `event_`** in `structuredMetadata` — the event
  name is `event_name` (not `name`). Logs use `message`, exceptions/measurements
  use `type`.
- **gcx `logs query -o json` returns `values` as objects** with `.line` and
  `.structuredMetadata` — not `[ts, line]` arrays. Extracting `.[1]` yields
  nothing. The per-signal RFC3339 `timestamp` is inside `structuredMetadata`
  (so lexicographic string sort is chronological).
- **gcx metric queries (`sum by(...)`) drop labels** in the metric object in
  some versions — prefer raw stream queries and parse `structuredMetadata`.
- **Tempo `gcx traces get <id>` returns OTLP JSON** with `spanId` as **base64**
  (`resourceSpans[].scopeSpans[].spans[].spanId`). Decode to hex to compare with
  Loki's hex `span_id`. Query traces by the 32-char hex trace id.
- **Ingestion delay ~30–45s.** If empty, widen `--since` before concluding data
  is missing.
- **`--limit` applies to the raw Loki stream, before client-side run/session
  filtering.** On a busy app your run's signals can be truncated; the tools warn
  when the limit is hit — raise `--limit` or narrow `--since`.
- **FEO registry id ≠ Loki `app_id`** necessarily — resolve `app_id` from Loki.
- Separate stderr from stdout: `gcx ... -o json 2>/dev/null` is clean JSON; a
  merged stream has a non-JSON first line.

## Driving the example app (Android emulator)

Buttons expose their label as the accessibility `content-desc`, so taps can be
scripted without hardcoded coordinates:

```bash
# dump the UI tree and find a button's bounds by its label
adb -s emulator-5554 shell uiautomator dump /sdcard/ui.xml
adb -s emulator-5554 shell cat /sdcard/ui.xml | tr '>' '>\n' \
  | grep -oE 'content-desc="<label>"[^/]*bounds="\[[0-9,]+\]\[[0-9,]+\]"'
# tap the center of the reported bounds
adb -s emulator-5554 shell input tap <cx> <cy>
```

Navigation for telemetry demos: Home → "Change Route" → "Tracing / Spans"
(or "Custom Telemetry" / "Network Requests"). The "Span + Telemetry" button runs
a span and emits one log/event/exception/measurement inside it — the canonical
correlation test.
