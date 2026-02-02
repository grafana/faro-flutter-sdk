import 'dart:async';
import 'dart:math';

import 'package:faro/faro.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Callback type for logging messages during span operations.
typedef LogCallback = void Function(String message, {bool isError});

/// Service that encapsulates all tracing/span operations.
///
/// This separates the business logic of creating and managing spans
/// from the UI layer, making it easier to test and maintain.
class TracingService {
  const TracingService();

  /// Runs a simple span with minimal configuration.
  Future<void> runSimpleSpan(LogCallback log) async {
    log('Starting simple span...');

    try {
      final result = await Faro().startSpan<String>(
        'simple-test-span',
        (span) async {
          log('Inside span, doing work...');
          await Future.delayed(const Duration(milliseconds: 500));
          span.addEvent('work-completed');
          return 'success';
        },
      );
      log('Span completed with result: $result');
    } catch (error) {
      log('Error: $error', isError: true);
    }
  }

  /// Runs a span with string attributes.
  Future<void> runSpanWithStringAttributes(LogCallback log) async {
    log('Starting span with string attributes...');

    try {
      await Faro().startSpan<void>(
        'string-attributes-span',
        (span) async {
          span.setAttributes({
            'user.name': 'John Doe',
            'user.email': 'john@example.com',
            'action': 'test-action',
          });
          span.addEvent('user-action', attributes: {
            'button': 'submit',
            'page': 'checkout',
          });
          await Future.delayed(const Duration(milliseconds: 300));
        },
        attributes: {
          'environment': 'test',
          'version': '1.0.0',
        },
      );
      log('String attributes span completed');
    } catch (error) {
      log('Error: $error', isError: true);
    }
  }

  /// Runs a span with typed attributes (int, double, bool).
  Future<void> runSpanWithTypedAttributes(LogCallback log) async {
    log('Starting span with TYPED attributes (int, double, bool)...');

    final random = Random();
    final accountCount = random.nextInt(100) + 1;
    final balance = random.nextDouble() * 10000;
    final isPremium = random.nextBool();

    try {
      await Faro().startSpan<void>(
        'typed-attributes-span',
        (span) async {
          // Set typed attributes on the span
          span.setAttributes({
            'user.account_count': accountCount, // int
            'user.balance': balance, // double
            'user.is_premium': isPremium, // bool
            'user.name': 'Test User', // string
          });

          log('Set attributes: account_count=$accountCount (int)');
          log(
            'Set attributes: balance=${balance.toStringAsFixed(2)} (double)',
          );
          log('Set attributes: is_premium=$isPremium (bool)');

          // Add event with typed attributes
          span.addEvent('purchase-completed', attributes: {
            'item_count': random.nextInt(10) + 1,
            'total_amount': random.nextDouble() * 500,
            'used_coupon': random.nextBool(),
            'payment_method': 'credit_card',
          });

          await Future.delayed(const Duration(milliseconds: 400));
        },
        attributes: {
          'request.id': random.nextInt(999999),
          'request.priority': random.nextDouble(),
        },
      );
      log('Typed attributes span completed successfully!');
    } catch (error) {
      log('Error: $error', isError: true);
    }
  }

  /// Runs a manual span where you control when it ends.
  Future<void> runManualSpan(LogCallback log) async {
    log('Starting manual span (you control when it ends)...');

    try {
      final span = Faro().startSpanManual(
        'manual-control-span',
        attributes: {
          'manual': true,
          'start_time_ms': DateTime.now().millisecondsSinceEpoch,
        },
      );

      log('Manual span started, waiting 1 second...');
      await Future.delayed(const Duration(seconds: 1));

      span.setAttribute('duration_planned_ms', 1000);
      span.addEvent('checkpoint-1', attributes: {'progress': 50});

      await Future.delayed(const Duration(milliseconds: 500));

      span.addEvent('checkpoint-2', attributes: {'progress': 100});
      span.setStatus(SpanStatusCode.ok, message: 'Completed successfully');
      span.end();

      log('Manual span ended after ~1.5 seconds');
    } catch (error) {
      log('Error: $error', isError: true);
    }
  }

  /// Runs nested spans to demonstrate parent-child relationships.
  Future<void> runNestedSpans(LogCallback log) async {
    log('Starting nested spans demo...');

    try {
      await Faro().startSpan<void>(
        'parent-span',
        (parentSpan) async {
          log('Parent span started');
          parentSpan.setAttributes({'level': 0, 'type': 'parent'});

          await Faro().startSpan<void>(
            'child-span-1',
            (childSpan) async {
              log('  Child span 1 started');
              childSpan.setAttributes({'level': 1, 'type': 'child'});
              await Future.delayed(const Duration(milliseconds: 200));
              log('  Child span 1 completed');
            },
          );

          await Faro().startSpan<void>(
            'child-span-2',
            (childSpan) async {
              log('  Child span 2 started');
              childSpan.setAttributes({
                'level': 1,
                'items_processed': 42,
                'success_rate': 0.95,
              });
              await Future.delayed(const Duration(milliseconds: 300));
              log('  Child span 2 completed');
            },
          );

          log('Parent span completing');
        },
        attributes: {'test_type': 'nested'},
      );
      log('All nested spans completed');
    } catch (error) {
      log('Error: $error', isError: true);
    }
  }

  /// Runs a span that records an error.
  Future<void> runSpanWithError(LogCallback log) async {
    log('Starting span that will record an error...');

    try {
      await Faro().startSpan<void>(
        'error-demo-span',
        (span) async {
          span.setAttributes({
            'operation': 'risky-operation',
            'attempt': 1,
          });

          await Future.delayed(const Duration(milliseconds: 200));

          // Record an exception
          try {
            throw Exception('Simulated error for testing');
          } catch (error, stackTrace) {
            span.recordException(error, stackTrace: stackTrace);
            span.setStatus(SpanStatusCode.error, message: 'Operation failed');
            log('Recorded exception in span');
          }
        },
      );
      log('Error span completed (error was recorded, not thrown)');
    } catch (error) {
      log('Unexpected error: $error', isError: true);
    }
  }

