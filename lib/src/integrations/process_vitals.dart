import 'dart:async';
import 'dart:developer';

import 'package:flutter/widgets.dart';

/// Event name for app CPU utilization samples.
const appCpuUsageEventName = 'app.cpu_usage';

/// Event name for app memory samples.
const appMemoryEventName = 'app.memory';

/// Bytes in one MB as used by the `app.memory` event.
const bytesPerMegabyte = 1048576;

/// The accepted `memory.basis` values: `rss` (Android) and
/// `phys_footprint` (iOS).
const memoryBases = {'rss', 'phys_footprint'};

/// One raw reading of the app process, as reported by the native platform.
///
/// The native side only reads counters. Windows, the CPU formula and the
/// cadence live in Dart so they are shared by Android and iOS.
@immutable
class ProcessVitalsReading {
  const ProcessVitalsReading({
    required this.monotonicNanos,
    required this.timestamp,
    this.cpuTimeSeconds,
    this.cpuCount,
    this.memoryBytes,
    this.memoryBasis,
  });

  /// Parses the map returned by the `getProcessVitals` method call.
  ///
  /// Returns `null` when the map has no usable monotonic clock value or
  /// capture time, since such a reading cannot start or end a window and
  /// cannot be timestamped.
  static ProcessVitalsReading? fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return null;
    }
    final monotonicNanos = map['monotonicNanos'];
    final timestampMillis = map['timestampMillis'];
    if (monotonicNanos is! int || timestampMillis is! int) {
      return null;
    }
    final cpuTimeSeconds = map['cpuTimeSeconds'];
    final cpuCount = map['cpuCount'];
    final memoryBytes = map['memoryBytes'];
    final memoryBasis = map['memoryBasis'];
    return ProcessVitalsReading(
      monotonicNanos: monotonicNanos,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        timestampMillis,
        isUtc: true,
      ),
      cpuTimeSeconds: cpuTimeSeconds is num ? cpuTimeSeconds.toDouble() : null,
      cpuCount: cpuCount is int ? cpuCount : null,
      memoryBytes: memoryBytes is int ? memoryBytes : null,
      memoryBasis: memoryBasis is String ? memoryBasis : null,
    );
  }

  /// Monotonic clock in nanoseconds.
  final int monotonicNanos;

  /// Wall-clock time at which the native side took the reading.
  ///
  /// Events use this time, not the time the reply reached Dart.
  final DateTime timestamp;

  /// User plus system CPU time of the process, in seconds.
  final double? cpuTimeSeconds;

  /// Logical CPUs available to the process at the time of the reading.
  final int? cpuCount;

  /// Physical memory in use by the process, in bytes.
  final int? memoryBytes;

  /// `rss` on Android, `phys_footprint` on iOS.
  final String? memoryBasis;
}

/// Reads the native process counters.
typedef ProcessVitalsReader =
    Future<ProcessVitalsReading?> Function({
      required bool cpu,
      required bool memory,
    });

/// Receives a finished vitals event.
typedef ProcessVitalsEmitter =
    void Function(String name, Map<String, String> attributes, DateTime time);

/// CPU utilization between two readings, in percent of the CPU time
/// available to the process.
///
/// `100 × Δ(user + system) ÷ (Δ elapsed × logical CPUs)`, using the CPU
/// count of the [end] reading. Returns `null` when either reading lacks CPU
/// data, or when the value is negative, not finite or above 100. Such values
/// are dropped, never clamped. 0 is a valid value.
@visibleForTesting
double? cpuUtilizationPercent(
  ProcessVitalsReading start,
  ProcessVitalsReading end,
) {
  final startCpu = start.cpuTimeSeconds;
  final endCpu = end.cpuTimeSeconds;
  final cpuCount = end.cpuCount;
  if (startCpu == null || endCpu == null || cpuCount == null) {
    return null;
  }
  final elapsedSeconds = (end.monotonicNanos - start.monotonicNanos) / 1e9;
  if (cpuCount <= 0 || elapsedSeconds <= 0) {
    return null;
  }
  final value = 100 * (endCpu - startCpu) / (elapsedSeconds * cpuCount);
  if (!value.isFinite || value < 0 || value > 100) {
    return null;
  }
  return value;
}

