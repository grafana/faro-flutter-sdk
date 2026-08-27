import 'package:faro/src/models/log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FaroLog:', () {
    group('trace serialization:', () {
      test('toJson includes trace when set and fromJson reads it back', () {
        final log = FaroLog(
          'clicked',
          trace: const {'trace_id': 'trace-1', 'span_id': 'span-1'},
        );

        final json = log.toJson();
        expect(
          json['trace'],
          equals({'trace_id': 'trace-1', 'span_id': 'span-1'}),
        );

        final decoded = FaroLog.fromJson(json);
        expect(
          decoded.trace,
          equals({'trace_id': 'trace-1', 'span_id': 'span-1'}),
        );
      });

      test('toJson omits trace when null', () {
        final log = FaroLog('clicked');

        expect(log.trace, isNull);
        expect(log.toJson().containsKey('trace'), isFalse);
      });

      test('toJson omits trace when empty', () {
        final log = FaroLog('clicked', trace: const {});

        expect(log.toJson().containsKey('trace'), isFalse);
      });
    });
  });
}
