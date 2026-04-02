import 'package:faro/src/faro_widgets_binding_observer.dart';
import 'package:faro/src/models/event.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Faro lifecycle transport investigation:', () {
    test(
      'serialized lifecycle events preserve sub-millisecond timestamps',
      () async {
        final observer = FaroWidgetsBindingObserver();

        observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
        observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
        observer.didChangeAppLifecycleState(AppLifecycleState.paused);

        await Future<void>.delayed(Duration.zero);

        final lifecycleEvents = <Event>[
          Event('app_lifecycle_changed', attributes: {
            'fromState': '',
            'toState': 'inactive',
          }),
          Event('app_lifecycle_changed', attributes: {
            'fromState': 'inactive',
            'toState': 'hidden',
          }),
          Event('app_lifecycle_changed', attributes: {
            'fromState': 'hidden',
            'toState': 'paused',
          }),
        ].map((event) => event.toJson()).toList();

        expect(lifecycleEvents, hasLength(3));
        expect(
          lifecycleEvents.map((event) => event['timestamp']),
          everyElement(
            matches(
              RegExp(
                r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z$',
              ),
            ),
          ),
        );
        expect(
          lifecycleEvents.map((event) => event['timestamp']).toSet().length,
          equals(3),
        );
      },
    );
  });
}
