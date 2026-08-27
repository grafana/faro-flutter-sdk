import 'package:faro/src/models/event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Event:', () {
    group('trace serialization:', () {
      test('toJson includes trace when set and fromJson reads it back', () {
        final event = Event(
          'button_click',
          trace: const {'trace_id': 'trace-1', 'span_id': 'span-1'},
        );

        final json = event.toJson();
        expect(
          json['trace'],
          equals({'trace_id': 'trace-1', 'span_id': 'span-1'}),
        );

        final decoded = Event.fromJson(json);
        expect(
          decoded.trace,
          equals({'trace_id': 'trace-1', 'span_id': 'span-1'}),
        );
      });

      test('toJson omits trace when null', () {
        final event = Event('button_click');

        expect(event.trace, isNull);
        expect(event.toJson().containsKey('trace'), isFalse);
      });

      test('toJson omits trace when empty', () {
        final event = Event('button_click', trace: const {});

        expect(event.toJson().containsKey('trace'), isFalse);
      });
    });
  });
}