/// Converts [bytes] to MB, where 1 MB is 1,048,576 bytes.
@visibleForTesting
double bytesToMegabytes(int bytes) => bytes / bytesPerMegabyte;

/// Formats [value] with at most [maxDecimals] decimal places and no
/// trailing zeros, for example `12.5`, `7.81` or `0`.
@visibleForTesting
String formatDecimal(double value, int maxDecimals) {
  var text = value.toStringAsFixed(maxDecimals);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
  }
  return text == '-0' ? '0' : text;
}

/// Attributes of an `app.cpu_usage` event for the window from [start] to
/// [end], or `null` when the window yields no valid sample.
@visibleForTesting
Map<String, String>? cpuUsageAttributes(
  ProcessVitalsReading start,
  ProcessVitalsReading end,
) {
  final value = cpuUtilizationPercent(start, end);
  if (value == null) {
    return null;
  }
  final windowMs = ((end.monotonicNanos - start.monotonicNanos) / 1e6).round();
  return {
    'value': formatDecimal(value, 2),
    'unit': 'percent',
    'cpu.logical_count': '${end.cpuCount}',
    'window_ms': '$windowMs',
    'cpu.basis': 'process_utilization',
  };
}

/// Attributes of an `app.memory` event for [reading], or `null` when the
/// memory read failed or reported an unknown basis. A failed
/// read never becomes 0.
@visibleForTesting
Map<String, String>? memoryAttributes(ProcessVitalsReading reading) {
  final bytes = reading.memoryBytes;
  final basis = reading.memoryBasis;
  if (bytes == null || bytes <= 0 || !memoryBases.contains(basis)) {
    return null;
  }
  return {
    'value': formatDecimal(bytesToMegabytes(bytes), 1),
    'unit': 'MB',
    'memory.basis': basis!,
  };
}

/// Whether [state] counts as visible for vitals sampling.
///
/// A visible but unfocused app (`inactive`) is visible.
/// `null` means the engine has not reported a state yet; sampling waits for
/// the first reported state.
@visibleForTesting
bool isVisibleLifecycleState(AppLifecycleState? state) =>
    state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;

/// Samples app CPU and memory while the app is visible.
///
/// - A CPU window starts when the app becomes visible, and when sampling
///   starts in a visible app.
/// - Every [interval] the window ends with one `app.cpu_usage` for the window
///   and one `app.memory` read at that moment, then the next window starts
///   from the same reading.
/// - Hiding the app discards the current window.
/// - A window longer than twice [interval] (suspension or a stalled timer) is
///   discarded with its memory sample, and the next window starts right away
///   from that fresh reading.
/// - When the reading that started a window failed, the window sends
///   nothing: its length cannot be checked on the native monotonic clock. The
///   reading that ends it starts the next window.
/// - Events carry the native capture time of the reading they come from.
/// - A read that does not answer within [interval], at most 10 s, counts as
///   failed.
/// - One extra `app.memory` is read [memoryReadDelay] after the app becomes
///   visible, or after sampling starts in a visible app, unless the app is
///   hidden first.
class ProcessVitalsSampler {
  ProcessVitalsSampler({
    required ProcessVitalsReader reader,
    required ProcessVitalsEmitter emit,
    required this.interval,
    required this.cpuEnabled,
    required this.memoryEnabled,
    this.memoryReadDelay = defaultMemoryReadDelay,
  }) : _reader = reader,
       _emit = emit;

  /// Delay of the memory read after becoming visible.
  static const defaultMemoryReadDelay = Duration(seconds: 2);

  static const _maxReadTimeout = Duration(seconds: 10);

  final ProcessVitalsReader _reader;
  final ProcessVitalsEmitter _emit;

  /// Configured window length.
  final Duration interval;

  /// Whether `app.cpu_usage` events are emitted.
  final bool cpuEnabled;

  /// Whether `app.memory` events are emitted.
  final bool memoryEnabled;

  /// Delay of the memory read after becoming visible.
  final Duration memoryReadDelay;

