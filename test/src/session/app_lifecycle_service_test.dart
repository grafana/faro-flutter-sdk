import 'package:faro/src/session/app_lifecycle_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLifecycleService:', () {
    test('defaults to foreground', () {
      expect(AppLifecycleService().isInForeground, isTrue);
    });

    test('resumed counts as foreground', () {
      final service = AppLifecycleService()
        ..updateFromLifecycleState(AppLifecycleState.paused);
      expect(service.isInForeground, isFalse);

      service.updateFromLifecycleState(AppLifecycleState.resumed);
      expect(service.isInForeground, isTrue);
    });

    test('inactive, paused, hidden and detached count as background', () {
      final service = AppLifecycleService();
      for (final state in const [
        AppLifecycleState.inactive,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.detached,
      ]) {
        service
          ..updateFromLifecycleState(AppLifecycleState.resumed)
          ..updateFromLifecycleState(state);
        expect(
          service.isInForeground,
          isFalse,
          reason: '$state should be treated as background',
        );
      }
    });
  });
}
