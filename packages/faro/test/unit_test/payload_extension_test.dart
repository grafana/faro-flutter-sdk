// ignore_for_file: avoid_positional_boolean_parameters, use_setters_to_change_properties, lines_longer_than_80_chars

import 'package:faro/faro_sdk.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/util/payload_extension.dart';
import 'package:flutter_test/flutter_test.dart';

class MockTraces extends Traces {
  bool _hasTraces = false;

  @override
  bool hasNoTraces() {
    return !_hasTraces;
  }

  void setHasTraces(bool value) {
    _hasTraces = value;
  }
}

void main() {
  group('PayloadX:', () {
    test('isEmpty returns true when all collections are empty', () {
      final payload = Payload(Meta());
      expect(payload.isEmpty(), true);
    });

    test('isEmpty returns false when events is not empty', () {
      final payload = Payload(Meta());
      payload.events.add(Event('test_event'));
      expect(payload.isEmpty(), false);
    });

    test('isEmpty returns false when measurements is not empty', () {
      final payload = Payload(Meta());
      payload.measurements.add(Measurement({'value': 1}, 'test_type'));
      expect(payload.isEmpty(), false);
    });

    test('isEmpty returns false when logs is not empty', () {
      final payload = Payload(Meta());
      payload.logs.add(FaroLog('test_message'));
      expect(payload.isEmpty(), false);
    });

    test('isEmpty returns false when exceptions is not empty', () {
      final payload = Payload(Meta());
      payload.exceptions.add(FaroException(
        'test_type',
        'test_value',
        {'frames': <String>[]},
      ));
      expect(payload.isEmpty(), false);
    });

    test('isEmpty returns false when traces has traces', () {
      final payload = Payload(Meta());
      final mockTraces = MockTraces();
      mockTraces.setHasTraces(true);
      payload.traces = mockTraces;
      expect(payload.isEmpty(), false);
    });

    test('isEmpty returns true when traces has no traces', () {
      final payload = Payload(Meta());
      final mockTraces = MockTraces();
      mockTraces.setHasTraces(false);
      payload.traces = mockTraces;
      expect(payload.isEmpty(), true);
    });
  });
}
