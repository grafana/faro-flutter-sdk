import 'package:faro/faro.dart';
import 'package:faro_example/shared/models/demo_log_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef CustomTelemetryLogCallback = void Function(
  String message, {
  DemoLogTone tone,
});

final customTelemetryDemoServiceProvider = Provider<CustomTelemetryDemoService>(
  (ref) => const CustomTelemetryDemoService(),
);

/// Runs the custom telemetry demos shown in the example app.
class CustomTelemetryDemoService {
  const CustomTelemetryDemoService();

  void emitWarnLog(CustomTelemetryLogCallback log) {
    Faro().pushLog('Custom Warning Log', level: LogLevel.warn);
    log('Sent warn log: Custom Warning Log', tone: DemoLogTone.warning);
  }

  void emitInfoLog(CustomTelemetryLogCallback log) {
    Faro().pushLog('This is an info message', level: LogLevel.info);
    log('Sent info log: This is an info message', tone: DemoLogTone.info);
  }

  void emitErrorLog(CustomTelemetryLogCallback log) {
    Faro().pushLog('This is an error message', level: LogLevel.error);
    log('Sent error log: This is an error message', tone: DemoLogTone.error);
  }

  void emitDebugLog(CustomTelemetryLogCallback log) {
    Faro().pushLog('This is a debug message', level: LogLevel.debug);
    log('Sent debug log: This is a debug message', tone: DemoLogTone.neutral);
  }

  void emitTraceLog(CustomTelemetryLogCallback log) {
    Faro().pushLog('This is a trace message', level: LogLevel.trace);
    log('Sent trace log: This is a trace message', tone: DemoLogTone.neutral);
  }

  void emitMeasurement(CustomTelemetryLogCallback log) {
    Faro().pushMeasurement({'custom_value': 1}, 'custom_measurement');
    log(
      'Sent measurement: custom_measurement {custom_value: 1}',
      tone: DemoLogTone.highlight,
    );
  }

  void emitEvent(CustomTelemetryLogCallback log) {
    Faro().pushEvent('custom_event');
    log('Sent event: custom_event', tone: DemoLogTone.highlight);
  }

  bool toggleDataCollection(CustomTelemetryLogCallback log) {
    Faro().enableDataCollection = !Faro().enableDataCollection;
    final isEnabled = Faro().enableDataCollection;

    log(
      isEnabled
          ? 'Data collection enabled for the current session.'
          : 'Data collection disabled for the current session.',
      tone: DemoLogTone.info,
    );

    return isEnabled;
  }
}