  bool _visible = false;
  bool _disposed = false;

  /// Incremented on every visibility change and on dispose, so reads that
  /// were in flight across a change are ignored.
  int _generation = 0;
  ProcessVitalsReading? _windowStart;
  Timer? _windowTimer;
  Timer? _memoryTimer;

  bool get _enabled => cpuEnabled || memoryEnabled;

  Duration get _readTimeout =>
      interval < _maxReadTimeout ? interval : _maxReadTimeout;

  /// Whether the sampler currently treats the app as visible.
  @visibleForTesting
  bool get isVisible => _visible;

  /// Starts sampling given the current lifecycle [state].
  void start(AppLifecycleState? state) {
    if (isVisibleLifecycleState(state)) {
      _becameVisible();
    }
  }

  /// Applies a lifecycle change.
  void onLifecycleStateChanged(AppLifecycleState state) {
    final visible = isVisibleLifecycleState(state);
    if (visible && !_visible) {
      _becameVisible();
    } else if (!visible && _visible) {
      _becameHidden();
    }
  }

  /// Stops all timers and ignores reads still in flight.
  void dispose() {
    _disposed = true;
    _becameHidden();
  }

  void _becameVisible() {
    if (_disposed || !_enabled) {
      return;
    }
    _visible = true;
    final generation = ++_generation;
    if (memoryEnabled) {
      _memoryTimer = Timer(
        memoryReadDelay,
        () => _readVisibleMemory(generation),
      );
    }
    unawaited(_startWindow(generation));
  }

  void _becameHidden() {
    _visible = false;
    _generation++;
    _windowTimer?.cancel();
    _windowTimer = null;
    _memoryTimer?.cancel();
    _memoryTimer = null;
    _windowStart = null;
  }

  bool _isCurrent(int generation) =>
      !_disposed && _visible && generation == _generation;

  Future<void> _startWindow(int generation) async {
    final reading = await _read(cpu: cpuEnabled, memory: false);
    if (!_isCurrent(generation)) {
      return;
    }
    _windowStart = reading;
    _armWindowTimer(generation);
  }

  void _armWindowTimer(int generation) {
    _windowTimer?.cancel();
    _windowTimer = Timer(interval, () => _endWindow(generation));
  }

  Future<void> _endWindow(int generation) async {
    final reading = await _read(cpu: cpuEnabled, memory: memoryEnabled);
    if (!_isCurrent(generation)) {
      return;
    }
    final start = _windowStart;
    _windowStart = reading;
    _armWindowTimer(generation);
    if (start == null || reading == null) {
      return;
    }
    final windowNanos = reading.monotonicNanos - start.monotonicNanos;
    if (windowNanos > 2 * interval.inMicroseconds * 1000) {
      log(
        'Faro: discarding a ${windowNanos ~/ 1000000} ms vitals window, '
        'longer than twice the interval',
      );
      return;
    }
    if (cpuEnabled) {
      final cpu = cpuUsageAttributes(start, reading);
      if (cpu != null) {
        _emit(appCpuUsageEventName, cpu, reading.timestamp);
      }
    }
    if (memoryEnabled) {
      final memory = memoryAttributes(reading);
      if (memory != null) {
        _emit(appMemoryEventName, memory, reading.timestamp);
      }
    }
  }

  Future<void> _readVisibleMemory(int generation) async {
    _memoryTimer = null;
    if (!_isCurrent(generation)) {
      return;
    }
    final reading = await _read(cpu: false, memory: true);
    if (!_isCurrent(generation) || reading == null) {
      return;
    }
    final memory = memoryAttributes(reading);
    if (memory != null) {
      _emit(appMemoryEventName, memory, reading.timestamp);
    }
  }

  Future<ProcessVitalsReading?> _read({
    required bool cpu,
    required bool memory,
  }) async {
    try {
      // A reply that never comes must not stall sampling for good.
      return await _reader(cpu: cpu, memory: memory).timeout(_readTimeout);
    } catch (error) {
      log('Faro: could not read process vitals: $error');
      return null;
    }
  }
}
