import 'dart:async';

import 'package:faro/src/configurations/batch_config.dart';
import 'package:faro/src/configurations/faro_config.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:faro/src/user_actions/user_action_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockBaseTransport extends Mock implements BaseTransport {}

class _RebuildController {
  VoidCallback? _triggerRebuild;

  void triggerRebuild() {
    _triggerRebuild?.call();
  }
}

class _RebuildHarness extends StatefulWidget {
  const _RebuildHarness({
    required this.controller,
    this.enableContinuousAnimation = false,
  });

  final _RebuildController controller;
  final bool enableContinuousAnimation;

  @override
  State<_RebuildHarness> createState() => _RebuildHarnessState();
}

class _RebuildHarnessState extends State<_RebuildHarness> {
  Timer? _animationTimer;
  int _buildTick = 0;

  @override
  void initState() {
    super.initState();
    widget.controller._triggerRebuild = () {
      if (!mounted) {
        return;
      }
      setState(() {
        _buildTick += 1;
      });
    };

    if (widget.enableContinuousAnimation) {
      _animationTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _buildTick += 1;
        });
      });
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text('ticks=$_buildTick');
  }
}

void main() {
  late _MockBaseTransport mockTransport;
  late Faro faro;

  Future<void> initializeFaro() async {
    await faro.init(
      optionsConfiguration: FaroConfig(
        collectorUrl: 'https://example.com',
        appName: 'test-app',
        appEnv: 'test',
        apiKey: 'test-key',
        batchConfig: BatchConfig(enabled: false),
      ),
    );
    clearInteractions(mockTransport);
  }

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Faro.resetForTesting();
    BatchTransportFactory().reset();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PackageInfo.setMockInitialValues(
      appName: 'test-app',
      packageName: 'com.example.test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: 'test',
    );

    mockTransport = _MockBaseTransport();
    when(() => mockTransport.send(any())).thenAnswer((_) async {});

    faro = Faro();
    faro.transports = <BaseTransport>[mockTransport];
  });

  tearDown(() {
    Faro.resetForTesting();
    BatchTransportFactory().reset();
  });

  testWidgets('cancels action when no follow-up rebuild occurs', (
    tester,
  ) async {
    await initializeFaro();
    final controller = _RebuildController();
    await tester.pumpWidget(
      MaterialApp(home: _RebuildHarness(controller: controller)),
    );
    await tester.pump();

    final action = faro.startUserAction('ua-no-followup');
    expect(action, isNotNull);

    await tester.pump(const Duration(milliseconds: 140));

    expect(action!.getState(), UserActionState.cancelled);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ends action for a real rebuild after start', (tester) async {
    await initializeFaro();
    final controller = _RebuildController();
    await tester.pumpWidget(
      MaterialApp(home: _RebuildHarness(controller: controller)),
    );
    await tester.pump();

    final action = faro.startUserAction('ua-single-rebuild');
    expect(action, isNotNull);

    controller.triggerRebuild();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    expect(action!.getState(), UserActionState.ended);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('continuous animation does not keep action alive indefinitely', (
    tester,
  ) async {
    await initializeFaro();
    final controller = _RebuildController();
    await tester.pumpWidget(
      MaterialApp(
        home: _RebuildHarness(
          controller: controller,
          enableContinuousAnimation: true,
        ),
      ),
    );
    await tester.pump();

    final action = faro.startUserAction('ua-spinner');
    expect(action, isNotNull);

    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(action!.getState(), UserActionState.ended);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
