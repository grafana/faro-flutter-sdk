import 'package:faro/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceId:', () {
    test('should stay available as a backwards-compatible alias', () {
      final deviceId = DeviceId('legacy_device_id');
      final printedDeviceId = '$deviceId';
      expect(printedDeviceId, 'legacy_device_id');
    });
  });
}
