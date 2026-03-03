import 'package:faro/src/models/event.dart';
import 'package:faro/src/models/exception.dart';
import 'package:faro/src/models/log.dart';
import 'package:faro/src/models/user_action_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserActionContext:', () {
    test('should round-trip JSON with id', () {
      const context = UserActionContext(
        name: 'checkout',
        id: 'action-123',
      );

      final decoded = UserActionContext.fromJson(context.toJson());

      expect(decoded.name, equals('checkout'));
      expect(decoded.id, equals('action-123'));
      expect(decoded.parentId, isNull);
    });

    test('should round-trip JSON with parentId', () {
      const context = UserActionContext(
        name: 'checkout',
        parentId: 'action-123',
      );

      final decoded = UserActionContext.fromJson(context.toJson());

      expect(decoded.name, equals('checkout'));
      expect(decoded.parentId, equals('action-123'));
      expect(decoded.id, isNull);
    });
  });

  group('action model serialization:', () {
    test('Event should serialize and deserialize action context', () {
      final event = Event('button_click');
      event.action = const UserActionContext(
        name: 'checkout',
        parentId: 'action-123',
      );

      final decoded = Event.fromJson(event.toJson());

      expect(decoded.action, isNotNull);
      expect(decoded.action!.name, equals('checkout'));
      expect(decoded.action!.parentId, equals('action-123'));
    });

    test('FaroLog should serialize and deserialize action context', () {
      final log = FaroLog('clicked');
      log.action = const UserActionContext(
        name: 'checkout',
        parentId: 'action-123',
      );

      final decoded = FaroLog.fromJson(log.toJson());

      expect(decoded.action, isNotNull);
      expect(decoded.action!.name, equals('checkout'));
      expect(decoded.action!.parentId, equals('action-123'));
    });

    test('FaroException should serialize and deserialize action context', () {
      final exception = FaroException('type', 'value', null);
      exception.action = const UserActionContext(
        name: 'checkout',
        parentId: 'action-123',
      );

      final decoded = FaroException.fromJson(exception.toJson());

      expect(decoded.action, isNotNull);
      expect(decoded.action!.name, equals('checkout'));
      expect(decoded.action!.parentId, equals('action-123'));
    });
  });
}
