import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:faro/src/integrations/process_vitals.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

ProcessVitalsReading _reading({
  required int monotonicNanos,
  double? cpuTimeSeconds,
  int? cpuCount = 4,
  int? memoryBytes,
  String? memoryBasis = 'rss',
}) {
  return ProcessVitalsReading(
    monotonicNanos: monotonicNanos,
    timestamp: _epoch,
    cpuTimeSeconds: cpuTimeSeconds,
    cpuCount: cpuCount,
    memoryBytes: memoryBytes,
    memoryBasis: memoryBasis,
  );
}

const _thirtySecondsNanos = 30 * 1000 * 1000 * 1000;

final _epoch = DateTime.utc(2026, 11, 17, 12);

class _Emitted {
  _Emitted(this.name, this.attributes, this.time);
  final String name;
  final Map<String, String> attributes;
  final DateTime time;
}

/// A fake process whose clock follows fake time and whose counters the test
/// moves by hand.
class _FakeProcess {
  _FakeProcess(this.async);

  final FakeAsync async;

  /// Added to the fake clock, to simulate time the timer did not see.
  Duration clockOffset = Duration.zero;

  /// The native monotonic clock, including time the timer did not see.
  Duration elapsed() => async.elapsed + clockOffset;

  double cpuTimeSeconds = 0;
  int cpuCount = 4;
  int? memoryBytes = 100 * bytesPerMegabyte;
  Duration readLatency = Duration.zero;

  /// How many of the next reads fail.
  int failNextReads = 0;
  final List<({bool cpu, bool memory})> reads = [];

  Future<ProcessVitalsReading?> read({
    required bool cpu,
    required bool memory,
  }) async {
    reads.add((cpu: cpu, memory: memory));
    // Captured when the read starts, like the native side does before it
    // replies.
    final captured = elapsed();
    final readFails = failNextReads > 0;
    if (readFails) {
      failNextReads--;
    }
    if (readLatency > Duration.zero) {
      await Future<void>.delayed(readLatency);
    }
    if (readFails) {
      return null;
    }
    return ProcessVitalsReading(
      monotonicNanos: captured.inMicroseconds * 1000,
      timestamp: _epoch.add(captured),
      cpuTimeSeconds: cpu ? cpuTimeSeconds : null,
      cpuCount: cpu ? cpuCount : null,
      memoryBytes: memory ? memoryBytes : null,
      memoryBasis: memory ? 'rss' : null,
    );
  }
}

