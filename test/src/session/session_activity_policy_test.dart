import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_activity_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SessionActivityPolicy:', () {
    late SessionActivityPolicy policy;

    setUp(() {
      policy = SessionActivityPolicy();
    });

    test('meaningful work records activity', () {
      expect(policy.recordsActivity(SessionActivityKind.meaningful), isTrue);
    });

    test('passive telemetry does not record activity', () {
      expect(policy.recordsActivity(SessionActivityKind.passive), isFalse);
    });
  });
}
