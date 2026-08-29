import 'package:flutter_test/flutter_test.dart';

import '../../tool/poc/reference_kit/grafana_reference_kit.dart';

void main() {
  group('GrafanaReferenceKit', () {
    test('keeps the native SDK available for advanced configuration', () {
      final sdk = _FakeTelemetrySdk();
      final kit = GrafanaReferenceKit<_FakeTelemetrySdk>(
        sdk: sdk,
        plugins: const [],
      );

      expect(identical(kit.sdk, sdk), isTrue);
      expect(kit.sdk.nativeOperation(), 'native result');
    });

    test('starts plugins in registration order only once', () async {
      final calls = <String>[];
      final kit = GrafanaReferenceKit<_FakeTelemetrySdk>(
        sdk: _FakeTelemetrySdk(),
        plugins: [
          _RecordingPlugin('one', calls),
          _RecordingPlugin('two', calls),
        ],
      );

      await kit.start();
      await kit.start();

      expect(calls, ['start one', 'start two']);
    });

    test('stops installed plugins in reverse order only once', () async {
      final calls = <String>[];
      final kit = GrafanaReferenceKit<_FakeTelemetrySdk>(
        sdk: _FakeTelemetrySdk(),
        plugins: [
          _RecordingPlugin('one', calls),
          _RecordingPlugin('two', calls),
        ],
      );

      await kit.start();
      await kit.stop();
      await kit.stop();

      expect(calls, ['start one', 'start two', 'stop two', 'stop one']);
    });

    test('rolls back installed plugins when startup fails', () async {
      final calls = <String>[];
      final kit = GrafanaReferenceKit<_FakeTelemetrySdk>(
        sdk: _FakeTelemetrySdk(),
        plugins: [
          _RecordingPlugin('one', calls),
          _RecordingPlugin('two', calls, failOnStart: true),
          _RecordingPlugin('three', calls),
        ],
      );

      await expectLater(kit.start(), throwsStateError);

      expect(calls, ['start one', 'start two', 'stop two', 'stop one']);
      expect(kit.isRunning, isFalse);
    });

    test('attempts all cleanup when one plugin fails to stop', () async {
      final calls = <String>[];
      final kit = GrafanaReferenceKit<_FakeTelemetrySdk>(
        sdk: _FakeTelemetrySdk(),
        plugins: [
          _RecordingPlugin('one', calls),
          _RecordingPlugin('two', calls, failOnStop: true),
          _RecordingPlugin('three', calls),
        ],
      );
      await kit.start();

      await expectLater(kit.stop(), throwsStateError);

      expect(calls, [
        'start one',
        'start two',
        'start three',
        'stop three',
        'stop two',
        'stop one',
      ]);
      expect(kit.isRunning, isFalse);
    });
  });
}

final class _FakeTelemetrySdk {
  String nativeOperation() => 'native result';
}

final class _RecordingPlugin
    implements GrafanaReferenceKitPlugin<_FakeTelemetrySdk> {
  _RecordingPlugin(
    this.name,
    this.calls, {
    this.failOnStart = false,
    this.failOnStop = false,
  });

  final String name;
  final List<String> calls;
  final bool failOnStart;
  final bool failOnStop;

  @override
  Future<void> start(_FakeTelemetrySdk sdk) async {
    calls.add('start $name');
    if (failOnStart) {
      throw StateError('start $name failed');
    }
  }

  @override
  Future<void> stop(_FakeTelemetrySdk sdk) async {
    calls.add('stop $name');
    if (failOnStop) {
      throw StateError('stop $name failed');
    }
  }
}
