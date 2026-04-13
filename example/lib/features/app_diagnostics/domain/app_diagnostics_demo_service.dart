import 'package:faro_example/shared/models/demo_log_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef AppDiagnosticsLogCallback = void Function(
  String message, {
  DemoLogTone tone,
});

final appDiagnosticsDemoServiceProvider = Provider<AppDiagnosticsDemoService>(
  (ref) => const AppDiagnosticsDemoService(),
);

/// Runs the error and ANR demos shown in the example app.
class AppDiagnosticsDemoService {
  const AppDiagnosticsDemoService();

  void triggerUnhandledError(AppDiagnosticsLogCallback log) {
    log(
      'Scheduling an unhandled Error on the async queue.',
      tone: DemoLogTone.warning,
    );

    Future<void>.delayed(const Duration(milliseconds: 10), () {
      throw UnsupportedError('This is an Error!');
    });
  }

  void triggerUnhandledException(AppDiagnosticsLogCallback log) {
    log(
      'Scheduling an unhandled Exception on the async queue.',
      tone: DemoLogTone.warning,
    );

    Future<void>.delayed(const Duration(milliseconds: 10), () {
      throw Exception('This is an Exception! ${DateTime.now()}');
    });
  }

  Future<void> simulateAnr({
    required int seconds,
    required AppDiagnosticsLogCallback log,
  }) async {
    log(
      'Blocking the main thread for $seconds seconds.',
      tone: DemoLogTone.warning,
    );

    // Yield once so the warning can paint before the UI freezes.
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final startTime = DateTime.now();
    while (DateTime.now().difference(startTime).inSeconds < seconds) {
      for (int i = 0; i < 10000000; i++) {
        final _ = i * i * i;
      }
    }

    log(
      'ANR simulation completed after $seconds seconds.',
      tone: DemoLogTone.highlight,
    );
  }
}
