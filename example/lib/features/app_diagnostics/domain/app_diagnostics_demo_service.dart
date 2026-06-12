import 'package:faro/faro.dart';
import 'package:faro_example/shared/models/demo_log_entry.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef AppDiagnosticsLogCallback =
    void Function(String message, {DemoLogTone tone});

final appDiagnosticsDemoServiceProvider = Provider<AppDiagnosticsDemoService>(
  (ref) => const AppDiagnosticsDemoService(),
);

/// Runs the error and ANR demos shown in the example app.
class AppDiagnosticsDemoService {
  const AppDiagnosticsDemoService();

  static const MethodChannel _crashChannel = MethodChannel(
    'faro_example/crash',
  );

  /// Triggers a native crash (force-unwrap of nil on iOS, null dereference
  /// on Android) to validate the SDK's native crash reporting. The process
  /// terminates; the crash is reported on the next launch.
  Future<void> triggerNativeCrash(AppDiagnosticsLogCallback log) async {
    log(
      'Triggering a native crash. The app will terminate; relaunch to '
      'let the SDK report it.',
      tone: DemoLogTone.warning,
    );

    // Yield so the warning can paint before the process dies.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await _crashChannel.invokeMethod<void>('crashNative');
  }

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

  void pushCustomTraceError(AppDiagnosticsLogCallback log) {
    log(
      'Pushing an error with a non-standard stack trace.',
      tone: DemoLogTone.warning,
    );

    // A stack trace in a format Faro does not natively parse: a normal
    // Dart frame, a token with no spaces (which previously crashed the
    // parser), a stack_trace-package line, and a free-form note. See #102.
    final customTrace = StackTrace.fromString(
      '#0      MyWidget.build '
      '(package:my_app/widgets/my_widget.dart:42:13)\n'
      'sanitized_frame_without_spaces\n'
      'package:my_app/foo.dart 10:5  Foo.bar\n'
      'some free-form diagnostic note',
    );

    Faro().pushError(
      type: 'custom_stacktrace_demo',
      value: 'Custom-trace error ${DateTime.now()}',
      stacktrace: customTrace,
    );
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
