import 'package:flutter_test/flutter_test.dart';
import 'package:rum_sdk/src/models/models.dart';

void main() {
  group('DeviceId:', () {
    test('should return the value when printed', () {
      final deviceId = DeviceId('test_device_id');
      final printedDeviceId = '$deviceId';
      expect(printedDeviceId, 'test_device_id');
    });
  });
}