void main() {
  group('cpuUtilizationPercent', () {
    test('uses the CPU time spent in this window only', () {
      // 3 CPU seconds over 30 s on 4 CPUs. An average since process start
      // (cpu time 13 s) would give a different figure.
      final value = cpuUtilizationPercent(
        _reading(monotonicNanos: 0, cpuTimeSeconds: 10),
        _reading(monotonicNanos: _thirtySecondsNanos, cpuTimeSeconds: 13),
      );
      expect(value, closeTo(2.5, 1e-9));
    });

    test('divides by the CPU count read at the end of the window', () {
      final value = cpuUtilizationPercent(
        _reading(monotonicNanos: 0, cpuTimeSeconds: 0, cpuCount: 2),
        _reading(
          monotonicNanos: _thirtySecondsNanos,
          cpuTimeSeconds: 30,
          cpuCount: 8,
        ),
      );
      expect(value, closeTo(12.5, 1e-9));
    });

    test('returns 0 for an idle window', () {
      final value = cpuUtilizationPercent(
        _reading(monotonicNanos: 0, cpuTimeSeconds: 5),
        _reading(monotonicNanos: _thirtySecondsNanos, cpuTimeSeconds: 5),
      );
      expect(value, 0);
    });

    test('keeps exactly 100', () {
      final value = cpuUtilizationPercent(
        _reading(monotonicNanos: 0, cpuTimeSeconds: 0),
        _reading(monotonicNanos: _thirtySecondsNanos, cpuTimeSeconds: 120),
      );
      expect(value, 100);
    });

    test('drops values above 100 instead of clamping', () {
      final value = cpuUtilizationPercent(
        _reading(monotonicNanos: 0, cpuTimeSeconds: 0),
        _reading(monotonicNanos: _thirtySecondsNanos, cpuTimeSeconds: 121),
      );
      expect(value, isNull);
    });

    test('drops negative and non-finite values', () {
      expect(
        cpuUtilizationPercent(
          _reading(monotonicNanos: 0, cpuTimeSeconds: 10),
          _reading(monotonicNanos: _thirtySecondsNanos, cpuTimeSeconds: 9),
        ),
        isNull,
      );
      expect(
        cpuUtilizationPercent(
          _reading(monotonicNanos: 0, cpuTimeSeconds: 0),
          _reading(
            monotonicNanos: _thirtySecondsNanos,
            cpuTimeSeconds: double.nan,
          ),
        ),
        isNull,
      );
      expect(
        cpuUtilizationPercent(
          _reading(monotonicNanos: 0, cpuTimeSeconds: 0),
          _reading(
            monotonicNanos: _thirtySecondsNanos,
            cpuTimeSeconds: double.infinity,
          ),
        ),
        isNull,
      );
    });

    test('drops windows without elapsed time, CPU count or CPU time', () {
      expect(
        cpuUtilizationPercent(
          _reading(monotonicNanos: 5, cpuTimeSeconds: 0),
          _reading(monotonicNanos: 5, cpuTimeSeconds: 0),
        ),
        isNull,
      );
      expect(
        cpuUtilizationPercent(
          _reading(monotonicNanos: 0, cpuTimeSeconds: 0),
          _reading(
            monotonicNanos: _thirtySecondsNanos,
            cpuTimeSeconds: 1,
            cpuCount: 0,
          ),
        ),
        isNull,
      );
      expect(
        cpuUtilizationPercent(
          _reading(monotonicNanos: 0),
          _reading(monotonicNanos: _thirtySecondsNanos, cpuTimeSeconds: 1),
        ),
        isNull,
      );
    });
  });

  group('formatting', () {
    test('formatDecimal keeps at most the given decimals', () {
      expect(formatDecimal(7.8149, 2), '7.81');
      expect(formatDecimal(7.8151, 2), '7.82');
      expect(formatDecimal(12.5, 2), '12.5');
      expect(formatDecimal(0, 2), '0');
      expect(formatDecimal(100, 2), '100');
      expect(formatDecimal(0.004, 2), '0');
      expect(formatDecimal(212.44, 1), '212.4');
      expect(formatDecimal(212.46, 1), '212.5');
    });

    test('formatDecimal rounds up into the next whole number', () {
      expect(formatDecimal(99.999, 2), '100');
      expect(formatDecimal(1.96, 1), '2');
    });

    test('formatDecimal rounds an exact half away from zero', () {
      // 0.125 and 0.25 are exact in binary, so this is the real tie rule.
      expect(formatDecimal(0.125, 2), '0.13');
      expect(formatDecimal(0.25, 1), '0.3');
    });

    test('formatDecimal never returns negative zero', () {
      expect(formatDecimal(-0.0001, 2), '0');
      // An int literal would be positive zero, which is not the case here.
      // ignore: prefer_int_literals
      expect(formatDecimal(-0.0, 1), '0');
    });

    test('formatDecimal keeps whole numbers without a decimal point', () {
      expect(formatDecimal(10, 2), '10');
      expect(formatDecimal(1048576, 1), '1048576');
      // Without decimals there is no point, so trailing zeros are digits.
      expect(formatDecimal(10, 0), '10');
      expect(formatDecimal(1000, 0), '1000');
    });

    test('bytesToMegabytes uses 1 MB = 1,048,576 bytes', () {
      expect(bytesToMegabytes(1048576), 1);
      expect(bytesToMegabytes(1000000), closeTo(0.9537, 1e-4));
    });
  });

  group('payload', () {
    test('app.cpu_usage carries exactly the expected attributes', () {
      final attributes = cpuUsageAttributes(
        _reading(monotonicNanos: 1000000000, cpuTimeSeconds: 1),
        _reading(
          monotonicNanos: 1000000000 + 30004 * 1000000,
          cpuTimeSeconds: 1 + 0.0781 * 30.004 * 8,
          cpuCount: 8,
        ),
      );
      expect(attributes, {
        'value': '7.81',
        'unit': 'percent',
        'cpu.logical_count': '8',
        'window_ms': '30004',
        'cpu.basis': 'process_utilization',
      });
    });

    test('app.cpu_usage rounds window_ms to the nearest millisecond', () {
      Map<String, String>? windowOf(int nanos) => cpuUsageAttributes(
        _reading(monotonicNanos: 0, cpuTimeSeconds: 0),
        _reading(monotonicNanos: nanos, cpuTimeSeconds: 0),
      );
      expect(windowOf(30000499999)?['window_ms'], '30000');
      expect(windowOf(30000500000)?['window_ms'], '30001');
      expect(windowOf(30000999999)?['window_ms'], '30001');
    });

    test('app.cpu_usage sends an idle window as 0', () {
      final attributes = cpuUsageAttributes(
        _reading(monotonicNanos: 0, cpuTimeSeconds: 2),
        _reading(monotonicNanos: _thirtySecondsNanos, cpuTimeSeconds: 2),
      );
      expect(attributes?['value'], '0');
    });

    test('app.memory sends MB with one decimal and the basis', () {
      final attributes = memoryAttributes(
        _reading(
          monotonicNanos: 0,
          memoryBytes: 222715904,
          memoryBasis: 'phys_footprint',
        ),
      );
      expect(attributes, {
        'value': '212.4',
        'unit': 'MB',
        'memory.basis': 'phys_footprint',
      });
    });

    test('app.memory is omitted when the read failed, never sent as 0', () {
      expect(memoryAttributes(_reading(monotonicNanos: 0)), isNull);
      expect(
        memoryAttributes(_reading(monotonicNanos: 0, memoryBytes: 0)),
        isNull,
      );
      expect(
        memoryAttributes(
          _reading(monotonicNanos: 0, memoryBytes: 10, memoryBasis: null),
        ),
        isNull,
      );
    });

    test('app.memory only accepts the rss and phys_footprint bases', () {
      for (final basis in ['rss', 'phys_footprint']) {
        expect(
          memoryAttributes(
            _reading(monotonicNanos: 0, memoryBytes: 10, memoryBasis: basis),
          )?['memory.basis'],
          basis,
        );
      }
      for (final basis in ['resident_size', 'pss', 'RSS', '']) {
        expect(
          memoryAttributes(
            _reading(monotonicNanos: 0, memoryBytes: 10, memoryBasis: basis),
          ),
          isNull,
          reason: basis,
        );
      }
    });
  });

  group('ProcessVitalsReading.fromMap', () {
    Map<String, dynamic> nativeMap() => {
      'monotonicNanos': 42,
      'timestampMillis': 1795435200123,
      'cpuTimeSeconds': 3.25,
      'cpuCount': 6,
      'memoryBytes': 1024,
      'memoryBasis': 'rss',
    };

    test('parses every field of a full native map', () {
      final reading = ProcessVitalsReading.fromMap(nativeMap());
      expect(reading?.monotonicNanos, 42);
      expect(
        reading?.timestamp,
        DateTime.fromMillisecondsSinceEpoch(1795435200123, isUtc: true),
      );
      expect(reading?.timestamp.isUtc, isTrue);
      expect(reading?.cpuTimeSeconds, 3.25);
      expect(reading?.cpuCount, 6);
      expect(reading?.memoryBytes, 1024);
      expect(reading?.memoryBasis, 'rss');
    });

    test('returns null for a null map', () {
      expect(ProcessVitalsReading.fromMap(null), isNull);
    });

    test('returns null without a monotonic clock value', () {
      expect(
        ProcessVitalsReading.fromMap(nativeMap()..remove('monotonicNanos')),
        isNull,
      );
    });

    test('returns null without a capture time', () {
      // No fallback to the Dart clock: a reading without its capture time
      // is a failed read.
      expect(
        ProcessVitalsReading.fromMap(nativeMap()..remove('timestampMillis')),
        isNull,
      );
    });

    test('returns null when the clock or capture time is not an int', () {
      expect(
        ProcessVitalsReading.fromMap(nativeMap()..['monotonicNanos'] = 42.0),
        isNull,
      );
      expect(
        ProcessVitalsReading.fromMap(nativeMap()..['timestampMillis'] = 1.5),
        isNull,
      );
    });

    test('accepts CPU time that arrives as an int', () {
      // Both platforms send a double today. A whole number that arrives as
      // an int is still CPU time.
      final reading = ProcessVitalsReading.fromMap(
        nativeMap()..['cpuTimeSeconds'] = 3,
      );
      expect(reading?.cpuTimeSeconds, 3.0);
    });

    test('keeps the reading but drops counters of the wrong type', () {
      final reading = ProcessVitalsReading.fromMap(
        nativeMap()
          ..['cpuTimeSeconds'] = '3'
          ..['cpuCount'] = 6.0
          ..['memoryBytes'] = 1024.0
          ..['memoryBasis'] = 1,
      );
      expect(reading, isNotNull);
      expect(reading?.cpuTimeSeconds, isNull);
      expect(reading?.cpuCount, isNull);
      expect(reading?.memoryBytes, isNull);
      expect(reading?.memoryBasis, isNull);
    });

    test('keeps the reading when counters were not requested', () {
      final reading = ProcessVitalsReading.fromMap({
        'monotonicNanos': 42,
        'timestampMillis': 1795435200123,
      });
      expect(reading, isNotNull);
      expect(reading?.cpuTimeSeconds, isNull);
      expect(reading?.memoryBytes, isNull);
    });
  });

  group('isVisibleLifecycleState', () {
    test('counts resumed and inactive as visible', () {
      expect(isVisibleLifecycleState(AppLifecycleState.resumed), isTrue);
      expect(isVisibleLifecycleState(AppLifecycleState.inactive), isTrue);
      expect(isVisibleLifecycleState(AppLifecycleState.hidden), isFalse);
      expect(isVisibleLifecycleState(AppLifecycleState.paused), isFalse);
      expect(isVisibleLifecycleState(AppLifecycleState.detached), isFalse);
      expect(isVisibleLifecycleState(null), isFalse);
    });
  });

  group('ProcessVitalsSampler', () {
    late List<_Emitted> emitted;
    final epoch = _epoch;

    setUp(() {
      emitted = [];
    });

    ProcessVitalsSampler createSampler(
      FakeAsync async,
      _FakeProcess process, {
      bool cpu = true,
      bool memory = true,
      Duration interval = const Duration(seconds: 30),
    }) {
      return ProcessVitalsSampler(
        reader: process.read,
        emit: (name, attributes, time) =>
            emitted.add(_Emitted(name, attributes, time)),
        interval: interval,
        cpuEnabled: cpu,
        memoryEnabled: memory,
      );
    }

    List<String> names() => emitted.map((event) => event.name).toList();

    test('emits CPU and memory at the end of each visible window', () {
      fakeAsync((async) {
        final process = _FakeProcess(async);
        createSampler(async, process).start(AppLifecycleState.resumed);
        async.flushMicrotasks();

        process.cpuTimeSeconds = 12; // 12 s over 30 s on 4 CPUs = 10 %.
        async.elapse(const Duration(seconds: 30));

        final cpu = emitted.where((e) => e.name == appCpuUsageEventName);
        expect(cpu, hasLength(1));
        expect(cpu.single.attributes['value'], '10');
        expect(cpu.single.attributes['window_ms'], '30000');
        expect(cpu.single.time, epoch.add(const Duration(seconds: 30)));

        final memory = emitted.where((e) => e.name == appMemoryEventName);
        expect(memory.map((e) => e.time), [
          epoch.add(const Duration(seconds: 2)),
          epoch.add(const Duration(seconds: 30)),
        ]);
        expect(memory.last.attributes['value'], '100');

        // The next window starts where the last one ended.
        process.cpuTimeSeconds = 12; // Idle window.
        async.elapse(const Duration(seconds: 30));
        expect(emitted.last.name, appMemoryEventName);
        expect(
          emitted
              .where((e) => e.name == appCpuUsageEventName)
              .last
              .attributes['value'],
          '0',
        );
      });
    });

    test('reads memory 2 s after starting in a visible app', () {
      fakeAsync((async) {
        final process = _FakeProcess(async);
        createSampler(async, process).start(AppLifecycleState.resumed);

        async.elapse(const Duration(milliseconds: 1999));
        expect(emitted, isEmpty);

        async.elapse(const Duration(milliseconds: 1));
        expect(names(), [appMemoryEventName]);
        expect(emitted.single.time, epoch.add(const Duration(seconds: 2)));
      });
    });

    test('does nothing while hidden or before the first lifecycle state', () {
      fakeAsync((async) {
        final process = _FakeProcess(async);
        createSampler(async, process).start(null);
        async.elapse(const Duration(minutes: 5));

        final hidden = createSampler(async, process)
          ..start(AppLifecycleState.paused);
        async.elapse(const Duration(minutes: 5));
        hidden.onLifecycleStateChanged(AppLifecycleState.hidden);
        async.elapse(const Duration(minutes: 5));

        expect(emitted, isEmpty);
        expect(process.reads, isEmpty);
      });
    });

    test('starts a window and a memory read on becoming visible', () {
      fakeAsync((async) {
        final process = _FakeProcess(async);
        final sampler = createSampler(async, process)..start(null);
        async.elapse(const Duration(seconds: 10));

        sampler.onLifecycleStateChanged(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 2));
        expect(names(), [appMemoryEventName]);
        expect(emitted.single.time, epoch.add(const Duration(seconds: 12)));

        async.elapse(const Duration(seconds: 28));
        expect(names(), [
          appMemoryEventName,
          appCpuUsageEventName,
          appMemoryEventName,
        ]);
      });
    });

    test('discards the current window when the app is hidden', () {
      fakeAsync((async) {
        final process = _FakeProcess(async);
        final sampler = createSampler(async, process)
          ..start(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 20));
        expect(names(), [appMemoryEventName]);

        sampler.onLifecycleStateChanged(AppLifecycleState.paused);
        async.elapse(const Duration(minutes: 5));
        expect(names(), [appMemoryEventName]);

        process.cpuTimeSeconds = 6;
        sampler.onLifecycleStateChanged(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 29));
        // Only the visible memory read; the partial window left no CPU.
        expect(names(), [appMemoryEventName, appMemoryEventName]);

        process.cpuTimeSeconds = 18; // 12 s over the new 30 s window.
        async.elapse(const Duration(seconds: 1));
        final cpu = emitted.singleWhere((e) => e.name == appCpuUsageEventName);
        expect(cpu.attributes['value'], '10');
        expect(cpu.attributes['window_ms'], '30000');
      });
    });

    test('keeps sampling while the app is inactive but visible', () {
      fakeAsync((async) {
        final process = _FakeProcess(async);
        final sampler = createSampler(async, process)
          ..start(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 10));
        sampler.onLifecycleStateChanged(AppLifecycleState.inactive);
        async.elapse(const Duration(seconds: 10));
        sampler.onLifecycleStateChanged(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 10));

        expect(
          emitted.where((e) => e.name == appCpuUsageEventName),
          hasLength(1),
        );
        // No extra memory read for an inactive → resumed change.
        expect(
          emitted.where((e) => e.name == appMemoryEventName),
          hasLength(2),
        );
      });
    });

    test('skips the visible memory read when hidden before it fires', () {
      fakeAsync((async) {
        final process = _FakeProcess(async);
        final sampler = createSampler(async, process)
          ..start(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 1));
        sampler.onLifecycleStateChanged(AppLifecycleState.hidden);
        async.elapse(const Duration(minutes: 1));

        expect(emitted, isEmpty);
        expect(process.reads.where((read) => read.memory), isEmpty);
      });
    });

    test('ignores a read that returns after the app was hidden', () {
      fakeAsync((async) {
        final process = _FakeProcess(async)
          ..readLatency = const Duration(milliseconds: 500);
        final sampler = createSampler(async, process)
          ..start(AppLifecycleState.resumed);
        async.elapse(const Duration(milliseconds: 2200));
        sampler.onLifecycleStateChanged(AppLifecycleState.paused);
        async.elapse(const Duration(minutes: 1));

        expect(emitted, isEmpty);
      });
    });

    test('discards a window longer than twice the interval', () {
      fakeAsync((async) {
        final process = _FakeProcess(async);
        createSampler(async, process).start(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 10));
        final beforeStall = emitted.length;

        // The device was suspended for 45 s while the timer was not running.
        process.clockOffset = const Duration(seconds: 45);
        process.cpuTimeSeconds = 3;
        async.elapse(const Duration(seconds: 20));
        expect(
          emitted.length,
          beforeStall,
          reason: 'neither CPU nor memory from a 75 s window',
        );

        // The next window starts from that fresh reading.
        process.cpuTimeSeconds = 15;
        async.elapse(const Duration(seconds: 30));
        final cpu = emitted.singleWhere((e) => e.name == appCpuUsageEventName);
        expect(cpu.attributes['window_ms'], '30000');
        expect(cpu.attributes['value'], '10');
      });
    });

    test('keeps a window of exactly twice the interval', () {
      fakeAsync((async) {
        final process = _FakeProcess(async);
        createSampler(async, process).start(AppLifecycleState.resumed);
        async.flushMicrotasks();
        process.clockOffset = const Duration(seconds: 30);
        async.elapse(const Duration(seconds: 30));

        final cpu = emitted.singleWhere((e) => e.name == appCpuUsageEventName);
        expect(cpu.attributes['window_ms'], '60000');
      });
    });

    test('drops an out-of-range CPU sample but keeps its memory', () {
      fakeAsync((async) {
        final process = _FakeProcess(async);
        createSampler(async, process).start(AppLifecycleState.resumed);
        async.flushMicrotasks();
        process.cpuTimeSeconds = 200; // 166 % of 4 CPUs over 30 s.
        async.elapse(const Duration(seconds: 30));

        expect(names(), [appMemoryEventName, appMemoryEventName]);
      });
    });

    test('omits memory when the read fails', () {
      fakeAsync((async) {
        final process = _FakeProcess(async)..memoryBytes = null;
        createSampler(async, process).start(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 30));

        expect(names(), [appCpuUsageEventName]);
      });
    });

    test('keeps going after a failed read', () {
      fakeAsync((async) {
        final process = _FakeProcess(async);
        var fail = true;
        final sampler = ProcessVitalsSampler(
          reader: ({required cpu, required memory}) {
            if (fail) {
              return Future.error(StateError('channel gone'));
            }
            return process.read(cpu: cpu, memory: memory);
          },
          emit: (name, attributes, time) =>
              emitted.add(_Emitted(name, attributes, time)),
          interval: const Duration(seconds: 30),
          cpuEnabled: true,
          memoryEnabled: false,
        )..start(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 1));
        fail = false;
        async.elapse(const Duration(seconds: 29));
        expect(emitted, isEmpty);
        async.elapse(const Duration(seconds: 30));
        expect(names(), [appCpuUsageEventName]);
        sampler.dispose();
      });
    });

    test('recovers from a read that never returns', () {
      fakeAsync((async) {
        final process = _FakeProcess(async);
        var hang = true;
        ProcessVitalsSampler(
          reader: ({required cpu, required memory}) {
            if (hang) {
              return Completer<ProcessVitalsReading?>().future;
            }
            return process.read(cpu: cpu, memory: memory);
          },
          emit: (name, attributes, time) =>
              emitted.add(_Emitted(name, attributes, time)),
          interval: const Duration(seconds: 30),
          cpuEnabled: true,
          memoryEnabled: false,
        ).start(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 10));
        hang = false;
        async.elapse(const Duration(seconds: 70));
        expect(names(), [appCpuUsageEventName]);
      });
    });

    test('times out a hung read after one interval when it is short', () {
      fakeAsync((async) {
        final process = _FakeProcess(async);
        var hang = true;
        ProcessVitalsSampler(
          reader: ({required cpu, required memory}) {
            if (hang) {
              return Completer<ProcessVitalsReading?>().future;
            }
            return process.read(cpu: cpu, memory: memory);
          },
          emit: (name, attributes, time) =>
              emitted.add(_Emitted(name, attributes, time)),
          interval: const Duration(seconds: 2),
          cpuEnabled: true,
          memoryEnabled: false,
        ).start(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 1));
        hang = false;
        // Timeout at 2 s, then a window without a start reading ending at
        // 4 s, then the first full window ending at 6 s. A fixed
        // 10 s timeout would delay the first sample to 14 s.
        async.elapse(const Duration(milliseconds: 4999));
        expect(emitted, isEmpty);
        async.elapse(const Duration(milliseconds: 1));
        expect(names(), [appCpuUsageEventName]);
        expect(emitted.single.attributes['window_ms'], '2000');
      });
    });

    test('ignores a reply that arrives after its read timed out', () {
      fakeAsync((async) {
        final process = _FakeProcess(async);
        final late = Completer<ProcessVitalsReading?>();
        var first = true;
        ProcessVitalsSampler(
          reader: ({required cpu, required memory}) {
            if (first) {
              first = false;
              return late.future;
            }
            return process.read(cpu: cpu, memory: memory);
          },
          emit: (name, attributes, time) =>
              emitted.add(_Emitted(name, attributes, time)),
          interval: const Duration(seconds: 2),
          cpuEnabled: true,
          memoryEnabled: false,
        ).start(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 3));
        // A stale baseline with huge CPU time would yield an invalid window
        // if it were used.
        late.complete(
          ProcessVitalsReading(
            monotonicNanos: 0,
            timestamp: epoch,
            cpuTimeSeconds: -1000,
            cpuCount: 4,
          ),
        );
        async.elapse(const Duration(seconds: 3));
        expect(names(), [appCpuUsageEventName]);
        expect(emitted.single.attributes['value'], '0');
      });
    });

    test('stamps events with the native capture time, not delivery time', () {
      fakeAsync((async) {
        final process = _FakeProcess(async)
          ..readLatency = const Duration(milliseconds: 700);
        createSampler(async, process).start(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 32));

        // The visible read starts at 2 s, the window-end read at 30.7 s
        // (start read reply at 0.7 s + 30 s timer). Replies land 0.7 s later.
        expect(names(), [
          appMemoryEventName,
          appCpuUsageEventName,
          appMemoryEventName,
        ]);
        expect(emitted[0].time, epoch.add(const Duration(seconds: 2)));
        expect(emitted[1].time, epoch.add(const Duration(milliseconds: 30700)));
        expect(emitted[2].time, emitted[1].time);
      });
    });

    test('sends nothing for a window whose start read failed', () {
      fakeAsync((async) {
        final process = _FakeProcess(async)..failNextReads = 1;
        createSampler(async, process).start(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 30));

        // Only the visible read at 2 s. The window ending at 30 s has no
        // start reading, so its length cannot be checked and it is dropped,
        // memory included.
        expect(names(), [appMemoryEventName]);
      });
    });

    test('starts the next window from the reading after a failed start', () {
      fakeAsync((async) {
        final process = _FakeProcess(async)..failNextReads = 1;
        createSampler(async, process).start(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 30));
        emitted.clear();

        process.cpuTimeSeconds = 12;
        async.elapse(const Duration(seconds: 30));

        // 12 CPU seconds over a 30 s window on 4 CPUs.
        expect(names(), [appCpuUsageEventName, appMemoryEventName]);
        expect(emitted.first.attributes['value'], '10');
        expect(emitted.first.attributes['window_ms'], '30000');
        expect(emitted.last.time, epoch.add(const Duration(seconds: 60)));
      });
    });

    test('sends no memory for a failed start window when CPU is off', () {
      fakeAsync((async) {
        final process = _FakeProcess(async)..failNextReads = 1;
        createSampler(
          async,
          process,
          cpu: false,
        ).start(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 30));
        expect(names(), [appMemoryEventName]);

        async.elapse(const Duration(seconds: 30));
        expect(names(), [appMemoryEventName, appMemoryEventName]);
      });
    });

    test('only reads and emits what is enabled', () {
      fakeAsync((async) {
        final process = _FakeProcess(async);
        final cpuOnly = createSampler(async, process, memory: false)
          ..start(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 60));
        expect(names(), [appCpuUsageEventName, appCpuUsageEventName]);
        expect(process.reads.where((read) => read.memory), isEmpty);
        cpuOnly.dispose();

        emitted.clear();
        process.reads.clear();
        createSampler(
          async,
          process,
          cpu: false,
        ).start(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 30));
        expect(names(), [appMemoryEventName, appMemoryEventName]);
        expect(process.reads.where((read) => read.cpu), isEmpty);
      });
    });

    test('dispose stops sampling', () {
      fakeAsync((async) {
        final process = _FakeProcess(async);
        createSampler(async, process)
          ..start(AppLifecycleState.resumed)
          ..dispose();
        async.elapse(const Duration(minutes: 5));
        expect(emitted, isEmpty);
      });
    });
  });
}
