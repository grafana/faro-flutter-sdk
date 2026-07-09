import 'package:faro/src/session/app_lifecycle_service.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_activity_policy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SessionActivityPolicy:', () {
    late AppLifecycleService lifecycle;
    late SessionActivityPolicy policy;

    setUp(() {
      lifecycle = AppLifecycleService();
      policy = SessionActivityPolicy(lifecycle);
    });

    test('active always records activity, even when backgrounded', () {
      lifecycle.updateFromLifecycleState(AppLifecycleState.paused);
      expect(policy.recordsActivity(SessionActivityKind.active), isTrue);
    });

    test('none never records activity, even when foregrounded', () {
      lifecycle.updateFromLifecycleState(AppLifecycleState.resumed);
      expect(policy.recordsActivity(SessionActivityKind.none), isFalse);
    });

    test('foregroundOnly records activity only while in the foreground', () {
      lifecycle.updateFromLifecycleState(AppLifecycleState.resumed);
      expect(
        policy.recordsActivity(SessionActivityKind.foregroundOnly),
        isTrue,
      );

      lifecycle.updateFromLifecycleState(AppLifecycleState.paused);
      expect(
        policy.recordsActivity(SessionActivityKind.foregroundOnly),
        isFalse,
      );
    });
  });
}