  /// Demonstrates Span.noParent for independent traces.
  ///
  /// Shows how to start a new trace that ignores the active span in context.
  /// Useful for timer callbacks or when you want independent traces.
  Future<void> runSpanWithNoParent(LogCallback log) async {
    log('Starting Span.noParent demo...');
    log('This shows how to start independent traces.');

    try {
      await Faro().startSpan<void>(
        'outer-context-span',
        (outerSpan) async {
          outerSpan.setAttributes({'type': 'outer-context'});
          log('Outer span started (traceId: ${outerSpan.traceId.substring(0, 8)}...)');

          // Simulate a "timer callback" scenario
          // In real code, this might be Timer.periodic or a stream listener
          log('Simulating timer callback scenario...');
          await Future.delayed(const Duration(milliseconds: 300));

          // WITHOUT Span.noParent - would inherit outer span as parent
          await Faro().startSpan<void>(
            'child-with-parent',
            (childSpan) async {
              log('  Child WITH parent (traceId: ${childSpan.traceId.substring(0, 8)}...)');
              log('  ^ Same traceId = same trace');
              await Future.delayed(const Duration(milliseconds: 200));
            },
          );

          // WITH Span.noParent - starts a completely new trace
          await Faro().startSpan<void>(
            'independent-trace',
            (independentSpan) async {
              independentSpan.setAttributes({
                'type': 'independent',
                'reason': 'timer-callback',
              });
              log('  Independent span (traceId: ${independentSpan.traceId.substring(0, 8)}...)');
              log('  ^ Different traceId = new trace!');
              await Future.delayed(const Duration(milliseconds: 200));
            },
            parentSpan: Span.noParent,
          );

          log('Outer span completing');
        },
      );
      log('Span.noParent demo completed!');
      log('Check backend: you should see 2 separate traces.');
    } catch (error) {
      log('Error: $error', isError: true);
    }
  }

  /// Demonstrates ContextScope for controlling span context lifetime.
  ///
  /// Shows the difference between ContextScope.callback (default) and
  /// ContextScope.zone for timer/async operations.
  Future<void> runContextScopeDemo(LogCallback log) async {
    log('Starting ContextScope demo...');
    log('');
    log('ContextScope controls whether timer callbacks inherit the parent span.');
    log('');

    try {
      // Demo 1: Default behavior (ContextScope.callback)
      log('--- Demo 1: ContextScope.callback (default) ---');
      log('Timer callbacks will NOT inherit the parent span.');

      String? parentTraceId1;
      String? timerSpanTraceId1;
      final completer1 = Completer<void>();

      await Faro().startSpan<void>(
        'parent-callback-scope',
        (parentSpan) async {
          parentTraceId1 = parentSpan.traceId;
          log('Parent span started (traceId: ${parentSpan.traceId.substring(0, 8)}...)');

          // Schedule a timer that fires after parent callback ends
          Timer(const Duration(milliseconds: 100), () async {
            await Faro().startSpan<void>(
              'timer-child-callback',
              (timerSpan) async {
                timerSpanTraceId1 = timerSpan.traceId;
                log('  Timer span (traceId: ${timerSpan.traceId.substring(0, 8)}...)');
              },
            );
            completer1.complete();
          });

          await Future.delayed(const Duration(milliseconds: 50));
          log('Parent callback ending...');
        },
        // contextScope: ContextScope.callback, // This is the default
      );

      await completer1.future;
      if (timerSpanTraceId1 != parentTraceId1) {
        log('Result: Timer span has DIFFERENT traceId = new trace');
      } else {
        log('Result: Timer span has SAME traceId (unexpected)');
      }
      log('');

      // Demo 2: Zone scope (ContextScope.zone)
      log('--- Demo 2: ContextScope.zone ---');
      log('Timer callbacks WILL inherit the parent span.');

      String? parentTraceId;
      String? timerSpanTraceId2;
      final completer2 = Completer<void>();

      await Faro().startSpan<void>(
        'parent-zone-scope',
        (parentSpan) async {
          parentTraceId = parentSpan.traceId;
          log('Parent span started (traceId: ${parentSpan.traceId.substring(0, 8)}...)');

          // Schedule a timer that fires after parent callback ends
          Timer(const Duration(milliseconds: 100), () async {
            await Faro().startSpan<void>(
              'timer-child-zone',
              (timerSpan) async {
                timerSpanTraceId2 = timerSpan.traceId;
                log('  Timer span (traceId: ${timerSpan.traceId.substring(0, 8)}...)');
              },
            );
            completer2.complete();
          });

          await Future.delayed(const Duration(milliseconds: 50));
          log('Parent callback ending...');
        },
        contextScope: ContextScope.zone, // Keep span active for timer
      );

      await completer2.future;

      if (timerSpanTraceId2 == parentTraceId) {
        log('Result: Timer span has SAME traceId = child of parent!');
      } else {
        log('Result: Timer span traceId differs (unexpected)');
      }

      log('');
      log('ContextScope demo completed!');
      log('Use ContextScope.zone when you want timer/stream callbacks');
      log('to be children of the parent span.');
    } catch (error) {
      log('Error: $error', isError: true);
    }
  }
}

// =============================================================================
// Provider
// =============================================================================

/// Provider for the TracingService.
final tracingServiceProvider = Provider<TracingService>((ref) {
  return const TracingService();
});
